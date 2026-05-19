#!/usr/bin/env bash
set -euo pipefail

APP_PORT="${APP_PORT:-5000}"
APP_LOG_PATH="${APP_LOG_PATH:-./logs}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$APP_LOG_PATH"

echo "==> Building project-api"
cd "$SCRIPT_DIR/project-api"
./gradlew bootJar --quiet

JAR=$(ls build/libs/project-api-*.jar | head -n1)
echo "==> Starting $JAR on port $APP_PORT (logs: $APP_LOG_PATH)"

exec java \
  -DAPP_PORT="$APP_PORT" \
  -DAPP_LOG_PATH="$APP_LOG_PATH" \
  -jar "$JAR"
