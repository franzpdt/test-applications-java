#!/usr/bin/env bash
# print-host-metadata.sh
#
# Prints Dynatrace host-level metadata files:
#   hostautotag.conf
#   dt_host_metadata.properties
#   dt_node_metadata.properties
#
# Supports three environments:
#   microk8s  – single-node k8s, files read directly from the local filesystem
#   minikube  – files read via `minikube ssh`
#   local     – standard (non-container) OneAgent installation, files read
#               directly from the local filesystem
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
  MODE="local"
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

# Run a command on the node (directly for microk8s/local, via ssh for minikube).
node_cmd() {
  if [[ "$MODE" == "minikube" ]]; then
    minikube ssh -- "$1"
  else
    bash -c "$1"
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
