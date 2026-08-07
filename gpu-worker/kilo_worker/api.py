from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import requests


class KiloApi:
    def __init__(self, base_url: str, api_key: str, timeout_seconds: int = 120) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.session = requests.Session()
        self.session.headers.update({"x-kilo-gpu-key": api_key})

    def claim(self) -> dict[str, Any] | None:
        response = self.session.post(
            f"{self.base_url}/v1/internal/gpu/jobs/claim",
            json={},
            timeout=self.timeout_seconds,
        )
        if response.status_code == 204:
            return None
        response.raise_for_status()
        return response.json()["job"]

    def download_input(self, job_id: str, destination: Path) -> None:
        with self.session.get(
            f"{self.base_url}/v1/internal/gpu/jobs/{job_id}/input",
            stream=True,
            timeout=(15, self.timeout_seconds),
        ) as response:
            response.raise_for_status()
            with destination.open("wb") as target:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        target.write(chunk)

    def upload_artifact(self, job_id: str, kind: str, path: Path, content_type: str) -> None:
        size = path.stat().st_size
        with path.open("rb") as source:
            response = self.session.put(
                f"{self.base_url}/v1/internal/gpu/jobs/{job_id}/artifact",
                data=source,
                headers={
                    "x-artifact-kind": kind,
                    "content-type": content_type,
                    "content-length": str(size),
                },
                timeout=(15, max(self.timeout_seconds, 600)),
            )
        response.raise_for_status()

    def complete(self, job_id: str, result: dict[str, Any], model_version: str) -> None:
        response = self.session.post(
            f"{self.base_url}/v1/internal/gpu/jobs/{job_id}/result",
            json={"result": result, "modelVersion": model_version},
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()

    def fail(self, job_id: str, error_code: str) -> None:
        response = self.session.post(
            f"{self.base_url}/v1/internal/gpu/jobs/{job_id}/fail",
            data=json.dumps({"errorCode": error_code}),
            headers={"content-type": "application/json"},
            timeout=self.timeout_seconds,
        )
        if response.status_code != 409:
            response.raise_for_status()

