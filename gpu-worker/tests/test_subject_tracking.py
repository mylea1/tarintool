from __future__ import annotations

import unittest

import numpy as np

from kilo_worker.subject_tracking import SubjectTracker


def confidence(value: float) -> np.ndarray:
    return np.full(17, value, dtype=np.float32)


def points_for(box: list[float]) -> np.ndarray:
    x1, y1, x2, y2 = box
    xs = np.linspace(x1 + 4, x2 - 4, 17, dtype=np.float32)
    ys = np.linspace(y1 + 4, y2 - 4, 17, dtype=np.float32)
    return np.column_stack((xs, ys))


class SubjectTrackerTests(unittest.TestCase):
    def test_initial_selection_prefers_large_central_exerciser(self) -> None:
        tracker = SubjectTracker()
        boxes = np.array(
            [[493, 0, 881, 720], [9, 66, 110, 342]], dtype=np.float32
        )
        selected = tracker.select_index(
            np.stack([points_for(box) for box in boxes]),
            np.stack([confidence(0.69), confidence(0.76)]),
            boxes,
            np.array([0.91, 0.85], dtype=np.float32),
            frame_width=1280,
            frame_height=720,
        )

        self.assertEqual(selected, 0)
        self.assertEqual(tracker.metrics.multi_person_frames, 1)
        self.assertEqual(tracker.metrics.max_detected_people, 2)

    def test_tracking_survives_detection_order_change(self) -> None:
        tracker = SubjectTracker()
        first_boxes = np.array(
            [[493, 0, 881, 720], [9, 66, 110, 342]], dtype=np.float32
        )
        tracker.select_index(
            np.stack([points_for(box) for box in first_boxes]),
            np.stack([confidence(0.69), confidence(0.76)]),
            first_boxes,
            np.array([0.91, 0.85], dtype=np.float32),
            frame_width=1280,
            frame_height=720,
        )
        next_boxes = np.array(
            [[18, 70, 120, 348], [500, 4, 888, 720]], dtype=np.float32
        )
        selected = tracker.select_index(
            np.stack([points_for(box) for box in next_boxes]),
            np.stack([confidence(0.93), confidence(0.65)]),
            next_boxes,
            np.array([0.93, 0.90], dtype=np.float32),
            frame_width=1280,
            frame_height=720,
        )

        self.assertEqual(selected, 1)

    def test_brief_occlusion_does_not_switch_to_bystander(self) -> None:
        tracker = SubjectTracker(max_missing_frames=4)
        target_box = np.array([[493, 0, 881, 720]], dtype=np.float32)
        tracker.select_index(
            np.stack([points_for(target_box[0])]),
            np.stack([confidence(0.7)]),
            target_box,
            np.array([0.9], dtype=np.float32),
            frame_width=1280,
            frame_height=720,
        )
        bystander_box = np.array([[10, 60, 115, 340]], dtype=np.float32)
        selected = tracker.select_index(
            np.stack([points_for(bystander_box[0])]),
            np.stack([confidence(0.95)]),
            bystander_box,
            np.array([0.95], dtype=np.float32),
            frame_width=1280,
            frame_height=720,
        )

        self.assertIsNone(selected)
        self.assertEqual(tracker.metrics.missing_target_frames, 1)


if __name__ == "__main__":
    unittest.main()
