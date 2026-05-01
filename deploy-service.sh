#!/usr/bin/env bash
set -euo pipefail

APP_NAME="project-api"
DEPLOY_DIR="/var/www/${APP_NAME}"
LOG_DIR="/var/log/${APP_NAME}"
SERVICE_USER="${APP_NAME}"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
APP_PORT=5000
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_VARS_FILE="${SCRIPT_DIR}/service.environment.variables.txt"

echo "=== Deploying ${APP_NAME} as a systemd service ==="

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# Locate java
JAVA_PATH="$(command -v java 2>/dev/null || true)"
if [[ -z "${JAVA_PATH}" ]]; then
    for d in /usr/lib/jvm/java-21-openjdk-amd64/bin \
              /usr/lib/jvm/java-21/bin \
              /usr/local/lib/jvm/java-21/bin; do
        if [[ -x "${d}/java" ]]; then
            JAVA_PATH="${d}/java"
            break
        fi
    done
fi

if [[ -z "${JAVA_PATH}" ]]; then
    echo "Error: 'java' not found. Run install-dependencies.sh first."
    exit 1
fi

echo "Using java at: ${JAVA_PATH}"

# Create service user if it doesn't exist
if ! id -u "${SERVICE_USER}" &>/dev/null; then
    echo "Creating service user '${SERVICE_USER}'..."
    useradd --system --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

# Create directories
echo "Creating directories..."
mkdir -p "${DEPLOY_DIR}"
mkdir -p "${LOG_DIR}"

# Stop the service if already running (jar can't be overwritten while locked)
if systemctl is-active --quiet "${APP_NAME}.service" 2>/dev/null; then
    echo "Stopping running ${APP_NAME} service..."
    systemctl stop "${APP_NAME}.service"
fi

# Build the fat jar
echo "Building ${APP_NAME}..."
cd "${SCRIPT_DIR}/project-api"
./gradlew bootJar --quiet
JAR=$(ls build/libs/project-api-*.jar | head -n1)

# Copy jar to deploy directory
echo "Copying ${JAR} to ${DEPLOY_DIR}..."
cp "${JAR}" "${DEPLOY_DIR}/${APP_NAME}.jar"

# Set ownership and permissions
echo "Setting permissions..."
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${DEPLOY_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${LOG_DIR}"
chmod 755 "${DEPLOY_DIR}"
chmod 755 "${LOG_DIR}"

# Build extra environment lines from env vars file
EXTRA_ENV_LINES=""
if [[ -f "${ENV_VARS_FILE}" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        EXTRA_ENV_LINES+="${line}"$'\n'
    done < "${ENV_VARS_FILE}"
    echo "Loaded environment variables from ${ENV_VARS_FILE}"
else
    echo "Warning: ${ENV_VARS_FILE} not found, skipping extra environment variables."
fi

# Create the systemd service unit
echo "Creating systemd service at ${SERVICE_FILE}..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Project API (Java)
After=network.target

[Service]
Type=exec
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DEPLOY_DIR}
ExecStart=${JAVA_PATH} -jar ${DEPLOY_DIR}/${APP_NAME}.jar
KillMode=control-group
TimeoutStopSec=15
Environment=APP_PORT=${APP_PORT}
Environment=APP_LOG_PATH=${LOG_DIR}
${EXTRA_ENV_LINES}Restart=on-failure
RestartSec=5
KillSignal=SIGTERM
SyslogIdentifier=${APP_NAME}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable "${APP_NAME}.service"
systemctl restart "${APP_NAME}.service"

echo ""
echo "=== Deployment complete ==="
echo "Service status:"
systemctl status "${APP_NAME}.service" --no-pager || true
echo ""
echo "The API is listening on port ${APP_PORT}."
echo "Logs are written to ${LOG_DIR}."
echo ""
echo "Useful commands:"
echo "  sudo systemctl status ${APP_NAME}"
echo "  sudo systemctl restart ${APP_NAME}"
echo "  sudo journalctl -u ${APP_NAME} -f"
