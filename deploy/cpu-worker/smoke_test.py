"""Minimal container smoke test for the CPU pose worker image."""

import time

import cv2
import numpy as np
import torch
import ultralytics
from ultralytics import YOLO


print(f"torch={torch.__version__} cuda={torch.cuda.is_available()}")
print(f"opencv={cv2.__version__} ultralytics={ultralytics.__version__}")

model = YOLO("/opt/kilo/models/yolo11n-pose.pt")
frame = np.zeros((512, 512, 3), dtype=np.uint8)
started_at = time.perf_counter()
results = model.predict(
    frame,
    device="cpu",
    imgsz=512,
    verbose=False,
)
elapsed = time.perf_counter() - started_at

assert len(results) == 1
print(f"pose_inference=ok elapsed_seconds={elapsed:.3f}")
