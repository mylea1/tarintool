from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Sequence

import numpy as np


UPPER_BODY_LANDMARKS = (5, 6, 7, 8, 9, 10, 11, 12)


@dataclass(frozen=True)
class SubjectTrackingMetrics:
    multi_person_frames: int
    max_detected_people: int
    missing_target_frames: int
    reacquisitions: int


class SubjectTracker:
    """Keep pose samples on one primary person instead of changing per frame.

    The first subject is selected from size, position and upper-body landmark
    quality. Once selected, bounding-box overlap, center continuity and scale
    continuity dominate the score. Brief occlusions therefore produce a
    missing sample instead of silently switching to a clearer bystander.
    """

    def __init__(
        self,
        confidence_floor: float = 0.35,
        *,
        max_missing_frames: int = 4,
        minimum_continuity_score: float = 0.34,
    ) -> None:
        self.confidence_floor = confidence_floor
        self.max_missing_frames = max(1, max_missing_frames)
        self.minimum_continuity_score = minimum_continuity_score
        self._last_box: np.ndarray | None = None
        self._missing_streak = 0
        self._ever_initialized = False
        self._multi_person_frames = 0
        self._max_detected_people = 0
        self._missing_target_frames = 0
        self._reacquisitions = 0

    @property
    def metrics(self) -> SubjectTrackingMetrics:
        return SubjectTrackingMetrics(
            multi_person_frames=self._multi_person_frames,
            max_detected_people=self._max_detected_people,
            missing_target_frames=self._missing_target_frames,
            reacquisitions=self._reacquisitions,
        )

    def select_index(
        self,
        points: np.ndarray,
        keypoint_confidence: np.ndarray,
        boxes: np.ndarray | None,
        detection_confidence: np.ndarray | None,
        *,
        frame_width: int,
        frame_height: int,
    ) -> int | None:
        count = min(len(points), len(keypoint_confidence))
        self._max_detected_people = max(self._max_detected_people, count)
        if count > 1:
            self._multi_person_frames += 1
        if count == 0:
            return self._mark_missing()

        normalized_boxes = self._normalized_boxes(
            points[:count],
            keypoint_confidence[:count],
            boxes[:count] if boxes is not None and len(boxes) >= count else None,
            frame_width,
            frame_height,
        )
        detector_scores = (
            np.asarray(detection_confidence[:count], dtype=np.float32)
            if detection_confidence is not None and len(detection_confidence) >= count
            else np.ones(count, dtype=np.float32)
        )

        if self._last_box is None:
            selected = self._select_initial(
                normalized_boxes,
                keypoint_confidence[:count],
                detector_scores,
                frame_width,
                frame_height,
            )
            if self._ever_initialized:
                self._reacquisitions += 1
            self._ever_initialized = True
            self._last_box = normalized_boxes[selected].copy()
            self._missing_streak = 0
            return selected

        areas = np.array([self._area(box) for box in normalized_boxes])
        largest_area = max(float(np.max(areas)), 1.0)
        scored: list[tuple[float, int]] = []
        for index, box in enumerate(normalized_boxes):
            overlap = self._intersection_over_union(self._last_box, box)
            proximity = self._center_proximity(
                self._last_box, box, frame_width, frame_height
            )
            scale_similarity = min(self._area(self._last_box), self._area(box)) / max(
                self._area(self._last_box), self._area(box), 1.0
            )
            quality = self._landmark_quality(keypoint_confidence[index])
            relative_area = self._area(box) / largest_area
            score = (
                0.50 * overlap
                + 0.24 * proximity
                + 0.12 * scale_similarity
                + 0.08 * quality
                + 0.06 * relative_area
            )
            scored.append((score, index))

        best_score, selected = max(scored)
        if best_score < self.minimum_continuity_score:
            return self._mark_missing()
        self._last_box = normalized_boxes[selected].copy()
        self._missing_streak = 0
        return selected

    def _mark_missing(self) -> None:
        self._missing_streak += 1
        self._missing_target_frames += 1
        if self._missing_streak > self.max_missing_frames:
            self._last_box = None
            self._missing_streak = 0
        return None

    def _select_initial(
        self,
        boxes: np.ndarray,
        confidence: np.ndarray,
        detector_scores: np.ndarray,
        frame_width: int,
        frame_height: int,
    ) -> int:
        areas = np.array([self._area(box) for box in boxes])
        largest_area = max(float(np.max(areas)), 1.0)
        frame_diagonal = max(1.0, math.hypot(frame_width, frame_height))
        frame_center = np.array([frame_width / 2.0, frame_height / 2.0])
        scored: list[tuple[float, int]] = []
        for index, box in enumerate(boxes):
            center = np.array([(box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0])
            center_score = max(
                0.0,
                1.0 - (2.0 * float(np.linalg.norm(center - frame_center)) / frame_diagonal),
            )
            relative_area = self._area(box) / largest_area
            quality = self._landmark_quality(confidence[index])
            detector = float(np.clip(detector_scores[index], 0.0, 1.0))
            score = (
                0.55 * relative_area
                + 0.20 * center_score
                + 0.15 * quality
                + 0.10 * detector
            )
            scored.append((score, index))
        return max(scored)[1]

    def _landmark_quality(self, confidence: Sequence[float]) -> float:
        values = np.asarray(confidence, dtype=np.float32)
        usable = [index for index in UPPER_BODY_LANDMARKS if index < len(values)]
        if not usable:
            return 0.0
        selected = values[usable]
        visible = float(np.mean(selected >= self.confidence_floor))
        mean_confidence = float(np.mean(np.clip(selected, 0.0, 1.0)))
        return 0.65 * mean_confidence + 0.35 * visible

    def _normalized_boxes(
        self,
        points: np.ndarray,
        confidence: np.ndarray,
        boxes: np.ndarray | None,
        frame_width: int,
        frame_height: int,
    ) -> np.ndarray:
        if boxes is not None:
            result = np.asarray(boxes, dtype=np.float32).copy()
        else:
            result = np.stack(
                [
                    self._box_from_keypoints(item, scores, frame_width, frame_height)
                    for item, scores in zip(points, confidence)
                ]
            )
        result[:, (0, 2)] = np.clip(result[:, (0, 2)], 0, frame_width - 1)
        result[:, (1, 3)] = np.clip(result[:, (1, 3)], 0, frame_height - 1)
        return result

    def _box_from_keypoints(
        self,
        points: np.ndarray,
        confidence: np.ndarray,
        frame_width: int,
        frame_height: int,
    ) -> np.ndarray:
        visible = np.asarray(confidence) >= self.confidence_floor
        usable = np.asarray(points)[visible]
        if not len(usable):
            return np.array([0, 0, frame_width - 1, frame_height - 1], dtype=np.float32)
        x1, y1 = np.min(usable, axis=0)
        x2, y2 = np.max(usable, axis=0)
        padding_x = max(8.0, (x2 - x1) * 0.12)
        padding_y = max(8.0, (y2 - y1) * 0.12)
        return np.array(
            [x1 - padding_x, y1 - padding_y, x2 + padding_x, y2 + padding_y],
            dtype=np.float32,
        )

    @staticmethod
    def _area(box: np.ndarray) -> float:
        return max(0.0, float(box[2] - box[0])) * max(0.0, float(box[3] - box[1]))

    @staticmethod
    def _intersection_over_union(first: np.ndarray, second: np.ndarray) -> float:
        x1 = max(float(first[0]), float(second[0]))
        y1 = max(float(first[1]), float(second[1]))
        x2 = min(float(first[2]), float(second[2]))
        y2 = min(float(first[3]), float(second[3]))
        intersection = max(0.0, x2 - x1) * max(0.0, y2 - y1)
        union = SubjectTracker._area(first) + SubjectTracker._area(second) - intersection
        return intersection / union if union > 0 else 0.0

    @staticmethod
    def _center_proximity(
        first: np.ndarray,
        second: np.ndarray,
        frame_width: int,
        frame_height: int,
    ) -> float:
        first_center = np.array(
            [(first[0] + first[2]) / 2.0, (first[1] + first[3]) / 2.0]
        )
        second_center = np.array(
            [(second[0] + second[2]) / 2.0, (second[1] + second[3]) / 2.0]
        )
        first_diagonal = math.hypot(first[2] - first[0], first[3] - first[1])
        second_diagonal = math.hypot(second[2] - second[0], second[3] - second[1])
        normalization = max(
            float(first_diagonal),
            float(second_diagonal),
            0.05 * math.hypot(frame_width, frame_height),
            1.0,
        )
        distance = float(np.linalg.norm(first_center - second_center))
        return max(0.0, 1.0 - distance / (2.0 * normalization))
