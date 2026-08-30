from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import cv2
import numpy as np
from ultralytics import YOLO

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from kilo_worker.events import (  # noqa: E402
    LEFT_ELBOW,
    LEFT_HIP,
    LEFT_SHOULDER,
    LEFT_WRIST,
    RIGHT_ELBOW,
    RIGHT_HIP,
    RIGHT_SHOULDER,
    RIGHT_WRIST,
)
from kilo_worker.subject_tracking import SubjectTracker  # noqa: E402


SKELETON = (
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 6),
    (5, 11),
    (6, 12),
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
)


def _rotate(frame: np.ndarray, mode: str) -> np.ndarray:
    if mode == "clockwise":
        return cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
    if mode == "counterclockwise":
        return cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return frame


def _restore(points: np.ndarray, mode: str, width: int, height: int) -> np.ndarray:
    restored = points.copy()
    if mode == "clockwise":
        restored[..., 0] = points[..., 1]
        restored[..., 1] = height - 1 - points[..., 0]
    elif mode == "counterclockwise":
        restored[..., 0] = width - 1 - points[..., 1]
        restored[..., 1] = points[..., 0]
    return restored


def _restore_boxes(
    boxes: np.ndarray, mode: str, width: int, height: int
) -> np.ndarray:
    if not len(boxes) or mode == "original":
        return boxes.copy()
    restored = []
    for x1, y1, x2, y2 in boxes:
        corners = np.array(
            ((x1, y1), (x2, y1), (x2, y2), (x1, y2)), dtype=np.float32
        )
        original = _restore(corners, mode, width, height)
        restored.append(
            (
                float(np.min(original[:, 0])),
                float(np.min(original[:, 1])),
                float(np.max(original[:, 0])),
                float(np.max(original[:, 1])),
            )
        )
    return np.asarray(restored, dtype=np.float32)


def _pose_quality(points: np.ndarray, scores: np.ndarray, floor: float) -> float:
    upper = scores[[5, 6, 7, 8, 9, 10, 11, 12]]
    coverage = float(np.mean(upper >= floor))
    confidence = float(np.mean(np.clip(upper, 0.0, 1.0)))
    plausible = []
    for shoulder, elbow, wrist in (
        (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
        (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
    ):
        if min(scores[shoulder], scores[elbow], scores[wrist]) < floor:
            continue
        upper_length = float(np.linalg.norm(points[shoulder] - points[elbow]))
        forearm_length = float(np.linalg.norm(points[elbow] - points[wrist]))
        ratio = forearm_length / max(upper_length, 1.0)
        plausible.append(1.0 if 0.4 <= ratio <= 1.7 else 0.0)
    anatomy = float(np.mean(plausible)) if plausible else 0.0
    return 0.50 * coverage + 0.35 * confidence + 0.15 * anatomy


def _draw(frame: np.ndarray, points: np.ndarray, scores: np.ndarray, floor: float) -> None:
    for start, end in SKELETON:
        if min(scores[start], scores[end]) >= floor:
            cv2.line(
                frame,
                tuple(points[start].astype(int)),
                tuple(points[end].astype(int)),
                (255, 142, 46),
                3,
                cv2.LINE_AA,
            )
    for index, (point, score) in enumerate(zip(points, scores)):
        if score < floor:
            continue
        cv2.circle(frame, tuple(point.astype(int)), 5, (60, 230, 150), -1)
        if index in {5, 6, 7, 8, 9, 10}:
            cv2.putText(
                frame,
                f"{index}:{score:.2f}",
                tuple((point + np.array((6, -6))).astype(int)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.42,
                (25, 25, 25),
                2,
                cv2.LINE_AA,
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--times", type=float, nargs="+", required=True)
    parser.add_argument("--confidence", type=float, default=0.25)
    parser.add_argument("--image-size", type=int, default=512)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    model = YOLO(str(args.model))
    capture = cv2.VideoCapture(str(args.video))
    if not capture.isOpened():
        raise ValueError("invalid_video")
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    trace: list[dict[str, object]] = []
    try:
        for timestamp in args.times:
            capture.set(cv2.CAP_PROP_POS_MSEC, timestamp * 1000.0)
            ok, original = capture.read()
            if not ok:
                raise ValueError(f"frame_unavailable:{timestamp}")
            panels = []
            entry: dict[str, object] = {"timestampSeconds": timestamp, "orientations": []}
            for mode in ("original", "clockwise", "counterclockwise"):
                frame = _rotate(original, mode)
                prediction = model.predict(
                    frame,
                    conf=args.confidence,
                    imgsz=args.image_size,
                    device="cpu",
                    verbose=False,
                )[0]
                xy = (
                    prediction.keypoints.xy.detach().cpu().numpy()
                    if prediction.keypoints is not None
                    and prediction.keypoints.xy is not None
                    else np.empty((0, 17, 2), dtype=np.float32)
                )
                scores = (
                    prediction.keypoints.conf.detach().cpu().numpy()
                    if prediction.keypoints is not None
                    and prediction.keypoints.conf is not None
                    else np.empty((0, 17), dtype=np.float32)
                )
                xy = _restore(xy, mode, width, height)
                boxes = (
                    prediction.boxes.xyxy.detach().cpu().numpy()
                    if prediction.boxes is not None
                    and prediction.boxes.xyxy is not None
                    else np.empty((0, 4), dtype=np.float32)
                )
                boxes = _restore_boxes(boxes, mode, width, height)
                detector_scores = (
                    prediction.boxes.conf.detach().cpu().numpy()
                    if prediction.boxes is not None
                    and prediction.boxes.conf is not None
                    else np.ones(len(xy), dtype=np.float32)
                )
                qualities = [
                    _pose_quality(points, confidence, args.confidence)
                    for points, confidence in zip(xy, scores)
                ]
                tracker = SubjectTracker(args.confidence)
                selected = tracker.select_index(
                    xy,
                    scores,
                    boxes,
                    detector_scores,
                    frame_width=width,
                    frame_height=height,
                )
                panel = original.copy()
                selected_payload: dict[str, object] | None = None
                for candidate_index, box in enumerate(boxes):
                    x1, y1, x2, y2 = box.astype(int)
                    cv2.rectangle(
                        panel,
                        (x1, y1),
                        (x2, y2),
                        (190, 190, 190),
                        1,
                    )
                    cv2.putText(
                        panel,
                        f"#{candidate_index} q={qualities[candidate_index]:.2f}",
                        (x1, max(62, y1 + 18)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.42,
                        (30, 30, 30),
                        2,
                        cv2.LINE_AA,
                    )
                if selected is not None:
                    points = xy[selected]
                    confidence = scores[selected]
                    _draw(panel, points, confidence, args.confidence)
                    selected_payload = {
                        "quality": round(qualities[selected], 4),
                        "candidateIndex": selected,
                        "box": [round(float(value), 2) for value in boxes[selected]],
                        "points": {
                            str(index): [
                                round(float(points[index][0]), 2),
                                round(float(points[index][1]), 2),
                                round(float(confidence[index]), 4),
                            ]
                            for index in (5, 6, 7, 8, 9, 10, 11, 12)
                        },
                    }
                cv2.rectangle(panel, (0, 0), (width, 48), (20, 20, 20), -1)
                cv2.putText(
                    panel,
                    f"{mode} candidates={len(xy)} quality={max(qualities, default=0):.3f}",
                    (14, 32),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.66,
                    (245, 245, 245),
                    2,
                    cv2.LINE_AA,
                )
                panels.append(panel)
                entry["orientations"].append(
                    {
                        "mode": mode,
                        "candidateCount": len(xy),
                        "selected": selected_payload,
                    }
                )
            contact = np.concatenate(panels, axis=1)
            filename = f"orientation-{timestamp:.1f}.jpg"
            cv2.imwrite(str(args.output / filename), contact)
            entry["image"] = filename
            trace.append(entry)
    finally:
        capture.release()
    (args.output / "orientation-trace.json").write_text(
        json.dumps(trace, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(args.output / "orientation-trace.json")


if __name__ == "__main__":
    main()
