import math
import unittest

import numpy as np

from kilo_worker.action_compatibility import assess_action_compatibility
from kilo_worker.events import (
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


def _press_sample(timestamp_ms: int, elbow_angle: float) -> PoseSample:
    points = np.zeros((17, 2), dtype=np.float32)
    scores = np.full(17, 0.9, dtype=np.float32)
    for shoulder, elbow, wrist, y in (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, 180.0),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST, 220.0),
    ):
        points[shoulder] = (120.0, y)
        points[elbow] = (200.0, y)
        direction = math.radians(180.0 - elbow_angle)
        points[wrist] = points[elbow] + 80 * np.array(
            (math.cos(direction), math.sin(direction)), dtype=np.float32
        )
    points[LEFT_HIP] = (340.0, 180.0)
    points[RIGHT_HIP] = (340.0, 220.0)
    points[LEFT_KNEE] = (440.0, 250.0)
    points[RIGHT_KNEE] = (440.0, 290.0)
    return PoseSample(timestamp_ms, timestamp_ms // 100, points, scores)


class ActionCompatibilityTests(unittest.TestCase):
    def test_press_signature_rejects_hip_thrust_selection(self) -> None:
        samples = [
            _press_sample(index * 100, angle)
            for index, angle in enumerate(
                (165, 145, 110, 75, 75, 110, 145, 165, 145, 100, 75, 165)
            )
        ]

        result = assess_action_compatibility("hip_thrust", "side", samples)

        self.assertTrue(result.checked)
        self.assertFalse(result.compatible)
        self.assertEqual(result.observed_family, "bench_press")

    def test_press_signature_accepts_bench_press_selection(self) -> None:
        samples = [
            _press_sample(index * 100, angle)
            for index, angle in enumerate(
                (165, 145, 110, 75, 75, 110, 145, 165, 145, 100, 75, 165)
            )
        ]

        result = assess_action_compatibility("bench_press", "side", samples)

        self.assertTrue(result.checked)
        self.assertTrue(result.compatible)


if __name__ == "__main__":
    unittest.main()
