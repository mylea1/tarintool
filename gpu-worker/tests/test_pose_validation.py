import unittest

import numpy as np

from kilo_worker.events import PoseSample
from kilo_worker.pose_recovery import recover_occluded_endpoints
from kilo_worker.pose_validation import validate_pose_sequence


def _bench_sample(timestamp_ms: int) -> PoseSample:
    points = np.zeros((17, 2), dtype=np.float32)
    scores = np.full(17, 0.95, dtype=np.float32)
    points[5] = (300.0, 200.0)
    points[6] = (300.0, 210.0)
    points[11] = (100.0, 200.0)
    points[12] = (100.0, 210.0)
    # Confident but incorrect chain: the detector attached the arm along the
    # supine torso, which is typical when a plate hides the actual forearm.
    points[7] = (225.0, 200.0)
    points[9] = (150.0, 200.0)
    # Visible chain: upper arm and forearm run away from the bench/torso axis.
    points[8] = (300.0, 125.0)
    points[10] = (300.0, 50.0)
    points[13] = (100.0, 300.0)
    points[14] = (100.0, 310.0)
    points[15] = (100.0, 390.0)
    points[16] = (100.0, 400.0)
    return PoseSample(timestamp_ms, timestamp_ms // 100, points, scores)


class PoseValidationTests(unittest.TestCase):
    def test_side_bench_uses_aligned_arm_not_high_confidence_wrong_arm(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(12)]

        validated, metrics = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="bench_press",
            camera="side",
            frame_width=640,
            frame_height=480,
        )

        self.assertEqual(metrics.selected_arm_side, "right")
        self.assertEqual(metrics.suppressed_arm_samples, 12)
        self.assertTrue(all(sample.scores[7] < 0.35 for sample in validated))
        self.assertTrue(all(sample.scores[8] >= 0.35 for sample in validated))

    def test_isolated_high_confidence_elbow_jump_is_rejected(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(5)]
        samples[2].points[8] = (500.0, 430.0)

        validated, metrics = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="overhead_press",
            camera="front",
            frame_width=640,
            frame_height=480,
        )

        self.assertGreaterEqual(metrics.temporal_joint_spikes, 1)
        self.assertLess(validated[2].scores[8], 0.35)

    def test_suppressed_elbow_prevents_false_wrist_recovery(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(12)]
        validated, _ = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="bench_press",
            camera="side",
            frame_width=640,
            frame_height=480,
        )
        recovered, _ = recover_occluded_endpoints(
            validated,
            confidence_floor=0.35,
            frame_width=640,
            frame_height=480,
        )

        self.assertTrue(all(sample.scores[7] < 0.35 for sample in recovered))
        self.assertTrue(all(sample.scores[9] < 0.35 for sample in recovered))

    def test_foreshortened_upper_arm_does_not_erase_elbow(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(9)]
        samples[0].points[8] = (300.0, 190.0)
        samples[0].points[10] = (300.0, 115.0)

        validated, metrics = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="bench_press",
            camera="front",
            frame_width=640,
            frame_height=480,
        )

        self.assertGreaterEqual(metrics.bone_length_outliers, 1)
        self.assertGreaterEqual(validated[0].scores[8], 0.35)

    def test_recovered_wrist_uses_body_scale_when_upper_arm_is_foreshortened(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(7)]
        sample = samples[3]
        sample.points[8] = (300.0, 190.0)
        sample.points[10] = (300.0, 115.0)
        sample.scores[10] = 0.08

        recovered, metrics = recover_occluded_endpoints(
            samples,
            confidence_floor=0.35,
            frame_width=640,
            frame_height=480,
        )

        length = float(np.linalg.norm(recovered[3].points[10] - recovered[3].points[8]))
        self.assertGreaterEqual(metrics.inferred_samples, 1)
        self.assertAlmostEqual(length, 75.0, delta=2.0)

    def test_bench_wrist_recovery_never_points_into_bench(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(7)]
        for sample in samples:
            sample.points[10] = (315.0, 235.0)
            sample.scores[10] = 0.9

        recovered, metrics = recover_occluded_endpoints(
            samples,
            confidence_floor=0.35,
            frame_width=640,
            frame_height=480,
            exercise_id="bench_press",
        )

        self.assertEqual(metrics.inferred_samples, len(samples))
        self.assertTrue(
            all(sample.points[10][1] < sample.points[8][1] for sample in recovered)
        )

    def test_side_bench_rejects_plate_occluded_arm_when_forearms_conflict(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(9)]
        # Start with two vertical, plausible arms.  During the middle window the
        # right elbow/wrist drift sideways onto a plate while the visible left
        # forearm remains vertical.
        for sample in samples:
            sample.points[7] = (280.0, 125.0)
            sample.points[9] = (280.0, 50.0)
            sample.points[8] = (320.0, 125.0)
            sample.points[10] = (320.0, 50.0)
        for sample in samples[3:6]:
            sample.points[8] = (250.0, 175.0)
            sample.points[10] = (325.0, 175.0)

        validated, metrics = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="bench_press",
            camera="side",
            frame_width=640,
            frame_height=480,
        )

        self.assertEqual(metrics.bilateral_occlusion_rejects, 3)
        self.assertTrue(all(validated[index].scores[8] < 0.35 for index in range(3, 6)))

    def test_side_bench_hides_both_arms_when_both_collapse_onto_plate(self) -> None:
        samples = [_bench_sample(index * 100) for index in range(9)]
        for sample in samples:
            sample.points[7] = (245.0, 155.0)
            sample.points[9] = (305.0, 105.0)
            sample.points[8] = (255.0, 165.0)
            sample.points[10] = (315.0, 115.0)

        validated, metrics = validate_pose_sequence(
            samples,
            confidence_floor=0.35,
            exercise_id="bench_press",
            camera="side",
            frame_width=640,
            frame_height=480,
        )

        self.assertEqual(metrics.bilateral_occlusion_rejects, 18)
        self.assertTrue(all(sample.scores[7] < 0.35 for sample in validated))
        self.assertTrue(all(sample.scores[8] < 0.35 for sample in validated))


if __name__ == "__main__":
    unittest.main()
