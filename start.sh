#!/usr/bin/env bash
set -euo pipefail

APP_PORT="${APP_PORT:-5000}"
APP_LOG_PATH="${APP_LOG_PATH:-./logs}"
JETTY_VERSION="${JETTY_VERSION:-12.0.21}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETTY_DIR="${SCRIPT_DIR}/.jetty"
JETTY_HOME="${JETTY_DIR}/jetty-home-${JETTY_VERSION}"
JETTY_BASE="${JETTY_DIR}/base"
DOWNLOAD_URL="https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz"

mkdir -p "$APP_LOG_PATH"

# ── Build WAR ─────────────────────────────────────────────────────────────────
echo "==> Building project-api"
cd "$SCRIPT_DIR/project-api"
./gradlew war --quiet
WAR="$(ls build/libs/project-api-*.war | head -n1)"
echo "==> Built: $WAR"
cd "$SCRIPT_DIR"

# ── Download Jetty if not already present ─────────────────────────────────────
if [[ ! -f "$JETTY_HOME/start.jar" ]]; then
  [[ -d "$JETTY_HOME" ]] && rm -rf "$JETTY_HOME"
  echo "==> Downloading Jetty $JETTY_VERSION ..."
  mkdir -p "$JETTY_DIR"
  TMP="$(mktemp)"
  curl -fsSL -o "$TMP" "$DOWNLOAD_URL"
  tar -xzf "$TMP" -C "$JETTY_DIR"
  rm -f "$TMP"
fi

# ── Initialise JETTY_BASE once ────────────────────────────────────────────────
if [[ ! -d "$JETTY_BASE" ]]; then
  mkdir -p "$JETTY_BASE/webapps"
  java -jar "$JETTY_HOME/start.jar" "jetty.base=$JETTY_BASE" \
    --add-module=http,ee10-deploy 2>&1 | grep -v "^NOTE:" || true
fi

# ── Deploy WAR ────────────────────────────────────────────────────────────────
mkdir -p "$JETTY_BASE/webapps"
cp "$SCRIPT_DIR/project-api/$WAR" "$JETTY_BASE/webapps/ROOT.war" 2>/dev/null || \
  cp "$WAR" "$JETTY_BASE/webapps/ROOT.war"

echo "==> Starting project-api on port $APP_PORT (logs: $APP_LOG_PATH)"

exec java \
  -DAPP_LOG_PATH="$APP_LOG_PATH" \
  -jar "$JETTY_HOME/start.jar" \
  "jetty.base=$JETTY_BASE" \
  "jetty.http.port=$APP_PORT"
