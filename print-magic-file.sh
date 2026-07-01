#!/usr/bin/env bash
# print-magic-file.sh
#
# Calls GET /api/metadata/virtual-file on the running project-api and prints
# the content of the Dynatrace virtual enrichment file (dt_metadata.properties,
# with indirection resolved by the API).
#
# Supports three environments:
#   microk8s  – kubectl exec into the pod, curl from inside
#   minikube  – same via minikube kubectl
#   local     – standard (non-container) OneAgent installation, calls localhost
#
# Usage:
#   ./print-magic-file.sh                    # auto-detect, port 5000
#   ./print-magic-file.sh -p 8080            # custom port (local mode)
#   ./print-magic-file.sh -n <namespace>     # target k8s namespace

set -uo pipefail

NAMESPACE="default"
APP_PORT="${APP_PORT:-5000}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    -p|--port)      APP_PORT="$2";  shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── detect environment ────────────────────────────────────────────────────────
if command -v microk8s >/dev/null 2>&1; then
  MODE="microk8s"
  KUBECTL=(microk8s kubectl)
elif command -v minikube >/dev/null 2>&1; then
  MODE="minikube"
  KUBECTL=(minikube kubectl --)
elif command -v kubectl >/dev/null 2>&1; then
  MODE="kubectl"
  KUBECTL=(kubectl)
else
  MODE="local"
fi

echo "mode : $MODE"

# ── helpers ───────────────────────────────────────────────────────────────────
SEP="$(printf '═%.0s' {1..60})"

header() {
  echo ""
  echo "$SEP"
  printf "  %-56s\n" "$1"
  echo "$SEP"
}

# ── k8s path: exec curl inside the pod ───────────────────────────────────────
if [[ "$MODE" != "local" ]]; then
  POD=$("${KUBECTL[@]}" get pods \
          -n "$NAMESPACE" \
          -l app=project-api \
          --field-selector=status.phase=Running \
          -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$POD" ]]; then
    echo "ERROR: no running project-api pod found in namespace '$NAMESPACE'." >&2
    echo "       ${KUBECTL[*]} get pods -n $NAMESPACE" >&2
    exit 1
  fi

  echo "pod  : $POD"
  echo "ns   : $NAMESPACE"

  header "OneAgent virtual enrichment file"
  echo ""
  "${KUBECTL[@]}" exec "$POD" -n "$NAMESPACE" -c project-api -- \
    sh -c "curl -sf http://localhost:${APP_PORT}/api/metadata/virtual-file || echo '(curl failed — is the API running?)'"
  echo ""
  exit 0
fi

# ── local path: call the service directly ────────────────────────────────────
BASE_URL="http://localhost:${APP_PORT}"
echo "url  : ${BASE_URL}/api/metadata/virtual-file"

header "OneAgent virtual enrichment file"
echo ""

HTTP_CODE=$(curl -s -o /tmp/_dt_meta_body -w "%{http_code}" \
  "${BASE_URL}/api/metadata/virtual-file" 2>/dev/null || echo "000")

case "$HTTP_CODE" in
  200)
    cat /tmp/_dt_meta_body ;;
  404)
    echo "(file not found on this host — OneAgent may not be installed)" ;;
  000)
    echo "(connection refused — is project-api running on port ${APP_PORT}?)" ;;
  *)
    echo "(unexpected HTTP ${HTTP_CODE})"
    cat /tmp/_dt_meta_body ;;
esac

rm -f /tmp/_dt_meta_body
echo ""
