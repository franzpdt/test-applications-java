#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:5000}"

echo "==> Calling project-api at $BASE_URL (Ctrl+C to stop)"

while true; do
  echo ""
  echo "--- $(date '+%Y-%m-%dT%H:%M:%S') ---"

  echo "[GET] /api/projects"
  curl -sf "$BASE_URL/api/projects" | head -c 200 || true
  echo ""

  echo "[GET] /api/projects/1"
  curl -sf "$BASE_URL/api/projects/1" || true
  echo ""

  echo "[GET] /api/stress/cpu?duration=1"
  curl -sf "$BASE_URL/api/stress/cpu?duration=1" || true
  echo ""

  sleep 10
done
