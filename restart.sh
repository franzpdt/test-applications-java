#!/usr/bin/env bash
# restart.sh
#
# Detects how project-api is running and restarts it:
#   k8s      → kubectl rollout restart deployment/project-api (microk8s or minikube)
#   service  → systemctl restart project-api
#   docker   → docker restart project-api
#   podman   → podman restart project-api
#   process  → kills the java process and relaunches via start.sh
#
# Usage:
#   ./restart.sh                    # auto-detect
#   ./restart.sh -n <namespace>     # k8s: target a specific namespace

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="project-api"
WAR_SERVICE_NAME="project-api-war"
NAMESPACE="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── detection ─────────────────────────────────────────────────────────────────
MODE=""
KUBECTL=()

# 1. Kubernetes — check for a live deployment before committing to this mode
if [[ -z "$MODE" ]]; then
  if command -v microk8s >/dev/null 2>&1; then
    _kc=(microk8s kubectl)
  elif command -v kubectl >/dev/null 2>&1; then
    _kc=(kubectl)
  elif command -v minikube >/dev/null 2>&1; then
    _kc=(minikube kubectl --)
  else
    _kc=()
  fi
  if [[ ${#_kc[@]} -gt 0 ]] && \
     "${_kc[@]}" get deployment "$APP_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    MODE="k8s"
    KUBECTL=("${_kc[@]}")
  fi
fi

# 2. systemd service — JAR-based (project-api.service)
if [[ -z "$MODE" ]]; then
  if systemctl list-units --full --all 2>/dev/null | grep -q "${APP_NAME}.service"; then
    MODE="service"
  fi
fi

# 2b. systemd service — WAR-based (project-api-war.service deployed by deploy-webserver.sh)
if [[ -z "$MODE" ]]; then
  if systemctl list-units --full --all 2>/dev/null | grep -q "${WAR_SERVICE_NAME}.service"; then
    MODE="war-service"
  fi
fi

# 3. Docker container — JAR-based (project-api)
if [[ -z "$MODE" ]]; then
  if command -v docker >/dev/null 2>&1 && \
     docker ps -a --filter "name=^/${APP_NAME}$" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    MODE="docker"
  fi
fi

# 3b. Docker container — WAR-based (project-api-war)
if [[ -z "$MODE" ]]; then
  if command -v docker >/dev/null 2>&1 && \
     docker ps -a --filter "name=^/${APP_NAME}-war$" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    MODE="docker-war"
  fi
fi

# 4. Podman container — JAR-based
if [[ -z "$MODE" ]]; then
  if command -v podman >/dev/null 2>&1 && \
     podman ps -a --filter "name=^${APP_NAME}$" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    MODE="podman"
  fi
fi

# 4b. Podman container — WAR-based
if [[ -z "$MODE" ]]; then
  if command -v podman >/dev/null 2>&1 && \
     podman ps -a --filter "name=^${APP_NAME}-war$" --format '{{.Names}}' 2>/dev/null | grep -q .; then
    MODE="podman-war"
  fi
fi

# 5. Bare process — JAR
if [[ -z "$MODE" ]]; then
  if pgrep -f "${APP_NAME}.*\.jar" >/dev/null 2>&1; then
    MODE="process"
  fi
fi

# 5b. Bare Jetty process — WAR (jetty start.jar running with project-api-war JETTY_BASE)
if [[ -z "$MODE" ]]; then
  if pgrep -f "start\.jar.*jetty\.base=.*project-api" >/dev/null 2>&1 || \
     pgrep -f "start\.jar.*${APP_NAME}" >/dev/null 2>&1; then
    MODE="war-process"
  fi
fi

if [[ -z "$MODE" ]]; then
  echo "ERROR: no running project-api found (checked k8s, systemd, docker, podman, process, war)." >&2
  exit 1
fi

echo "Detected mode: $MODE"

# ── restart ───────────────────────────────────────────────────────────────────
case "$MODE" in

  k8s)
    echo "kubectl : ${KUBECTL[*]}"
    echo "ns      : $NAMESPACE"
    echo ""
    echo "Rolling out deployment/$APP_NAME ..."
    "${KUBECTL[@]}" rollout restart deployment/"$APP_NAME" -n "$NAMESPACE"
    echo ""
    echo "Waiting for rollout to complete ..."
    "${KUBECTL[@]}" rollout status deployment/"$APP_NAME" -n "$NAMESPACE"
    ;;

  service)
    echo ""
    echo "Restarting systemd service $APP_NAME ..."
    systemctl restart "$APP_NAME"
    echo ""
    systemctl status "$APP_NAME" --no-pager || true
    ;;

  war-service)
    echo ""
    echo "Restarting systemd service $WAR_SERVICE_NAME (WAR/Jetty) ..."
    systemctl restart "$WAR_SERVICE_NAME"
    echo ""
    systemctl status "$WAR_SERVICE_NAME" --no-pager || true
    ;;

  docker)
    echo ""
    echo "Restarting Docker container $APP_NAME ..."
    docker restart "$APP_NAME"
    echo ""
    docker ps --filter "name=^/${APP_NAME}$"
    ;;

  docker-war)
    echo ""
    echo "Restarting Docker container ${APP_NAME}-war ..."
    docker restart "${APP_NAME}-war"
    echo ""
    docker ps --filter "name=^/${APP_NAME}-war$"
    ;;

  podman)
    echo ""
    echo "Restarting Podman container $APP_NAME ..."
    podman restart "$APP_NAME"
    echo ""
    podman ps --filter "name=^${APP_NAME}$"
    ;;

  podman-war)
    echo ""
    echo "Restarting Podman container ${APP_NAME}-war ..."
    podman restart "${APP_NAME}-war"
    echo ""
    podman ps --filter "name=^${APP_NAME}-war$"
    ;;

  war-process)
    PIDS=$(pgrep -f "start\.jar" | tr '\n' ' ')
    echo ""
    echo "Killing Jetty process(es): $PIDS"
    pkill -f "start\.jar" || true

    for i in {1..10}; do
      if ! pgrep -f "start\.jar" >/dev/null 2>&1; then break; fi
      sleep 1
    done
    if pgrep -f "start\.jar" >/dev/null 2>&1; then
      echo "Process did not exit cleanly, sending SIGKILL ..."
      pkill -9 -f "start\.jar" || true
      sleep 1
    fi

    echo ""
    echo "Starting new Jetty process via deploy-webserver.sh is required for WAR mode."
    echo "Run: sudo $SCRIPT_DIR/deploy-webserver.sh"
    ;;

  process)
    PIDS=$(pgrep -f "${APP_NAME}.*\.jar" | tr '\n' ' ')
    echo ""
    echo "Killing process(es): $PIDS"
    pkill -f "${APP_NAME}.*\.jar" || true

    # Wait for the old process to exit
    for i in {1..10}; do
      if ! pgrep -f "${APP_NAME}.*\.jar" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
    if pgrep -f "${APP_NAME}.*\.jar" >/dev/null 2>&1; then
      echo "Process did not exit cleanly, sending SIGKILL ..."
      pkill -9 -f "${APP_NAME}.*\.jar" || true
      sleep 1
    fi

    echo ""
    echo "Starting new process via start.sh ..."
    mkdir -p "${APP_LOG_PATH:-$SCRIPT_DIR/logs}"
    nohup "$SCRIPT_DIR/start.sh" >> "${APP_LOG_PATH:-$SCRIPT_DIR/logs}/restart.log" 2>&1 &
    NEW_PID=$!
    echo "Started (PID $NEW_PID) — logs: ${APP_LOG_PATH:-$SCRIPT_DIR/logs}/restart.log"
    ;;

esac

echo ""
echo "Done."
