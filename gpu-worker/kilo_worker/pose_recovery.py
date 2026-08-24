from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Sequence

import numpy as np

from .events import (
    LEFT_ELBOW,
    LEFT_SHOULDER,
    LEFT_WRIST,
    RIGHT_ELBOW,
    RIGHT_SHOULDER,
    RIGHT_WRIST,
    PoseSample,
)


@dataclass(frozen=True)
class WristRecoveryMetrics:
    inferred_samples: int = 0
    temporal_samples: int = 0
    direction_only_samples: int = 0
    rejected_observations: int = 0


def recover_occluded_wrists(
    samples: Sequence[PoseSample],
    *,
    confidence_floor: float,
    weak_direction_floor: float = 0.05,
    max_neighbor_ms: int = 1200,
    frame_width: int | None = None,
    frame_height: int | None = None,
) -> tuple[list[PoseSample], WristRecoveryMetrics]:
    """Recover wrist *direction* without treating it as an observation.

    The recovery is deliberately task-limited. It keeps observed keypoints
    unchanged and only reconstructs an occluded wrist when the shoulder and
    elbow remain visible. The preferred source is a nearby observed forearm
    direction expressed relative to the upper arm. A weak raw wrist proposal
    is used only as a direction hint and its length is replaced with a stable
    anatomical ratio. The inferred mask allows downstream scoring and drawing
    to keep this evidence weaker than a genuinely observed wrist.
    """
    if not samples:
        return [], WristRecoveryMetrics()

    recovered = [
        PoseSample(
            timestamp_ms=sample.timestamp_ms,
            source_frame_index=sample.source_frame_index,
            points=sample.points.copy(),
            scores=sample.scores.copy(),
            inferred=(
                sample.inferred.copy()
                if sample.inferred is not None
                else np.zeros(len(sample.scores), dtype=np.bool_)
            ),
        )
        for sample in samples
    ]
    temporal_count = 0
    direction_count = 0
    rejected_count = 0

    for shoulder, elbow, wrist in (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
    ):
        rejected_count += _reject_unreliable_observations(
            recovered,
            shoulder,
            elbow,
            wrist,
            confidence_floor,
            frame_width,
            frame_height,
        )
        expected_ratio = _stable_forearm_ratio(
            recovered, shoulder, elbow, wrist, confidence_floor
        )
        observed = [
            index
            for index, sample in enumerate(recovered)
            if _observed_chain(sample, shoulder, elbow, wrist, confidence_floor)
        ]
        for index, sample in enumerate(recovered):
            if sample.scores[wrist] >= confidence_floor:
                continue
            if min(sample.scores[shoulder], sample.scores[elbow]) < confidence_floor:
                continue
            upper = sample.points[shoulder] - sample.points[elbow]
            upper_length = float(np.linalg.norm(upper))
            if not np.isfinite(upper_length) or upper_length < 6.0:
                continue

            relative_angle = _temporal_relative_angle(
                recovered,
                observed,
                index,
                shoulder,
                elbow,
                wrist,
                max_neighbor_ms,
            )
            source_score = 0.0
            if relative_angle is not None:
                upper_angle = math.atan2(float(upper[1]), float(upper[0]))
                direction_angle = upper_angle + relative_angle
                direction = np.array(
                    (math.cos(direction_angle), math.sin(direction_angle)),
                    dtype=np.float32,
                )
                source_score = _nearest_observed_score(
                    recovered, observed, index, wrist, max_neighbor_ms
                )
                temporal_count += 1
            else:
                raw = sample.points[wrist] - sample.points[elbow]
                raw_length = float(np.linalg.norm(raw))
                raw_score = float(sample.scores[wrist])
                if (
                    raw_score < weak_direction_floor
                    or not np.isfinite(raw_length)
                    or raw_length < max(5.0, upper_length * 0.18)
                    or raw_length > upper_length * 3.0
                ):
                    continue
                direction = raw.astype(np.float32) / raw_length
                source_score = raw_score
                direction_count += 1

            sample.points[wrist] = (
                sample.points[elbow]
                + direction * upper_length * expected_ratio
            )
            # Downstream geometry needs a usable point, while ``inferred``
            # carries the evidence penalty. Never raise it to observed quality.
            sample.scores[wrist] = max(
                confidence_floor + 0.01,
                min(float(sample.scores[elbow]), max(source_score, confidence_floor))
                * 0.72,
            )
            if sample.inferred is not None:
                sample.inferred[wrist] = True

    return recovered, WristRecoveryMetrics(
        inferred_samples=temporal_count + direction_count,
        temporal_samples=temporal_count,
        direction_only_samples=direction_count,
        rejected_observations=rejected_count,
    )


def _reject_unreliable_observations(
    samples: Sequence[PoseSample],
    shoulder: int,
    elbow: int,
    wrist: int,
    floor: float,
    frame_width: int | None,
    frame_height: int | None,
) -> int:
    """Downgrade confident but geometrically impossible wrist proposals."""
    ratios: list[float] = []
    for sample in samples:
        if min(sample.scores[shoulder], sample.scores[elbow], sample.scores[wrist]) < floor:
            continue
        wrist_point = sample.points[wrist]
        if not _inside_frame(wrist_point, frame_width, frame_height):
            continue
        upper = float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow]))
        forearm = float(np.linalg.norm(wrist_point - sample.points[elbow]))
        if upper >= 6.0 and forearm >= 6.0:
            ratio = forearm / upper
            if 0.4 <= ratio <= 1.7:
                ratios.append(ratio)
    median_ratio = float(np.median(ratios)) if ratios else 0.9
    rejected = 0
    for sample in samples:
        if sample.scores[wrist] < floor:
            continue
        upper = float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow]))
        forearm = float(np.linalg.norm(sample.points[wrist] - sample.points[elbow]))
        ratio = forearm / upper if upper >= 6.0 else math.inf
        out_of_frame = not _inside_frame(
            sample.points[wrist], frame_width, frame_height
        )
        implausible_ratio = (
            not np.isfinite(ratio)
            or ratio < max(0.38, median_ratio * 0.55)
            or ratio > min(1.75, median_ratio * 1.65)
        )
        if not out_of_frame and not implausible_ratio:
            continue
        # Preserve the raw coordinate as a possible direction hint, but force
        # it through the recovery path so it cannot masquerade as observed.
        sample.scores[wrist] = min(float(sample.scores[wrist]), max(0.08, floor * 0.5))
        rejected += 1
    return rejected


def _inside_frame(
    point: np.ndarray,
    frame_width: int | None,
    frame_height: int | None,
) -> bool:
    if not np.all(np.isfinite(point)):
        return False
    if frame_width is None or frame_height is None:
        return True
    x, y = float(point[0]), float(point[1])
    return 0.0 <= x < float(frame_width) and 0.0 <= y < float(frame_height)


def _observed_chain(
    sample: PoseSample,
    shoulder: int,
    elbow: int,
    wrist: int,
    floor: float,
) -> bool:
    if min(sample.scores[shoulder], sample.scores[elbow], sample.scores[wrist]) < floor:
        return False
    lengths = (
        float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow])),
        float(np.linalg.norm(sample.points[wrist] - sample.points[elbow])),
    )
    return all(np.isfinite(length) and length >= 6.0 for length in lengths)


def _stable_forearm_ratio(
    samples: Sequence[PoseSample],
    shoulder: int,
    elbow: int,
    wrist: int,
    floor: float,
) -> float:
    ratios: list[float] = []
    for sample in samples:
        if not _observed_chain(sample, shoulder, elbow, wrist, floor):
            continue
        upper = float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow]))
        forearm = float(np.linalg.norm(sample.points[wrist] - sample.points[elbow]))
        ratio = forearm / upper
        if 0.45 <= ratio <= 1.55:
            ratios.append(ratio)
    return float(np.clip(np.median(ratios), 0.65, 1.25)) if ratios else 0.9


def _relative_forearm_angle(
    sample: PoseSample,
    shoulder: int,
    elbow: int,
    wrist: int,
) -> float:
    upper = sample.points[shoulder] - sample.points[elbow]
    forearm = sample.points[wrist] - sample.points[elbow]
    upper_angle = math.atan2(float(upper[1]), float(upper[0]))
    forearm_angle = math.atan2(float(forearm[1]), float(forearm[0]))
    return math.atan2(
        math.sin(forearm_angle - upper_angle),
        math.cos(forearm_angle - upper_angle),
    )


def _temporal_relative_angle(
    samples: Sequence[PoseSample],
    observed: Sequence[int],
    index: int,
    shoulder: int,
    elbow: int,
    wrist: int,
    max_neighbor_ms: int,
) -> float | None:
    neighbors = sorted(
        (
            abs(samples[candidate].timestamp_ms - samples[index].timestamp_ms),
            candidate,
        )
        for candidate in observed
        if abs(samples[candidate].timestamp_ms - samples[index].timestamp_ms)
        <= max_neighbor_ms
    )[:2]
    if not neighbors:
        return None
    vectors = []
    weights = []
    for distance, candidate in neighbors:
        angle = _relative_forearm_angle(
            samples[candidate], shoulder, elbow, wrist
        )
        vectors.append((math.cos(angle), math.sin(angle)))
        weights.append(1.0 / max(1.0, float(distance)))
    x = sum(vector[0] * weight for vector, weight in zip(vectors, weights))
    y = sum(vector[1] * weight for vector, weight in zip(vectors, weights))
    if math.hypot(x, y) < 1e-6:
        return None
    return math.atan2(y, x)


def _nearest_observed_score(
    samples: Sequence[PoseSample],
    observed: Sequence[int],
    index: int,
    wrist: int,
    max_neighbor_ms: int,
) -> float:
    candidates = [
        candidate
        for candidate in observed
        if abs(samples[candidate].timestamp_ms - samples[index].timestamp_ms)
        <= max_neighbor_ms
    ]
    if not candidates:
        return 0.0
    nearest = min(
        candidates,
        key=lambda candidate: abs(
            samples[candidate].timestamp_ms - samples[index].timestamp_ms
        ),
    )
    return float(samples[nearest].scores[wrist])
