from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import subprocess
from typing import Any, Callable

import cv2
import numpy as np
import torch
from ultralytics import YOLO

from .angles import RepetitionCounter, joint_angle


SKELETON = (
    (5, 7), (7, 9), (6, 8), (8, 10), (5, 6), (5, 11), (6, 12),
    (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
)


@dataclass(frozen=True)
class AnalysisOutput:
    result: dict[str, Any]
    overlay_path: Path | None
    preview_path: Path


class PoseAnalyzer:
    def __init__(
        self,
        model_path: str,
        confidence: float = 0.35,
        *,
        device: str = "cpu",
        image_size: int = 512,
        target_fps: float = 10.0,
        max_duration_seconds: float = 45.0,
        max_dimension: int = 1280,
        cpu_threads: int = 4,
    ) -> None:
        if device == "cpu":
            torch.set_num_threads(max(1, cpu_threads))
            torch.set_num_interop_threads(1)
            cv2.setNumThreads(1)
        self.model = YOLO(model_path)
        try:
            self.model.fuse()
        except (AttributeError, RuntimeError):
            pass
        self.confidence = confidence
        self.device = device
        self.image_size = image_size
        self.target_fps = max(1.0, target_fps)
        self.max_duration_seconds = max(1.0, max_duration_seconds)
        self.max_dimension = max(320, max_dimension)

    def analyze(
        self,
        source: Path,
        output_dir: Path,
        exercise_id: str,
        progress: Callable[[int, int], None] | None = None,
        include_overlay: bool = True,
    ) -> AnalysisOutput:
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            raise ValueError("invalid_video")

        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = float(capture.get(cv2.CAP_PROP_FPS) or 30.0)
        source_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        if width <= 0 or height <= 0:
            capture.release()
            raise ValueError("invalid_video_dimensions")
        duration = source_frames / fps if source_frames > 0 else 0.0
        if duration > self.max_duration_seconds:
            capture.release()
            raise ValueError("video_too_long")

        scale = min(1.0, self.max_dimension / max(width, height))
        output_width = max(2, int(width * scale) // 2 * 2)
        output_height = max(2, int(height * scale) // 2 * 2)
        inference_stride = max(1, round(fps / self.target_fps))

        overlay_path = output_dir / "overlay.mp4"
        raw_overlay_path = output_dir / "overlay-raw.mp4"
        preview_path = output_dir / "preview.jpg"
        output_fps = max(1.0, fps / inference_stride)
        writer = cv2.VideoWriter(
            str(raw_overlay_path),
            cv2.VideoWriter_fourcc(*"mp4v"),
            output_fps,
            (output_width, output_height),
        ) if include_overlay else None
        if writer is not None and not writer.isOpened():
            capture.release()
            raise RuntimeError("video_writer_unavailable")

        configuration = self._counter_configuration(exercise_id)
        counter = RepetitionCounter(configuration[3], configuration[4])
        confidence_total = 0.0
        detected_frames = 0
        frame_count = 0
        inference_frames = 0
        preview_written = False
        last_points = None
        last_scores = None

        try:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                frame_count += 1
                if frame_count > int(self.max_duration_seconds * fps) + 1:
                    raise ValueError("video_too_long")
                should_infer = (frame_count - 1) % inference_stride == 0
                if not should_infer:
                    if progress is not None:
                        progress(frame_count, source_frames)
                    continue
                if scale < 1.0:
                    frame = cv2.resize(frame, (output_width, output_height), interpolation=cv2.INTER_AREA)
                inference_frames += 1
                prediction = self.model.predict(
                    frame,
                    conf=self.confidence,
                    device=self.device,
                    imgsz=self.image_size,
                    verbose=False,
                )[0]
                last_points, last_scores = self._best_pose(prediction)
                points, scores = last_points, last_scores
                if points is not None and scores is not None:
                    detected_frames += 1
                    confidence_total += float(np.mean(scores[scores > 0])) if np.any(scores > 0) else 0.0
                    self._draw_pose(frame, points, scores)
                    a, b, c, _, _ = configuration
                    if min(scores[a], scores[b], scores[c]) >= self.confidence:
                        angle = joint_angle(points[a], points[b], points[c])
                        counter.update(angle)
                        cv2.putText(frame, f"Angle {angle:.0f}", (20, 74), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 179, 71), 2)
                cv2.putText(frame, f"Reps {counter.count}", (20, 42), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (48, 210, 122), 2)
                if writer is not None:
                    writer.write(frame)
                if not preview_written and detected_frames:
                    cv2.imwrite(str(preview_path), frame, [cv2.IMWRITE_JPEG_QUALITY, 88])
                    preview_written = True
                if progress is not None:
                    progress(frame_count, source_frames)
        finally:
            if writer is not None:
                writer.release()
            capture.release()

        if not frame_count:
            raise ValueError("empty_video")
        if not preview_written:
            fallback = np.zeros((output_height, output_width, 3), dtype=np.uint8)
            cv2.putText(fallback, "No pose detected", (20, max(50, output_height // 2)), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (230, 230, 230), 2)
            cv2.imwrite(str(preview_path), fallback, [cv2.IMWRITE_JPEG_QUALITY, 88])

        if include_overlay:
            self._encode_compatible_overlay(raw_overlay_path, overlay_path)

        detection_rate = detected_frames / inference_frames if inference_frames else 0.0
        pose_confidence = confidence_total / detected_frames if detected_frames else 0.0
        overall_confidence = round(min(1.0, detection_rate * pose_confidence), 4)
        summary = "动作骨骼提取完成" if detected_frames else "未检测到稳定人体骨骼，请调整机位和光线后重试"
        result = {
            "status": "complete",
            "confidence": overall_confidence,
            "repetitions": counter.count,
            "summary": summary,
            "metrics": {
                "frames": frame_count,
                "detectedFrames": detected_frames,
                "inferenceFrames": inference_frames,
                "inferenceStride": inference_stride,
                "detectionRate": round(detection_rate, 4),
                "fps": round(fps, 2),
                "outputFps": round(output_fps, 2),
                "durationSeconds": round(frame_count / fps, 2),
                "outputWidth": output_width,
                "outputHeight": output_height,
            },
        }
        return AnalysisOutput(result, overlay_path if include_overlay else None, preview_path)

    @staticmethod
    def _encode_compatible_overlay(source: Path, destination: Path) -> None:
        """Convert OpenCV's intermediate file to mobile-safe H.264 MP4.

        OpenCV's mp4v output is not consistently decoded by AVPlayer and
        Android MediaCodec. yuv420p + faststart is supported by both clients
        and lets the app start playback before reading the whole file.
        """
        try:
            subprocess.run(
                [
                    "ffmpeg", "-y", "-loglevel", "error", "-i", str(source),
                    "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "24",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(destination),
                ],
                check=True,
                timeout=180,
            )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise RuntimeError("overlay_encoding_failed") from error
        finally:
            source.unlink(missing_ok=True)

    @staticmethod
    def _best_pose(prediction: Any) -> tuple[np.ndarray | None, np.ndarray | None]:
        keypoints = prediction.keypoints
        if keypoints is None or keypoints.xy is None or len(keypoints.xy) == 0:
            return None, None
        xy = keypoints.xy.detach().cpu().numpy()
        if keypoints.conf is None:
            confidence = np.ones((xy.shape[0], xy.shape[1]), dtype=np.float32)
        else:
            confidence = keypoints.conf.detach().cpu().numpy()
        best = int(np.argmax(np.mean(confidence, axis=1)))
        return xy[best], confidence[best]

    def _draw_pose(self, frame: np.ndarray, points: np.ndarray, scores: np.ndarray) -> None:
        for start, end in SKELETON:
            if scores[start] >= self.confidence and scores[end] >= self.confidence:
                cv2.line(frame, tuple(points[start].astype(int)), tuple(points[end].astype(int)), (255, 142, 46), 3, cv2.LINE_AA)
        for point, score in zip(points, scores):
            if score >= self.confidence:
                cv2.circle(frame, tuple(point.astype(int)), 4, (60, 230, 150), -1, cv2.LINE_AA)

    @staticmethod
    def _counter_configuration(exercise_id: str) -> tuple[int, int, int, float, float]:
        normalized = exercise_id.lower()
        if any(token in normalized for token in ("squat", "蹲", "leg", "腿")):
            return 11, 13, 15, 75.0, 155.0
        if any(token in normalized for token in ("curl", "弯举", "二头")):
            return 5, 7, 9, 65.0, 145.0
        return 5, 7, 9, 80.0, 155.0
