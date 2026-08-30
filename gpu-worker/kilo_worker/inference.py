from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
import subprocess
from typing import Any, Callable, Sequence

import cv2
import numpy as np
import torch
from ultralytics import YOLO

from .action_compatibility import assess_action_compatibility
from .angles import EvidenceAssessment, assess_exercise_evidence
from .events import (
    MotionEvent,
    PoseSample,
    analyze_pose_events,
    event_to_result,
    format_video_time,
)
from .pose_recovery import recover_occluded_endpoints
from .subject_tracking import SubjectTracker


SKELETON = (
    (5, 7), (7, 9), (6, 8), (8, 10), (5, 6), (5, 11), (6, 12),
    (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
)


@dataclass(frozen=True)
class AnalysisOutput:
    result: dict[str, Any]
    overlay_path: Path | None
    preview_path: Path
    evidence_paths: dict[str, Path]


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
        camera: str,
        progress: Callable[[int, int], None] | None = None,
        include_overlay: bool = False,
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

        output_dir.mkdir(parents=True, exist_ok=True)
        scale = min(1.0, self.max_dimension / max(width, height))
        output_width = max(2, int(width * scale) // 2 * 2)
        output_height = max(2, int(height * scale) // 2 * 2)
        inference_stride = max(1, round(fps / self.target_fps))

        overlay_path = output_dir / "overlay.mp4"
        raw_overlay_path = output_dir / "overlay-raw.mp4"
        preview_path = output_dir / "preview.jpg"
        output_fps = max(1.0, fps / inference_stride)
        confidence_total = 0.0
        detected_frames = 0
        frame_count = 0
        inference_frames = 0
        samples: list[PoseSample] = []
        subject_tracker = SubjectTracker(self.confidence)

        try:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                frame_count += 1
                if frame_count > int(self.max_duration_seconds * fps) + 1:
                    raise ValueError("video_too_long")
                if (frame_count - 1) % inference_stride != 0:
                    if progress is not None:
                        progress(frame_count, source_frames)
                    continue
                if scale < 1.0:
                    frame = cv2.resize(
                        frame,
                        (output_width, output_height),
                        interpolation=cv2.INTER_AREA,
                    )
                inference_frames += 1
                prediction = self.model.predict(
                    frame,
                    conf=self.confidence,
                    device=self.device,
                    imgsz=self.image_size,
                    verbose=False,
                )[0]
                points, scores = self._best_pose(
                    prediction,
                    subject_tracker,
                    output_width,
                    output_height,
                )
                timestamp_ms = round((frame_count - 1) * 1000.0 / fps)
                if points is not None and scores is not None:
                    detected_frames += 1
                    confidence_total += (
                        float(np.mean(scores[scores > 0]))
                        if np.any(scores > 0)
                        else 0.0
                    )
                    samples.append(
                        PoseSample(
                            timestamp_ms=timestamp_ms,
                            source_frame_index=frame_count - 1,
                            points=points.copy(),
                            scores=scores.copy(),
                        )
                    )
                if progress is not None:
                    progress(frame_count, source_frames)
        finally:
            capture.release()

        if not frame_count:
            raise ValueError("empty_video")
        detection_rate = detected_frames / inference_frames if inference_frames else 0.0
        pose_confidence = confidence_total / detected_frames if detected_frames else 0.0
        overall_confidence = round(min(1.0, detection_rate * pose_confidence), 4)
        samples, endpoint_recovery = recover_occluded_endpoints(
            samples,
            confidence_floor=self.confidence,
            frame_width=output_width,
            frame_height=output_height,
        )
        preview_written = False
        if include_overlay:
            preview_written = self._render_recovered_overlay(
                source,
                raw_overlay_path,
                overlay_path,
                preview_path,
                samples,
                scale,
                output_width,
                output_height,
                inference_stride,
                output_fps,
                fps,
            )
        elif samples:
            preview_written = self._render_recovered_preview(
                source,
                preview_path,
                samples[0],
                scale,
                output_width,
                output_height,
            )
        if not preview_written:
            self._write_missing_pose_preview(
                preview_path,
                output_width,
                output_height,
            )

        compatibility = assess_action_compatibility(
            exercise_id,
            camera,
            samples,
            confidence_floor=self.confidence,
        )
        event_analysis = analyze_pose_events(
            exercise_id,
            camera,
            samples,
            confidence_floor=self.confidence,
        )
        evidence = assess_exercise_evidence(
            complete_cycles=event_analysis.complete_motion_cycles,
            partial_cycles=event_analysis.partial_motion_cycles,
            visible_phases=event_analysis.visible_phases,
            confidence=overall_confidence,
            detected_frames=detected_frames,
            inference_frames=inference_frames,
            angle_samples=event_analysis.primary_angles,
        )
        if not compatibility.compatible:
            evidence = EvidenceAssessment(
                False,
                "selected_exercise_mismatch",
                evidence.angle_range,
                level="mismatch",
                can_count_repetitions=False,
                visible_phases=event_analysis.visible_phases,
            )
        report_events = event_analysis.events if evidence.assessable else ()
        event_pairs = [
            (f"event-{number:03d}", event)
            for number, event in enumerate(report_events, start=1)
        ]
        rendered = self._render_evidence_images(
            source,
            output_dir,
            samples,
            event_pairs,
            scale,
            output_width,
            output_height,
        )
        event_pairs = [
            (evidence_id, event)
            for evidence_id, event in event_pairs
            if evidence_id in rendered
        ]
        result_events = [
            event_to_result(event, samples, evidence_id)
            for evidence_id, event in event_pairs
        ]
        if evidence.reason == "selected_exercise_mismatch":
            summary = "视频中的动作过程与所选动作不一致，请确认动作类型后重新分析。"
        elif not evidence.assessable:
            summary = "当前画面没有提供足够的目标动作证据，暂不判断动作好坏。"
        elif result_events:
            prefix = "在可见动作阶段" if evidence.level == "partial_cycle" else "在视频中"
            summary = f"{prefix}的 {len(result_events)} 个时间点发现需要注意的动作现象。"
        elif evidence.level == "partial_cycle":
            if (
                "bench_cycle_uses_relative_motion_due_endpoint_occlusion"
                in event_analysis.limitations
            ):
                summary = (
                    "已识别到卧推的下放和推回过程，但端点遮挡使绝对角度不足以可靠计次；"
                    "本次只评价可见阶段。"
                )
            else:
                summary = (
                    "已识别到主要动作阶段，但没有可靠确认完整周期；"
                    "本次只评价可见阶段，不计次数。"
                )
        else:
            summary = "当前可测的主要动作没有发现明显问题；这不代表所有动作细节都已验证。"

        angle_min = (
            round(min(event_analysis.primary_angles), 2)
            if event_analysis.primary_angles
            else None
        )
        angle_max = (
            round(max(event_analysis.primary_angles), 2)
            if event_analysis.primary_angles
            else None
        )
        tracking_metrics = subject_tracker.metrics
        evaluated_rules = event_analysis.evaluated_rules or (
            f"{exercise_id.lower()}_primary_motion",
        )
        skipped_rules = tuple(
            dict.fromkeys((*event_analysis.skipped_rules, *event_analysis.limitations))
        )
        supported_rule_count = len(evaluated_rules) + len(skipped_rules)
        primary_coverage = (
            1.0
            if evidence.level == "full_cycle"
            else 0.65
            if evidence.level == "partial_cycle"
            else 0.0
        )
        result = {
            "status": "complete",
            "assessment": "assessable" if evidence.assessable else "insufficient_evidence",
            "evidenceReason": evidence.reason,
            "confidence": overall_confidence,
            "summary": summary,
            "events": result_events,
            "limitations": list(event_analysis.limitations),
            "actionCompatibility": compatibility.to_result(),
            "evidence": {
                "level": evidence.level,
                "canJudgePrimary": evidence.assessable,
                "canCountRepetitions": evidence.can_count_repetitions,
                "visiblePhases": list(evidence.visible_phases),
                "evaluatedRules": list(evaluated_rules),
                "skippedRules": list(skipped_rules),
            },
            "ruleCoverage": {
                "supported": supported_rule_count,
                "evaluated": len(evaluated_rules),
                "skipped": len(skipped_rules),
                "primaryCoverage": primary_coverage,
            },
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
                "primaryAngleMin": angle_min,
                "primaryAngleMax": angle_max,
                "primaryAngleRange": round(evidence.angle_range, 2),
                "completeMotionCycles": event_analysis.complete_motion_cycles,
                "partialMotionCycles": event_analysis.partial_motion_cycles,
                "eventCount": len(result_events),
                "subjectSelectionStrategy": "temporal_primary_subject",
                "multiPersonFrames": tracking_metrics.multi_person_frames,
                "maxDetectedPeople": tracking_metrics.max_detected_people,
                "missingTargetFrames": tracking_metrics.missing_target_frames,
                "subjectReacquisitions": tracking_metrics.reacquisitions,
                "assessable": evidence.assessable,
                "evidenceReason": evidence.reason,
                "evidenceLevel": evidence.level,
                "canCountRepetitions": evidence.can_count_repetitions,
                "inferredWristSamples": endpoint_recovery.inferred_samples,
                "temporalWristSamples": endpoint_recovery.temporal_samples,
                "directionOnlyWristSamples": endpoint_recovery.direction_only_samples,
                "rejectedWristObservations": endpoint_recovery.rejected_observations,
                "inferredAnkleSamples": endpoint_recovery.inferred_ankle_samples,
                "temporalAnkleSamples": endpoint_recovery.temporal_ankle_samples,
                "directionOnlyAnkleSamples": endpoint_recovery.direction_only_ankle_samples,
                "rejectedAnkleObservations": endpoint_recovery.rejected_ankle_observations,
            },
        }
        return AnalysisOutput(
            result=result,
            overlay_path=overlay_path if include_overlay else None,
            preview_path=preview_path,
            evidence_paths=rendered,
        )

    def _render_recovered_overlay(
        self,
        source: Path,
        raw_overlay_path: Path,
        overlay_path: Path,
        preview_path: Path,
        samples: Sequence[PoseSample],
        scale: float,
        output_width: int,
        output_height: int,
        inference_stride: int,
        output_fps: float,
        source_fps: float,
    ) -> bool:
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            raise ValueError("invalid_video")
        writer = cv2.VideoWriter(
            str(raw_overlay_path),
            cv2.VideoWriter_fourcc(*"mp4v"),
            output_fps,
            (output_width, output_height),
        )
        if not writer.isOpened():
            capture.release()
            raise RuntimeError("video_writer_unavailable")
        by_frame = {sample.source_frame_index: sample for sample in samples}
        preview_written = False
        frame_index = -1
        try:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                frame_index += 1
                if frame_index % inference_stride != 0:
                    continue
                if scale < 1.0:
                    frame = cv2.resize(
                        frame,
                        (output_width, output_height),
                        interpolation=cv2.INTER_AREA,
                    )
                sample = by_frame.get(frame_index)
                if sample is not None:
                    self._draw_pose(
                        frame,
                        sample.points,
                        sample.scores,
                        inferred=sample.inferred,
                    )
                timestamp_ms = (
                    sample.timestamp_ms
                    if sample is not None
                    else round(frame_index * 1000.0 / source_fps)
                )
                cv2.putText(
                    frame,
                    format_video_time(timestamp_ms),
                    (20, 42),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (48, 210, 122),
                    2,
                    cv2.LINE_AA,
                )
                writer.write(frame)
                if sample is not None and not preview_written:
                    preview_written = cv2.imwrite(
                        str(preview_path),
                        frame,
                        [cv2.IMWRITE_JPEG_QUALITY, 88],
                    )
        finally:
            writer.release()
            capture.release()
        self._encode_compatible_overlay(raw_overlay_path, overlay_path)
        return preview_written

    def _render_recovered_preview(
        self,
        source: Path,
        preview_path: Path,
        sample: PoseSample,
        scale: float,
        output_width: int,
        output_height: int,
    ) -> bool:
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            return False
        try:
            capture.set(cv2.CAP_PROP_POS_FRAMES, sample.source_frame_index)
            ok, frame = capture.read()
            if not ok:
                return False
            if scale < 1.0:
                frame = cv2.resize(
                    frame,
                    (output_width, output_height),
                    interpolation=cv2.INTER_AREA,
                )
            self._draw_pose(
                frame,
                sample.points,
                sample.scores,
                inferred=sample.inferred,
            )
            cv2.putText(
                frame,
                format_video_time(sample.timestamp_ms),
                (20, 42),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                (48, 210, 122),
                2,
                cv2.LINE_AA,
            )
            return cv2.imwrite(
                str(preview_path),
                frame,
                [cv2.IMWRITE_JPEG_QUALITY, 88],
            )
        finally:
            capture.release()

    @staticmethod
    def _write_missing_pose_preview(
        preview_path: Path,
        output_width: int,
        output_height: int,
    ) -> None:
        fallback = np.zeros((output_height, output_width, 3), dtype=np.uint8)
        cv2.putText(
            fallback,
            "No pose detected",
            (20, max(50, output_height // 2)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (230, 230, 230),
            2,
        )
        cv2.imwrite(
            str(preview_path),
            fallback,
            [cv2.IMWRITE_JPEG_QUALITY, 88],
        )

    def _render_evidence_images(
        self,
        source: Path,
        output_dir: Path,
        samples: Sequence[PoseSample],
        events: Sequence[tuple[str, MotionEvent]],
        scale: float,
        output_width: int,
        output_height: int,
    ) -> dict[str, Path]:
        if not events:
            return {}
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            raise ValueError("invalid_video")
        evidence_dir = output_dir / "evidence"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        paths: dict[str, Path] = {}
        try:
            for evidence_id, event in events:
                sample = samples[event.peak_index]
                capture.set(cv2.CAP_PROP_POS_FRAMES, sample.source_frame_index)
                ok, frame = capture.read()
                if not ok:
                    continue
                if scale < 1.0:
                    frame = cv2.resize(
                        frame,
                        (output_width, output_height),
                        interpolation=cv2.INTER_AREA,
                    )
                self._draw_pose(
                    frame,
                    sample.points,
                    sample.scores,
                    inferred=sample.inferred,
                )
                self._draw_event_reference(frame, event, samples)
                self._draw_evidence_header(frame, sample.timestamp_ms)
                if frame.shape[1] > 960:
                    ratio = 960 / frame.shape[1]
                    frame = cv2.resize(
                        frame,
                        (960, round(frame.shape[0] * ratio)),
                        interpolation=cv2.INTER_AREA,
                    )
                destination = evidence_dir / f"{evidence_id}.jpg"
                if cv2.imwrite(
                    str(destination), frame, [cv2.IMWRITE_JPEG_QUALITY, 88]
                ):
                    paths[evidence_id] = destination
        finally:
            capture.release()
        return paths

    def _draw_event_reference(
        self,
        frame: np.ndarray,
        event: MotionEvent,
        samples: Sequence[PoseSample],
    ) -> None:
        sample = samples[event.peak_index]
        points = sample.points
        color = (70, 225, 255)
        for start, end in zip(
            event.highlight_landmarks, event.highlight_landmarks[1:]
        ):
            if min(sample.scores[start], sample.scores[end]) >= self.confidence:
                cv2.line(
                    frame,
                    tuple(points[start].astype(int)),
                    tuple(points[end].astype(int)),
                    color,
                    6,
                    cv2.LINE_AA,
                )
        if event.reference == "hip_ankle_line" and len(event.highlight_landmarks) >= 3:
            hip, _, ankle = event.highlight_landmarks[:3]
            cv2.line(
                frame,
                tuple(points[hip].astype(int)),
                tuple(points[ankle].astype(int)),
                (245, 245, 245),
                3,
                cv2.LINE_AA,
            )
        elif event.reference == "vertical_forearm" and event.highlight_landmarks:
            elbow = event.highlight_landmarks[0]
            x, y = points[elbow].astype(int)
            length = max(80, round(frame.shape[0] * 0.22))
            cv2.line(
                frame,
                (x, max(0, y - length)),
                (x, min(frame.shape[0] - 1, y + length)),
                (245, 245, 245),
                3,
                cv2.LINE_AA,
            )
        elif event.reference == "elbow_path" and len(event.highlight_landmarks) >= 2:
            elbow = event.highlight_landmarks[-1]
            start_point = samples[event.start_index].points[elbow]
            end_point = points[elbow]
            cv2.arrowedLine(
                frame,
                tuple(start_point.astype(int)),
                tuple(end_point.astype(int)),
                (245, 245, 245),
                3,
                cv2.LINE_AA,
                tipLength=0.12,
            )

    @staticmethod
    def _draw_evidence_header(
        frame: np.ndarray,
        timestamp_ms: int,
    ) -> None:
        height, width = frame.shape[:2]
        bar_height = max(52, round(height * 0.09))
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (width, bar_height), (18, 20, 23), -1)
        cv2.addWeighted(overlay, 0.82, frame, 0.18, 0, frame)
        label = format_video_time(timestamp_ms)
        cv2.putText(
            frame,
            label,
            (18, max(35, round(bar_height * 0.68))),
            cv2.FONT_HERSHEY_SIMPLEX,
            max(0.58, width / 1200),
            (238, 248, 255),
            2,
            cv2.LINE_AA,
        )

    @staticmethod
    def _encode_compatible_overlay(source: Path, destination: Path) -> None:
        """Convert OpenCV's intermediate file to mobile-safe H.264 MP4."""
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
        except (
            OSError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ) as error:
            raise RuntimeError("overlay_encoding_failed") from error
        finally:
            source.unlink(missing_ok=True)

    @staticmethod
    def _best_pose(
        prediction: Any,
        tracker: SubjectTracker,
        frame_width: int,
        frame_height: int,
    ) -> tuple[np.ndarray | None, np.ndarray | None]:
        keypoints = prediction.keypoints
        if keypoints is None or keypoints.xy is None or len(keypoints.xy) == 0:
            tracker.select_index(
                np.empty((0, 17, 2), dtype=np.float32),
                np.empty((0, 17), dtype=np.float32),
                None,
                None,
                frame_width=frame_width,
                frame_height=frame_height,
            )
            return None, None
        xy = keypoints.xy.detach().cpu().numpy()
        if keypoints.conf is None:
            confidence = np.ones((xy.shape[0], xy.shape[1]), dtype=np.float32)
        else:
            confidence = keypoints.conf.detach().cpu().numpy()
        boxes = None
        detector_confidence = None
        if prediction.boxes is not None:
            if prediction.boxes.xyxy is not None:
                boxes = prediction.boxes.xyxy.detach().cpu().numpy()
            if prediction.boxes.conf is not None:
                detector_confidence = prediction.boxes.conf.detach().cpu().numpy()
        best = tracker.select_index(
            xy,
            confidence,
            boxes,
            detector_confidence,
            frame_width=frame_width,
            frame_height=frame_height,
        )
        if best is None:
            return None, None
        return xy[best], confidence[best]

    def _draw_pose(
        self,
        frame: np.ndarray,
        points: np.ndarray,
        scores: np.ndarray,
        inferred: np.ndarray | None = None,
    ) -> None:
        for start, end in SKELETON:
            if scores[start] >= self.confidence and scores[end] >= self.confidence:
                if not self._segment_geometry_is_plausible(points, start, end):
                    continue
                start_point = tuple(points[start].astype(int))
                end_point = tuple(points[end].astype(int))
                segment_inferred = inferred is not None and (
                    bool(inferred[start]) or bool(inferred[end])
                )
                if segment_inferred:
                    self._draw_dashed_line(
                        frame,
                        start_point,
                        end_point,
                        (70, 225, 255),
                        3,
                    )
                else:
                    cv2.line(
                        frame,
                        start_point,
                        end_point,
                        (255, 142, 46),
                        3,
                        cv2.LINE_AA,
                    )
        for index, (point, score) in enumerate(zip(points, scores)):
            if score >= self.confidence:
                cv2.circle(
                    frame,
                    tuple(point.astype(int)),
                    4,
                    (
                        (70, 225, 255)
                        if inferred is not None and bool(inferred[index])
                        else (60, 230, 150)
                    ),
                    -1,
                    cv2.LINE_AA,
                )

    @staticmethod
    def _segment_geometry_is_plausible(
        points: np.ndarray,
        start: int,
        end: int,
    ) -> bool:
        if not np.all(np.isfinite(points[[start, end]])):
            return False
        proximal_for_segment = {
            (7, 9): 5,
            (8, 10): 6,
            (13, 15): 11,
            (14, 16): 12,
        }
        proximal = proximal_for_segment.get((start, end))
        if proximal is None:
            return True
        reference = float(np.linalg.norm(points[start] - points[proximal]))
        segment = float(np.linalg.norm(points[end] - points[start]))
        if not np.isfinite(reference) or not np.isfinite(segment) or reference < 6.0:
            return False
        return reference * 0.30 <= segment <= reference * 1.75

    @staticmethod
    def _draw_dashed_line(
        frame: np.ndarray,
        start: tuple[int, int],
        end: tuple[int, int],
        color: tuple[int, int, int],
        width: int,
    ) -> None:
        distance = max(1.0, math.hypot(end[0] - start[0], end[1] - start[1]))
        direction = ((end[0] - start[0]) / distance, (end[1] - start[1]) / distance)
        dash = 10.0
        gap = 7.0
        offset = 0.0
        while offset < distance:
            finish = min(distance, offset + dash)
            first = (
                round(start[0] + direction[0] * offset),
                round(start[1] + direction[1] * offset),
            )
            second = (
                round(start[0] + direction[0] * finish),
                round(start[1] + direction[1] * finish),
            )
            cv2.line(frame, first, second, color, width, cv2.LINE_AA)
            offset += dash + gap
