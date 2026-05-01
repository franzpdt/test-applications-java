#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:5000}"
ITERATION=0
MEMORY_EVERY=30  # every 30 × 10s = 5 minutes

echo "==> Calling project-api at $BASE_URL (Ctrl+C to stop)"

while true; do
  ITERATION=$((ITERATION + 1))
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

  if (( ITERATION % MEMORY_EVERY == 0 )); then
    echo "[GET] /api/stress/memory (triggering OOM)"
    curl -sf "$BASE_URL/api/stress/memory" || true
    echo ""
  fi

  sleep 10
done
