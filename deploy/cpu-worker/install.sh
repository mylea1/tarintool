#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash install.sh" >&2
  exit 1
fi

install -d -m 0750 /etc/kilo
if [[ ! -f /etc/kilo/cpu-worker.env ]]; then
  install -m 0600 cpu-worker.env.example /etc/kilo/cpu-worker.env
  echo "Created /etc/kilo/cpu-worker.env. Set KILO_GPU_API_KEY before starting." >&2
fi

install -m 0644 kilo-cpu-worker.service /etc/systemd/system/kilo-cpu-worker.service
systemctl daemon-reload
systemctl enable kilo-cpu-worker.service

echo "Next: edit /etc/kilo/cpu-worker.env, then run:"
echo "  systemctl start kilo-cpu-worker"
echo "  journalctl -u kilo-cpu-worker -f"
