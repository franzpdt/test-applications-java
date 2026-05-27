#!/usr/bin/env bash
# print-metadata.sh
#
# Prints Dynatrace metadata files and environment variables as visible to
# the project-api process running in Kubernetes (microk8s or minikube).
#
# Usage:
#   ./print-metadata.sh                     # auto-detects kubectl
#   ./print-metadata.sh -n <namespace>      # target a specific namespace

set -uo pipefail

NAMESPACE="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── detect kubectl ────────────────────────────────────────────────────────────
if command -v microk8s >/dev/null 2>&1; then
  KUBECTL=(microk8s kubectl)
elif command -v kubectl >/dev/null 2>&1; then
  KUBECTL=(kubectl)
elif command -v minikube >/dev/null 2>&1; then
  KUBECTL=(minikube kubectl --)
else
  echo "ERROR: no kubectl, microk8s, or minikube found on PATH." >&2
  exit 1
fi

# ── find a running project-api pod ───────────────────────────────────────────
POD=$("${KUBECTL[@]}" get pods \
        -n "$NAMESPACE" \
        -l app=project-api \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "$POD" ]]; then
  echo "ERROR: no running project-api pod found in namespace '$NAMESPACE'." >&2
  echo "       Make sure the deployment is up: ${KUBECTL[*]} get pods -n $NAMESPACE" >&2
  exit 1
fi

EXEC=("${KUBECTL[@]}" exec "$POD" -n "$NAMESPACE" -c project-api --)

echo "kubectl : ${KUBECTL[*]}"
echo "pod     : $POD"
echo "ns      : $NAMESPACE"

# ── helpers ───────────────────────────────────────────────────────────────────
SEP="$(printf '═%.0s' {1..60})"

header() {
  echo ""
  echo "$SEP"
  printf "  %-56s\n" "$1"
  echo "$SEP"
}

print_file() {
  local label="$1"
  local path="$2"
  header "FILE: $label"
  echo "  path: $path"
  echo ""
  "${EXEC[@]}" sh -c "
    if [ -f '$path' ]; then
      cat '$path'
    else
      echo '(file not found)'
    fi
  " 2>/dev/null || echo "(exec error — container may not have sh)"
}

# dt_metadata.properties may be an indirection file: its first line is the
# path to the actual enrichment file (dt_metadata_<id>.properties).
print_dt_metadata() {
  local path="/var/lib/dynatrace/enrichment/dt_metadata.properties"
  header "FILE: dt_metadata.properties"
  echo "  path: $path"
  echo ""
  "${EXEC[@]}" sh -c "
    if [ ! -f '$path' ]; then
      echo '(file not found)'
      exit 0
    fi
    target=\$(head -1 '$path')
    if [ -f \"\$target\" ]; then
      echo \"(indirection -> \$target)\"
      echo
      cat \"\$target\"
    else
      cat '$path'
    fi
  " 2>/dev/null || echo "(exec error — container may not have sh)"
}

print_env() {
  local label="$1"
  local var="$2"
  header "ENV: $label"
  echo ""
  # DT_TAGS / DT_CUSTOM_PROP are injected only into the java process via
  # `exec env "VAR=val" java ...` in entrypoint.sh — they are NOT part of the
  # container-wide environment.  Read them from the process's own /proc environ
  # instead (java is PID 1 due to the exec chain).  Fall back to printenv for
  # variables that are set container-wide.
  "${EXEC[@]}" sh -c "
    # Try the process environ first (null-separated, so use tr to split)
    val=\$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^${var}=' | cut -d= -f2-)
    if [ -z \"\$val\" ]; then
      val=\$(printenv '${var}' 2>/dev/null || true)
    fi
    if [ -n \"\$val\" ]; then
      echo \"\$val\"
    else
      echo '(not set)'
    fi
  " 2>/dev/null || echo "(exec error — container may not have sh)"
}

# ── print everything ──────────────────────────────────────────────────────────
print_file      "dt_host_metadata.properties" "/var/lib/dynatrace/enrichment/dt_host_metadata.properties"
print_file      "dt_node_metadata.properties" "/var/lib/dynatrace/enrichment/dt_node_metadata.properties"
print_dt_metadata

print_env       "DT_TAGS"        "DT_TAGS"
print_env       "DT_CUSTOM_PROP" "DT_CUSTOM_PROP"

echo ""
