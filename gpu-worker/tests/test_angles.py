import unittest

from kilo_worker.angles import RepetitionCounter, joint_angle


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


if __name__ == "__main__":
    unittest.main()

