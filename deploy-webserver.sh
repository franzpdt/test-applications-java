#!/usr/bin/env bash
# deploy-webserver.sh
#
# Installs standalone Jetty 12 on Ubuntu/Debian, builds the project-api WAR,
# and deploys it as the ROOT web application.
#
# Usage:
#   sudo ./deploy-webserver.sh                         # default port 5000
#   sudo APP_PORT=8080 ./deploy-webserver.sh           # custom port
#   sudo APP_LOG_PATH=/var/log/myapp ./deploy-webserver.sh
#
# What it does:
#   1. Installs Java 21 JRE (apt)
#   2. Downloads Jetty 12 distribution to /opt/jetty (if not already present)
#   3. Configures a JETTY_BASE at /opt/jetty/base with http + ee10-deploy modules
#   4. Builds the WAR from source and copies it to the JETTY_BASE webapps/ROOT.war
#   5. Creates a 'jetty' system user
#   6. Installs a systemd unit file and starts the service
#
# Environment variables are read from service.environment.variables.txt in the
# same directory (same format used by deploy-service.sh):
#   Environment=DT_TAGS="..."
#   Environment=DT_CUSTOM_PROP="..."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JETTY_VERSION="${JETTY_VERSION:-12.0.21}"
JETTY_HOME="/opt/jetty/jetty-home-${JETTY_VERSION}"
JETTY_BASE="/opt/jetty/base"
JETTY_USER="jetty"
SERVICE_NAME="project-api-war"
APP_PORT="${APP_PORT:-5000}"
APP_LOG_PATH="${APP_LOG_PATH:-/var/log/project-api}"
DOWNLOAD_URL="https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz"
ENV_VARS_FILE="${SCRIPT_DIR}/service.environment.variables.txt"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: this script must be run as root (sudo)." >&2
  exit 1
fi

echo "=== deploy-webserver.sh ==="
echo "Jetty version : $JETTY_VERSION"
echo "APP_PORT      : $APP_PORT"
echo "APP_LOG_PATH  : $APP_LOG_PATH"
echo ""

# ── 1. Java 21 ───────────────────────────────────────────────────────────────
echo "[1/6] Installing Java 21 JRE ..."
apt-get update -qq
apt-get install -y --no-install-recommends openjdk-21-jre-headless curl wget tar
JAVA_BIN="$(which java)"
echo "      java: $JAVA_BIN ($($JAVA_BIN -version 2>&1 | head -1))"

# ── 2. Download Jetty ─────────────────────────────────────────────────────────
echo "[2/6] Setting up Jetty $JETTY_VERSION ..."
mkdir -p /opt/jetty

# Guard against a partially extracted directory from a previous interrupted run
if [[ ! -f "$JETTY_HOME/start.jar" ]]; then
  [[ -d "$JETTY_HOME" ]] && rm -rf "$JETTY_HOME"
  TMP_ARCHIVE="/tmp/jetty-home-${JETTY_VERSION}.tar.gz"
  echo "      Downloading $DOWNLOAD_URL ..."
  wget -qO "$TMP_ARCHIVE" "$DOWNLOAD_URL"
  tar -xzf "$TMP_ARCHIVE" -C /opt/jetty
  rm -f "$TMP_ARCHIVE"
  echo "      Extracted to $JETTY_HOME"
else
  echo "      Already present at $JETTY_HOME, skipping download."
fi

# ── 3. Configure JETTY_BASE ───────────────────────────────────────────────────
echo "[3/6] Configuring Jetty base at $JETTY_BASE ..."
mkdir -p "$JETTY_BASE/webapps"

# Enable the required modules (idempotent — Jetty skips already-enabled ones)
java -jar "$JETTY_HOME/start.jar" \
  "jetty.base=$JETTY_BASE" \
  --add-module=http,ee10-deploy,console-capture \
  2>&1 | grep -v "^NOTE:" || true

# Set port and logging via start.d ini overrides
mkdir -p "$JETTY_BASE/start.d"

cat > "$JETTY_BASE/start.d/http-port.ini" <<EOF
## HTTP connector port
jetty.http.port=$APP_PORT
EOF

cat > "$JETTY_BASE/start.d/logging.ini" <<EOF
## Console capture log path
jetty.console-capture.dir=$APP_LOG_PATH
jetty.console-capture.filename=jetty.log
jetty.console-capture.retainDays=30
EOF

mkdir -p "$APP_LOG_PATH"

# ── 4. Build and deploy WAR ───────────────────────────────────────────────────
echo "[4/6] Building WAR ..."
pushd "$SCRIPT_DIR/project-api" > /dev/null
./gradlew war --no-daemon --quiet
WAR_FILE="$(ls build/libs/project-api-*.war 2>/dev/null | head -1)"
if [[ -z "$WAR_FILE" ]]; then
  echo "ERROR: WAR not found in project-api/build/libs/" >&2
  exit 1
fi
echo "      Built: $WAR_FILE"
cp "$WAR_FILE" "$JETTY_BASE/webapps/ROOT.war"
echo "      Deployed to $JETTY_BASE/webapps/ROOT.war"
popd > /dev/null

# ── 5. Create jetty system user ───────────────────────────────────────────────
echo "[5/6] Ensuring system user '$JETTY_USER' exists ..."
if ! id "$JETTY_USER" &>/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "$JETTY_USER"
  echo "      Created user '$JETTY_USER'."
else
  echo "      User '$JETTY_USER' already exists."
fi
chown -R "$JETTY_USER:$JETTY_USER" "$JETTY_BASE" "$APP_LOG_PATH"
chown -R root:root "$JETTY_HOME"

# ── 6. Systemd service ────────────────────────────────────────────────────────
echo "[6/6] Installing systemd unit '$SERVICE_NAME' ..."

# Read extra environment variables from service.environment.variables.txt.
# Each non-comment line must already be a valid systemd Environment= directive.
EXTRA_ENV_LINES=""
if [[ -f "$ENV_VARS_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    EXTRA_ENV_LINES+="${line}"$'\n'
  done < "$ENV_VARS_FILE"
  echo "      Loaded environment variables from $ENV_VARS_FILE"
else
  echo "      Warning: $ENV_VARS_FILE not found, skipping extra environment variables."
fi

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=project-api WAR on Jetty $JETTY_VERSION
After=network.target

[Service]
Type=simple
User=$JETTY_USER
Group=$JETTY_USER
Environment="JAVA_HOME=/usr"
Environment="APP_PORT=$APP_PORT"
Environment="APP_LOG_PATH=$APP_LOG_PATH"
${EXTRA_ENV_LINES}ExecStart=$JAVA_BIN \\
  -DAPP_LOG_PATH=$APP_LOG_PATH \\
  -jar $JETTY_HOME/start.jar \\
  jetty.base=$JETTY_BASE \\
  jetty.http.port=$APP_PORT
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo ""
echo "Done. Service '$SERVICE_NAME' is running on port $APP_PORT."
echo ""
echo "Useful commands:"
echo "  systemctl status $SERVICE_NAME"
echo "  journalctl -u $SERVICE_NAME -f"
echo "  curl http://localhost:$APP_PORT/api/projects"
