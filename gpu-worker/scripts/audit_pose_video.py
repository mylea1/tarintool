from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import sys

import cv2
import numpy as np

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
    PoseSample,
    format_video_time,
)
from kilo_worker.inference import PoseAnalyzer, SKELETON  # noqa: E402
from kilo_worker.pose_recovery import recover_occluded_endpoints  # noqa: E402
from kilo_worker.pose_validation import (  # noqa: E402
    LEFT_ARM,
    RIGHT_ARM,
    validate_pose_sequence,
)
from kilo_worker.subject_tracking import SubjectTracker  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Record pose telemetry and build AI-review contact sheets."
    )
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("exercise_id")
    parser.add_argument("camera")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--image-size", type=int, default=960)
    parser.add_argument("--target-fps", type=float, default=10.0)
    parser.add_argument("--confidence", type=float, default=0.35)
    parser.add_argument("--max-review-segments", type=int, default=16)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    capture = cv2.VideoCapture(str(args.video))
    if not capture.isOpened():
        raise ValueError("invalid_video")
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = float(capture.get(cv2.CAP_PROP_FPS) or 30.0)
    source_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    stride = max(1, round(fps / max(1.0, args.target_fps)))
    scale = min(1.0, 1280.0 / max(width, height))
    output_width = max(2, int(width * scale) // 2 * 2)
    output_height = max(2, int(height * scale) // 2 * 2)

    analyzer = PoseAnalyzer(
        str(args.model),
        args.confidence,
        device="cpu",
        image_size=args.image_size,
        target_fps=args.target_fps,
        max_dimension=1280,
        cpu_threads=4,
    )
    orientation_mode, orientation_scores = analyzer._select_orientation_mode(
        capture,
        exercise_id=args.exercise_id,
        source_frames=source_frames,
        fps=fps,
        scale=scale,
        output_width=output_width,
        output_height=output_height,
    )
    tracker = SubjectTracker(args.confidence)
    raw_samples: list[PoseSample] = []
    detections: dict[int, int] = {}
    frame_index = -1
    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            frame_index += 1
            if frame_index % stride:
                continue
            if scale < 1.0:
                frame = cv2.resize(
                    frame,
                    (output_width, output_height),
                    interpolation=cv2.INTER_AREA,
                )
            prediction = analyzer.model.predict(
                analyzer._rotate_frame(frame, orientation_mode),
                conf=args.confidence,
                imgsz=args.image_size,
                device="cpu",
                verbose=False,
            )[0]
            people = (
                len(prediction.keypoints.xy)
                if prediction.keypoints is not None
                and prediction.keypoints.xy is not None
                else 0
            )
            detections[frame_index] = people
            points, scores = analyzer._best_pose_oriented(
                prediction,
                tracker,
                output_width,
                output_height,
                orientation_mode,
            )
            if points is None or scores is None:
                continue
            raw_samples.append(
                PoseSample(
                    timestamp_ms=round(frame_index * 1000.0 / fps),
                    source_frame_index=frame_index,
                    points=points.copy(),
                    scores=scores.copy(),
                )
            )
    finally:
        capture.release()

    validated, validation_metrics = validate_pose_sequence(
        raw_samples,
        confidence_floor=args.confidence,
        exercise_id=args.exercise_id,
        camera=args.camera,
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
        validation_metrics.selected_arm_side is not None
        and analyzer._sequence_is_horizontal(raw_samples)
    ):
        repaired, fallback_metrics = analyzer._repair_side_chain_with_orientation_fallback(
            args.video,
            raw_samples,
            validation_metrics.selected_arm_side,
            args.exercise_id,
            orientation_mode,
            scale,
            output_width,
            output_height,
        )
        if fallback_metrics["replacedFrames"]:
            raw_samples = repaired
            validated, validation_metrics = validate_pose_sequence(
                repaired,
                confidence_floor=args.confidence,
                exercise_id=args.exercise_id,
                camera=args.camera,
                frame_width=output_width,
                frame_height=output_height,
            )
    recovered, recovery_metrics = recover_occluded_endpoints(
        validated,
        confidence_floor=args.confidence,
        frame_width=output_width,
        frame_height=output_height,
        exercise_id=args.exercise_id,
    )

    raw_by_frame = {sample.source_frame_index: sample for sample in raw_samples}
    final_by_frame = {sample.source_frame_index: sample for sample in recovered}
    selected_side = validation_metrics.selected_arm_side
    if selected_side is None and validation_metrics.arm_qualities:
        selected_side = max(
            validation_metrics.arm_qualities, key=lambda quality: quality.score
        ).side
    selected_chain = LEFT_ARM if selected_side == "left" else RIGHT_ARM
    records = _build_records(
        raw_samples,
        recovered,
        detections,
        selected_chain,
        args.confidence,
        fps,
    )
    trace_path = args.output / "frame-trace.jsonl"
    trace_path.write_text(
        "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records),
        encoding="utf-8",
    )

    suspicious = _group_suspicious_records(records)
    suspicious = suspicious[: max(1, args.max_review_segments)]
    review_items = _build_review_items(records, suspicious, source_frames, stride)
    capture = cv2.VideoCapture(str(args.video))
    if not capture.isOpened():
        raise ValueError("invalid_video")
    try:
        for number, item in enumerate(review_items, start=1):
            destination = args.output / f"review-{number:03d}.jpg"
            _write_review_board(
                capture,
                destination,
                item["frameIndexes"],
                raw_by_frame,
                final_by_frame,
                output_width,
                output_height,
                scale,
                args.confidence,
                fps,
            )
            item["image"] = destination.name
    finally:
        capture.release()

    manifest = {
        "video": str(args.video.resolve()),
        "exerciseId": args.exercise_id,
        "camera": args.camera,
        "model": str(args.model),
        "imageSize": args.image_size,
        "targetFps": args.target_fps,
        "inferenceOrientation": orientation_mode,
        "orientationPreflightScores": orientation_scores,
        "orientationFallback": fallback_metrics,
        "source": {
            "width": width,
            "height": height,
            "fps": round(fps, 3),
            "frames": source_frames,
        },
        "validation": {
            "invalidCoordinates": validation_metrics.invalid_coordinates,
            "temporalJointSpikes": validation_metrics.temporal_joint_spikes,
            "boneLengthOutliers": validation_metrics.bone_length_outliers,
            "bilateralOcclusionRejects": validation_metrics.bilateral_occlusion_rejects,
            "selectedArmSide": validation_metrics.selected_arm_side,
            "suppressedArmSamples": validation_metrics.suppressed_arm_samples,
            "armChainQuality": [
                quality.to_result() for quality in validation_metrics.arm_qualities
            ],
        },
        "recovery": {
            "inferredWrists": recovery_metrics.inferred_samples,
            "rejectedWrists": recovery_metrics.rejected_observations,
            "inferredAnkles": recovery_metrics.inferred_ankle_samples,
            "rejectedAnkles": recovery_metrics.rejected_ankle_observations,
        },
        "suspiciousSegments": suspicious,
        "reviewItems": review_items,
        "aiReviewContract": {
            "outputFile": "ai-review.json",
            "fields": [
                "reviewItem",
                "personFound",
                "subjectStable",
                "jointsOnBody",
                "selectedChainCorrect",
                "issues",
                "recommendedRule",
            ],
        },
    }
    manifest_path = args.output / "review-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    _write_html(args.output / "index.html", manifest)
    print(manifest_path)
    print(args.output / "index.html")


def _build_records(
    raw_samples: list[PoseSample],
    final_samples: list[PoseSample],
    detections: dict[int, int],
    selected_chain: tuple[int, int, int],
    floor: float,
    fps: float,
) -> list[dict[str, object]]:
    raw_by_frame = {sample.source_frame_index: sample for sample in raw_samples}
    final_by_frame = {sample.source_frame_index: sample for sample in final_samples}
    records: list[dict[str, object]] = []
    previous_final: PoseSample | None = None
    for frame_index in sorted(detections):
        raw = raw_by_frame.get(frame_index)
        final = final_by_frame.get(frame_index)
        if raw is None or final is None:
            timestamp_ms = round(frame_index * 1000.0 / fps)
            records.append(
                {
                    "frameIndex": frame_index,
                    "timestampMs": timestamp_ms,
                    "displayTime": format_video_time(timestamp_ms),
                    "peopleDetected": detections.get(frame_index, 0),
                    "alerts": ["target_missing"],
                    "rejectedLandmarks": [],
                    "inferredLandmarks": [],
                    "selectedChain": list(selected_chain),
                    "raw": None,
                    "final": None,
                }
            )
            previous_final = None
            continue
        alerts: list[str] = []
        rejected = [
            index
            for index in range(len(raw.scores))
            if raw.scores[index] >= floor and final.scores[index] < floor
        ]
        if any(index in selected_chain for index in rejected):
            alerts.append("selected_chain_joint_rejected")
        if min(final.scores[index] for index in selected_chain[:2]) < floor:
            alerts.append("selected_proximal_chain_missing")
        raw_collapsed = _chain_collapsed(raw, selected_chain, floor)
        final_collapsed = _chain_collapsed(final, selected_chain, floor)
        if final_collapsed:
            alerts.append("selected_chain_collapsed")
        jump = _selected_chain_jump(previous_final, final, selected_chain, floor)
        if jump is not None and jump > 0.62:
            alerts.append("selected_chain_temporal_jump")
        inferred = [
            index
            for index in selected_chain
            if final.inferred is not None and bool(final.inferred[index])
        ]
        record = {
            "frameIndex": raw.source_frame_index,
            "timestampMs": raw.timestamp_ms,
            "displayTime": format_video_time(raw.timestamp_ms),
            "peopleDetected": detections.get(raw.source_frame_index, 0),
            "alerts": alerts,
            "rejectedLandmarks": rejected,
            "inferredLandmarks": inferred,
            "rawChainCollapsed": raw_collapsed,
            "finalChainCollapsed": final_collapsed,
            "selectedChain": list(selected_chain),
            "raw": _sample_payload(raw, selected_chain),
            "final": _sample_payload(final, selected_chain),
        }
        records.append(record)
        previous_final = final
    return records


def _sample_payload(
    sample: PoseSample,
    chain: tuple[int, int, int],
) -> dict[str, object]:
    shoulder, elbow, wrist = chain
    upper = float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow]))
    forearm = float(np.linalg.norm(sample.points[elbow] - sample.points[wrist]))
    return {
        "chainScores": [round(float(sample.scores[index]), 4) for index in chain],
        "upperArmPx": round(upper, 2),
        "forearmPx": round(forearm, 2),
        "forearmUpperRatio": round(forearm / max(upper, 1.0), 4),
        "points": {
            str(index): [
                round(float(sample.points[index][0]), 2),
                round(float(sample.points[index][1]), 2),
            ]
            for index in chain
        },
    }


def _chain_collapsed(
    sample: PoseSample,
    chain: tuple[int, int, int],
    floor: float,
) -> bool:
    if min(sample.scores[index] for index in chain) < floor:
        return False
    shoulder, elbow, wrist = chain
    if sample.inferred is not None and bool(sample.inferred[wrist]):
        return False
    upper = float(np.linalg.norm(sample.points[shoulder] - sample.points[elbow]))
    forearm = float(np.linalg.norm(sample.points[elbow] - sample.points[wrist]))
    if upper < 4.0:
        return True
    ratio = forearm / upper
    return ratio < 0.32 or ratio > 1.90


def _selected_chain_jump(
    previous: PoseSample | None,
    current: PoseSample,
    chain: tuple[int, int, int],
    floor: float,
) -> float | None:
    if previous is None:
        return None
    if min(
        *(previous.scores[index] for index in chain),
        *(current.scores[index] for index in chain),
    ) < floor:
        return None
    torso = _torso_scale(current, floor)
    if torso is None:
        return None
    distances = [
        float(np.linalg.norm(current.points[index] - previous.points[index])) / torso
        for index in chain
    ]
    return max(distances)


def _torso_scale(sample: PoseSample, floor: float) -> float | None:
    shoulders = [
        sample.points[index]
        for index in (LEFT_SHOULDER, RIGHT_SHOULDER)
        if sample.scores[index] >= floor
    ]
    hips = [
        sample.points[index]
        for index in (LEFT_HIP, RIGHT_HIP)
        if sample.scores[index] >= floor
    ]
    if not shoulders or not hips:
        return None
    value = float(np.linalg.norm(np.mean(shoulders, axis=0) - np.mean(hips, axis=0)))
    return value if value >= 8.0 else None


def _group_suspicious_records(
    records: list[dict[str, object]],
) -> list[dict[str, object]]:
    flagged = [record for record in records if record["alerts"]]
    groups: list[list[dict[str, object]]] = []
    for record in flagged:
        if (
            not groups
            or int(record["timestampMs"]) - int(groups[-1][-1]["timestampMs"]) > 550
        ):
            groups.append([record])
        else:
            groups[-1].append(record)
    result = []
    for number, group in enumerate(groups, start=1):
        reasons = sorted(
            {
                str(reason)
                for record in group
                for reason in record["alerts"]  # type: ignore[union-attr]
            }
        )
        result.append(
            {
                "id": f"suspect-{number:03d}",
                "startMs": group[0]["timestampMs"],
                "endMs": group[-1]["timestampMs"],
                "frameIndexes": [record["frameIndex"] for record in group],
                "reasons": reasons,
            }
        )
    return result


def _build_review_items(
    records: list[dict[str, object]],
    segments: list[dict[str, object]],
    source_frames: int,
    stride: int,
) -> list[dict[str, object]]:
    items: list[dict[str, object]] = []
    for segment in segments:
        frames = [int(value) for value in segment["frameIndexes"]]  # type: ignore[arg-type]
        selected = sorted({frames[0], frames[len(frames) // 2], frames[-1]})
        items.append(
            {
                "kind": "suspicious_segment",
                "segmentId": segment["id"],
                "frameIndexes": selected,
                "reasons": segment["reasons"],
            }
        )
    available = [int(record["frameIndex"]) for record in records]
    if available:
        positions = np.linspace(0, len(available) - 1, min(9, len(available))).astype(int)
        sample_frames = [available[index] for index in positions]
        for start in range(0, len(sample_frames), 3):
            items.append(
                {
                    "kind": "coverage_sample",
                    "segmentId": f"coverage-{start // 3 + 1:03d}",
                    "frameIndexes": sample_frames[start : start + 3],
                    "reasons": ["stratified_random_guard"],
                }
            )
    return items


def _write_review_board(
    capture: cv2.VideoCapture,
    destination: Path,
    frame_indexes: list[int],
    raw_by_frame: dict[int, PoseSample],
    final_by_frame: dict[int, PoseSample],
    width: int,
    height: int,
    scale: float,
    floor: float,
    fps: float,
) -> None:
    rows = []
    for frame_index in frame_indexes:
        capture.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        ok, frame = capture.read()
        if not ok:
            continue
        if scale < 1.0:
            frame = cv2.resize(frame, (width, height), interpolation=cv2.INTER_AREA)
        raw_panel = frame.copy()
        final_panel = frame.copy()
        raw = raw_by_frame.get(frame_index)
        final = final_by_frame.get(frame_index)
        if raw is not None:
            _draw_pose(raw_panel, raw, floor, (35, 65, 235), (35, 65, 235))
        if final is not None:
            _draw_pose(final_panel, final, floor, (255, 142, 46), (70, 225, 255))
        timestamp = (
            raw.timestamp_ms
            if raw is not None
            else final.timestamp_ms
            if final is not None
            else round(frame_index * 1000.0 / fps)
        )
        time_label = format_video_time(timestamp)
        original = _with_label(frame.copy(), f"ORIGINAL | {time_label}")
        raw_panel = _with_label(raw_panel, f"RAW MODEL | {time_label}")
        final_panel = _with_label(
            final_panel, f"VALIDATED / RECOVERED | {time_label}"
        )
        rows.append(np.hstack((_resize_panel(original), _resize_panel(raw_panel), _resize_panel(final_panel))))
    if rows:
        cv2.imwrite(str(destination), np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 90])


def _draw_pose(
    frame: np.ndarray,
    sample: PoseSample,
    floor: float,
    observed_color: tuple[int, int, int],
    inferred_color: tuple[int, int, int],
) -> None:
    for start, end in SKELETON:
        if min(sample.scores[start], sample.scores[end]) < floor:
            continue
        inferred = sample.inferred is not None and (
            bool(sample.inferred[start]) or bool(sample.inferred[end])
        )
        cv2.line(
            frame,
            tuple(sample.points[start].astype(int)),
            tuple(sample.points[end].astype(int)),
            inferred_color if inferred else observed_color,
            4,
            cv2.LINE_AA,
        )
    for index, point in enumerate(sample.points):
        if sample.scores[index] < floor:
            continue
        inferred = sample.inferred is not None and bool(sample.inferred[index])
        cv2.circle(
            frame,
            tuple(point.astype(int)),
            5,
            inferred_color if inferred else observed_color,
            -1,
            cv2.LINE_AA,
        )


def _with_label(frame: np.ndarray, label: str) -> np.ndarray:
    cv2.rectangle(frame, (0, 0), (frame.shape[1], 44), (18, 20, 23), -1)
    cv2.putText(
        frame,
        label,
        (14, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (245, 245, 245),
        2,
        cv2.LINE_AA,
    )
    return frame


def _resize_panel(frame: np.ndarray, target_width: int = 520) -> np.ndarray:
    scale = target_width / frame.shape[1]
    return cv2.resize(
        frame,
        (target_width, max(1, round(frame.shape[0] * scale))),
        interpolation=cv2.INTER_AREA,
    )


def _write_html(destination: Path, manifest: dict[str, object]) -> None:
    items = manifest["reviewItems"]  # type: ignore[index]
    cards = []
    for number, item in enumerate(items, start=1):  # type: ignore[arg-type]
        cards.append(
            "<section><h2>#{number} {kind} · {segment}</h2>"
            "<p>{reasons}</p><img loading='lazy' src='{image}'></section>".format(
                number=number,
                kind=html.escape(str(item["kind"])),
                segment=html.escape(str(item["segmentId"])),
                reasons=html.escape(", ".join(str(value) for value in item["reasons"])),
                image=html.escape(str(item.get("image", ""))),
            )
        )
    validation = json.dumps(manifest["validation"], ensure_ascii=False, indent=2)
    destination.write_text(
        "<!doctype html><meta charset='utf-8'><title>Pose AI audit</title>"
        "<style>body{font:16px system-ui;margin:24px;background:#f6f4ef;color:#171717}"
        "main{max-width:1600px;margin:auto}section{background:white;padding:18px;margin:18px 0;"
        "border-radius:14px}img{max-width:100%;height:auto}pre{white-space:pre-wrap}</style>"
        f"<main><h1>Pose AI audit</h1><pre>{html.escape(validation)}</pre>"
        + "".join(cards)
        + "</main>",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
