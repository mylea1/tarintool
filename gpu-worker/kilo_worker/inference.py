from __future__ import annotations

from dataclasses import dataclass
import math
import os
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
from .pose_validation import (
    LEFT_ARM,
    LEFT_LEG,
    RIGHT_ARM,
    RIGHT_LEG,
    chain_quality,
    validate_pose_sequence,
)
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
        image_size: int = 960,
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

        orientation_mode, orientation_scores = self._select_orientation_mode(
            capture,
            exercise_id=exercise_id,
            source_frames=source_frames,
            fps=fps,
            scale=scale,
            output_width=output_width,
            output_height=output_height,
        )

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
                inference_frame = self._rotate_frame(frame, orientation_mode)
                prediction = self.model.predict(
                    inference_frame,
                    conf=self.confidence,
                    device=self.device,
                    imgsz=self.image_size,
                    verbose=False,
                )[0]
                points, scores = self._best_pose_oriented(
                    prediction,
                    subject_tracker,
                    output_width,
                    output_height,
                    orientation_mode,
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
        raw_samples = samples
        samples, pose_validation = validate_pose_sequence(
            samples,
            confidence_floor=self.confidence,
            exercise_id=exercise_id,
            camera=camera,
            frame_width=output_width,
            frame_height=output_height,
        )
        fallback_metrics = {
            "attemptedFrames": 0,
            "replacedFrames": 0,
            "geometryCandidateFrames": 0,
            "originalFrames": 0,
            "clockwiseFrames": 0,
            "counterclockwiseFrames": 0,
        }
        if (
            pose_validation.selected_arm_side is not None
            and self._sequence_is_horizontal(raw_samples)
        ):
            repaired, fallback_metrics = self._repair_side_chain_with_orientation_fallback(
                source,
                raw_samples,
                pose_validation.selected_arm_side,
                exercise_id,
                orientation_mode,
                scale,
                output_width,
                output_height,
            )
            if fallback_metrics["replacedFrames"]:
                samples, pose_validation = validate_pose_sequence(
                    repaired,
                    confidence_floor=self.confidence,
                    exercise_id=exercise_id,
                    camera=camera,
                    frame_width=output_width,
                    frame_height=output_height,
                )
        samples, endpoint_recovery = recover_occluded_endpoints(
            samples,
            confidence_floor=self.confidence,
            frame_width=output_width,
            frame_height=output_height,
            exercise_id=exercise_id,
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
                "inferenceOrientation": orientation_mode,
                "orientationPreflightScores": orientation_scores,
                "orientationFallback": fallback_metrics,
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
                "invalidPoseCoordinates": pose_validation.invalid_coordinates,
                "temporalJointSpikes": pose_validation.temporal_joint_spikes,
                "boneLengthOutliers": pose_validation.bone_length_outliers,
                "bilateralOcclusionRejects": pose_validation.bilateral_occlusion_rejects,
                "selectedArmSide": pose_validation.selected_arm_side,
                "suppressedArmSamples": pose_validation.suppressed_arm_samples,
                "armChainQuality": [
                    quality.to_result() for quality in pose_validation.arm_qualities
                ],
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
                    os.getenv("KILO_FFMPEG_PATH", "ffmpeg"),
                    "-y", "-loglevel", "error", "-i", str(source),
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
        return PoseAnalyzer._best_pose_oriented(
            prediction,
            tracker,
            frame_width,
            frame_height,
            "original",
        )

    @staticmethod
    def _best_pose_oriented(
        prediction: Any,
        tracker: SubjectTracker,
        frame_width: int,
        frame_height: int,
        orientation: str,
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
        xy = PoseAnalyzer._restore_points(
            xy,
            orientation,
            frame_width,
            frame_height,
        )
        if keypoints.conf is None:
            confidence = np.ones((xy.shape[0], xy.shape[1]), dtype=np.float32)
        else:
            confidence = keypoints.conf.detach().cpu().numpy()
        boxes = None
        detector_confidence = None
        if prediction.boxes is not None:
            if prediction.boxes.xyxy is not None:
                boxes = prediction.boxes.xyxy.detach().cpu().numpy()
                boxes = PoseAnalyzer._restore_boxes(
                    boxes,
                    orientation,
                    frame_width,
                    frame_height,
                )
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

    def _select_orientation_mode(
        self,
        capture: cv2.VideoCapture,
        *,
        exercise_id: str,
        source_frames: int,
        fps: float,
        scale: float,
        output_width: int,
        output_height: int,
    ) -> tuple[str, dict[str, float]]:
        """Choose one video-level pose orientation for a horizontal subject.

        Pose estimators are trained mostly on upright people.  A short
        preflight over the same clip lets a supine athlete be evaluated under
        three rotation hypotheses without switching orientation frame by
        frame.  One stable choice avoids both the bench-press arm collapse and
        the leg-as-arm hallucinations produced by a blind rotation.
        """
        if source_frames <= 0:
            capture.set(cv2.CAP_PROP_POS_FRAMES, 0)
            return "original", {"original": 0.0}
        count = min(8, max(4, round(source_frames / max(1.0, fps * 2.5))))
        last = max(0, source_frames - 1)
        frame_indexes = sorted(
            {int(value) for value in np.linspace(0, last, count)}
        )
        frames: list[tuple[int, np.ndarray]] = []
        for frame_index in frame_indexes:
            capture.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ok, frame = capture.read()
            if not ok:
                continue
            if scale < 1.0:
                frame = cv2.resize(
                    frame,
                    (output_width, output_height),
                    interpolation=cv2.INTER_AREA,
                )
            frames.append((frame_index, frame))
        if not frames:
            capture.set(cv2.CAP_PROP_POS_FRAMES, 0)
            return "original", {"original": 0.0}

        samples_by_mode: dict[str, list[PoseSample]] = {}
        for mode in ("original", "clockwise", "counterclockwise"):
            tracker = SubjectTracker(self.confidence)
            samples: list[PoseSample] = []
            for frame_index, frame in frames:
                prediction = self.model.predict(
                    self._rotate_frame(frame, mode),
                    conf=self.confidence,
                    device=self.device,
                    imgsz=self.image_size,
                    verbose=False,
                )[0]
                points, scores = self._best_pose_oriented(
                    prediction,
                    tracker,
                    output_width,
                    output_height,
                    mode,
                )
                if points is None or scores is None:
                    continue
                samples.append(
                    PoseSample(
                        timestamp_ms=round(frame_index * 1000.0 / fps),
                        source_frame_index=frame_index,
                        points=points.copy(),
                        scores=scores.copy(),
                    )
                )
            samples_by_mode[mode] = samples

        original = samples_by_mode["original"]
        if not self._sequence_is_horizontal(original):
            capture.set(cv2.CAP_PROP_POS_FRAMES, 0)
            return "original", {"original": 1.0}

        raw_scores = {
            mode: self._orientation_sequence_quality(samples, exercise_id)
            for mode, samples in samples_by_mode.items()
        }
        best_mode = max(raw_scores, key=raw_scores.get)
        # A marginal score win is not enough to rotate a complete video.
        if raw_scores[best_mode] < raw_scores["original"] + 0.025:
            best_mode = "original"
        capture.set(cv2.CAP_PROP_POS_FRAMES, 0)
        return best_mode, {
            mode: round(float(score), 4) for mode, score in raw_scores.items()
        }

    def _orientation_sequence_quality(
        self,
        samples: Sequence[PoseSample],
        exercise_id: str,
    ) -> float:
        if not samples:
            return 0.0
        arm = max(
            chain_quality(
                samples,
                LEFT_ARM,
                self.confidence,
                side="left",
                exercise_id=exercise_id,
            ).score,
            chain_quality(
                samples,
                RIGHT_ARM,
                self.confidence,
                side="right",
                exercise_id=exercise_id,
            ).score,
        )
        leg = max(
            chain_quality(samples, LEFT_LEG, self.confidence, side="left").score,
            chain_quality(samples, RIGHT_LEG, self.confidence, side="right").score,
        )
        torso_coverage = float(
            np.mean(
                [
                    min(sample.scores[5], sample.scores[6], sample.scores[11], sample.scores[12])
                    >= self.confidence
                    for sample in samples
                ]
            )
        )
        return 0.68 * arm + 0.22 * leg + 0.10 * torso_coverage

    def _repair_side_chain_with_orientation_fallback(
        self,
        source: Path,
        samples: Sequence[PoseSample],
        selected_side: str,
        exercise_id: str,
        primary_orientation: str,
        scale: float,
        output_width: int,
        output_height: int,
    ) -> tuple[list[PoseSample], dict[str, int]]:
        target_chain = LEFT_ARM if selected_side == "left" else RIGHT_ARM
        scored = [
            (
                self._single_frame_chain_score(sample, target_chain, exercise_id),
                index,
            )
            for index, sample in enumerate(samples)
        ]
        regular_suspects = [
            (score, index)
            for score, index in scored
            if score < 0.53
            or self._chain_endpoint_ratio(samples[index], target_chain) < 0.30
            or self._chain_endpoint_ratio(samples[index], target_chain) > 2.15
        ]
        is_bench = exercise_id.strip().lower().replace("-", "_").replace(" ", "_") in {
            "bench_press",
            "incline_bench_press",
            "decline_bench_press",
            "dumbbell_bench_press",
            "close_grip_bench_press",
            "wide_grip_bench_press",
        }
        geometry_suspects = [
            (score, index)
            for score, index in scored
            if is_bench
            and self._chain_vertical_deviation(samples[index], target_chain) > 35.0
        ]
        max_attempts = max(12, round(len(samples) * 0.35))
        geometry_budget = max(6, round(len(samples) * 0.20))
        prioritized = sorted(geometry_suspects)[:geometry_budget]
        included = {index for _, index in prioritized}
        prioritized.extend(
            item
            for item in sorted(regular_suspects)
            if item[1] not in included
        )
        suspects = prioritized[:max_attempts]
        metrics = {
            "attemptedFrames": len(suspects),
            "replacedFrames": 0,
            "geometryCandidateFrames": len(geometry_suspects),
            "originalFrames": 0,
            "clockwiseFrames": 0,
            "counterclockwiseFrames": 0,
        }
        if not suspects:
            return list(samples), metrics
        repaired = [
            PoseSample(
                sample.timestamp_ms,
                sample.source_frame_index,
                sample.points.copy(),
                sample.scores.copy(),
                sample.inferred.copy() if sample.inferred is not None else None,
            )
            for sample in samples
        ]
        capture = cv2.VideoCapture(str(source))
        if not capture.isOpened():
            return repaired, metrics
        alternatives = [
            mode
            for mode in ("original", "clockwise", "counterclockwise")
            if mode != primary_orientation
        ]
        try:
            for current_score, index in suspects:
                original = samples[index]
                capture.set(cv2.CAP_PROP_POS_FRAMES, original.source_frame_index)
                ok, frame = capture.read()
                if not ok:
                    continue
                if scale < 1.0:
                    frame = cv2.resize(
                        frame,
                        (output_width, output_height),
                        interpolation=cv2.INTER_AREA,
                    )
                best: tuple[float, str, np.ndarray, np.ndarray, tuple[int, int, int]] | None = None
                for mode in alternatives:
                    prediction = self.model.predict(
                        self._rotate_frame(frame, mode),
                        conf=self.confidence,
                        device=self.device,
                        imgsz=self.image_size,
                        verbose=False,
                    )[0]
                    for points, scores in self._matching_pose_candidates(
                        prediction,
                        mode,
                        output_width,
                        output_height,
                        original,
                    ):
                        candidate = PoseSample(
                            original.timestamp_ms,
                            original.source_frame_index,
                            points,
                            scores,
                        )
                        for side, chain in (("left", LEFT_ARM), ("right", RIGHT_ARM)):
                            score = self._single_frame_chain_score(
                                candidate,
                                chain,
                                exercise_id,
                            )
                            candidate_payload = (score, mode, points, scores, chain)
                            if best is None or candidate_payload[0] > best[0]:
                                best = candidate_payload
                if best is None or best[0] < current_score + 0.055:
                    continue
                _, mode, points, scores, source_chain = best
                sample = repaired[index]
                source_shoulder = source_chain[0]
                target_shoulder = target_chain[0]
                source_anchor = points[source_shoulder].copy()
                target_anchor = sample.points[target_shoulder].copy()
                # Keep the already tracked shoulder as the chain root.  The
                # fallback may use the other visible arm, so copying absolute
                # coordinates would create a side-switch jump.  Transfer the
                # shoulder-relative arm vectors instead.
                for source_landmark, target_landmark in zip(
                    source_chain[1:], target_chain[1:]
                ):
                    sample.points[target_landmark] = (
                        target_anchor + points[source_landmark] - source_anchor
                    )
                    sample.scores[target_landmark] = min(
                        float(sample.scores[target_shoulder]),
                        float(scores[source_landmark]),
                    )
                    if sample.inferred is not None:
                        sample.inferred[target_landmark] = False
                metrics["replacedFrames"] += 1
                metrics[f"{mode}Frames"] += 1
        finally:
            capture.release()
        return repaired, metrics

    def _matching_pose_candidates(
        self,
        prediction: Any,
        orientation: str,
        frame_width: int,
        frame_height: int,
        reference: PoseSample,
    ) -> list[tuple[np.ndarray, np.ndarray]]:
        keypoints = prediction.keypoints
        if keypoints is None or keypoints.xy is None or len(keypoints.xy) == 0:
            return []
        xy = self._restore_points(
            keypoints.xy.detach().cpu().numpy(),
            orientation,
            frame_width,
            frame_height,
        )
        confidence = (
            keypoints.conf.detach().cpu().numpy()
            if keypoints.conf is not None
            else np.ones((xy.shape[0], xy.shape[1]), dtype=np.float32)
        )
        reference_center, reference_scale = self._pose_torso(reference)
        candidates: list[tuple[np.ndarray, np.ndarray]] = []
        for points, scores in zip(xy, confidence):
            sample = PoseSample(
                reference.timestamp_ms,
                reference.source_frame_index,
                points,
                scores,
            )
            center, scale = self._pose_torso(sample)
            if reference_center is None or center is None:
                continue
            normalizer = max(20.0, reference_scale or scale or 1.0)
            if float(np.linalg.norm(center - reference_center)) / normalizer > 1.05:
                continue
            candidates.append((points.copy(), scores.copy()))
        return candidates

    def _single_frame_chain_score(
        self,
        sample: PoseSample,
        chain: tuple[int, int, int],
        exercise_id: str,
    ) -> float:
        quality = chain_quality(
            (sample,),
            chain,
            self.confidence,
            side="candidate",
            exercise_id=exercise_id,
        )
        score = quality.score
        ratio = self._chain_endpoint_ratio(sample, chain)
        if ratio < 0.30 or ratio > 2.15:
            score -= 0.16
        return score

    def _chain_endpoint_ratio(
        self,
        sample: PoseSample,
        chain: tuple[int, int, int],
    ) -> float:
        proximal, joint, endpoint = chain
        if min(sample.scores[index] for index in chain) < self.confidence:
            return 0.0
        upper = float(np.linalg.norm(sample.points[proximal] - sample.points[joint]))
        distal = float(np.linalg.norm(sample.points[endpoint] - sample.points[joint]))
        return distal / max(1.0, upper)

    def _chain_vertical_deviation(
        self,
        sample: PoseSample,
        chain: tuple[int, int, int],
    ) -> float:
        _, joint, endpoint = chain
        if min(sample.scores[joint], sample.scores[endpoint]) < self.confidence:
            return 0.0
        delta = sample.points[endpoint] - sample.points[joint]
        return math.degrees(
            math.atan2(abs(float(delta[0])), max(1e-6, abs(float(delta[1]))))
        )

    def _pose_torso(
        self,
        sample: PoseSample,
    ) -> tuple[np.ndarray | None, float | None]:
        if min(sample.scores[5], sample.scores[6], sample.scores[11], sample.scores[12]) < self.confidence:
            return None, None
        shoulder = (sample.points[5] + sample.points[6]) * 0.5
        hip = (sample.points[11] + sample.points[12]) * 0.5
        center = (shoulder + hip) * 0.5
        scale = float(np.linalg.norm(hip - shoulder))
        return center, scale if scale >= 8.0 else None

    def _sequence_is_horizontal(self, samples: Sequence[PoseSample]) -> bool:
        ratios: list[float] = []
        for sample in samples:
            if min(sample.scores[5], sample.scores[6], sample.scores[11], sample.scores[12]) < self.confidence:
                continue
            shoulder = (sample.points[5] + sample.points[6]) * 0.5
            hip = (sample.points[11] + sample.points[12]) * 0.5
            delta = hip - shoulder
            ratios.append(abs(float(delta[0])) / max(1.0, abs(float(delta[1]))))
        return bool(ratios) and float(np.median(ratios)) >= 1.25

    @staticmethod
    def _rotate_frame(frame: np.ndarray, orientation: str) -> np.ndarray:
        if orientation == "clockwise":
            return cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
        if orientation == "counterclockwise":
            return cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)
        return frame

    @staticmethod
    def _restore_points(
        points: np.ndarray,
        orientation: str,
        width: int,
        height: int,
    ) -> np.ndarray:
        if orientation == "original":
            return points
        restored = points.copy()
        if orientation == "clockwise":
            restored[..., 0] = points[..., 1]
            restored[..., 1] = height - 1 - points[..., 0]
        else:
            restored[..., 0] = width - 1 - points[..., 1]
            restored[..., 1] = points[..., 0]
        return restored

    @staticmethod
    def _restore_boxes(
        boxes: np.ndarray,
        orientation: str,
        width: int,
        height: int,
    ) -> np.ndarray:
        if orientation == "original" or not len(boxes):
            return boxes
        restored = []
        for x1, y1, x2, y2 in boxes:
            corners = np.asarray(
                ((x1, y1), (x2, y1), (x2, y2), (x1, y2)),
                dtype=np.float32,
            )
            original = PoseAnalyzer._restore_points(
                corners,
                orientation,
                width,
                height,
            )
            restored.append(
                (
                    float(np.min(original[:, 0])),
                    float(np.min(original[:, 1])),
                    float(np.max(original[:, 0])),
                    float(np.max(original[:, 1])),
                )
            )
        return np.asarray(restored, dtype=np.float32)

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
