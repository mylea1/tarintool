from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Sequence

import numpy as np

from .angles import joint_angle
from .events import (
    LEFT_ELBOW,
    LEFT_HIP,
    LEFT_KNEE,
    LEFT_SHOULDER,
    LEFT_WRIST,
    RIGHT_ELBOW,
    RIGHT_HIP,
    RIGHT_KNEE,
    RIGHT_SHOULDER,
    RIGHT_WRIST,
    PoseSample,
)


@dataclass(frozen=True)
class ActionCompatibility:
    compatible: bool
    checked: bool
    confidence: float
    selected_family: str
    observed_family: str | None = None
    reasons: tuple[str, ...] = ()
    measurements: tuple[tuple[str, float], ...] = ()

    def to_result(self) -> dict[str, object]:
        return {
            "compatible": self.compatible,
            "checked": self.checked,
            "confidence": round(float(np.clip(self.confidence, 0.0, 1.0)), 3),
            "selectedFamily": self.selected_family,
            "observedFamily": self.observed_family,
            "reasons": list(self.reasons),
            "measurements": {
                key: round(value, 3) for key, value in self.measurements
            },
        }


def assess_action_compatibility(
    exercise_id: str,
    camera: str,
    samples: Sequence[PoseSample],
    confidence_floor: float = 0.35,
) -> ActionCompatibility:
    """Reject only strong press-vs-hip-thrust contradictions.

    This is deliberately a compatibility gate, not a general exercise
    classifier. Ambiguous evidence remains compatible so the worker does not
    silently replace the user's selected exercise.
    """
    selected = exercise_id.lower()
    if selected not in {"bench_press", "dumbbell_press", "hip_thrust"}:
        return ActionCompatibility(True, False, 0.0, selected)
    if camera not in {"side", "side_front", "side_rear"}:
        return ActionCompatibility(True, False, 0.0, selected)

    elbow_range = _best_joint_range(
        samples,
        (
            (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
            (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
        ),
        confidence_floor,
    )
    hip_angle_range = _best_joint_range(
        samples,
        (
            (LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE),
            (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE),
        ),
        confidence_floor,
    )
    hip_vertical_range = _normalized_hip_vertical_range(samples, confidence_floor)
    horizontal_ratio = _horizontal_torso_ratio(samples, confidence_floor)
    if None in (elbow_range, hip_angle_range, hip_vertical_range, horizontal_ratio):
        return ActionCompatibility(
            True,
            True,
            0.35,
            selected,
            reasons=("insufficient_signature_features",),
        )

    assert elbow_range is not None
    assert hip_angle_range is not None
    assert hip_vertical_range is not None
    assert horizontal_ratio is not None
    measurements = (
        ("elbowRangeDeg", elbow_range),
        ("hipAngleRangeDeg", hip_angle_range),
        ("hipVerticalRangeTorso", hip_vertical_range),
        ("horizontalTorsoRatio", horizontal_ratio),
    )

    if selected == "hip_thrust":
        press_signature = (
            horizontal_ratio >= 0.55
            and elbow_range >= 60.0
        )
        if press_signature:
            confidence = min(
                0.96,
                0.62
                + min(0.18, (elbow_range - 60.0) / 160.0)
                + min(0.10, horizontal_ratio * 0.10)
            )
            return ActionCompatibility(
                False,
                True,
                confidence,
                selected,
                observed_family="bench_press",
                reasons=(
                    "dominant_elbow_press_cycle",
                    "horizontal_supported_torso",
                ),
                measurements=measurements,
            )

    if selected in {"bench_press", "dumbbell_press"}:
        hip_thrust_signature = (
            horizontal_ratio >= 0.45
            and elbow_range <= 28.0
            and hip_vertical_range >= 0.20
            and hip_angle_range >= 35.0
        )
        if hip_thrust_signature:
            return ActionCompatibility(
                False,
                True,
                min(0.92, 0.68 + hip_vertical_range * 0.35),
                selected,
                observed_family="hip_thrust",
                reasons=(
                    "dominant_hip_extension_cycle",
                    "limited_elbow_press_motion",
                    "horizontal_supported_torso",
                ),
                measurements=measurements,
            )

    return ActionCompatibility(
        True,
        True,
        0.72,
        selected,
        reasons=("selected_action_signature_is_plausible",),
        measurements=measurements,
    )


def _best_joint_range(
    samples: Sequence[PoseSample],
    chains: Sequence[tuple[int, int, int]],
    floor: float,
) -> float | None:
    ranges: list[float] = []
    for chain in chains:
        values = [
            joint_angle(*(sample.points[index] for index in chain))
            for sample in samples
            if min(sample.scores[index] for index in chain) >= floor
        ]
        if len(values) >= 6:
            ranges.append(float(np.percentile(values, 90) - np.percentile(values, 10)))
    return max(ranges) if ranges else None


def _horizontal_torso_ratio(
    samples: Sequence[PoseSample],
    floor: float,
) -> float | None:
    horizontal = 0
    valid = 0
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    for sample in samples:
        if min(sample.scores[index] for index in required) < floor:
            continue
        shoulder_mid = (sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        vector = hip_mid - shoulder_mid
        length = float(np.linalg.norm(vector))
        if not np.isfinite(length) or length < 8.0:
            continue
        angle = abs(math.degrees(math.atan2(float(vector[1]), float(vector[0]))))
        angle = min(angle, abs(180.0 - angle))
        valid += 1
        if angle <= 30.0:
            horizontal += 1
    return horizontal / valid if valid >= 6 else None


def _normalized_hip_vertical_range(
    samples: Sequence[PoseSample],
    floor: float,
) -> float | None:
    values: list[float] = []
    required = (LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP)
    for sample in samples:
        if min(sample.scores[index] for index in required) < floor:
            continue
        shoulder_mid = (sample.points[LEFT_SHOULDER] + sample.points[RIGHT_SHOULDER]) / 2
        hip_mid = (sample.points[LEFT_HIP] + sample.points[RIGHT_HIP]) / 2
        torso = float(np.linalg.norm(hip_mid - shoulder_mid))
        if not np.isfinite(torso) or torso < 8.0:
            continue
        values.append(float(hip_mid[1]) / torso)
    if len(values) < 6:
        return None
    return float(np.percentile(values, 90) - np.percentile(values, 10))
