#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:5000}"
STRESS_DURATION=40           # seconds each stress type runs
CYCLE_SECONDS=$((7 * 60))    # 420s total cycle
GAP_SECONDS=60               # 1 min gap between stress calls
CALL_TIMEOUT=15              # max seconds for fast-return calls
CPU_TIMEOUT=$((STRESS_DURATION + 30))  # blocking cpu stress needs extra headroom

echo "==> Calling project-api at $BASE_URL"
echo "    Cycle: ${CYCLE_SECONDS}s | Stress duration: ${STRESS_DURATION}s | Gap between stress calls: ${GAP_SECONDS}s"
echo "    Ctrl+C to stop"

while true; do
  CYCLE_START=$(date +%s)
  echo ""
  echo "--- $(date '+%Y-%m-%dT%H:%M:%S') ---"

  echo "[GET] /api/projects"
  curl -sf --max-time $CALL_TIMEOUT "$BASE_URL/api/projects" | head -c 200 || true
  echo ""

  echo "[GET] /api/projects/1"
  curl -sf --max-time $CALL_TIMEOUT "$BASE_URL/api/projects/1" || true
  echo ""

  # --- stress/memory (returns immediately; stress runs for STRESS_DURATION seconds in background) ---
  echo "[GET] /api/stress/memory?duration=${STRESS_DURATION}"
  curl -sf --max-time $CALL_TIMEOUT "$BASE_URL/api/stress/memory?duration=${STRESS_DURATION}" || true
  echo ""

  sleep $GAP_SECONDS

  # --- stress/threads (returns immediately; exhausts HTTP thread pool for STRESS_DURATION seconds) ---
  echo "[GET] /api/stress/threads?duration=${STRESS_DURATION}"
  curl -sf --max-time $CALL_TIMEOUT "$BASE_URL/api/stress/threads?duration=${STRESS_DURATION}" || true
  echo ""

  sleep $GAP_SECONDS

  # --- stress/cpu (blocks for STRESS_DURATION seconds before returning) ---
  echo "[GET] /api/stress/cpu?duration=${STRESS_DURATION}"
  curl -sf --max-time $CPU_TIMEOUT "$BASE_URL/api/stress/cpu?duration=${STRESS_DURATION}" || true
  echo ""

  # Sleep for the remainder of the 7-minute cycle
  ELAPSED=$(( $(date +%s) - CYCLE_START ))
  REMAINING=$(( CYCLE_SECONDS - ELAPSED ))
  if (( REMAINING > 0 )); then
    echo "--- next cycle in ${REMAINING}s ---"
    sleep $REMAINING
  fi
done
