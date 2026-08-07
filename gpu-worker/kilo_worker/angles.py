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

