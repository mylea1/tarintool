from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Iterable, Sequence

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
LEFT_ANKLE = 15
RIGHT_ANKLE = 16


@dataclass(frozen=True)
class PoseSample:
    timestamp_ms: int
    source_frame_index: int
    points: np.ndarray
    scores: np.ndarray


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


@dataclass(frozen=True)
class EventAnalysis:
    events: tuple[MotionEvent, ...]
    primary_angles: tuple[float, ...]
    complete_motion_cycles: int
    limitations: tuple[str, ...]


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
        "confidence": round(max(0.0, min(1.0, event.confidence)), 3),
        "measurements": event.measurements,
        "explanation": event.explanation,
        "evidenceId": evidence_id,
    }


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
    elif normalized in {"bench_press", "dumbbell_press"}:
        analysis = _bench_press_events(camera, samples, confidence_floor)
    else:
        analysis = _generic_elbow_analysis(samples, confidence_floor)

    events = _merge_nearby_events(analysis.events, samples)
    return EventAnalysis(
        events=tuple(events[:max_events]),
        primary_angles=analysis.primary_angles,
        complete_motion_cycles=analysis.complete_motion_cycles,
        limitations=analysis.limitations,
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
    values = _median_series(_angle_series(samples, chain, floor))
    episodes = _episodes_below(samples, values, enter=130.0, exit=135.0)
    events: list[MotionEvent] = []
    elbow_index = LEFT_ELBOW if side == "left" else RIGHT_ELBOW
    for episode in episodes:
        start_angle = values[episode.start_index]
        bottom_angle = values[episode.key_index]
        if start_angle is None or bottom_angle is None:
            continue
        confidence = _sample_confidence(samples[episode.key_index], chain)
        if start_angle < 135.0 or bottom_angle > 90.0:
            events.append(
                MotionEvent(
                    code="LAT_PULLDOWN_RANGE_INCOMPLETE",
                    label="高位下拉行程可能不足",
                    explanation=(
                        f"可见侧肘角从约 {start_angle:.1f}° 变化到 {bottom_angle:.1f}°，"
                        "尚未稳定覆盖当前 135° 到 90° 的参考范围。"
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
                        "startReferenceDeg": 135.0,
                        "bottomReferenceDeg": 90.0,
                    },
                    highlight_landmarks=chain,
                    reference="joint_angle",
                )
            )

        descent = _normalized_elbow_descent(
            samples[episode.start_index], samples[episode.key_index], elbow_index, floor
        )
        if descent is not None and descent < 0.035:
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

    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        ("handle_position_requires_equipment_detector",),
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
    values = _median_series(_angle_series(samples, chain, floor))
    episodes = _episodes_below(samples, values, enter=120.0, exit=140.0)
    if camera != "side":
        return EventAnalysis(
            (),
            tuple(value for value in values if value is not None),
            len(episodes),
            (
                "forearm_verticality_requires_true_side_view",
                "bar_path_requires_equipment_detector",
            ),
        )
    events: list[MotionEvent] = []
    elbow = LEFT_ELBOW if side == "left" else RIGHT_ELBOW
    wrist = LEFT_WRIST if side == "left" else RIGHT_WRIST
    for episode in episodes:
        deviations: list[float] = []
        confidences: list[float] = []
        for index in range(max(episode.start_index, episode.key_index - 1), min(episode.end_index, episode.key_index + 1) + 1):
            sample = samples[index]
            if min(sample.scores[elbow], sample.scores[wrist]) < floor:
                continue
            deviations.append(_vertical_deviation(sample.points[elbow], sample.points[wrist]))
            confidences.append(float(min(sample.scores[elbow], sample.scores[wrist])))
        if not deviations:
            continue
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
                },
                highlight_landmarks=(elbow, wrist),
                reference="vertical_forearm",
            )
        )
    limitations = []
    if camera not in {"side", "side_front"}:
        limitations.append("forearm_verticality_requires_side_view")
    limitations.append("bar_path_requires_equipment_detector")
    return EventAnalysis(
        tuple(events),
        tuple(value for value in values if value is not None),
        len(episodes),
        tuple(limitations),
    )


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
    def quality(chain: tuple[int, int, int]) -> tuple[float, float]:
        confidences: list[float] = []
        angles: list[float] = []
        for sample in samples:
            score = float(min(sample.scores[index] for index in chain))
            if score < floor:
                continue
            confidences.append(score)
            angles.append(joint_angle(*(sample.points[index] for index in chain)))
        motion = float(np.percentile(angles, 90) - np.percentile(angles, 10)) if len(angles) >= 3 else 0.0
        return (float(np.mean(confidences)) if confidences else 0.0, motion)

    left_quality = quality(left)
    right_quality = quality(right)
    if right_quality > left_quality:
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


def _sample_confidence(sample: PoseSample, landmarks: Sequence[int]) -> float:
    return float(min(sample.scores[index] for index in landmarks))


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
