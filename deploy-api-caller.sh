#!/usr/bin/env bash
set -euo pipefail

APP_NAME="project-api-caller"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="call-apis.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}"
API_URL="${1:-http://localhost:5000}"

echo "=== Deploying ${APP_NAME} as a systemd service ==="

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# Verify source script exists
if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
    echo "Error: ${SOURCE_SCRIPT} not found."
    exit 1
fi

# Install the script
echo "Installing ${SCRIPT_NAME} to ${INSTALL_DIR}..."
cp "${SOURCE_SCRIPT}" "${INSTALL_DIR}/${SCRIPT_NAME}"
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"

# Create the systemd service unit
echo "Creating systemd service at ${SERVICE_FILE}..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Project API Caller
After=network.target project-api.service
Wants=project-api.service

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${SCRIPT_NAME} ${API_URL}
Restart=on-failure
RestartSec=5
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
echo "API URL: ${API_URL}"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status ${APP_NAME}"
echo "  sudo systemctl restart ${APP_NAME}"
echo "  sudo journalctl -u ${APP_NAME} -f"
