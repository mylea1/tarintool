from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def _read_even_frames(path: Path, count: int) -> tuple[dict[str, object], list[tuple[float, np.ndarray]]]:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise RuntimeError(f"Cannot open video: {path}")
    fps = float(capture.get(cv2.CAP_PROP_FPS) or 0.0)
    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
    duration = frame_count / fps if fps > 0 else 0.0
    timestamps = np.linspace(0, max(0.0, duration - 1 / max(fps, 1)), count)
    frames: list[tuple[float, np.ndarray]] = []
    for timestamp in timestamps:
        capture.set(cv2.CAP_PROP_POS_MSEC, float(timestamp * 1000))
        ok, frame = capture.read()
        if ok:
            frames.append((float(timestamp), frame))
    capture.release()
    return {
        "path": str(path),
        "fps": round(fps, 3),
        "frameCount": frame_count,
        "width": width,
        "height": height,
        "durationSeconds": round(duration, 3),
        "sizeBytes": path.stat().st_size,
    }, frames


def _contact_sheet(frames: list[tuple[float, np.ndarray]], columns: int = 3) -> np.ndarray:
    cell_width = 480
    rows = (len(frames) + columns - 1) // columns
    cells: list[np.ndarray] = []
    for timestamp, frame in frames:
        scale = cell_width / frame.shape[1]
        resized = cv2.resize(frame, (cell_width, int(frame.shape[0] * scale)))
        cv2.rectangle(resized, (0, 0), (150, 42), (20, 20, 20), -1)
        cv2.putText(
            resized,
            f"{timestamp:05.1f}s",
            (14, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )
        cells.append(resized)
    cell_height = max(cell.shape[0] for cell in cells)
    canvas = np.full((rows * cell_height, columns * cell_width, 3), 246, np.uint8)
    for index, cell in enumerate(cells):
        row, column = divmod(index, columns)
        y = row * cell_height + (cell_height - cell.shape[0]) // 2
        x = column * cell_width
        canvas[y : y + cell.shape[0], x : x + cell.shape[1]] = cell
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("videos", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--frames", type=int, default=9)
    parser.add_argument(
        "--save-samples",
        action="store_true",
        help="Also save each sampled frame at its original aspect ratio.",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    metadata: list[dict[str, object]] = []
    for video in args.videos:
        item, frames = _read_even_frames(video, args.frames)
        metadata.append(item)
        target = args.output / f"{video.stem}-contact-sheet.jpg"
        cv2.imwrite(str(target), _contact_sheet(frames), [cv2.IMWRITE_JPEG_QUALITY, 92])
        if args.save_samples:
            for index, (timestamp, frame) in enumerate(frames):
                frame_target = args.output / (
                    f"{video.stem}-sample-{index + 1:02d}-{timestamp:05.1f}s.jpg"
                )
                cv2.imwrite(
                    str(frame_target), frame, [cv2.IMWRITE_JPEG_QUALITY, 92]
                )
    (args.output / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
