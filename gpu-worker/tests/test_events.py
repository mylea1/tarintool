import math
import unittest

import numpy as np

from kilo_worker.events import (
    LEFT_ANKLE,
    LEFT_ELBOW,
    LEFT_HIP,
    LEFT_KNEE,
    LEFT_SHOULDER,
    LEFT_WRIST,
    RIGHT_ANKLE,
    RIGHT_ELBOW,
    RIGHT_HIP,
    RIGHT_KNEE,
    RIGHT_SHOULDER,
    RIGHT_WRIST,
    PoseSample,
    analyze_pose_events,
    event_to_result,
)


def _sample_with_joint_angle(
    timestamp_ms: int,
    chain: tuple[int, int, int],
    angle_degrees: float,
    *,
    outgoing_degrees: float = -90.0,
) -> PoseSample:
    points = np.zeros((17, 2), dtype=np.float32)
    scores = np.full(17, 0.95, dtype=np.float32)
    first, vertex, third = chain
    vertex_point = np.array((200.0, 300.0), dtype=np.float32)
    outgoing = math.radians(outgoing_degrees)
    incoming = math.radians(outgoing_degrees + angle_degrees)
    points[vertex] = vertex_point
    points[third] = vertex_point + 100 * np.array(
        (math.cos(outgoing), math.sin(outgoing)), dtype=np.float32
    )
    points[first] = vertex_point + 100 * np.array(
        (math.cos(incoming), math.sin(incoming)), dtype=np.float32
    )
    return PoseSample(timestamp_ms, timestamp_ms // 100, points, scores)


def _hinge_sample(
    timestamp_ms: int,
    hip_angle_degrees: float,
    knee_angle_degrees: float,
) -> PoseSample:
    points = np.zeros((17, 2), dtype=np.float32)
    scores = np.full(17, 0.95, dtype=np.float32)
    hip = np.array((200.0, 260.0), dtype=np.float32)
    knee = hip + np.array((0.0, 100.0), dtype=np.float32)
    shoulder_angle = math.radians(90.0 - hip_angle_degrees)
    ankle_angle = math.radians(-90.0 + knee_angle_degrees)
    points[LEFT_HIP] = hip
    points[LEFT_KNEE] = knee
    points[LEFT_SHOULDER] = hip + 100 * np.array(
        (math.cos(shoulder_angle), math.sin(shoulder_angle)), dtype=np.float32
    )
    points[LEFT_ANKLE] = knee + 100 * np.array(
        (math.cos(ankle_angle), math.sin(ankle_angle)), dtype=np.float32
    )
    scores[[RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]] = 0.1
    return PoseSample(timestamp_ms, timestamp_ms // 100, points, scores)


class PoseEventTests(unittest.TestCase):
    def test_squat_depth_event_is_located_by_video_time(self) -> None:
        samples = []
        for index, angle in enumerate((170, 155, 142, 120, 125, 158, 170)):
            sample = _sample_with_joint_angle(
                index * 100,
                (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
                angle,
            )
            sample.scores[[RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]] = 0.1
            samples.append(sample)

        analysis = analyze_pose_events("barbell_squat", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertEqual(len(analysis.events), 1)
        payload = event_to_result(analysis.events[0], samples, "event-001")
        self.assertEqual(payload["code"], "SQUAT_DEPTH_LIMITED")
        self.assertEqual(payload["peakMs"], 300)
        self.assertEqual(payload["displayTime"], "00:00.3")
        self.assertNotIn("repetition", payload)
        self.assertNotIn("repIndex", payload)

        front_analysis = analyze_pose_events("barbell_squat", "front", samples)
        self.assertEqual(front_analysis.events, ())
        self.assertIn("squat_depth_requires_side_view", front_analysis.limitations)

    def test_motion_cycle_does_not_bridge_a_long_pose_gap(self) -> None:
        samples = []
        for timestamp_ms, angle in zip(
            (0, 1000, 1100, 1200, 1300, 1400),
            (170, 142, 120, 125, 158, 170),
        ):
            sample = _sample_with_joint_angle(
                timestamp_ms,
                (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
                angle,
            )
            sample.scores[[RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]] = 0.1
            samples.append(sample)

        analysis = analyze_pose_events("barbell_squat", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 0)
        self.assertEqual(analysis.events, ())

    def test_bench_press_uses_forearm_reference_at_the_event_time(self) -> None:
        samples = []
        for index, angle in enumerate((170, 145, 118, 80, 115, 145, 170)):
            sample = _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                angle,
                outgoing_degrees=-60.0,
            )
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1
            samples.append(sample)

        analysis = analyze_pose_events("bench_press", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertEqual(len(analysis.events), 1)
        event = analysis.events[0]
        self.assertEqual(event.code, "BENCH_FOREARM_NOT_VERTICAL")
        self.assertAlmostEqual(
            event.measurements["forearmVerticalDeviationDeg"], 30.0, delta=0.2
        )

        oblique = analyze_pose_events("bench_press", "side_front", samples)
        self.assertEqual(oblique.events, ())
        self.assertIn(
            "forearm_verticality_requires_true_side_view", oblique.limitations
        )

    def test_deadlift_knee_dominance_uses_bettercoach_threshold(self) -> None:
        samples = [
            _hinge_sample(index * 100, hip_angle, knee_angle)
            for index, (hip_angle, knee_angle) in enumerate(
                zip(
                    (170, 155, 142, 125, 130, 158, 170),
                    (170, 150, 125, 100, 105, 150, 170),
                )
            )
        ]

        analysis = analyze_pose_events("deadlift", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertIn("DEADLIFT_KNEE_DOMINANT", {event.code for event in analysis.events})


if __name__ == "__main__":
    unittest.main()
