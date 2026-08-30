import unittest

from kilo_worker.angles import (
    RepetitionCounter,
    assess_exercise_evidence,
    joint_angle,
)


class AngleTests(unittest.TestCase):
    def test_joint_angle(self) -> None:
        self.assertAlmostEqual(joint_angle((1, 0), (0, 0), (0, 1)), 90.0)
        self.assertAlmostEqual(joint_angle((-1, 0), (0, 0), (1, 0)), 180.0)

    def test_counter_requires_full_cycle(self) -> None:
        counter = RepetitionCounter(75.0, 155.0)
        for angle in (170, 120, 70, 90, 160, 160):
            counter.update(angle)
        self.assertEqual(counter.count, 1)
        for angle in (70, 160):
            counter.update(angle)
        self.assertEqual(counter.count, 2)

    def test_evidence_rejects_pose_without_complete_exercise(self) -> None:
        assessment = assess_exercise_evidence(
            repetitions=0,
            confidence=0.0988,
            detected_frames=29,
            inference_frames=29,
            angle_samples=(155.0, 150.0, 148.0, 152.0),
        )

        self.assertFalse(assessment.assessable)
        self.assertEqual(assessment.reason, "insufficient_pose_quality")

    def test_evidence_accepts_visible_complete_cycle(self) -> None:
        assessment = assess_exercise_evidence(
            repetitions=1,
            confidence=0.755,
            detected_frames=186,
            inference_frames=186,
            angle_samples=(168.0, 151.0, 132.0, 72.0, 104.0, 161.0),
        )

        self.assertTrue(assessment.assessable)
        self.assertEqual(assessment.reason, "assessable")
        self.assertEqual(assessment.level, "full_cycle")
        self.assertTrue(assessment.can_count_repetitions)

    def test_evidence_accepts_visible_partial_cycle_without_counting(self) -> None:
        assessment = assess_exercise_evidence(
            complete_cycles=0,
            partial_cycles=1,
            visible_phases=("extended", "pulled"),
            confidence=0.78,
            detected_frames=140,
            inference_frames=140,
            angle_samples=(138.0, 132.0, 120.0, 99.0, 95.0, 98.0),
        )

        self.assertTrue(assessment.assessable)
        self.assertEqual(assessment.reason, "partial_cycle")
        self.assertEqual(assessment.level, "partial_cycle")
        self.assertFalse(assessment.can_count_repetitions)


if __name__ == "__main__":
    unittest.main()
