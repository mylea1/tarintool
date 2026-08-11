"""Run the production analyzer against a mounted video and print timings."""

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, "/opt/kilo/worker")

from kilo_worker.inference import PoseAnalyzer


output_dir = Path("/tmp/kilo-benchmark-output")
output_dir.mkdir(parents=True, exist_ok=True)
analyzer = PoseAnalyzer(
    "/opt/kilo/models/yolo11n-pose.pt",
    device="cpu",
    image_size=512,
    target_fps=10,
    max_duration_seconds=120,
    max_dimension=960,
    cpu_threads=4,
)

started_at = time.perf_counter()
output = analyzer.analyze(
    Path("/input/video.mp4"),
    output_dir,
    "benchmark",
)
elapsed = time.perf_counter() - started_at

print(json.dumps(output.result, ensure_ascii=False))
print(f"processing_seconds={elapsed:.3f}")
print(f"overlay_bytes={output.overlay_path.stat().st_size}")
print(f"preview_bytes={output.preview_path.stat().st_size}")
