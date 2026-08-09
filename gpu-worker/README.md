# KILO GPU Worker

The worker claims queued recognition jobs from the KILO backend, performs real
YOLO pose inference, creates a skeleton-overlay video and preview, then submits
the structured result. It is intentionally stateless: original media and
artifacts remain owned by the backend/object-storage layer.

## Required environment

- `KILO_API_BASE`: public HTTPS base URL of the KILO backend.
- `KILO_GPU_API_KEY`: the same 32+ byte secret configured on the backend.

Optional tuning variables are `KILO_POLL_SECONDS`, `KILO_POSE_CONFIDENCE`,
`KILO_HTTP_TIMEOUT_SECONDS`, and `KILO_RUN_ONCE`.

Never bake the API key into an image. Add it through the GPU provider's secret
or environment-variable settings.

## Local protocol check

```powershell
python -m unittest discover -s tests -v
```

## Container

```bash
docker build -t ghcr.io/mylea1/tarintool-gpu-worker:latest .
docker run --rm --gpus all \
  -e KILO_API_BASE=https://api.kilostrength.cn \
  -e KILO_GPU_API_KEY=replace-with-a-secret \
  ghcr.io/mylea1/tarintool-gpu-worker:latest
```
