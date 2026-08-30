from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Iterable, Sequence

import numpy as np

from .angles import joint_angle
from .exercise_rules import NEW_EXERCISE_RULES, ExerciseRule
from .pose_validation import chain_quality


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
LEFT_ANKLE = 15
RIGHT_ANKLE = 16


@dataclass(frozen=True)
class PoseSample:
    timestamp_ms: int
    source_frame_index: int
    points: np.ndarray
    scores: np.ndarray
    inferred: np.ndarray | None = None


@dataclass(frozen=True)
class MotionEpisode:
    start_index: int
    key_index: int
    end_index: int


@dataclass(frozen=True)
class MotionEvent:
    code: str
    label: str
    explanation: str
    stage: str
    start_index: int
    peak_index: int
    end_index: int
    confidence: float
    measurements: dict[str, Any]
    highlight_landmarks: tuple[int, ...]
    reference: str | None = None
    category: str | None = None
    evidence_quality: str | None = None


@dataclass(frozen=True)
class EventAnalysis:
    events: tuple[MotionEvent, ...]
    primary_angles: tuple[float, ...]
    complete_motion_cycles: int
    limitations: tuple[str, ...]
    partial_motion_cycles: int = 0
    visible_phases: tuple[str, ...] = ()
    evaluated_rules: tuple[str, ...] = ()
    skipped_rules: tuple[str, ...] = ()


def format_video_time(timestamp_ms: int) -> str:
    total_seconds = max(0, timestamp_ms) / 1000.0
    minutes = int(total_seconds // 60)
    seconds = total_seconds - minutes * 60
    return f"{minutes:02d}:{seconds:04.1f}"


def event_to_result(
    event: MotionEvent,
    samples: Sequence[PoseSample],
    evidence_id: str,
) -> dict[str, Any]:
    start_ms = samples[event.start_index].timestamp_ms
    peak_ms = samples[event.peak_index].timestamp_ms
    end_ms = samples[event.end_index].timestamp_ms
    endpoint_evidence = str(event.measurements.get("endpointEvidence") or "")
    evidence_quality = event.evidence_quality or (
        "inferred_direction"
        if endpoint_evidence == "inferred_direction"
        else "observed"
    )
    return {
        "id": evidence_id,
        "code": event.code,
        "label": event.label,
        "startMs": start_ms,
        "peakMs": peak_ms,
        "endMs": end_ms,
        "displayTime": format_video_time(peak_ms),
        "stage": event.stage,
        "severity": "warning",
        "category": event.category or _event_category(event.code),
        "evidenceQuality": evidence_quality,
        "confidence": round(max(0.0, min(1.0, event.confidence)), 3),
        "measurements": event.measurements,
        "explanation": event.explanation,
        "evidenceId": evidence_id,
    }


def _event_category(code: str) -> str:
    normalized = code.upper()
    if any(
        marker in normalized
        for marker in (
            "TRUNK",
            "ASYMMETRY",
            "KNEE_MEDIAL",
            "BODY_LINE",
            "SHOULDER_HIKE",
            "SHOULDER_TILT",
            "HIP_SHIFT",
            "SWAY",
        )
    ):
        return "stability_compensation"
    if any(marker in normalized for marker in ("CAMERA", "EVIDENCE", "MISMATCH")):
        return "evidence_camera"
    return "primary_form"


def analyze_pose_events(
    exercise_id: str,
    camera: str,
    samples: Sequence[PoseSample],
    confidence_floor: float = 0.35,
    max_events: int = 8,
) -> EventAnalysis:
    normalized = exercise_id.lower()
    if not samples:
        return EventAnalysis((), (), 0, ())

    if normalized in {"barbell_squat", "goblet_squat"}:
        analysis = _squat_events(camera, samples, confidence_floor)
    elif normalized in {"deadlift", "romanian_deadlift"}:
        analysis = _hinge_events(normalized, camera, samples, confidence_floor)
    elif normalized == "lat_pulldown":
        analysis = _lat_pulldown_events(camera, samples, confidence_floor)
    elif normalized == "pull_up":
        analysis = _pull_up_events(camera, samples, confidence_floor)
    elif normalized in {"bench_press", "dumbbell_press"}:
        analysis = _bench_press_events(camera, samples, confidence_floor)
    elif normalized == "hip_thrust":
        analysis = _hip_thrust_events(samples, confidence_floor)
    elif normalized == "lateral_raise":
        analysis = _lateral_raise_events(camera, samples, confidence_floor)
    elif normalized == "row":
        analysis = _row_events(camera, samples, confidence_floor)
    elif normalized in {
        "shoulder_press",
        "push_up",
        "dip",
        "face_pull",
        "biceps_curl",
        "triceps_extension",
    }:
        analysis = _elbow_family_events(
            normalized, camera, samples, confidence_floor
        )
    elif normalized in NEW_EXERCISE_RULES:
        analysis = _configured_exercise_events(
            normalized, camera, samples, confidence_floor
        )
    else:
        analysis = _generic_elbow_analysis(samples, confidence_floor)

    events = _select_representative_events(
        _merge_nearby_events(analysis.events, samples),
        samples,
        max_events,
    )
    return EventAnalysis(
        events=tuple(events),
        primary_angles=analysis.primary_angles,
        complete_motion_cycles=analysis.complete_motion_cycles,
        limitations=analysis.limitations,
        partial_motion_cycles=analysis.partial_motion_cycles,
        visible_phases=analysis.visible_phases,
        evaluated_rules=analysis.evaluated_rules,
        skipped_rules=analysis.skipped_rules,
    )


def _squat_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    side, chain = _best_side_chain(
        samples,
        (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
        (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE),
        floor,
    )
    values = _angle_series(samples, chain, floor)
    smooth = _median_series(values)
    episodes = _episodes_below(samples, smooth, enter=145.0, exit=155.0)
    events: list[MotionEvent] = []
    for episode in episodes:
        if camera not in {"side", "side_rear"}:
            continue
        bottom_angle = smooth[episode.key_index]
        if bottom_angle is None or bottom_angle <= 118.0:
            continue
        confidence = _sample_confidence(samples[episode.key_index], chain)
        if camera == "side_rear":
            confidence = min(confidence, 0.72)
        events.append(
            MotionEvent(
                code="SQUAT_DEPTH_LIMITED",
                label="下蹲深度可能不足",
                explanation=(
                    f"最低位置可见侧膝角约 {bottom_angle:.1f}°，"
                    "高于当前 118° 参考线。"
                ),
                stage="lower_position",
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=confidence,
                measurements={
                    "visibleSide": side,
                    "kneeAngleDeg": round(bottom_angle, 1),
                    "referenceLimitDeg": 118.0,
                },
                highlight_landmarks=chain,
                reference="joint_angle",
            )
        )

    limitations = ["foot_pressure_not_measurable_from_rgb"]
    if camera not in {"side", "side_rear"}:
        limitations.append("squat_depth_requires_side_view")
    if camera in {"front", "rear", "side_rear"}:
        medial_values, medial_sides = _knee_medial_series(samples, floor)
        for start, peak, end in _continuous_ranges(
            samples, medial_values, threshold=0.045, minimum_duration_ms=300
        ):
            value = medial_values[peak]
            selected_side = medial_sides[peak]
            if value is None or selected_side is None:
                continue
            chain = (
                (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE)
                if selected_side == "left"
                else (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE)
            )
            confidence = _sample_confidence(samples[peak], chain)
            if camera == "side_rear":
                confidence = min(confidence, 0.68)
            events.append(
                MotionEvent(
                    code="KNEE_MEDIAL_MOVEMENT",
                    label="膝部出现持续向内偏移",
                    explanation=(
                        f"{_side_label(selected_side)}膝相对髋部和脚踝参考线"
                        f"向内偏移约 {value:.3f} 个躯干长度。"
                    ),
                    stage="movement",
                    start_index=start,
                    peak_index=peak,
                    end_index=end,
                    confidence=confidence,
                    measurements={
                        "side": selected_side,
                        "medialOffsetNormalized": round(value, 3),
                        "referenceLimit": 0.045,
                    },
                    highlight_landmarks=chain,
                    reference="hip_ankle_line",
                )
            )
    else:
        limitations.append("knee_medial_movement_requires_front_or_rear_view")

    return EventAnalysis(
        tuple(events),
        tuple(value for value in smooth if value is not None),
        len(episodes),
        tuple(limitations),
    )


def _hinge_events(
    exercise_id: str,
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    side, hip_chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE),
        (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE),
        floor,
    )
    knee_chain = (
        (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE)
        if side == "left"
        else (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE)
    )
    hip_values = _median_series(_angle_series(samples, hip_chain, floor))
    knee_values = _median_series(_angle_series(samples, knee_chain, floor))
    episodes = _episodes_below(samples, hip_values, enter=145.0, exit=155.0)
    events: list[MotionEvent] = []
    for episode in episodes:
        hip_angle = hip_values[episode.key_index]
        knee_angle = knee_values[episode.key_index]
        if hip_angle is None:
            continue
        confidence = _sample_confidence(samples[episode.key_index], hip_chain)
        if hip_angle > 130.0:
            events.append(
                MotionEvent(
                    code="HINGE_RANGE_LIMITED",
                    label="髋部折叠幅度可能不足",
                    explanation=(
                        f"最低位置可见侧髋角约 {hip_angle:.1f}°，"
                        "高于当前 130° 参考线。"
                    ),
                    stage="lower_position",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=confidence,
                    measurements={
                        "visibleSide": side,
                        "hipAngleDeg": round(hip_angle, 1),
                        "referenceLimitDeg": 130.0,
                    },
                    highlight_landmarks=hip_chain,
                    reference="joint_angle",
                )
            )
        if knee_angle is not None and knee_angle < 112.0 and hip_angle > 115.0:
            is_rdl = exercise_id == "romanian_deadlift"
            events.append(
                MotionEvent(
                    code=(
                        "RDL_EXCESSIVE_KNEE_BEND"
                        if is_rdl
                        else "DEADLIFT_KNEE_DOMINANT"
                    ),
                    label="屈膝较多，髋主导不明显",
                    explanation=(
                        f"最低位置可见侧膝角约 {knee_angle:.1f}°，"
                        f"同时髋角约 {hip_angle:.1f}°，动作更接近下蹲。"
                    ),
                    stage="lower_position",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=min(
                        confidence,
                        _sample_confidence(samples[episode.key_index], knee_chain),
                    ),
                    measurements={
                        "visibleSide": side,
                        "kneeAngleDeg": round(knee_angle, 1),
                        "hipAngleDeg": round(hip_angle, 1),
                        "kneeReferenceDeg": 112.0,
                    },
                    highlight_landmarks=tuple(dict.fromkeys((*hip_chain, *knee_chain))),
                    reference="joint_angles",
                )
            )

        shift = _trunk_shift_in_episode(samples, hip_values, episode, side, floor)
        if shift is not None:
            start, peak, end, degrees, shift_confidence = shift
            shoulder = LEFT_SHOULDER if side == "left" else RIGHT_SHOULDER
            hip = LEFT_HIP if side == "left" else RIGHT_HIP
            events.append(
                MotionEvent(
                    code="TRUNK_POSTURE_SHIFT",
                    label="躯干姿态出现突然变化",
                    explanation=(
                        f"髋部角度变化较小时，肩髋连线在短时间内变化约 {degrees:.1f}°。"
                        "当前骨骼模型只能评价躯干线，不能直接判断腰椎形态。"
                    ),
                    stage="movement",
                    start_index=start,
                    peak_index=peak,
                    end_index=end,
                    confidence=shift_confidence,
                    measurements={
                        "visibleSide": side,
                        "trunkLineShiftDeg": round(degrees, 1),
                        "referenceLimitDeg": 8.0,
                    },
                    highlight_landmarks=(shoulder, hip),
                    reference="trunk_line",
                )
            )

    limitations = (
        "lumbar_spine_shape_not_measurable_with_coco17",
        "side_view_required_for_hinge_geometry",
    ) if camera not in {"side", "side_rear", "side_front"} else (
        "lumbar_spine_shape_not_measurable_with_coco17",
    )
    return EventAnalysis(
        tuple(events),
        tuple(value for value in hip_values if value is not None),
        len(episodes),
        limitations,
    )


def _lat_pulldown_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    side, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor), radius=2)
    episodes = _episodes_below(
        samples,
        values,
        enter=130.0,
        exit=140.0,
        minimum_duration_ms=600,
    )
    events: list[MotionEvent] = []
    elbow_index = LEFT_ELBOW if side == "left" else RIGHT_ELBOW
    for episode in episodes:
        start_angle = values[episode.start_index]
        bottom_angle = values[episode.key_index]
        if start_angle is None or bottom_angle is None:
            continue
        confidence = _sample_confidence(samples[episode.key_index], chain)
        if start_angle < 125.0 or bottom_angle > 100.0:
            events.append(
                MotionEvent(
                    code="LAT_PULLDOWN_RANGE_INCOMPLETE",
                    label="高位下拉行程可能不足",
                    explanation=(
                        f"可见侧肘角从约 {start_angle:.1f}° 变化到 {bottom_angle:.1f}°，"
                        "尚未稳定覆盖当前 125° 到 100° 的参考范围。"
                    ),
                    stage="lower_position",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=confidence,
                    measurements={
                        "visibleSide": side,
                        "startElbowAngleDeg": round(start_angle, 1),
                        "bottomElbowAngleDeg": round(bottom_angle, 1),
                        "startReferenceDeg": 125.0,
                        "bottomReferenceDeg": 100.0,
                    },
                    highlight_landmarks=chain,
                    reference="joint_angle",
                )
            )

        descent = _normalized_elbow_descent(
            samples[episode.start_index], samples[episode.key_index], elbow_index, floor
        )
        if descent is not None and 0.0 <= descent < 0.035:
            events.append(
                MotionEvent(
                    code="LAT_PULLDOWN_ELBOW_PATH_LIMITED",
                    label="肘部向下移动不明显",
                    explanation=(
                        f"从起始到最低位置，肘部标准化下降量约 {descent:.3f}，"
                        "低于当前 0.035 参考线。"
                    ),
                    stage="movement",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=confidence,
                    measurements={
                        "visibleSide": side,
                        "elbowDescentNormalized": round(descent, 3),
                        "referenceLimit": 0.035,
                    },
                    highlight_landmarks=(chain[0], chain[1]),
                    reference="elbow_path",
                )
            )

    if camera == "rear":
        events.extend(
            _bilateral_elbow_asymmetry_events(
                "lat_pulldown",
                {
                    "direction": "below",
                    "enter": 130.0,
                    "exit": 135.0,
                    "target": 90.0,
                },
                samples,
                floor,
            )
        )

    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        ("handle_position_requires_equipment_detector",),
    )


def _pull_up_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    left_chain = (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST)
    right_chain = (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST)
    left_values = _median_series(_angle_series(samples, left_chain, floor))
    right_values = _median_series(_angle_series(samples, right_chain, floor))
    combined = [
        float(np.mean(visible)) if visible else None
        for left, right in zip(left_values, right_values)
        for visible in [[value for value in (left, right) if value is not None]]
    ]
    # A cycle is still a pull-up when the top is incomplete; use a permissive
    # entry threshold, then report the top-angle quality separately.
    episodes = _episodes_below(samples, combined, enter=130.0, exit=145.0)
    events: list[MotionEvent] = []

    for episode in episodes:
        top_angle = combined[episode.key_index]
        if top_angle is None or top_angle <= 98.0:
            continue
        visible = [
            value
            for value in (
                left_values[episode.key_index],
                right_values[episode.key_index],
            )
            if value is not None
        ]
        confidence = min(
            _sample_confidence(samples[episode.key_index], left_chain),
            _sample_confidence(samples[episode.key_index], right_chain),
        ) if len(visible) == 2 else 0.52
        events.append(
            MotionEvent(
                code="PULL_UP_RANGE_INCOMPLETE",
                label="顶端屈肘行程偏短",
                explanation=(
                    f"顶端双侧平均肘角约 {top_angle:.1f}°，"
                    "这组在最上方仍保留了较多伸展。"
                ),
                stage="upper_position",
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=confidence,
                measurements={
                    "topElbowAngleDeg": round(top_angle, 1),
                    "referenceLimitDeg": 98.0,
                },
                highlight_landmarks=tuple(dict.fromkeys((*left_chain, *right_chain))),
                reference="joint_angles",
            )
        )

    if camera in {"front", "rear"}:
        angle_difference = []
        for sample, left, right in zip(samples, left_values, right_values):
            if (
                left is None
                or right is None
                or max(left, right) >= 150.0
                or _frontal_pose_quality(sample, floor) < 0.45
                or _has_inferred_landmark(sample, (LEFT_WRIST, RIGHT_WRIST))
            ):
                angle_difference.append(None)
            else:
                angle_difference.append(abs(left - right))
        for start, peak, end in _continuous_ranges(
            samples,
            angle_difference,
            threshold=14.0,
            minimum_duration_ms=300,
        ):
            left = left_values[peak]
            right = right_values[peak]
            difference = angle_difference[peak]
            if left is None or right is None or difference is None:
                continue
            confidence = min(
                _sample_confidence(samples[peak], left_chain),
                _sample_confidence(samples[peak], right_chain),
            )
            events.append(
                MotionEvent(
                    code="PULL_UP_ARM_ASYMMETRY",
                    label="两侧手臂没有同步屈曲",
                    explanation=(
                        f"同一时刻左肘约 {left:.1f}°、右肘约 {right:.1f}°，"
                        f"相差约 {difference:.1f}°。"
                    ),
                    stage="movement",
                    start_index=start,
                    peak_index=peak,
                    end_index=end,
                    confidence=confidence,
                    measurements={
                        "leftElbowAngleDeg": round(left, 1),
                        "rightElbowAngleDeg": round(right, 1),
                        "differenceDeg": round(difference, 1),
                        "referenceLimitDeg": 14.0,
                    },
                    highlight_landmarks=tuple(
                        dict.fromkeys((*left_chain, *right_chain))
                    ),
                    reference="bilateral_elbow_angles",
                )
            )

        shoulder_offsets = _shoulder_height_difference_series(samples, floor)
        for start, peak, end in _continuous_ranges(
            samples,
            shoulder_offsets,
            threshold=0.055,
            minimum_duration_ms=300,
        ):
            offset = shoulder_offsets[peak]
            if offset is None:
                continue
            left_y = float(samples[peak].points[LEFT_SHOULDER][1])
            right_y = float(samples[peak].points[RIGHT_SHOULDER][1])
            higher_side = "left" if left_y < right_y else "right"
            events.append(
                MotionEvent(
                    code="PULL_UP_SHOULDER_ASYMMETRY",
                    label="两侧肩膀高度不一致",
                    explanation=(
                        f"{_side_label(higher_side)}肩先抬高，肩线高度差约为 "
                        f"{offset:.3f} 个躯干长度。"
                    ),
                    stage="movement",
                    start_index=start,
                    peak_index=peak,
                    end_index=end,
                    confidence=_sample_confidence(
                        samples[peak], (LEFT_SHOULDER, RIGHT_SHOULDER)
                    ),
                    measurements={
                        "higherSide": higher_side,
                        "shoulderHeightDifferenceNormalized": round(offset, 3),
                        "referenceLimit": 0.055,
                    },
                    highlight_landmarks=(LEFT_SHOULDER, RIGHT_SHOULDER),
                    reference="shoulder_line",
                )
            )
    limitations = ["bar_and_chin_contact_require_equipment_detector"]
    if camera not in {"front", "rear"}:
        limitations.append("bilateral_symmetry_requires_front_or_rear_view")
    return EventAnalysis(
        tuple(events),
        tuple(value for value in combined if value is not None),
        len(episodes),
        tuple(limitations),
    )


def _bench_press_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    side, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor), radius=2)
    strict_episodes = _episodes_below(
        samples,
        values,
        enter=120.0,
        exit=140.0,
    )
    relative_episodes = (
        []
        if strict_episodes
        else _adaptive_bench_press_episodes(samples, values)
    )
    visible_phases = (
        ("extended", "lowered", "returned")
        if strict_episodes
        else ("lowered", "returned")
        if relative_episodes
        else ()
    )
    if camera != "side":
        return EventAnalysis(
            (),
            tuple(value for value in values if value is not None),
            len(strict_episodes),
            (
                "forearm_verticality_requires_true_side_view",
                "bar_path_requires_equipment_detector",
            ),
            partial_motion_cycles=len(relative_episodes),
            visible_phases=visible_phases,
            evaluated_rules=("bench_press_primary_motion",),
            skipped_rules=(
                "bench_press_depth",
                "bench_press_forearm_verticality",
            ),
        )
    events: list[MotionEvent] = []
    elbow = LEFT_ELBOW if side == "left" else RIGHT_ELBOW
    wrist = LEFT_WRIST if side == "left" else RIGHT_WRIST
    forearm_rule_evaluated = False
    forearm_rule_unstable = False
    for episode in strict_episodes:
        bottom_angle = values[episode.key_index]
        if bottom_angle is not None and bottom_angle > 105.0:
            events.append(
                MotionEvent(
                    code="BENCH_DEPTH_LIMITED",
                    label="卧推下放幅度不足",
                    explanation=(
                        f"最低位置可见侧肘角约 {bottom_angle:.1f}°，"
                        "高于当前 105° 参考线。下一组在肩部稳定的前提下，把肘部再多下放一点。"
                    ),
                    stage="lower_position",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=_sample_confidence(
                        samples[episode.key_index], chain
                    ),
                    measurements={
                        "visibleSide": side,
                        "bottomElbowAngleDeg": round(bottom_angle, 1),
                        "referenceLimitDeg": 105.0,
                        "endpointEvidence": _endpoint_evidence(
                            samples[episode.key_index], (chain,)
                        ),
                    },
                    highlight_landmarks=chain,
                    reference="joint_angle",
                )
            )
        key_sample = samples[episode.key_index]
        if (
            min(key_sample.scores[elbow], key_sample.scores[wrist]) < floor
            or _has_inferred_landmark(key_sample, (wrist,))
        ):
            continue
        stability_deviations = _observed_forearm_deviations(
            samples,
            elbow,
            wrist,
            episode.key_index,
            floor,
            radius=3,
        )
        if len(stability_deviations) < 5:
            continue
        low, high = np.percentile(stability_deviations, (10, 90))
        if float(high - low) > 35.0:
            # A plate-covered elbow often drifts gradually rather than making
            # one obvious spike. Three central frames can therefore agree on
            # a completely false angle. Require a wider stable window before
            # turning an observed wrist into user-facing feedback.
            forearm_rule_unstable = True
            continue
        deviations: list[float] = []
        confidences: list[float] = []
        for index in range(
            max(episode.start_index, episode.key_index - 1),
            min(episode.end_index, episode.key_index + 1) + 1,
        ):
            sample = samples[index]
            if min(sample.scores[elbow], sample.scores[wrist]) < floor:
                continue
            # A reconstructed wrist is sufficient to keep the elbow-angle
            # sequence usable, but it is not an observed endpoint from which
            # an absolute vertical-forearm judgement may be made.
            if _has_inferred_landmark(sample, (wrist,)):
                continue
            deviations.append(_vertical_deviation(sample.points[elbow], sample.points[wrist]))
            confidences.append(_sample_confidence(sample, (elbow, wrist)))
        if not deviations:
            continue
        forearm_rule_evaluated = True
        deviation = float(np.median(deviations))
        confidence = float(np.median(confidences))
        if deviation <= 18.0:
            continue
        events.append(
            MotionEvent(
                code="BENCH_FOREARM_NOT_VERTICAL",
                label="底部小臂偏离竖直方向",
                explanation=(
                    f"最低位置可见侧小臂相对竖直参考线偏离约 {deviation:.1f}°，"
                    "超过当前 18° 参考范围。"
                ),
                stage="lower_position",
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=confidence,
                measurements={
                    "visibleSide": side,
                    "forearmVerticalDeviationDeg": round(deviation, 1),
                    "referenceLimitDeg": 18.0,
                    "endpointEvidence": _endpoint_evidence(
                        samples[episode.key_index], ((elbow, wrist),)
                    ),
                },
                highlight_landmarks=(elbow, wrist),
                reference="vertical_forearm",
            )
        )
    limitations = []
    if relative_episodes:
        limitations.append(
            "bench_cycle_uses_relative_motion_due_endpoint_occlusion"
        )
    limitations.append("bar_path_requires_equipment_detector")
    if strict_episodes:
        evaluated = [
            "bench_press_primary_motion",
            "bench_press_depth",
        ]
        skipped: list[str] = []
        if forearm_rule_evaluated:
            evaluated.append("bench_press_forearm_verticality")
        else:
            skipped.append(
                "bench_press_forearm_verticality_requires_stable_observed_wrist"
                if forearm_rule_unstable
                else "bench_press_forearm_verticality_requires_observed_wrist"
            )
        evaluated_rules = tuple(evaluated)
        skipped_rules = tuple(skipped)
    elif relative_episodes:
        evaluated_rules = ("bench_press_relative_primary_motion",)
        skipped_rules = (
            "bench_press_depth_requires_stable_endpoint_geometry",
            "bench_press_forearm_verticality_requires_stable_endpoint_geometry",
        )
    else:
        evaluated_rules = ("bench_press_primary_motion",)
        skipped_rules = ()
    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(strict_episodes),
        tuple(limitations),
        partial_motion_cycles=len(relative_episodes),
        visible_phases=visible_phases,
        evaluated_rules=evaluated_rules,
        skipped_rules=skipped_rules,
    )


def _hip_thrust_events(
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    side, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE),
        (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor))
    episodes = _episodes_above(samples, values, enter=145.0, exit=125.0)
    events: list[MotionEvent] = []
    for episode in episodes:
        top_angle = values[episode.key_index]
        if top_angle is None or top_angle >= 165.0:
            continue
        events.append(
            MotionEvent(
                code="HIP_THRUST_EXTENSION_LIMITED",
                label="臀推顶端伸髋不足",
                explanation=(
                    f"顶端可见侧肩—髋—膝角约 {top_angle:.1f}°，"
                    "躯干与大腿还没有接近一条线。"
                ),
                stage="upper_position",
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=_sample_confidence(samples[episode.key_index], chain),
                measurements={
                    "visibleSide": side,
                    "topHipAngleDeg": round(top_angle, 1),
                    "referenceLimitDeg": 165.0,
                },
                highlight_landmarks=chain,
                reference="joint_angle",
            )
        )
    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        ("bench_contact_and_pelvic_tilt_not_measurable",),
    )


def _lateral_raise_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    left_chain = (LEFT_HIP, LEFT_SHOULDER, LEFT_ELBOW)
    right_chain = (RIGHT_HIP, RIGHT_SHOULDER, RIGHT_ELBOW)
    left_values = _median_series(_angle_series(samples, left_chain, floor))
    right_values = _median_series(_angle_series(samples, right_chain, floor))
    combined = [
        float(np.mean(visible)) if visible else None
        for left, right in zip(left_values, right_values)
        for visible in [[value for value in (left, right) if value is not None]]
    ]
    episodes = _episodes_above(samples, combined, enter=55.0, exit=25.0)
    events: list[MotionEvent] = []
    for episode in episodes:
        top_angle = combined[episode.key_index]
        if top_angle is None or top_angle >= 75.0:
            continue
        events.append(
            MotionEvent(
                code="LATERAL_RAISE_HEIGHT_LIMITED",
                label="侧平举抬起高度偏低",
                explanation=(
                    f"最高位置双侧平均抬臂角约 {top_angle:.1f}°，"
                    "还没有稳定接近肩部高度。"
                ),
                stage="upper_position",
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=min(
                    _sample_confidence(samples[episode.key_index], left_chain),
                    _sample_confidence(samples[episode.key_index], right_chain),
                ),
                measurements={
                    "topArmAngleDeg": round(top_angle, 1),
                    "referenceLimitDeg": 75.0,
                },
                highlight_landmarks=tuple(
                    dict.fromkeys((*left_chain, *right_chain))
                ),
                reference="bilateral_shoulder_angles",
            )
        )
    if camera == "front":
        differences = [
            abs(left - right)
            if left is not None
            and right is not None
            and max(left, right) >= 35.0
            else None
            for left, right in zip(left_values, right_values)
        ]
        for start, peak, end in _continuous_ranges(
            samples, differences, threshold=12.0, minimum_duration_ms=300
        ):
            difference = differences[peak]
            if difference is None:
                continue
            events.append(
                MotionEvent(
                    code="LATERAL_RAISE_ARM_ASYMMETRY",
                    label="两侧手臂抬起不同步",
                    explanation=(
                        f"同一时刻左右抬臂角相差约 {difference:.1f}°。"
                    ),
                    stage="movement",
                    start_index=start,
                    peak_index=peak,
                    end_index=end,
                    confidence=min(
                        _sample_confidence(samples[peak], left_chain),
                        _sample_confidence(samples[peak], right_chain),
                    ),
                    measurements={
                        "differenceDeg": round(difference, 1),
                        "referenceLimitDeg": 12.0,
                    },
                    highlight_landmarks=tuple(
                        dict.fromkeys((*left_chain, *right_chain))
                    ),
                    reference="bilateral_shoulder_angles",
                )
            )
    return EventAnalysis(
        tuple(events),
        tuple(value for value in combined if value is not None),
        len(episodes),
        ("scapular_elevation_not_directly_measurable",),
    )


def _row_events(
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    """Evaluate a row from elbow range *and* hand travel.

    A row is ready at a sustained extended position, enters the pull only after
    the hand has moved toward the torso, and completes only after the hand has
    returned. This avoids treating a single elbow-angle crossing as a rep.
    """
    side, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor))
    hand_forward = _row_hand_forward_series(samples, chain, floor)
    episodes, incomplete_episodes, partial_cycles, visible_phases = _row_motion_episodes(
        samples,
        values,
        hand_forward,
    )

    events: list[MotionEvent] = []
    for episode in incomplete_episodes:
        key_angle = values[episode.key_index]
        if key_angle is not None and key_angle > 100.0:
            events.append(
                MotionEvent(
                    code="ROW_RANGE_INCOMPLETE",
                    label="划船肘部回拉不足",
                    explanation=(
                        f"回拉位置可见侧肘角约 {key_angle:.1f}°，"
                        "没有稳定达到当前 100° 参考范围。"
                    ),
                    stage="lower_position",
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=_sample_confidence(samples[episode.key_index], chain),
                    measurements={
                        "visibleSide": side,
                        "keyElbowAngleDeg": round(key_angle, 1),
                        "referenceLimitDeg": 100.0,
                        "endpointEvidence": _endpoint_evidence(
                            samples[episode.key_index], (chain,)
                        ),
                    },
                    highlight_landmarks=chain,
                    reference="joint_angle",
                    category="primary_form",
                )
            )

    if camera in {"front", "rear"}:
        events.extend(
            _bilateral_elbow_asymmetry_events(
                "row",
                {
                    "direction": "below",
                    "enter": 100.0,
                    "exit": 125.0,
                    "target": 100.0,
                },
                samples,
                floor,
            )
        )

    evaluated_rules = ["row_elbow_range", "row_hand_path"]
    skipped_rules: list[str] = []
    if camera in {"side", "side_front", "side_rear"}:
        trunk = _trunk_orientation_series(samples, floor)
        evaluated_rules.append("row_trunk_stability")
        for episode in episodes:
            change, peak = _range_and_peak(trunk, episode)
            if change is None or peak is None or change <= 12.0:
                continue
            events.append(
                MotionEvent(
                    code="ROW_TRUNK_SWAY",
                    label="划船过程中躯干摆动较大",
                    explanation=(
                        f"这段回拉中躯干方向变化约 {change:.1f}°，"
                        "超过当前 12° 稳定性参考线。"
                    ),
                    stage="movement",
                    start_index=episode.start_index,
                    peak_index=peak,
                    end_index=episode.end_index,
                    confidence=_sample_confidence(
                        samples[peak],
                        (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP),
                    ),
                    measurements={
                        "trunkLineChangeDeg": round(change, 1),
                        "referenceLimitDeg": 12.0,
                    },
                    highlight_landmarks=(
                        LEFT_SHOULDER,
                        RIGHT_SHOULDER,
                        LEFT_HIP,
                        RIGHT_HIP,
                    ),
                    reference="trunk_line",
                    category="stability_compensation",
                )
            )
    else:
        skipped_rules.append("row_trunk_stability_requires_side_view")

    if camera in {"front", "rear"}:
        evaluated_rules.append("row_bilateral_symmetry")
    else:
        skipped_rules.append("row_bilateral_symmetry_requires_front_or_rear_view")

    return EventAnalysis(
        events=tuple(events),
        primary_angles=tuple(value for value in values if value is not None),
        complete_motion_cycles=len(episodes),
        limitations=(
            "equipment_contact_not_measurable",
            *(
                ()
                if camera in {"front", "rear"}
                else ("bilateral_symmetry_requires_front_or_rear_view",)
            ),
        ),
        partial_motion_cycles=partial_cycles,
        visible_phases=visible_phases,
        evaluated_rules=tuple(evaluated_rules),
        skipped_rules=tuple(skipped_rules),
    )


def _row_hand_forward_series(
    samples: Sequence[PoseSample],
    chain: tuple[int, int, int],
    floor: float,
) -> list[float | None]:
    shoulder, elbow, wrist = chain
    values: list[float | None] = []
    for sample in samples:
        if min(sample.scores[index] for index in chain) < floor:
            values.append(None)
            continue
        upper_arm = float(
            np.linalg.norm(sample.points[shoulder] - sample.points[elbow])
        )
        if not np.isfinite(upper_arm) or upper_arm < 6.0:
            values.append(None)
            continue
        forward = abs(float(sample.points[wrist][0] - sample.points[shoulder][0]))
        values.append(forward / upper_arm)
    return _median_series(values)


def _row_motion_episodes(
    samples: Sequence[PoseSample],
    angles: Sequence[float | None],
    hand_forward: Sequence[float | None],
    *,
    sustained_samples: int = 3,
) -> tuple[list[MotionEpisode], list[MotionEpisode], int, tuple[str, ...]]:
    valid_angles = [value for value in angles if value is not None]
    valid_forward = [value for value in hand_forward if value is not None]
    if not valid_angles or not valid_forward:
        return [], [], 0, ()
    top_twenty_floor = float(np.percentile(valid_angles, 80))
    maximum_forward = float(max(valid_forward))
    near_maximum_forward = maximum_forward * 0.85

    episodes: list[MotionEpisode] = []
    incomplete_episodes: list[MotionEpisode] = []
    phases: list[str] = []
    state = "seeking_extended"
    run: list[int] = []
    return_run: list[int] = []
    start_index: int | None = None
    start_forward: float | None = None
    key_index: int | None = None
    key_value = math.inf

    def reset() -> None:
        nonlocal state, run, return_run, start_index, start_forward, key_index, key_value
        state = "seeking_extended"
        run = []
        return_run = []
        start_index = None
        start_forward = None
        key_index = None
        key_value = math.inf

    for index, (angle, forward) in enumerate(zip(angles, hand_forward)):
        gap_ms = (
            samples[index].timestamp_ms - samples[index - 1].timestamp_ms
            if index > 0
            else 0
        )
        if angle is None or forward is None or gap_ms > 300:
            reset()
            continue

        if state == "seeking_extended":
            extended = (
                (angle >= 125.0 or angle >= top_twenty_floor)
                and forward >= near_maximum_forward
            )
            run = [*run, index] if extended else []
            if len(run) >= sustained_samples:
                stable = run[-sustained_samples:]
                start_index = stable[0]
                start_forward = float(np.median([hand_forward[i] for i in stable]))
                phases.append("extended")
                state = "seeking_pull"
                run = []
            continue

        if state == "seeking_pull":
            assert start_forward is not None
            meaningful_pull = start_forward - forward >= 0.25
            if meaningful_pull and angle < key_value:
                key_index = index
                key_value = angle
            pulled = angle <= 100.0 and meaningful_pull
            if pulled:
                run = [*run, index]
                return_run = []
                if len(run) >= sustained_samples:
                    stable = run[-sustained_samples:]
                    key_index = min(stable, key=lambda value: float(angles[value]))
                    key_value = float(angles[key_index])
                    phases.append("pulled")
                    state = "seeking_return"
                    run = []
                continue
            returned_without_full_pull = (
                key_index is not None
                and angle >= 125.0
                and forward >= start_forward * 0.70
            )
            run = []
            return_run = (
                [*return_run, index] if returned_without_full_pull else []
            )
            if len(return_run) >= sustained_samples and key_index is not None:
                assert start_index is not None
                incomplete_episodes.append(
                    MotionEpisode(start_index, key_index, return_run[-1])
                )
                phases.extend(("partial_pull", "returned"))
                reset()
            continue

        assert state == "seeking_return"
        assert start_forward is not None and start_index is not None
        if angle < key_value:
            key_index = index
            key_value = angle
        returned = angle >= 125.0 and forward >= start_forward * 0.70
        run = [*run, index] if returned else []
        if len(run) < sustained_samples or key_index is None:
            continue
        end_index = run[-1]
        if samples[end_index].timestamp_ms - samples[start_index].timestamp_ms >= 300:
            episodes.append(MotionEpisode(start_index, key_index, end_index))
            phases.append("returned")
        reset()

    unfinished_cycle = 1 if state != "seeking_extended" and key_index is not None else 0
    partial_cycles = len(incomplete_episodes) + unfinished_cycle
    return (
        episodes,
        incomplete_episodes,
        partial_cycles,
        tuple(dict.fromkeys(phases)),
    )


def _elbow_family_events(
    exercise_id: str,
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    # Entry thresholds are intentionally permissive. They establish a complete
    # movement cycle first; the stricter target below decides whether to coach
    # the range. This prevents a partial repetition from being called "good".
    configs: dict[str, dict[str, Any]] = {
        "shoulder_press": {
            "direction": "above",
            "enter": 135.0,
            "exit": 115.0,
            "target": 155.0,
            "code": "SHOULDER_PRESS_RANGE_INCOMPLETE",
            "label": "肩推顶端伸展不足",
        },
        "push_up": {
            "direction": "below",
            "enter": 130.0,
            "exit": 150.0,
            "target": 95.0,
            "code": "PUSH_UP_DEPTH_LIMITED",
            "label": "俯卧撑下降幅度不足",
        },
        "dip": {
            "direction": "below",
            "enter": 135.0,
            "exit": 150.0,
            "target": 105.0,
            "code": "DIP_DEPTH_LIMITED",
            "label": "双杠臂屈伸下降幅度不足",
        },
        "face_pull": {
            "direction": "below",
            "enter": 135.0,
            "exit": 150.0,
            "target": 100.0,
            "code": "FACE_PULL_RANGE_INCOMPLETE",
            "label": "面拉回拉幅度不足",
        },
        "biceps_curl": {
            "direction": "below",
            "enter": 110.0,
            "exit": 145.0,
            "target": 65.0,
            "code": "BICEPS_CURL_RANGE_INCOMPLETE",
            "label": "弯举屈肘幅度不足",
        },
        "triceps_extension": {
            "direction": "below",
            "enter": 115.0,
            "exit": 145.0,
            "target": 75.0,
            "code": "TRICEPS_EXTENSION_RANGE_INCOMPLETE",
            "label": "三头伸展屈伸幅度不足",
        },
    }
    config = configs[exercise_id]
    side, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor))
    if config["direction"] == "above":
        episodes = _episodes_above(
            samples, values, enter=config["enter"], exit=config["exit"]
        )
    else:
        episodes = _episodes_below(
            samples, values, enter=config["enter"], exit=config["exit"]
        )
    events: list[MotionEvent] = []
    for episode in episodes:
        key_angle = values[episode.key_index]
        if key_angle is None:
            continue
        range_limited = (
            key_angle < config["target"]
            if config["direction"] == "above"
            else key_angle > config["target"]
        )
        if not range_limited:
            continue
        events.append(
            MotionEvent(
                code=config["code"],
                label=config["label"],
                explanation=(
                    f"动作关键位置可见侧肘角约 {key_angle:.1f}°，"
                    f"没有稳定达到当前 {config['target']:.0f}° 参考范围。"
                ),
                stage=(
                    "upper_position"
                    if config["direction"] == "above"
                    else "lower_position"
                ),
                start_index=episode.start_index,
                peak_index=episode.key_index,
                end_index=episode.end_index,
                confidence=_sample_confidence(samples[episode.key_index], chain),
                measurements={
                    "visibleSide": side,
                    "keyElbowAngleDeg": round(key_angle, 1),
                    "referenceLimitDeg": config["target"],
                },
                highlight_landmarks=chain,
                reference="joint_angle",
            )
        )

    if camera in {"front", "rear"}:
        events.extend(
            _bilateral_elbow_asymmetry_events(
                exercise_id,
                config,
                samples,
                floor,
            )
        )
    limitations = ["equipment_contact_not_measurable"]
    if camera not in {"front", "rear"}:
        limitations.append("bilateral_symmetry_requires_front_or_rear_view")
    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        tuple(limitations),
    )


def _bilateral_elbow_asymmetry_events(
    exercise_id: str,
    config: dict[str, Any],
    samples: Sequence[PoseSample],
    floor: float,
) -> list[MotionEvent]:
    left_chain = (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST)
    right_chain = (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST)
    left_values = _median_series(_angle_series(samples, left_chain, floor))
    right_values = _median_series(_angle_series(samples, right_chain, floor))
    differences: list[float | None] = []
    for sample, left, right in zip(samples, left_values, right_values):
        if (
            left is None
            or right is None
            or _frontal_pose_quality(sample, floor) < 0.45
            or _has_inferred_landmark(sample, (LEFT_WRIST, RIGHT_WRIST))
        ):
            differences.append(None)
            continue
        not_both_active = (
            min(left, right) <= config["exit"]
            if config["direction"] == "above"
            else max(left, right) >= config["exit"]
        )
        implausible_endpoint = (
            min(left, right) < max(30.0, float(config["target"]) - 60.0)
            if config["direction"] == "below"
            else False
        )
        differences.append(
            None if not_both_active or implausible_endpoint else abs(left - right)
        )
    events: list[MotionEvent] = []
    for start, peak, end in _continuous_ranges(
        samples, differences, threshold=14.0, minimum_duration_ms=300
    ):
        left = left_values[peak]
        right = right_values[peak]
        difference = differences[peak]
        if left is None or right is None or difference is None:
            continue
        confidence = min(
            _sample_confidence(samples[peak], left_chain),
            _sample_confidence(samples[peak], right_chain),
        )
        if confidence < 0.45:
            continue
        prefix = exercise_id.upper()
        events.append(
            MotionEvent(
                code=f"{prefix}_ARM_ASYMMETRY",
                label="两侧手臂没有同步完成动作",
                explanation=(
                    f"同一时刻左肘约 {left:.1f}°、右肘约 {right:.1f}°，"
                    f"相差约 {difference:.1f}°。"
                ),
                stage="movement",
                start_index=start,
                peak_index=peak,
                end_index=end,
                confidence=confidence,
                measurements={
                    "leftElbowAngleDeg": round(left, 1),
                    "rightElbowAngleDeg": round(right, 1),
                    "differenceDeg": round(difference, 1),
                    "referenceLimitDeg": 14.0,
                },
                highlight_landmarks=tuple(
                    dict.fromkeys((*left_chain, *right_chain))
                ),
                reference="bilateral_elbow_angles",
            )
        )
    return events


def _configured_exercise_events(
    exercise_id: str,
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    rule = NEW_EXERCISE_RULES[exercise_id]
    side, chains, values = _configured_primary_signal(rule, camera, samples, floor)
    episodes = (
        _episodes_above(
            samples,
            values,
            enter=rule.enter,
            exit=rule.exit,
            minimum_duration_ms=500,
        )
        if rule.direction == "above"
        else _episodes_below(
            samples,
            values,
            enter=rule.enter,
            exit=rule.exit,
            minimum_duration_ms=500,
        )
    )
    limitations = list(rule.limitations)
    if camera not in rule.cameras:
        limitations.append(f"{exercise_id}_requires_compatible_view")
        return EventAnalysis(
            (),
            tuple(value for value in values if value is not None),
            len(episodes),
            tuple(dict.fromkeys(limitations)),
        )

    events: list[MotionEvent] = []
    for episode in episodes:
        key_angle = values[episode.key_index]
        if key_angle is None:
            continue
        limited = (
            key_angle < rule.target
            if rule.direction == "above"
            else key_angle > rule.target
        )
        if limited:
            relation = "低于" if rule.direction == "above" else "高于"
            cue = (
                "下一组把动作继续做到目标位置，同时保持节奏稳定。"
                if rule.direction == "above"
                else "下一组在不失去控制的前提下再多完成一点行程。"
            )
            measurements: dict[str, Any] = {
                "camera": camera,
                "visibleSide": side,
                "keyAngleDeg": round(key_angle, 1),
                "referenceLimitDeg": rule.target,
                "endpointEvidence": _endpoint_evidence(
                    samples[episode.key_index], chains
                ),
            }
            events.append(
                MotionEvent(
                    code=rule.code,
                    label=rule.label,
                    explanation=(
                        f"{_stage_label(rule.stage)}{_side_phrase(side)}角度约 "
                        f"{key_angle:.1f}°，{relation}当前 {rule.target:.0f}° 参考线。"
                        f"{cue}"
                    ),
                    stage=rule.stage,
                    start_index=episode.start_index,
                    peak_index=episode.key_index,
                    end_index=episode.end_index,
                    confidence=_capped_confidence(
                        _primary_confidence(
                            samples[episode.key_index], chains, floor
                        ),
                        camera,
                    ),
                    measurements=measurements,
                    highlight_landmarks=_flatten_chains(chains),
                    reference="joint_angle",
                )
            )
        events.extend(
            _configured_stability_events(
                exercise_id,
                rule,
                camera,
                samples,
                episode,
                side,
                chains,
                floor,
            )
        )

    if "bilateral" in rule.checks and not rule.unilateral and camera in {"front", "rear"}:
        if rule.chain == "elbow":
            events.extend(
                _bilateral_elbow_asymmetry_events(
                    exercise_id,
                    {
                        "direction": rule.direction,
                        "enter": rule.enter,
                        "exit": rule.exit,
                        "target": rule.target,
                    },
                    samples,
                    floor,
                )
            )
        elif rule.chain == "shoulder":
            events.extend(
                _bilateral_shoulder_asymmetry_events(
                    exercise_id, samples, values, floor
                )
            )

    if "knee_medial" in rule.checks and camera in {"front", "rear"}:
        events.extend(_configured_knee_medial_events(samples, floor, camera))

    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        tuple(dict.fromkeys(limitations)),
    )


def _configured_primary_signal(
    rule: ExerciseRule,
    camera: str,
    samples: Sequence[PoseSample],
    floor: float,
) -> tuple[str, tuple[tuple[int, int, int], ...], list[float | None]]:
    chain_pairs = {
        "elbow": (
            (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
            (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        ),
        "knee": (
            (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
            (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE),
        ),
        "hip": (
            (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE),
            (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE),
        ),
        "shoulder": (
            (LEFT_HIP, LEFT_SHOULDER, LEFT_ELBOW),
            (RIGHT_HIP, RIGHT_SHOULDER, RIGHT_ELBOW),
        ),
    }
    left_chain, right_chain = chain_pairs[rule.chain]
    left_values = _median_series(_angle_series(samples, left_chain, floor))
    right_values = _median_series(_angle_series(samples, right_chain, floor))
    if rule.unilateral or camera not in {"front", "rear"}:
        side, chain = _best_side_chain(
            samples, left_chain, right_chain, floor
        )
        return (
            side,
            (chain,),
            left_values if side == "left" else right_values,
        )
    combined = [
        float(np.mean(visible)) if visible else None
        for left, right in zip(left_values, right_values)
        for visible in [[value for value in (left, right) if value is not None]]
    ]
    return "bilateral", (left_chain, right_chain), _median_series(combined)


def _configured_stability_events(
    exercise_id: str,
    rule: ExerciseRule,
    camera: str,
    samples: Sequence[PoseSample],
    episode: MotionEpisode,
    side: str,
    chains: tuple[tuple[int, int, int], ...],
    floor: float,
) -> list[MotionEvent]:
    events: list[MotionEvent] = []
    prefix = exercise_id.upper()
    if "trunk_stability" in rule.checks and camera in {"side", "side_front", "side_rear"}:
        trunk = _trunk_orientation_series(samples, floor)
        change, peak = _range_and_peak(trunk, episode)
        if change is not None and peak is not None and change > 10.0:
            events.append(
                _configured_event(
                    f"{prefix}_TRUNK_SHIFT",
                    "躯干出现借力摆动",
                    f"这段动作里躯干方向变化约 {change:.1f}°，超过当前 10° 参考线。下一组把负重降到能稳住身体的范围。",
                    "movement",
                    episode,
                    peak,
                    _capped_confidence(
                        _sample_confidence(
                            samples[peak],
                            (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP),
                        ),
                        camera,
                    ),
                    {
                        "camera": camera,
                        "trunkLineChangeDeg": round(change, 1),
                        "referenceLimitDeg": 10.0,
                    },
                    (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP),
                    "trunk_line",
                )
            )

    if "body_line" in rule.checks and camera in {"side", "side_front", "side_rear"}:
        body = _body_line_series(samples, floor)
        segment = [
            (index, value)
            for index, value in enumerate(
                body[episode.start_index: episode.end_index + 1],
                start=episode.start_index,
            )
            if value is not None
        ]
        if segment:
            peak, angle = min(segment, key=lambda item: item[1])
            if angle < 160.0:
                events.append(
                    _configured_event(
                        f"{prefix}_BODY_LINE_BREAK",
                        "身体线出现中断",
                        f"动作中肩—髋—踝夹角最低约 {angle:.1f}°，低于当前 160° 参考线。下一组收紧躯干，让肩、髋和脚踝尽量保持成线。",
                        "movement",
                        episode,
                        peak,
                        _capped_confidence(
                            _primary_confidence(samples[peak], chains, floor), camera
                        ),
                        {
                            "camera": camera,
                            "bodyLineAngleDeg": round(angle, 1),
                            "referenceLimitDeg": 160.0,
                        },
                        _flatten_chains(chains),
                        "body_line",
                    )
                )

    if "shoulder_tilt" in rule.checks and camera in {"front", "rear"}:
        offsets = _shoulder_height_difference_series(samples, floor)
        segment = [
            (index, value)
            for index, value in enumerate(
                offsets[episode.start_index: episode.end_index + 1],
                start=episode.start_index,
            )
            if value is not None
        ]
        if segment:
            peak, offset = max(segment, key=lambda item: item[1])
            if offset > 0.065:
                events.append(
                    _configured_event(
                        f"{prefix}_SHOULDER_TILT",
                        "肩线出现明显倾斜",
                        f"发力时两侧肩高差约 {offset:.3f} 个躯干长度。下一组先稳住肩线，再完成工作侧行程。",
                        "movement",
                        episode,
                        peak,
                        min(_sample_confidence(samples[peak], (LEFT_SHOULDER, RIGHT_SHOULDER)), 0.68),
                        {"camera": camera, "shoulderTiltNormalized": round(offset, 3), "referenceLimit": 0.065},
                        (LEFT_SHOULDER, RIGHT_SHOULDER),
                        "shoulder_line",
                    )
                )

    if "shoulder_hike" in rule.checks and camera in {"front", "rear"}:
        gaps = _shoulder_hip_gap_series(samples, floor)
        start_value = gaps[episode.start_index]
        segment = [
            (index, value)
            for index, value in enumerate(
                gaps[episode.start_index: episode.end_index + 1],
                start=episode.start_index,
            )
            if value is not None
        ]
        if start_value is not None and segment:
            peak, value = max(segment, key=lambda item: item[1])
            rise = value - start_value
            if rise > 0.05:
                events.append(
                    _configured_event(
                        f"{prefix}_SHOULDER_HIKE",
                        "发力时肩部明显上提",
                        f"发力阶段肩带上提约 {rise:.3f} 个大腿长度。下一组先让肩膀远离耳朵，再完成动作。",
                        "movement",
                        episode,
                        peak,
                        min(_sample_confidence(samples[peak], (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)), 0.68),
                        {"camera": camera, "shoulderHipGapRise": round(rise, 3), "referenceLimit": 0.05},
                        (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP),
                        "normalized_metric",
                    )
                )

    if "forearm_vertical" in rule.checks and camera == "side":
        selected_chain = chains[0]
        elbow, wrist = selected_chain[1], selected_chain[2]
        candidates: list[tuple[int, float]] = []
        for index in range(
            max(episode.start_index, episode.key_index - 1),
            min(episode.end_index, episode.key_index + 1) + 1,
        ):
            if min(samples[index].scores[elbow], samples[index].scores[wrist]) >= floor:
                candidates.append(
                    (
                        index,
                        _vertical_deviation(
                            samples[index].points[elbow], samples[index].points[wrist]
                        ),
                    )
                )
        if candidates:
            peak, deviation = max(candidates, key=lambda item: item[1])
            if deviation > 18.0:
                events.append(
                    _configured_event(
                        f"{prefix}_FOREARM_NOT_VERTICAL",
                        "底部小臂方向偏斜",
                        f"最低位置小臂方向偏离竖直约 {deviation:.1f}°，超过当前 18° 参考线。下一组调整握距或下放位置，让肘部更接近手腕正下方。",
                        "lower_position",
                        episode,
                        peak,
                        _capped_confidence(_sample_confidence(samples[peak], (elbow, wrist)), camera),
                        {
                            "camera": camera,
                            "forearmVerticalDeviationDeg": round(deviation, 1),
                            "referenceLimitDeg": 18.0,
                            "endpointEvidence": _endpoint_evidence(samples[peak], ((elbow, wrist, wrist),)),
                        },
                        (elbow, wrist),
                        "forearm_direction",
                    )
                )

    if "elbow_flexion" in rule.checks:
        _, elbow_chains, elbow_values = _configured_primary_signal(
            ExerciseRule(rule.cameras, "elbow", "below", 130, 145, 120, "", "", "movement", rule.unilateral),
            camera,
            samples,
            floor,
        )
        segment = [
            (index, value)
            for index, value in enumerate(
                elbow_values[episode.start_index: episode.end_index + 1],
                start=episode.start_index,
            )
            if value is not None
        ]
        if segment:
            peak, angle = min(segment, key=lambda item: item[1])
            if angle < 110.0:
                events.append(
                    _configured_event(
                        f"{prefix}_ELBOW_FLEXION_DRIFT",
                        "动作逐渐变成屈肘",
                        f"动作中肘角最低约 {angle:.1f}°，小于当前 110° 参考线。下一组保持轻微屈肘但不要继续收紧肘角。",
                        "movement",
                        episode,
                        peak,
                        _capped_confidence(_primary_confidence(samples[peak], elbow_chains, floor), camera),
                        {"camera": camera, "elbowAngleDeg": round(angle, 1), "referenceLimitDeg": 110.0, "endpointEvidence": _endpoint_evidence(samples[peak], elbow_chains)},
                        _flatten_chains(elbow_chains),
                        "joint_angle",
                    )
                )

    events.extend(
        _configured_lower_body_checks(
            exercise_id, rule, camera, samples, episode, floor
        )
    )
    return events


def _configured_lower_body_checks(
    exercise_id: str,
    rule: ExerciseRule,
    camera: str,
    samples: Sequence[PoseSample],
    episode: MotionEpisode,
    floor: float,
) -> list[MotionEvent]:
    checks = set(rule.checks)
    if not checks.intersection({"knee_lock", "push_press_dip", "pike_shape", "knee_stability", "fast_return"}):
        return []
    events: list[MotionEvent] = []
    prefix = exercise_id.upper()
    _, knee_chains, knees = _configured_primary_signal(
        ExerciseRule(rule.cameras, "knee", "below", 145, 155, 100, "", "", "movement", rule.unilateral),
        camera,
        samples,
        floor,
    )
    if "knee_lock" in checks:
        candidates = [(episode.start_index, knees[episode.start_index]), (episode.end_index, knees[episode.end_index])]
        candidates = [(index, value) for index, value in candidates if value is not None]
        if candidates:
            peak, value = max(candidates, key=lambda item: item[1])
            if value >= 172.0:
                events.append(_configured_event(f"{prefix}_KNEE_LOCK", "顶端膝盖伸得过直", f"顶端膝角约 {value:.1f}°。下一组在接近伸直时保留一点控制，不要把关节顶死。", "upper_position", episode, peak, _capped_confidence(_primary_confidence(samples[peak], knee_chains, floor), camera), {"kneeAngleDeg": round(value, 1), "referenceLimitDeg": 172.0}, _flatten_chains(knee_chains), "joint_angle"))
    if "push_press_dip" in checks:
        visible = [(index, value) for index, value in enumerate(knees) if value is not None]
        if visible:
            peak, value = min(visible, key=lambda item: item[1])
            if value > 155.0:
                events.append(_configured_event(f"{prefix}_NO_DIP_DRIVE", "屈膝蓄力不明显", f"推起前膝角最低约 {value:.1f}°，没有进入当前 155° 以下的蓄力区间。下一组先做短而稳的预蹲，再连贯推起。", "movement", episode, peak, _capped_confidence(_primary_confidence(samples[peak], knee_chains, floor), camera), {"dipKneeAngleDeg": round(value, 1), "referenceLimitDeg": 155.0}, _flatten_chains(knee_chains), "joint_angle"))
    if "pike_shape" in checks:
        _, hip_chains, hips = _configured_primary_signal(
            ExerciseRule(rule.cameras, "hip", "below", 145, 155, 120, "", "", "movement", rule.unilateral),
            camera,
            samples,
            floor,
        )
        value = hips[episode.key_index]
        if value is not None and value > 120.0:
            events.append(_configured_event(f"{prefix}_PIKE_COLLAPSE", "倒V姿势出现塌陷", f"最低位置髋角约 {value:.1f}°，高于当前 120° 参考线。下一组先把髋部保持在高位，再垂直下降上身。", "movement", episode, episode.key_index, _capped_confidence(_primary_confidence(samples[episode.key_index], hip_chains, floor), camera), {"pikeHipAngleDeg": round(value, 1), "referenceLimitDeg": 120.0}, _flatten_chains(hip_chains), "joint_angle"))
    if "knee_stability" in checks:
        change, peak = _range_and_peak(knees, episode)
        if change is not None and peak is not None and change > 15.0:
            events.append(_configured_event(f"{prefix}_KNEE_COMPENSATION", "顶起时膝角变化较大", f"动作阶段膝角变化约 {change:.1f}°，超过当前 15° 参考线。下一组固定膝盖位置，把发力集中在髋部。", "movement", episode, peak, _capped_confidence(_primary_confidence(samples[peak], knee_chains, floor), camera), {"kneeAngleChangeDeg": round(change, 1), "referenceLimitDeg": 15.0}, _flatten_chains(knee_chains), "joint_angle"))
    if "fast_return" in checks:
        duration = samples[episode.end_index].timestamp_ms - samples[episode.key_index].timestamp_ms
        if 0 < duration < 300:
            events.append(_configured_event(f"{prefix}_RETURN_TOO_FAST", "回程速度偏快", f"从关键位置回到起点约用了 {duration} 毫秒，短于当前 300 毫秒参考线。下一组把回程放慢一点，保持全程受控。", "movement", episode, episode.end_index, _capped_confidence(_primary_confidence(samples[episode.end_index], knee_chains, floor), camera), {"returnDurationMs": duration, "referenceMs": 300}, _flatten_chains(knee_chains), "motion_timing"))
    return events


def _configured_event(
    code: str,
    label: str,
    explanation: str,
    stage: str,
    episode: MotionEpisode,
    peak: int,
    confidence: float,
    measurements: dict[str, Any],
    landmarks: tuple[int, ...],
    reference: str,
) -> MotionEvent:
    return MotionEvent(code, label, explanation, stage, episode.start_index, peak, episode.end_index, confidence, measurements, landmarks, reference)


def _bilateral_shoulder_asymmetry_events(
    exercise_id: str,
    samples: Sequence[PoseSample],
    primary_values: Sequence[float | None],
    floor: float,
) -> list[MotionEvent]:
    left_chain = (LEFT_HIP, LEFT_SHOULDER, LEFT_ELBOW)
    right_chain = (RIGHT_HIP, RIGHT_SHOULDER, RIGHT_ELBOW)
    left = _median_series(_angle_series(samples, left_chain, floor))
    right = _median_series(_angle_series(samples, right_chain, floor))
    differences = [
        abs(a - b) if a is not None and b is not None and (primary_values[index] or 0) > 30 else None
        for index, (a, b) in enumerate(zip(left, right))
    ]
    events: list[MotionEvent] = []
    for start, peak, end in _continuous_ranges(samples, differences, threshold=12.0, minimum_duration_ms=300):
        difference = differences[peak]
        if difference is None:
            continue
        episode = MotionEpisode(start, peak, end)
        events.append(_configured_event(f"{exercise_id.upper()}_ARM_ASYMMETRY", "两侧手臂没有同步", f"同一时刻两侧抬臂角相差约 {difference:.1f}°。下一组降低负重，让两侧同时到达关键位置。", "movement", episode, peak, min(_primary_confidence(samples[peak], (left_chain, right_chain), floor), 0.68), {"differenceDeg": round(difference, 1), "referenceLimitDeg": 12.0}, _flatten_chains((left_chain, right_chain)), "bilateral_shoulder_angles"))
    return events


def _configured_knee_medial_events(
    samples: Sequence[PoseSample], floor: float, camera: str
) -> list[MotionEvent]:
    values, sides = _knee_medial_series(samples, floor)
    events: list[MotionEvent] = []
    for start, peak, end in _continuous_ranges(samples, values, threshold=0.045, minimum_duration_ms=300):
        value, side = values[peak], sides[peak]
        if value is None or side is None:
            continue
        chain = (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE) if side == "left" else (RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE)
        events.append(_configured_event("KNEE_MEDIAL_MOVEMENT", "膝部持续向内偏移", f"{_side_label(side)}膝向内偏移约 {value:.3f} 个躯干长度。下一组让膝盖持续跟随脚尖方向。", "movement", MotionEpisode(start, peak, end), peak, min(_sample_confidence(samples[peak], chain), 0.68), {"camera": camera, "side": side, "medialOffsetNormalized": round(value, 3), "referenceLimit": 0.045}, chain, "hip_ankle_line"))
    return events


def _primary_confidence(
    sample: PoseSample,
    chains: Sequence[tuple[int, int, int]],
    floor: float,
) -> float:
    visible = [
        _sample_confidence(sample, chain)
        for chain in chains
        if min(sample.scores[index] for index in chain) >= floor
    ]
    return float(np.mean(visible)) if visible else 0.0


def _endpoint_evidence(
    sample: PoseSample, chains: Sequence[tuple[int, int, int]]
) -> str:
    if sample.inferred is None:
        return "observed"
    return (
        "inferred_direction"
        if any(sample.inferred[index] for chain in chains for index in chain)
        else "observed"
    )


def _flatten_chains(chains: Sequence[Sequence[int]]) -> tuple[int, ...]:
    return tuple(dict.fromkeys(index for chain in chains for index in chain))


def _capped_confidence(confidence: float, camera: str) -> float:
    caps = {"side_front": 0.75, "side_rear": 0.72, "front": 0.68, "rear": 0.70}
    return min(confidence, caps.get(camera, 1.0))


def _stage_label(stage: str) -> str:
    return {"lower_position": "最低位置", "upper_position": "最高位置"}.get(stage, "动作关键位置")


def _side_phrase(side: str) -> str:
    return "双侧平均" if side == "bilateral" else f"{_side_label(side)}侧"


def _range_and_peak(
    values: Sequence[float | None], episode: MotionEpisode
) -> tuple[float | None, int | None]:
    segment = [
        (index, value)
        for index, value in enumerate(
            values[episode.start_index: episode.end_index + 1],
            start=episode.start_index,
        )
        if value is not None
    ]
    if len(segment) < 2:
        return None, None
    low = min(segment, key=lambda item: item[1])
    high = max(segment, key=lambda item: item[1])
    return float(high[1] - low[1]), high[0]


def _generic_elbow_analysis(
    samples: Sequence[PoseSample],
    floor: float,
) -> EventAnalysis:
    _, chain = _best_side_chain(
        samples,
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        floor,
    )
    values = _median_series(_angle_series(samples, chain, floor))
    episodes = _episodes_below(samples, values, enter=100.0, exit=145.0)
    return EventAnalysis(
        (),
        tuple(value for value in values if value is not None),
        len(episodes),
        ("no_exercise_specific_event_rules",),
    )


def _best_side_chain(
    samples: Sequence[PoseSample],
    left: tuple[int, int, int],
    right: tuple[int, int, int],
    floor: float,
) -> tuple[str, tuple[int, int, int]]:
    # Neural-network confidence alone is not a side-selection strategy: an
    # occluded limb can be confidently attached to a plate, face or machine.
    # Select the chain that is anatomically stable and temporally continuous.
    left_quality = chain_quality(samples, left, floor, side="left")
    right_quality = chain_quality(samples, right, floor, side="right")
    if right_quality.score > left_quality.score:
        return "right", right
    return "left", left


def _angle_series(
    samples: Sequence[PoseSample],
    chain: tuple[int, int, int],
    floor: float,
) -> list[float | None]:
    values: list[float | None] = []
    for sample in samples:
        if min(sample.scores[index] for index in chain) < floor:
            values.append(None)
        else:
            values.append(joint_angle(*(sample.points[index] for index in chain)))
    return values


def _median_series(values: Sequence[float | None], radius: int = 1) -> list[float | None]:
    result: list[float | None] = []
    for index in range(len(values)):
        window = [
            value
            for value in values[max(0, index - radius): min(len(values), index + radius + 1)]
            if value is not None
        ]
        result.append(float(np.median(window)) if window else None)
    return result


def _adaptive_bench_press_episodes(
    samples: Sequence[PoseSample],
    values: Sequence[float | None],
) -> list[MotionEpisode]:
    """Find visible press phases without treating them as countable repetitions.

    A cropped or foreshortened forearm can preserve its direction while making
    the absolute elbow angle systematically too small.  In that case we use
    only the clip-relative low/high states to establish that a lower-and-return
    motion occurred.  Exact depth and forearm-angle rules remain disabled.
    """
    plausible = [
        value if value is not None and 25.0 <= value <= 175.0 else None
        for value in values
    ]
    usable = [value for value in plausible if value is not None]
    if len(usable) < 9:
        return []
    lower = float(np.percentile(usable, 30))
    upper = float(np.percentile(usable, 75))
    if upper - lower < 28.0:
        return []
    return _sustained_episodes_below(
        samples,
        plausible,
        enter=lower,
        exit=upper,
        sustained_samples=3,
    )


def _sustained_episodes_below(
    samples: Sequence[PoseSample],
    values: Sequence[float | None],
    *,
    enter: float,
    exit: float,
    sustained_samples: int,
    minimum_duration_ms: int = 300,
) -> list[MotionEpisode]:
    episodes: list[MotionEpisode] = []
    state = "seeking_ready"
    ready_index: int | None = None
    key_index: int | None = None
    key_value = math.inf
    high_run = 0
    low_run = 0

    for index, value in enumerate(values):
        gap_ms = (
            samples[index].timestamp_ms - samples[index - 1].timestamp_ms
            if index > 0
            else 0
        )
        if value is None or gap_ms > 300:
            state = "seeking_ready"
            ready_index = None
            key_index = None
            key_value = math.inf
            high_run = 0
            low_run = 0
            continue

        if state == "seeking_ready":
            high_run = high_run + 1 if value >= exit else 0
            if high_run >= sustained_samples:
                ready_index = index - sustained_samples + 1
                state = "seeking_bottom"
                low_run = 0
            continue

        if state == "seeking_bottom":
            if value >= exit:
                high_run += 1
                if high_run >= sustained_samples:
                    ready_index = index - sustained_samples + 1
            else:
                high_run = 0
            low_run = low_run + 1 if value <= enter else 0
            if low_run < sustained_samples:
                continue
            start = ready_index if ready_index is not None else index
            key_index = min(
                range(start, index + 1),
                key=lambda candidate: (
                    values[candidate]
                    if values[candidate] is not None
                    else math.inf
                ),
            )
            key_value = float(values[key_index])
            state = "seeking_return"
            high_run = 0
            continue

        if value < key_value:
            key_index = index
            key_value = value
        high_run = high_run + 1 if value >= exit else 0
        if high_run < sustained_samples or key_index is None:
            continue
        end = index
        start = ready_index if ready_index is not None else key_index
        if samples[end].timestamp_ms - samples[start].timestamp_ms >= minimum_duration_ms:
            episodes.append(MotionEpisode(start, key_index, end))
        state = "seeking_bottom"
        ready_index = index - sustained_samples + 1
        key_index = None
        key_value = math.inf
        high_run = sustained_samples
        low_run = 0

    return episodes


def _episodes_below(
    samples: Sequence[PoseSample],
    values: Sequence[float | None],
    *,
    enter: float,
    exit: float,
    minimum_duration_ms: int = 300,
) -> list[MotionEpisode]:
    episodes: list[MotionEpisode] = []
    start: int | None = None
    key: int | None = None
    key_value = math.inf
    ready_from_start_position = False
    for index, value in enumerate(values):
        gap_ms = (
            samples[index].timestamp_ms - samples[index - 1].timestamp_ms
            if index > 0
            else 0
        )
        if value is None or gap_ms > 300:
            start = None
            key = None
            key_value = math.inf
            ready_from_start_position = False
            continue
        if start is None and value >= exit:
            ready_from_start_position = True
            continue
        if start is None and ready_from_start_position and value <= enter:
            start = index - 1 if index > 0 and gap_ms <= 300 else index
            key = index
            key_value = value
            ready_from_start_position = False
            continue
        if start is None:
            continue
        if value < key_value:
            key = index
            key_value = value
        if value >= exit and key is not None:
            if samples[index].timestamp_ms - samples[start].timestamp_ms >= minimum_duration_ms:
                episodes.append(MotionEpisode(start, key, index))
            start = None
            key = None
            key_value = math.inf
            ready_from_start_position = True
    return episodes


def _episodes_above(
    samples: Sequence[PoseSample],
    values: Sequence[float | None],
    *,
    enter: float,
    exit: float,
    minimum_duration_ms: int = 300,
) -> list[MotionEpisode]:
    episodes: list[MotionEpisode] = []
    start: int | None = None
    key: int | None = None
    key_value = -math.inf
    ready_from_start_position = False
    for index, value in enumerate(values):
        gap_ms = (
            samples[index].timestamp_ms - samples[index - 1].timestamp_ms
            if index > 0
            else 0
        )
        if value is None or gap_ms > 300:
            start = None
            key = None
            key_value = -math.inf
            ready_from_start_position = False
            continue
        if start is None and value <= exit:
            ready_from_start_position = True
            continue
        if start is None and ready_from_start_position and value >= enter:
            start = index - 1 if index > 0 and gap_ms <= 300 else index
            key = index
            key_value = value
            ready_from_start_position = False
            continue
        if start is None:
            continue
        if value > key_value:
            key = index
            key_value = value
        if value <= exit and key is not None:
            if (
                samples[index].timestamp_ms - samples[start].timestamp_ms
                >= minimum_duration_ms
            ):
                episodes.append(MotionEpisode(start, key, index))
            start = None
            key = None
            key_value = -math.inf
            ready_from_start_position = True
    return episodes


def _knee_medial_series(
    samples: Sequence[PoseSample],
    floor: float,
) -> tuple[list[float | None], list[str | None]]:
    values: list[float | None] = []
    sides: list[str | None] = []
    for sample in samples:
        required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE)
        if min(sample.scores[index] for index in required) < floor:
            values.append(None)
            sides.append(None)
            continue
        shoulder_mid = (sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        torso = max(1.0, float(np.linalg.norm(shoulder_mid - hip_mid)))
        center_x = float(hip_mid[0])
        candidates: list[tuple[float, str]] = []
        for side, hip, knee, ankle in (
            ("left", LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
            ("right", RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE),
        ):
            hip_point = sample.points[hip]
            knee_point = sample.points[knee]
            ankle_point = sample.points[ankle]
            height = float(ankle_point[1] - hip_point[1])
            if abs(height) < 1.0:
                continue
            ratio = max(0.0, min(1.0, float((knee_point[1] - hip_point[1]) / height)))
            reference_x = float(hip_point[0] + ratio * (ankle_point[0] - hip_point[0]))
            inward = (abs(reference_x - center_x) - abs(float(knee_point[0]) - center_x)) / torso
            candidates.append((inward, side))
        if not candidates:
            values.append(None)
            sides.append(None)
            continue
        value, side = max(candidates)
        values.append(float(value))
        sides.append(side)
    return _median_series(values), sides


def _shoulder_height_difference_series(
    samples: Sequence[PoseSample],
    floor: float,
) -> list[float | None]:
    values: list[float | None] = []
    required = (
        LEFT_SHOULDER,
        RIGHT_SHOULDER,
        LEFT_HIP,
        RIGHT_HIP,
    )
    for sample in samples:
        if (
            min(sample.scores[index] for index in required) < floor
            or _frontal_pose_quality(sample, floor) < 0.45
        ):
            values.append(None)
            continue
        shoulder_mid = (
            sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]
        ) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        torso = max(1.0, float(np.linalg.norm(shoulder_mid - hip_mid)))
        difference = abs(
            float(
                sample.points[LEFT_SHOULDER][1]
                - sample.points[RIGHT_SHOULDER][1]
            )
        ) / torso
        values.append(difference)
    return _median_series(values)


def _torso_length(sample: PoseSample, floor: float) -> float | None:
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    if min(sample.scores[index] for index in required) < floor:
        return None
    shoulder_mid = (
        sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]
    ) / 2
    hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
    value = float(np.linalg.norm(shoulder_mid - hip_mid))
    return value if np.isfinite(value) and value >= 6.0 else None


def _thigh_length(sample: PoseSample, floor: float) -> float | None:
    required = (LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE)
    if min(sample.scores[index] for index in required) < floor:
        return None
    hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
    knee_mid = (sample.points[LEFT_KNEE] + sample.points[RIGHT_KNEE]) / 2
    value = float(np.linalg.norm(hip_mid - knee_mid))
    return value if np.isfinite(value) and value >= 6.0 else None


def _shoulder_hip_gap_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    values: list[float | None] = []
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    for sample in samples:
        thigh = _thigh_length(sample, floor)
        if thigh is None or min(sample.scores[index] for index in required) < floor:
            values.append(None)
            continue
        shoulder_mid = (
            sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]
        ) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        values.append(float((hip_mid[1] - shoulder_mid[1]) / thigh))
    return _median_series(values)


def _hip_swing_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    hip_positions: list[float | None] = []
    torso_lengths: list[float | None] = []
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None or min(sample.scores[LEFT_HIP], sample.scores[RIGHT_HIP]) < floor:
            hip_positions.append(None)
            torso_lengths.append(None)
            continue
        hip_positions.append(float((sample.points[LEFT_HIP][0] + sample.points[RIGHT_HIP][0]) / 2))
        torso_lengths.append(torso)
    baseline_values = [value for value in hip_positions if value is not None]
    if not baseline_values:
        return [None] * len(samples)
    baseline = float(np.median(baseline_values))
    return _median_series([
        abs(value - baseline) / torso if value is not None and torso is not None else None
        for value, torso in zip(hip_positions, torso_lengths)
    ])


def _elbow_tuck_series(
    samples: Sequence[PoseSample],
    floor: float,
    *,
    per_side: bool = False,
) -> list[float | None] | tuple[list[float | None], list[float | None]]:
    left: list[float | None] = []
    right: list[float | None] = []
    required_center = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None or min(sample.scores[index] for index in required_center) < floor:
            left.append(None)
            right.append(None)
            continue
        center_x = float((sample.points[LEFT_SHOULDER][0] + sample.points[RIGHT_SHOULDER][0]) / 2)
        left.append(abs(float(sample.points[LEFT_ELBOW][0]) - center_x) / torso if sample.scores[LEFT_ELBOW] >= floor else None)
        right.append(abs(float(sample.points[RIGHT_ELBOW][0]) - center_x) / torso if sample.scores[RIGHT_ELBOW] >= floor else None)
    left, right = _median_series(left), _median_series(right)
    if per_side:
        return left, right
    return [
        min(visible) if visible else None
        for a, b in zip(left, right)
        for visible in [[value for value in (a, b) if value is not None]]
    ]


def _wrist_shoulder_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    values: list[float | None] = []
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None:
            values.append(None)
            continue
        candidates = []
        for shoulder, wrist in ((LEFT_SHOULDER, LEFT_WRIST), (RIGHT_SHOULDER, RIGHT_WRIST)):
            if min(sample.scores[shoulder], sample.scores[wrist]) >= floor:
                candidates.append(float((sample.points[shoulder][1] - sample.points[wrist][1]) / torso))
        values.append(max(candidates) if candidates else None)
    return _median_series(values)


def _shoulder_elbow_height_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    values: list[float | None] = []
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None:
            values.append(None)
            continue
        candidates = []
        for shoulder, elbow in ((LEFT_SHOULDER, LEFT_ELBOW), (RIGHT_SHOULDER, RIGHT_ELBOW)):
            if min(sample.scores[shoulder], sample.scores[elbow]) >= floor:
                candidates.append(float((sample.points[shoulder][1] - sample.points[elbow][1]) / torso))
        values.append(max(candidates) if candidates else None)
    return _median_series(values)


def _body_line_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    left = _angle_series(samples, (LEFT_SHOULDER, LEFT_HIP, LEFT_ANKLE), floor)
    right = _angle_series(samples, (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_ANKLE), floor)
    return _median_series([
        float(np.mean(visible)) if visible else None
        for a, b in zip(left, right)
        for visible in [[value for value in (a, b) if value is not None]]
    ])


def _shoulder_span_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    return _median_series([
        value if value > 0 else None
        for value in (_frontal_pose_quality(sample, floor) for sample in samples)
    ])


def _hand_cross_series(
    samples: Sequence[PoseSample], floor: float
) -> tuple[list[float | None], list[float | None]]:
    left: list[float | None] = []
    right: list[float | None] = []
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None:
            left.append(None)
            right.append(None)
            continue
        center_x = float((sample.points[LEFT_SHOULDER][0] + sample.points[RIGHT_SHOULDER][0]) / 2)
        left.append((center_x - float(sample.points[LEFT_WRIST][0])) / torso if sample.scores[LEFT_WRIST] >= floor else None)
        right.append((float(sample.points[RIGHT_WRIST][0]) - center_x) / torso if sample.scores[RIGHT_WRIST] >= floor else None)
    return _median_series(left), _median_series(right)


def _hip_height_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    values: list[float | None] = []
    for sample in samples:
        torso = _torso_length(sample, floor)
        if torso is None or min(sample.scores[LEFT_HIP], sample.scores[RIGHT_HIP]) < floor:
            values.append(None)
            continue
        hip_y = float((sample.points[LEFT_HIP][1] + sample.points[RIGHT_HIP][1]) / 2)
        values.append(hip_y / torso)
    return _median_series(values)


def _trunk_orientation_series(
    samples: Sequence[PoseSample], floor: float
) -> list[float | None]:
    values: list[float | None] = []
    for sample in samples:
        required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
        if min(sample.scores[index] for index in required) < floor:
            values.append(None)
            continue
        shoulder_mid = (sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        values.append(_vertical_deviation(hip_mid, shoulder_mid))
    return _median_series(values)


def _frontal_pose_quality(sample: PoseSample, floor: float) -> float:
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    if min(sample.scores[index] for index in required) < floor:
        return 0.0
    shoulder_mid = (
        sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]
    ) / 2
    hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
    torso = float(np.linalg.norm(shoulder_mid - hip_mid))
    shoulder_span = float(
        np.linalg.norm(
            sample.points[LEFT_SHOULDER] - sample.points[RIGHT_SHOULDER]
        )
    )
    if not np.isfinite(torso) or not np.isfinite(shoulder_span) or torso < 6.0:
        return 0.0
    return shoulder_span / torso


def _continuous_ranges(
    samples: Sequence[PoseSample],
    values: Sequence[float | None],
    *,
    threshold: float,
    minimum_duration_ms: int,
) -> Iterable[tuple[int, int, int]]:
    start: int | None = None
    peak: int | None = None
    peak_value = -math.inf
    for index in range(len(values) + 1):
        value = values[index] if index < len(values) else None
        gap_ok = (
            index == 0
            or index >= len(samples)
            or samples[index].timestamp_ms - samples[index - 1].timestamp_ms <= 300
        )
        active = value is not None and value >= threshold and gap_ok
        if active:
            if start is None:
                start = index
                peak = index
                peak_value = float(value)
            elif float(value) > peak_value:
                peak = index
                peak_value = float(value)
            continue
        if start is not None and peak is not None:
            end = index - 1
            if (
                end - start >= 2
                and samples[end].timestamp_ms - samples[start].timestamp_ms >= minimum_duration_ms
            ):
                yield start, peak, end
        start = None
        peak = None
        peak_value = -math.inf


def _trunk_shift_in_episode(
    samples: Sequence[PoseSample],
    hip_values: Sequence[float | None],
    episode: MotionEpisode,
    side: str,
    floor: float,
) -> tuple[int, int, int, float, float] | None:
    shoulder = LEFT_SHOULDER if side == "left" else RIGHT_SHOULDER
    hip = LEFT_HIP if side == "left" else RIGHT_HIP
    tilts: list[float | None] = []
    for sample in samples:
        if min(sample.scores[shoulder], sample.scores[hip]) < floor:
            tilts.append(None)
            continue
        tilts.append(_vertical_deviation(sample.points[hip], sample.points[shoulder]))
    tilts = _median_series(tilts)
    best: tuple[int, int, int, float, float] | None = None
    for start in range(episode.start_index, episode.end_index - 2):
        end = min(episode.end_index, start + 3)
        if samples[end].timestamp_ms - samples[start].timestamp_ms > 450:
            continue
        if tilts[start] is None or tilts[end] is None or hip_values[start] is None or hip_values[end] is None:
            continue
        trunk_change = abs(float(tilts[end]) - float(tilts[start]))
        hip_change = abs(float(hip_values[end]) - float(hip_values[start]))
        if trunk_change <= 8.0 or hip_change >= 4.0:
            continue
        confidence = min(
            float(samples[start].scores[shoulder]),
            float(samples[start].scores[hip]),
            float(samples[end].scores[shoulder]),
            float(samples[end].scores[hip]),
        )
        candidate = (start, end, end, trunk_change, confidence)
        if best is None or candidate[3] > best[3]:
            best = candidate
    return best


def _normalized_elbow_descent(
    start: PoseSample,
    key: PoseSample,
    elbow: int,
    floor: float,
) -> float | None:
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, elbow)
    if min(start.scores[index] for index in required) < floor or key.scores[elbow] < floor:
        return None
    shoulder_mid = (start.points[LEFT_SHOULDER] + start.points[RIGHT_SHOULDER]) / 2
    hip_mid = (start.points[LEFT_HIP] + start.points[RIGHT_HIP]) / 2
    torso = max(1.0, float(np.linalg.norm(shoulder_mid - hip_mid)))
    return float((key.points[elbow][1] - start.points[elbow][1]) / torso)


def _vertical_deviation(first: np.ndarray, second: np.ndarray) -> float:
    dx = float(second[0] - first[0])
    dy = float(second[1] - first[1])
    angle = abs(math.degrees(math.atan2(dx, -dy))) % 180.0
    return min(angle, 180.0 - angle)


def _observed_forearm_deviations(
    samples: Sequence[PoseSample],
    elbow: int,
    wrist: int,
    center_index: int,
    floor: float,
    *,
    radius: int,
) -> list[float]:
    deviations: list[float] = []
    for index in range(
        max(0, center_index - radius),
        min(len(samples), center_index + radius + 1),
    ):
        sample = samples[index]
        if min(sample.scores[elbow], sample.scores[wrist]) < floor:
            continue
        if _has_inferred_landmark(sample, (wrist,)):
            continue
        deviations.append(
            _vertical_deviation(sample.points[elbow], sample.points[wrist])
        )
    return deviations


def _sample_confidence(sample: PoseSample, landmarks: Sequence[int]) -> float:
    score = float(min(sample.scores[index] for index in landmarks))
    if sample.inferred is not None and any(sample.inferred[index] for index in landmarks):
        score *= 0.62
    return score


def _has_inferred_landmark(
    sample: PoseSample, landmarks: Sequence[int]
) -> bool:
    return sample.inferred is not None and any(
        sample.inferred[index] for index in landmarks
    )


def _side_label(side: str) -> str:
    return "左" if side == "left" else "右"


def _merge_nearby_events(
    events: Sequence[MotionEvent],
    samples: Sequence[PoseSample],
    merge_window_ms: int = 650,
) -> list[MotionEvent]:
    ordered = sorted(events, key=lambda event: (samples[event.peak_index].timestamp_ms, event.code))
    merged: list[MotionEvent] = []
    for event in ordered:
        if not merged:
            merged.append(event)
            continue
        previous = merged[-1]
        if (
            previous.code == event.code
            and samples[event.start_index].timestamp_ms - samples[previous.end_index].timestamp_ms <= merge_window_ms
        ):
            peak = event if event.confidence >= previous.confidence else previous
            merged[-1] = MotionEvent(
                code=previous.code,
                label=peak.label,
                explanation=peak.explanation,
                stage=peak.stage,
                start_index=previous.start_index,
                peak_index=peak.peak_index,
                end_index=event.end_index,
                confidence=max(previous.confidence, event.confidence),
                measurements=peak.measurements,
                highlight_landmarks=peak.highlight_landmarks,
                reference=peak.reference,
            )
        else:
            merged.append(event)
    return merged


def _select_representative_events(
    events: Sequence[MotionEvent],
    samples: Sequence[PoseSample],
    maximum: int,
) -> list[MotionEvent]:
    """Keep issue diversity while spreading evidence across the full video."""
    ordered = sorted(events, key=lambda event: samples[event.peak_index].timestamp_ms)
    if maximum <= 0:
        return []
    if len(ordered) <= maximum:
        return ordered

    selected: list[MotionEvent] = []
    for code in dict.fromkeys(event.code for event in ordered):
        candidates = [event for event in ordered if event.code == code]
        selected.append(max(candidates, key=lambda event: event.confidence))
        if len(selected) >= maximum:
            return sorted(
                selected,
                key=lambda event: samples[event.peak_index].timestamp_ms,
            )

    remaining = [event for event in ordered if event not in selected]
    while remaining and len(selected) < maximum:
        selected_times = [
            samples[event.peak_index].timestamp_ms for event in selected
        ]

        def coverage_score(event: MotionEvent) -> tuple[float, float]:
            timestamp = samples[event.peak_index].timestamp_ms
            nearest_gap = min(abs(timestamp - value) for value in selected_times)
            return (float(nearest_gap), event.confidence)

        chosen = max(remaining, key=coverage_score)
        selected.append(chosen)
        remaining.remove(chosen)

    return sorted(selected, key=lambda event: samples[event.peak_index].timestamp_ms)
