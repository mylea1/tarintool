from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Sequence


Point = Sequence[float]


def joint_angle(first: Point, vertex: Point, third: Point) -> float:
    """Return the smaller angle in degrees at ``vertex``."""
    a = math.atan2(third[1] - vertex[1], third[0] - vertex[0])
    b = math.atan2(first[1] - vertex[1], first[0] - vertex[0])
    angle = abs(math.degrees(a - b))
    return 360.0 - angle if angle > 180.0 else angle


@dataclass
class RepetitionCounter:
    low_threshold: float
    high_threshold: float
    count: int = 0
    phase: str = "unknown"

    def update(self, angle: float) -> int:
        if angle <= self.low_threshold:
            self.phase = "compressed"
        elif angle >= self.high_threshold and self.phase == "compressed":
            self.count += 1
            self.phase = "extended"
        return self.count


@dataclass(frozen=True)
class EvidenceAssessment:
    assessable: bool
    reason: str
    angle_range: float


def assess_exercise_evidence(
    *,
    repetitions: int,
    confidence: float,
    detected_frames: int,
    inference_frames: int,
    angle_samples: Sequence[float],
    minimum_confidence: float = 0.25,
    minimum_detection_rate: float = 0.55,
    minimum_angle_range: float = 35.0,
) -> EvidenceAssessment:
    """Reject clips that contain a pose but not enough exercise evidence.

    A visible person is not proof that the selected exercise occurred. A clip
    is assessable only after the target joint is visible often enough, moves
    through a meaningful range, and completes at least one full cycle.
    """
    detection_rate = (
        detected_frames / inference_frames if inference_frames > 0 else 0.0
    )
    angle_range = (
        float(max(angle_samples) - min(angle_samples)) if angle_samples else 0.0
    )
    if detected_frames < 6 or detection_rate < minimum_detection_rate:
        return EvidenceAssessment(False, "insufficient_landmarks", angle_range)
    if confidence < minimum_confidence:
        return EvidenceAssessment(False, "insufficient_pose_quality", angle_range)
    if len(angle_samples) < 6 or angle_range < minimum_angle_range:
        return EvidenceAssessment(False, "insufficient_motion", angle_range)
    if repetitions < 1:
        return EvidenceAssessment(False, "no_complete_repetition", angle_range)
    return EvidenceAssessment(True, "assessable", angle_range)
