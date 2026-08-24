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
    elif normalized == "pull_up":
        analysis = _pull_up_events(camera, samples, confidence_floor)
    elif normalized in {"bench_press", "dumbbell_press"}:
        analysis = _bench_press_events(camera, samples, confidence_floor)
    elif normalized == "hip_thrust":
        analysis = _hip_thrust_events(samples, confidence_floor)
    elif normalized == "lateral_raise":
        analysis = _lateral_raise_events(camera, samples, confidence_floor)
    elif normalized in {
        "shoulder_press",
        "push_up",
        "dip",
        "row",
        "face_pull",
        "biceps_curl",
        "triceps_extension",
    }:
        analysis = _elbow_family_events(
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
                or min(left, right) >= 150.0
                or _frontal_pose_quality(sample, floor) < 0.45
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
        "row": {
            "direction": "below",
            "enter": 130.0,
            "exit": 145.0,
            "target": 90.0,
            "code": "ROW_RANGE_INCOMPLETE",
            "label": "划船肘部回拉不足",
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
        ):
            differences.append(None)
            continue
        average = (left + right) / 2
        at_rest = (
            average <= config["exit"]
            if config["direction"] == "above"
            else average >= config["exit"]
        )
        differences.append(None if at_rest else abs(left - right))
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


def _sample_confidence(sample: PoseSample, landmarks: Sequence[int]) -> float:
    score = float(min(sample.scores[index] for index in landmarks))
    if sample.inferred is not None and any(sample.inferred[index] for index in landmarks):
        score *= 0.62
    return score


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
