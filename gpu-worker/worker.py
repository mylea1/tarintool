from __future__ import annotations

import logging
import os
import signal
import tempfile
import time
from pathlib import Path

from kilo_worker.api import KiloApi
from kilo_worker.inference import PoseAnalyzer


logging.basicConfig(
    level=os.getenv("KILO_LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(message)s",
)
LOGGER = logging.getLogger("kilo-gpu-worker")
STOP = False


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"missing_environment:{name}")
    return value


def stop_worker(_signum: int, _frame: object) -> None:
    global STOP
    STOP = True


def safe_error_code(error: Exception) -> str:
    message = str(error).lower()
    if "invalid_video" in message or "empty_video" in message:
        return "invalid_video"
    if "cuda" in message or "out of memory" in message:
        return "gpu_resource_error"
    return "gpu_processing_failed"


def main() -> None:
    api = KiloApi(
        required_env("KILO_API_BASE"),
        required_env("KILO_GPU_API_KEY"),
        int(os.getenv("KILO_HTTP_TIMEOUT_SECONDS", "120")),
    )
    model_path = os.getenv("KILO_MODEL_PATH", "/opt/kilo/models/yolo11n-pose.pt")
    analyzer = PoseAnalyzer(model_path, float(os.getenv("KILO_POSE_CONFIDENCE", "0.35")))
    poll_seconds = max(1.0, float(os.getenv("KILO_POLL_SECONDS", "5")))
    once = os.getenv("KILO_RUN_ONCE", "false").lower() == "true"
    LOGGER.info("worker_ready model=%s", model_path)

    while not STOP:
        job = None
        try:
            job = api.claim()
            if job is None:
                if once:
                    return
                time.sleep(poll_seconds)
                continue
            job_id = str(job["id"])
            LOGGER.info("job_claimed id=%s exercise=%s", job_id, job.get("exerciseId"))
            with tempfile.TemporaryDirectory(prefix=f"kilo-{job_id}-") as directory:
                workdir = Path(directory)
                input_path = workdir / "input.mp4"
                api.download_input(job_id, input_path)
                output = analyzer.analyze(input_path, workdir, str(job.get("exerciseId", "")))
                api.upload_artifact(job_id, "preview", output.preview_path, "image/jpeg")
                api.upload_artifact(job_id, "overlay", output.overlay_path, "video/mp4")
                api.complete(job_id, output.result, "kilo-yolo11n-pose-v1")
            LOGGER.info("job_completed id=%s", job_id)
            if once:
                return
        except KeyboardInterrupt:
            return
        except Exception as error:  # Worker must report and continue with the next job.
            LOGGER.exception("job_failed id=%s", job.get("id") if job else "unclaimed")
            if job and job.get("id"):
                try:
                    api.fail(str(job["id"]), safe_error_code(error))
                except Exception:
                    LOGGER.exception("job_failure_report_failed id=%s", job["id"])
            if once:
                raise
            time.sleep(poll_seconds)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop_worker)
    signal.signal(signal.SIGINT, stop_worker)
    main()

