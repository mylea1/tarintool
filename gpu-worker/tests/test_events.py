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
    _body_line_series,
    _elbow_tuck_series,
    _hip_height_series,
    _hip_swing_series,
    _shoulder_hip_gap_series,
    _shoulder_span_series,
    _torso_length,
    analyze_pose_events,
    event_to_result,
)
from kilo_worker.exercise_rules import NEW_EXERCISE_RULES
from kilo_worker.pose_recovery import (
    recover_occluded_endpoints,
    recover_occluded_wrists,
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


def _pull_up_sample(
    timestamp_ms: int,
    left_angle: float,
    right_angle: float,
    *,
    right_shoulder_offset: float = 0.0,
) -> PoseSample:
    points = np.zeros((17, 2), dtype=np.float32)
    scores = np.full(17, 0.95, dtype=np.float32)
    for shoulder, elbow, wrist, x, angle, offset in (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, 150.0, left_angle, 0.0),
        (
            RIGHT_SHOULDER,
            RIGHT_ELBOW,
            RIGHT_WRIST,
            350.0,
            right_angle,
            right_shoulder_offset,
        ),
    ):
        points[shoulder] = (x, 220.0 + offset)
        points[elbow] = (x, 320.0 + offset)
        direction = math.radians(-90.0 + angle)
        points[wrist] = points[elbow] + 95 * np.array(
            (math.cos(direction), math.sin(direction)), dtype=np.float32
        )
    points[LEFT_HIP] = (190.0, 480.0)
    points[RIGHT_HIP] = (310.0, 480.0)
    return PoseSample(timestamp_ms, timestamp_ms // 100, points, scores)


class PoseEventTests(unittest.TestCase):
    def test_all_49_new_exercises_use_specific_dispatch(self) -> None:
        self.assertEqual(len(NEW_EXERCISE_RULES), 49)
        sample = _pull_up_sample(0, 150.0, 150.0)
        sample.points[LEFT_KNEE] = (190.0, 600.0)
        sample.points[RIGHT_KNEE] = (310.0, 600.0)
        sample.points[LEFT_ANKLE] = (190.0, 720.0)
        sample.points[RIGHT_ANKLE] = (310.0, 720.0)
        for exercise_id, rule in NEW_EXERCISE_RULES.items():
            with self.subTest(exercise_id=exercise_id):
                analysis = analyze_pose_events(
                    exercise_id, rule.cameras[0], [sample]
                )
                self.assertNotIn(
                    "no_exercise_specific_event_rules", analysis.limitations
                )

        for exercise_id in (
            "shrug",
            "hanging_leg_raise",
            "standing_calf_raise",
            "walking_lunge",
            "unknown_exercise",
        ):
            analysis = analyze_pose_events(exercise_id, "side", [sample])
            self.assertIn(
                "no_exercise_specific_event_rules", analysis.limitations
            )

    def test_occluded_wrist_is_recovered_from_nearby_forearm_direction(self) -> None:
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                90.0,
            )
            for index in range(5)
        ]
        for sample in samples:
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1
        for sample in samples[1:4]:
            sample.scores[LEFT_WRIST] = 0.08
            sample.points[LEFT_WRIST] = (520.0, 520.0)

        recovered, metrics = recover_occluded_wrists(
            samples,
            confidence_floor=0.35,
        )

        self.assertEqual(metrics.temporal_samples, 3)
        self.assertTrue(recovered[2].inferred[LEFT_WRIST])
        angle = math.degrees(
            math.acos(
                np.dot(
                    recovered[2].points[LEFT_SHOULDER]
                    - recovered[2].points[LEFT_ELBOW],
                    recovered[2].points[LEFT_WRIST]
                    - recovered[2].points[LEFT_ELBOW],
                )
                / (
                    np.linalg.norm(
                        recovered[2].points[LEFT_SHOULDER]
                        - recovered[2].points[LEFT_ELBOW]
                    )
                    * np.linalg.norm(
                        recovered[2].points[LEFT_WRIST]
                        - recovered[2].points[LEFT_ELBOW]
                    )
                )
            )
        )
        self.assertAlmostEqual(angle, 90.0, delta=0.5)

    def test_weak_wrist_direction_supports_elbow_angle_without_exact_wrist(self) -> None:
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                angle,
            )
            for index, angle in enumerate((170, 145, 125, 115, 115, 125, 145, 170))
        ]
        for sample in samples:
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1
            sample.scores[LEFT_WRIST] = 0.08

        recovered, metrics = recover_occluded_endpoints(
            samples, confidence_floor=0.35
        )
        analysis = analyze_pose_events(
            "barbell_row", "side", recovered, confidence_floor=0.35
        )

        self.assertEqual(metrics.direction_only_samples, len(samples))
        self.assertTrue(all(sample.inferred[LEFT_WRIST] for sample in recovered))
        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertIn("ROW_ELBOW_PULL_LIMITED", {event.code for event in analysis.events})
        range_event = next(event for event in analysis.events if event.code == "ROW_ELBOW_PULL_LIMITED")
        self.assertEqual(range_event.measurements["endpointEvidence"], "inferred_direction")

    def test_occluded_ankle_direction_supports_knee_angle(self) -> None:
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
                angle,
            )
            for index, angle in enumerate((170, 155, 140, 110, 110, 140, 155, 170))
        ]
        for sample in samples:
            sample.scores[[RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]] = 0.1
            sample.scores[LEFT_ANKLE] = 0.08

        recovered, metrics = recover_occluded_endpoints(
            samples, confidence_floor=0.35
        )
        analysis = analyze_pose_events(
            "leg_press", "side", recovered, confidence_floor=0.35
        )

        self.assertEqual(metrics.direction_only_ankle_samples, len(samples))
        self.assertTrue(all(sample.inferred[LEFT_ANKLE] for sample in recovered))
        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertIn("LEG_PRESS_DEPTH_LIMITED", {event.code for event in analysis.events})

    def test_new_normalized_primitives_degrade_when_required_points_missing(self) -> None:
        sample = _pull_up_sample(0, 120.0, 120.0)
        sample.points[LEFT_KNEE] = (190.0, 600.0)
        sample.points[RIGHT_KNEE] = (310.0, 600.0)
        sample.points[LEFT_ANKLE] = (190.0, 720.0)
        sample.points[RIGHT_ANKLE] = (310.0, 720.0)

        self.assertIsNotNone(_torso_length(sample, 0.35))
        self.assertIsNotNone(_shoulder_hip_gap_series([sample], 0.35)[0])
        self.assertAlmostEqual(_hip_swing_series([sample], 0.35)[0], 0.0)
        self.assertIsNotNone(_elbow_tuck_series([sample], 0.35)[0])
        self.assertIsNotNone(_body_line_series([sample], 0.35)[0])
        self.assertIsNotNone(_shoulder_span_series([sample], 0.35)[0])
        self.assertIsNotNone(_hip_height_series([sample], 0.35)[0])

        sample.scores[LEFT_HIP] = 0.1
        sample.scores[RIGHT_HIP] = 0.1
        self.assertIsNone(_torso_length(sample, 0.35))
        self.assertIsNone(_shoulder_hip_gap_series([sample], 0.35)[0])
        self.assertIsNone(_hip_height_series([sample], 0.35)[0])

    def test_pull_up_compares_both_arms_and_shoulder_height_at_same_time(self) -> None:
        left = (160, 145, 112, 82, 108, 145, 160)
        right = (160, 145, 136, 116, 132, 145, 160)
        samples = [
            _pull_up_sample(
                index * 150,
                left_angle,
                right_angle,
                right_shoulder_offset=(18.0 if 2 <= index <= 4 else 0.0),
            )
            for index, (left_angle, right_angle) in enumerate(zip(left, right))
        ]

        analysis = analyze_pose_events("pull_up", "front", samples)
        codes = {event.code for event in analysis.events}

        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertIn("PULL_UP_ARM_ASYMMETRY", codes)
        self.assertIn("PULL_UP_SHOULDER_ASYMMETRY", codes)

    def test_every_configured_upper_body_action_uses_specific_rules(self) -> None:
        cases = {
            "shoulder_press": (
                (100, 115, 140, 150, 150, 140, 115, 100),
                "SHOULDER_PRESS_RANGE_INCOMPLETE",
            ),
            "push_up": (
                (170, 150, 125, 105, 105, 125, 150, 170),
                "PUSH_UP_DEPTH_LIMITED",
            ),
            "dip": (
                (170, 150, 130, 115, 115, 130, 150, 170),
                "DIP_DEPTH_LIMITED",
            ),
            "face_pull": (
                (170, 150, 130, 110, 110, 130, 150, 170),
                "FACE_PULL_RANGE_INCOMPLETE",
            ),
            "biceps_curl": (
                (170, 145, 105, 80, 80, 105, 145, 170),
                "BICEPS_CURL_RANGE_INCOMPLETE",
            ),
            "triceps_extension": (
                (170, 145, 110, 90, 90, 110, 145, 170),
                "TRICEPS_EXTENSION_RANGE_INCOMPLETE",
            ),
        }
        for exercise_id, (angles, expected_code) in cases.items():
            with self.subTest(exercise_id=exercise_id):
                samples = [
                    _sample_with_joint_angle(
                        index * 100,
                        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                        angle,
                        outgoing_degrees=-90.0,
                    )
                    for index, angle in enumerate(angles)
                ]
                for sample in samples:
                    sample.scores[
                        [RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]
                    ] = 0.1
                analysis = analyze_pose_events(exercise_id, "side", samples)
                self.assertEqual(analysis.complete_motion_cycles, 1)
                self.assertIn(expected_code, {event.code for event in analysis.events})
                self.assertNotIn(
                    "no_exercise_specific_event_rules", analysis.limitations
                )

    def test_row_uses_sustained_125_100_125_positions_and_hand_travel(self) -> None:
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                angle,
                outgoing_degrees=0.0,
            )
            for index, angle in enumerate(
                (130, 130, 130, 95, 95, 95, 130, 130, 130)
            )
        ]
        for sample in samples:
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1

        analysis = analyze_pose_events("row", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 1)
        self.assertEqual(analysis.partial_motion_cycles, 0)
        self.assertEqual(analysis.visible_phases, ("extended", "pulled", "returned"))
        self.assertNotIn("ROW_RANGE_INCOMPLETE", {event.code for event in analysis.events})

    def test_row_reports_a_returned_attempt_that_never_reaches_100_degrees(self) -> None:
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                angle,
                outgoing_degrees=0.0,
            )
            for index, angle in enumerate(
                (130, 130, 130, 110, 110, 110, 130, 130, 130)
            )
        ]
        for sample in samples:
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1

        analysis = analyze_pose_events("row", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 0)
        self.assertEqual(analysis.partial_motion_cycles, 1)
        self.assertEqual(
            analysis.visible_phases,
            ("extended", "partial_pull", "returned"),
        )
        event = next(
            event for event in analysis.events if event.code == "ROW_RANGE_INCOMPLETE"
        )
        self.assertAlmostEqual(event.measurements["keyElbowAngleDeg"], 110.0)

    def test_hip_thrust_and_lateral_raise_have_specific_range_rules(self) -> None:
        hip_samples = [
            _hinge_sample(index * 100, angle, 150.0)
            for index, angle in enumerate(
                (110, 125, 150, 160, 160, 150, 125, 110)
            )
        ]
        hip = analyze_pose_events("hip_thrust", "side", hip_samples)
        self.assertEqual(hip.complete_motion_cycles, 1)
        self.assertIn(
            "HIP_THRUST_EXTENSION_LIMITED", {event.code for event in hip.events}
        )

        raise_samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_HIP, LEFT_SHOULDER, LEFT_ELBOW),
                angle,
            )
            for index, angle in enumerate((10, 25, 55, 65, 65, 55, 25, 10))
        ]
        for sample in raise_samples:
            sample.scores[[RIGHT_HIP, RIGHT_SHOULDER, RIGHT_ELBOW]] = 0.1
        lateral = analyze_pose_events("lateral_raise", "front", raise_samples)
        self.assertEqual(lateral.complete_motion_cycles, 1)
        self.assertIn(
            "LATERAL_RAISE_HEIGHT_LIMITED",
            {event.code for event in lateral.events},
        )
        self.assertNotIn(
            "no_exercise_specific_event_rules", lateral.limitations
        )

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
        self.assertIn("BENCH_DEPTH_LIMITED", {event.code for event in analysis.events})
        event = next(
            event
            for event in analysis.events
            if event.code == "BENCH_FOREARM_NOT_VERTICAL"
        )
        self.assertEqual(event.code, "BENCH_FOREARM_NOT_VERTICAL")
        self.assertAlmostEqual(
            event.measurements["forearmVerticalDeviationDeg"], 30.0, delta=0.2
        )

        oblique = analyze_pose_events("bench_press", "side_front", samples)
        self.assertEqual(oblique.events, ())
        self.assertIn(
            "forearm_verticality_requires_true_side_view", oblique.limitations
        )

    def test_bench_press_uses_relative_motion_only_when_endpoint_geometry_is_cropped(self) -> None:
        angles = (
            105,
            105,
            105,
            105,
            80,
            45,
            45,
            45,
            45,
            80,
            105,
            105,
            105,
            105,
        )
        samples = [
            _sample_with_joint_angle(
                index * 100,
                (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
                angle,
                outgoing_degrees=-90.0,
            )
            for index, angle in enumerate(angles)
        ]
        for sample in samples:
            sample.scores[[RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]] = 0.1

        analysis = analyze_pose_events("bench_press", "side", samples)

        self.assertEqual(analysis.complete_motion_cycles, 0)
        self.assertEqual(analysis.partial_motion_cycles, 1)
        self.assertEqual(analysis.events, ())
        self.assertEqual(analysis.visible_phases, ("lowered", "returned"))
        self.assertIn(
            "bench_cycle_uses_relative_motion_due_endpoint_occlusion",
            analysis.limitations,
        )
        self.assertIn(
            "bench_press_depth_requires_stable_endpoint_geometry",
            analysis.skipped_rules,
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
