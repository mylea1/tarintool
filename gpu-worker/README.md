# KILO BetterCoach Compute Worker

The worker claims queued recognition jobs from the KILO backend, performs real
YOLO pose inference, creates timestamped skeleton evidence images and a preview,
then submits the structured result. A full skeleton-overlay video is optional and
disabled by default because it adds frame rendering and video encoding to the
critical path. It supports the current 4-core CPU node and a future GPU
node. It is intentionally stateless: original media and artifacts remain owned
by the backend/object-storage layer.

## Required environment

- `KILO_API_BASE`: public HTTPS base URL of the KILO backend.
- `KILO_GPU_API_KEY`: the same 32+ byte secret configured on the backend.

Optional tuning variables include `KILO_INFERENCE_DEVICE`, `KILO_CPU_THREADS`,
`KILO_INFERENCE_IMAGE_SIZE`, `KILO_INFERENCE_FPS`, `KILO_MAX_VIDEO_SECONDS`,
`KILO_MAX_VIDEO_DIMENSION`, `KILO_HEARTBEAT_SECONDS`, `KILO_POLL_SECONDS`,
`KILO_POSE_CONFIDENCE`, `KILO_HTTP_TIMEOUT_SECONDS`, and `KILO_RUN_ONCE`.

Never bake the API key into an image. Add it through the GPU provider's secret
or environment-variable settings.

## Local protocol check

```powershell
python -m unittest discover -s tests -v
```

## Container

For the current 4-core/8-GB CPU server:

```bash
docker build -f Dockerfile.cpu -t tarintool-cpu-worker .
docker run --rm --cpus=4 --memory=7g \
  -e KILO_API_BASE=https://api.kilostrength.cn \
  -e KILO_GPU_API_KEY=replace-with-a-secret \
  tarintool-cpu-worker
```

For a future CUDA worker:

```bash
docker build -t ghcr.io/mylea1/tarintool-gpu-worker:latest .
docker run --rm --gpus all \
  -e KILO_API_BASE=https://api.kilostrength.cn \
  -e KILO_GPU_API_KEY=replace-with-a-secret \
  ghcr.io/mylea1/tarintool-gpu-worker:latest
```
