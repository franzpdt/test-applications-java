#!/usr/bin/env bash
# print-service-env.sh
#
# Prints the DT_TAGS and DT_CUSTOM_PROP environment variables as seen by the
# project-api process running as a systemd service.
#
# Reads directly from /proc/<pid>/environ so it reflects exactly what the JVM
# process received — not just what is written in the unit file.
#
# Must be run as root (or with sudo) to read another process's /proc environ.
#
# Usage:
#   sudo ./print-service-env.sh

set -uo pipefail

SERVICE="project-api"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: this script must be run as root (use sudo)." >&2
  exit 1
fi

# ── locate the service PID ────────────────────────────────────────────────────
if ! systemctl is-active --quiet "${SERVICE}.service" 2>/dev/null; then
  echo "ERROR: ${SERVICE}.service is not running." >&2
  exit 1
fi

PID=$(systemctl show "${SERVICE}.service" --property=MainPID --value)
if [[ -z "$PID" || "$PID" == "0" ]]; then
  echo "ERROR: could not determine MainPID for ${SERVICE}.service." >&2
  exit 1
fi

echo "service : ${SERVICE}.service"
echo "pid     : ${PID}"

# ── helpers ───────────────────────────────────────────────────────────────────
SEP="$(printf '═%.0s' {1..60})"

header() {
  echo ""
  echo "$SEP"
  printf "  %-56s\n" "$1"
  echo "$SEP"
}

print_env() {
  local var="$1"
  header "ENV: $var"
  echo ""
  local proc_env
  proc_env=$(tr '\0' '\n' < "/proc/${PID}/environ" 2>/dev/null || true)
  if echo "$proc_env" | grep -q "^${var}="; then
    local val
    val=$(echo "$proc_env" | grep "^${var}=" | cut -d= -f2-)
    if [[ -n "$val" ]]; then
      echo "$val"
    else
      echo "(set — empty)"
    fi
  else
    echo "(not set)"
  fi
}

# ── print vars ────────────────────────────────────────────────────────────────
print_env "DT_TAGS"
print_env "DT_CUSTOM_PROP"

echo ""
