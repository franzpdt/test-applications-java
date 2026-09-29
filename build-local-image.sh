#!/usr/bin/env bash
# Usage: ./build-local-image.sh [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NO_CACHE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cache) NO_CACHE="--no-cache"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

CONTAINER_CMD="$(command -v podman 2>/dev/null || command -v docker 2>/dev/null || true)"
if [[ -z "${CONTAINER_CMD}" ]]; then
    echo "Error: neither podman nor docker found in PATH" >&2
    exit 1
fi

VERSION="$(cat "${SCRIPT_DIR}/VERSION" | tr -d '[:space:]')"
REPO_NAME="$(basename "$(git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null)" .git)"
REPO_NAME="${REPO_NAME:-$(basename "${SCRIPT_DIR}")}"

API_IMAGE="${REPO_NAME}:${VERSION}"
CALLER_IMAGE="${REPO_NAME}-caller:${VERSION}"

echo "Container tool: ${CONTAINER_CMD}"
echo "Version:        ${VERSION}"
echo "API image:      ${API_IMAGE}"
echo "Caller image:   ${CALLER_IMAGE}"
echo ""

# DT_TAGS / DT_CUSTOM_PROP are no longer baked into the image at build time.
# They are supplied at deploy time as container environment variables (k8s pod
# spec injection from ONEAGENT_PROCESS_TAGS / ONEAGENT_CUSTOM_PROP; systemd via
# the service.environment.variables.txt EnvironmentFile).

echo "==> Building API image: ${API_IMAGE}"
"${CONTAINER_CMD}" build \
    ${NO_CACHE} \
    -f "${SCRIPT_DIR}/Dockerfile" \
    -t "${API_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Building caller image: ${CALLER_IMAGE}"
"${CONTAINER_CMD}" build \
    ${NO_CACHE} \
    -f "${SCRIPT_DIR}/Dockerfile.caller" \
    -t "${CALLER_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "Done. Images built:"
echo "  ${API_IMAGE}"
echo "  ${CALLER_IMAGE}"
