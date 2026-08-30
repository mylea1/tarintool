from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from kilo_worker.inference import PoseAnalyzer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("exercise_id")
    parser.add_argument("camera")
    parser.add_argument("--model", default="/opt/kilo/models/yolo11n-pose.pt")
    parser.add_argument("--image-size", type=int, default=512)
    parser.add_argument("--target-fps", type=float, default=10.0)
    parser.add_argument("--include-overlay", action="store_true")
    args = parser.parse_args()

    analyzer = PoseAnalyzer(
        args.model,
        device="cpu",
        image_size=args.image_size,
        target_fps=args.target_fps,
        max_duration_seconds=45.0,
        max_dimension=1280,
        cpu_threads=4,
    )
    output = analyzer.analyze(
        args.video,
        args.output,
        args.exercise_id,
        args.camera,
        include_overlay=args.include_overlay,
    )
    target = args.output / "result.json"
    target.write_text(
        json.dumps(output.result, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(target)
    if output.overlay_path is not None:
        print(output.overlay_path)
    print(json.dumps(output.result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
