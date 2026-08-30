from __future__ import annotations

from dataclasses import asdict, dataclass
import math
from typing import Any, Sequence

import numpy as np

from .angles import joint_angle
LEFT_SHOULDER = 5
RIGHT_SHOULDER = 6
LEFT_ELBOW = 7
RIGHT_ELBOW = 8
LEFT_WRIST = 9
RIGHT_WRIST = 10
LEFT_HIP = 11
RIGHT_HIP = 12
LEFT_KNEE = 13
RIGHT_KNEE = 14


LEFT_ARM = (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST)
RIGHT_ARM = (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST)
LEFT_LEG = (LEFT_HIP, LEFT_KNEE, 15)
RIGHT_LEG = (RIGHT_HIP, RIGHT_KNEE, 16)


@dataclass(frozen=True)
class ChainQuality:
    side: str
    coverage: float
    mean_confidence: float
    anatomy_consistency: float
    temporal_continuity: float
    observed_endpoint_rate: float
    motion_signal: float
    body_scale_plausibility: float
    exercise_alignment: float
    score: float

    def to_result(self) -> dict[str, float | str]:
        result = asdict(self)
        return {
            key: round(value, 4) if isinstance(value, float) else value
            for key, value in result.items()
        }


@dataclass(frozen=True)
class PoseValidationMetrics:
    invalid_coordinates: int
    temporal_joint_spikes: int
    bone_length_outliers: int
    bilateral_occlusion_rejects: int
    selected_arm_side: str | None
    suppressed_arm_samples: int
    arm_qualities: tuple[ChainQuality, ...]


def validate_pose_sequence(
    samples: Sequence[Any],
    *,
    confidence_floor: float,
    exercise_id: str,
    camera: str,
    frame_width: int | None = None,
    frame_height: int | None = None,
) -> tuple[list[Any], PoseValidationMetrics]:
    """Reject implausible pose chains before endpoint recovery and scoring.

    Detector confidence describes how certain the neural network is about its
    own proposal.  It does not prove that an elbow belongs to the tracked arm.
    This pass therefore validates coordinates, bone-length stability and
    temporal continuity before an occluded wrist/ankle may be reconstructed.
    For a side-view clip, a single stable visible arm is preferred over drawing
    a second arm whose joints repeatedly collapse onto equipment or the face.
    """
    validated = [_copy_sample(sample) for sample in samples]
    if not validated:
        return [], PoseValidationMetrics(0, 0, 0, 0, None, 0, ())

    invalid = _reject_invalid_coordinates(
        validated,
        confidence_floor,
        frame_width,
        frame_height,
    )
    spikes = _reject_temporal_joint_spikes(validated, confidence_floor)
    bone_outliers = _reject_bone_length_outliers(validated, confidence_floor)

    # Lock the video-level visible side before removing local occlusion
    # conflicts.  Otherwise a handful of rejected plate-covered frames can
    # flip the selected side for the whole clip and erase otherwise valid
    # cycles.
    left_quality = chain_quality(
        validated,
        LEFT_ARM,
        confidence_floor,
        side="left",
        exercise_id=exercise_id,
    )
    right_quality = chain_quality(
        validated,
        RIGHT_ARM,
        confidence_floor,
        side="right",
        exercise_id=exercise_id,
    )
    bilateral_rejects = _reject_side_bench_bilateral_conflicts(
        validated,
        confidence_floor,
        exercise_id,
        camera,
    )
    selected_side: str | None = None
    suppressed = bilateral_rejects
    if _is_side_camera(camera):
        selected_side, globally_suppressed = _suppress_unreliable_side_arm(
            validated,
            left_quality,
            right_quality,
            confidence_floor,
            exercise_id,
        )
        suppressed += globally_suppressed

    return validated, PoseValidationMetrics(
        invalid_coordinates=invalid,
        temporal_joint_spikes=spikes,
        bone_length_outliers=bone_outliers,
        bilateral_occlusion_rejects=bilateral_rejects,
        selected_arm_side=selected_side,
        suppressed_arm_samples=suppressed,
        arm_qualities=(left_quality, right_quality),
    )


def chain_quality(
    samples: Sequence[Any],
    chain: tuple[int, int, int],
    floor: float,
    *,
    side: str,
    exercise_id: str = "",
) -> ChainQuality:
    proximal, joint, endpoint = chain
    complete = []
    proximal_visible = []
    confidences: list[float] = []
    ratios: list[float] = []
    body_ratios: list[float] = []
    angles: list[float] = []
    endpoint_observed = 0
    aligned = 0
    trajectory: list[tuple[int, np.ndarray, float]] = []

    for index, sample in enumerate(samples):
        if min(sample.scores[proximal], sample.scores[joint]) >= floor:
            proximal_visible.append(index)
            scale = _torso_scale(sample, floor)
            upper = float(np.linalg.norm(sample.points[proximal] - sample.points[joint]))
            if scale is not None and upper >= 4.0:
                body_ratios.append(upper / scale)
            trajectory.append((index, sample.points[joint].copy(), scale or max(upper, 1.0)))
        if min(sample.scores[index] for index in chain) < floor:
            continue
        complete.append(index)
        confidences.append(float(min(sample.scores[index] for index in chain)))
        upper = float(np.linalg.norm(sample.points[proximal] - sample.points[joint]))
        distal = float(np.linalg.norm(sample.points[endpoint] - sample.points[joint]))
        if upper >= 4.0 and distal >= 4.0:
            ratios.append(distal / upper)
        angles.append(joint_angle(*(sample.points[index] for index in chain)))
        inferred = sample.inferred is not None and bool(sample.inferred[endpoint])
        if not inferred:
            endpoint_observed += 1
        if _exercise_alignment_ok(sample, chain, floor, exercise_id):
            aligned += 1

    count = max(1, len(samples))
    coverage = len(complete) / count
    mean_confidence = float(np.mean(confidences)) if confidences else 0.0
    plausible_ratios = [ratio for ratio in ratios if 0.38 <= ratio <= 1.75]
    if ratios:
        median_ratio = float(np.median(ratios))
        dispersion = float(np.median(np.abs(np.asarray(ratios) - median_ratio)))
        ratio_stability = max(0.0, 1.0 - dispersion / max(0.20, median_ratio * 0.42))
        anatomy = len(plausible_ratios) / len(ratios) * ratio_stability
    else:
        anatomy = 0.0
    body_plausible = (
        sum(0.18 <= ratio <= 0.85 for ratio in body_ratios) / len(body_ratios)
        if body_ratios
        else 0.0
    )
    continuity = _trajectory_continuity(trajectory)
    endpoint_rate = endpoint_observed / len(complete) if complete else 0.0
    motion = (
        min(1.0, float(np.percentile(angles, 90) - np.percentile(angles, 10)) / 75.0)
        if len(angles) >= 5
        else 0.0
    )
    alignment = aligned / len(complete) if complete else 0.0
    is_bench = _normalise_exercise(exercise_id) in {
        "bench_press",
        "incline_bench_press",
        "decline_bench_press",
        "dumbbell_bench_press",
    }
    if is_bench:
        score = (
            0.16 * coverage
            + 0.10 * mean_confidence
            + 0.15 * anatomy
            + 0.15 * continuity
            + 0.05 * endpoint_rate
            + 0.08 * motion
            + 0.08 * body_plausible
            + 0.23 * alignment
        )
    else:
        score = (
            0.23 * coverage
            + 0.14 * mean_confidence
            + 0.19 * anatomy
            + 0.18 * continuity
            + 0.07 * endpoint_rate
            + 0.09 * motion
            + 0.10 * body_plausible
        )
    return ChainQuality(
        side=side,
        coverage=coverage,
        mean_confidence=mean_confidence,
        anatomy_consistency=anatomy,
        temporal_continuity=continuity,
        observed_endpoint_rate=endpoint_rate,
        motion_signal=motion,
        body_scale_plausibility=body_plausible,
        exercise_alignment=alignment,
        score=float(score),
    )


def _copy_sample(sample: Any) -> Any:
    return type(sample)(
        timestamp_ms=sample.timestamp_ms,
        source_frame_index=sample.source_frame_index,
        points=sample.points.copy(),
        scores=sample.scores.copy(),
        inferred=(
            sample.inferred.copy()
            if sample.inferred is not None
            else np.zeros(len(sample.scores), dtype=np.bool_)
        ),
    )


def _reject_invalid_coordinates(
    samples: Sequence[Any],
    floor: float,
    frame_width: int | None,
    frame_height: int | None,
) -> int:
    rejected = 0
    for sample in samples:
        for index, point in enumerate(sample.points):
            valid = bool(np.all(np.isfinite(point)))
            if valid and frame_width is not None and frame_height is not None:
                valid = (
                    0.0 <= float(point[0]) < float(frame_width)
                    and 0.0 <= float(point[1]) < float(frame_height)
                )
            if valid or sample.scores[index] < floor:
                continue
            sample.scores[index] = min(float(sample.scores[index]), max(0.05, floor * 0.4))
            rejected += 1
    return rejected


def _reject_temporal_joint_spikes(
    samples: Sequence[Any],
    floor: float,
    max_gap_ms: int = 360,
) -> int:
    rejected = 0
    for landmark in range(5, 17):
        for index in range(1, len(samples) - 1):
            previous = samples[index - 1]
            current = samples[index]
            following = samples[index + 1]
            if (
                min(
                    previous.scores[landmark],
                    current.scores[landmark],
                    following.scores[landmark],
                )
                < floor
            ):
                continue
            if (
                current.timestamp_ms - previous.timestamp_ms > max_gap_ms
                or following.timestamp_ms - current.timestamp_ms > max_gap_ms
            ):
                continue
            scale = _torso_scale(current, floor)
            if scale is None:
                continue
            neighbor_gap = float(
                np.linalg.norm(previous.points[landmark] - following.points[landmark])
            ) / scale
            midpoint = (previous.points[landmark] + following.points[landmark]) * 0.5
            deviation = float(np.linalg.norm(current.points[landmark] - midpoint)) / scale
            if neighbor_gap > 0.42 or deviation <= 0.72:
                continue
            current.scores[landmark] = min(
                float(current.scores[landmark]), max(0.06, floor * 0.45)
            )
            rejected += 1
    return rejected


def _reject_bone_length_outliers(samples: Sequence[Any], floor: float) -> int:
    rejected = 0
    for proximal, distal, endpoint_segment in (
        (LEFT_SHOULDER, LEFT_ELBOW, False),
        (RIGHT_SHOULDER, RIGHT_ELBOW, False),
        (LEFT_ELBOW, LEFT_WRIST, True),
        (RIGHT_ELBOW, RIGHT_WRIST, True),
        (LEFT_HIP, LEFT_KNEE, False),
        (RIGHT_HIP, RIGHT_KNEE, False),
        (LEFT_KNEE, 15, True),
        (RIGHT_KNEE, 16, True),
    ):
        observed: list[tuple[int, float]] = []
        for index, sample in enumerate(samples):
            if min(sample.scores[proximal], sample.scores[distal]) < floor:
                continue
            length = float(np.linalg.norm(sample.points[proximal] - sample.points[distal]))
            if np.isfinite(length) and length >= 4.0:
                observed.append((index, length))
        if len(observed) < 7:
            continue
        lengths = np.asarray([length for _, length in observed], dtype=np.float32)
        median = float(np.median(lengths))
        lower = max(4.0, median * 0.48)
        upper = median * 1.90
        for index, length in observed:
            if lower <= length <= upper:
                continue
            # In a 2D image an upper arm or thigh can become very short when
            # it points toward the camera.  Record that instability, but do
            # not erase the elbow/knee merely because of foreshortening.  The
            # distal wrist/ankle may still be downgraded and reconstructed.
            if not endpoint_segment:
                rejected += 1
                continue
            sample = samples[index]
            sample.scores[distal] = min(
                float(sample.scores[distal]), max(0.06, floor * 0.45)
            )
            rejected += 1
    return rejected


def _reject_side_bench_bilateral_conflicts(
    samples: Sequence[Any],
    floor: float,
    exercise_id: str,
    camera: str,
) -> int:
    """Drop the arm that contradicts the clearly visible arm in side bench video.

    A plate often hides one elbow and wrist while the pose model still returns
    high-confidence points on the plate or face.  Confidence and bone length
    can both look plausible, but the two forearms then disagree by 40-80
    degrees.  A true bilateral asymmetry is evaluated from a front/rear view;
    in a side view this disagreement is evidence of occlusion, not a safe basis
    for grading the athlete.
    """
    if not _is_side_camera(camera) or _normalise_exercise(exercise_id) not in {
        "bench_press",
        "incline_bench_press",
        "decline_bench_press",
        "dumbbell_bench_press",
        "close_grip_bench_press",
        "wide_grip_bench_press",
    }:
        return 0

    rejected = 0
    for sample in samples:
        if min(sample.scores[index] for index in (*LEFT_ARM, *RIGHT_ARM)) < floor:
            continue
        left = _vertical_deviation(
            sample.points[LEFT_ELBOW], sample.points[LEFT_WRIST]
        )
        right = _vertical_deviation(
            sample.points[RIGHT_ELBOW], sample.points[RIGHT_WRIST]
        )
        if left >= 40.0 and right >= 40.0:
            # With a straight bar, two forearms cannot both swing this far
            # sideways in a true side view without the bar geometry becoming
            # impossible. This is the characteristic "triangle on the plate"
            # hallucination; showing no arm is safer than drawing it as fact.
            rejected += _downgrade_chain(sample, LEFT_ELBOW, LEFT_WRIST, floor)
            rejected += _downgrade_chain(sample, RIGHT_ELBOW, RIGHT_WRIST, floor)
        elif left <= 22.0 and right >= 50.0 and right - left >= 35.0:
            rejected += _downgrade_chain(sample, RIGHT_ELBOW, RIGHT_WRIST, floor)
        elif right <= 22.0 and left >= 50.0 and left - right >= 35.0:
            rejected += _downgrade_chain(sample, LEFT_ELBOW, LEFT_WRIST, floor)
    return rejected


def _vertical_deviation(elbow: np.ndarray, endpoint: np.ndarray) -> float:
    delta = endpoint - elbow
    return math.degrees(math.atan2(abs(float(delta[0])), max(1e-6, abs(float(delta[1])))))


def _downgrade_chain(sample: Any, joint: int, endpoint: int, floor: float) -> int:
    changed = int(sample.scores[joint] >= floor or sample.scores[endpoint] >= floor)
    rejected_score = max(0.05, floor * 0.40)
    sample.scores[joint] = min(float(sample.scores[joint]), rejected_score)
    sample.scores[endpoint] = min(float(sample.scores[endpoint]), rejected_score)
    return changed


def _suppress_unreliable_side_arm(
    samples: Sequence[Any],
    left: ChainQuality,
    right: ChainQuality,
    floor: float,
    exercise_id: str,
) -> tuple[str | None, int]:
    selected, other = (left, right) if left.score >= right.score else (right, left)
    if selected.coverage < 0.08:
        return None, 0
    is_bench = _normalise_exercise(exercise_id) in {
        "bench_press",
        "incline_bench_press",
        "decline_bench_press",
        "dumbbell_bench_press",
    }
    unreliable_other = (
        selected.score - other.score >= 0.035
        or selected.temporal_continuity - other.temporal_continuity >= 0.15
        or selected.anatomy_consistency - other.anatomy_consistency >= 0.18
        or (
            is_bench
            and selected.exercise_alignment - other.exercise_alignment >= 0.10
        )
    )
    if not unreliable_other and not is_bench:
        return selected.side, 0

    chain = RIGHT_ARM if other.side == "right" else LEFT_ARM
    suppressed = 0
    for sample in samples:
        changed = False
        for landmark in chain[1:]:
            if sample.scores[landmark] >= floor:
                changed = True
            sample.scores[landmark] = min(
                float(sample.scores[landmark]), max(0.05, floor * 0.40)
            )
        if changed:
            suppressed += 1
    return selected.side, suppressed


def _trajectory_continuity(
    trajectory: Sequence[tuple[int, np.ndarray, float]],
) -> float:
    if len(trajectory) < 3:
        return 0.0
    jumps: list[float] = []
    for previous, current in zip(trajectory, trajectory[1:]):
        previous_index, previous_point, previous_scale = previous
        current_index, current_point, current_scale = current
        if current_index - previous_index > 3:
            continue
        scale = max(8.0, (previous_scale + current_scale) * 0.5)
        jumps.append(float(np.linalg.norm(current_point - previous_point)) / scale)
    if not jumps:
        return 0.0
    array = np.asarray(jumps, dtype=np.float32)
    smooth_fraction = float(np.mean(array <= 0.48))
    median_penalty = min(1.0, float(np.median(array)) / 0.36)
    return max(0.0, 0.72 * smooth_fraction + 0.28 * (1.0 - median_penalty))


def _torso_scale(sample: Any, floor: float) -> float | None:
    shoulder_points = [
        sample.points[index]
        for index in (LEFT_SHOULDER, RIGHT_SHOULDER)
        if sample.scores[index] >= floor
    ]
    hip_points = [
        sample.points[index]
        for index in (LEFT_HIP, RIGHT_HIP)
        if sample.scores[index] >= floor
    ]
    if not shoulder_points or not hip_points:
        return None
    shoulder = np.mean(shoulder_points, axis=0)
    hip = np.mean(hip_points, axis=0)
    scale = float(np.linalg.norm(hip - shoulder))
    return scale if np.isfinite(scale) and scale >= 8.0 else None


def _exercise_alignment_ok(
    sample: Any,
    chain: tuple[int, int, int],
    floor: float,
    exercise_id: str,
) -> bool:
    if _normalise_exercise(exercise_id) not in {
        "bench_press",
        "incline_bench_press",
        "decline_bench_press",
        "dumbbell_bench_press",
    }:
        return True
    shoulder, elbow, _ = chain
    shoulder_points = [
        sample.points[index]
        for index in (LEFT_SHOULDER, RIGHT_SHOULDER)
        if sample.scores[index] >= floor
    ]
    hip_points = [
        sample.points[index]
        for index in (LEFT_HIP, RIGHT_HIP)
        if sample.scores[index] >= floor
    ]
    if not shoulder_points or not hip_points:
        return False
    torso = np.mean(hip_points, axis=0) - np.mean(shoulder_points, axis=0)
    upper_arm = sample.points[elbow] - sample.points[shoulder]
    torso_length = float(np.linalg.norm(torso))
    arm_length = float(np.linalg.norm(upper_arm))
    if torso_length < 8.0 or arm_length < 4.0:
        return False
    cosine = float(np.dot(torso, upper_arm) / (torso_length * arm_length))
    angle = math.degrees(math.acos(float(np.clip(abs(cosine), 0.0, 1.0))))
    return angle >= 22.0


def _is_side_camera(camera: str) -> bool:
    value = camera.strip().lower().replace("-", "_")
    return "side" in value or "侧" in value


def _normalise_exercise(exercise_id: str) -> str:
    return exercise_id.strip().lower().replace("-", "_").replace(" ", "_")
