#!/usr/bin/env bash
# print-host-metadata.sh
#
# Prints Dynatrace host-level metadata files directly from the Kubernetes node:
#   hostautotag.conf
#   dt_host_metadata.properties
#   dt_node_metadata.properties
#
# For microk8s (single-node, same machine) the files are read directly from
# the local filesystem.  For minikube the files are read via `minikube ssh`.
#
# Usage:
#   ./print-host-metadata.sh

set -uo pipefail

# ── detect environment ────────────────────────────────────────────────────────
if command -v microk8s >/dev/null 2>&1; then
  MODE="microk8s"
elif command -v minikube >/dev/null 2>&1; then
  MODE="minikube"
else
  echo "ERROR: neither microk8s nor minikube found on PATH." >&2
  exit 1
fi

echo "mode : $MODE"
echo ""

# ── helpers ───────────────────────────────────────────────────────────────────
SEP="$(printf '═%.0s' {1..60})"

header() {
  echo ""
  echo "$SEP"
  printf "  %-56s\n" "$1"
  echo "$SEP"
}

# Run a command on the node (directly for microk8s, via ssh for minikube).
node_cmd() {
  if [[ "$MODE" == "microk8s" ]]; then
    bash -c "$1"
  else
    minikube ssh -- "$1"
  fi
}

print_file() {
  local label="$1"
  local path="$2"
  header "FILE: $label"
  echo "  path: $path"
  echo ""
  node_cmd "
    if [ -f '$path' ]; then
      cat '$path'
    else
      echo '(file not found)'
    fi
  "
}

# ── print files ───────────────────────────────────────────────────────────────
print_file "hostautotag.conf"            "/var/lib/dynatrace/oneagent/agent/config/hostautotag.conf"
print_file "dt_host_metadata.properties" "/var/lib/dynatrace/enrichment/dt_host_metadata.properties"
print_file "dt_node_metadata.properties" "/var/lib/dynatrace/enrichment/dt_node_metadata.properties"

echo ""
