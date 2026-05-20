#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_CMD="$(command -v podman 2>/dev/null || command -v docker 2>/dev/null || true)"
if [[ -z "${CONTAINER_CMD}" ]]; then
    echo "Error: neither podman nor docker found in PATH" >&2
    exit 1
fi

VERSION="$(cat "${SCRIPT_DIR}/VERSION" | tr -d '[:space:]')"
REPO_NAME="$(basename "$(git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null)" .git)"

API_IMAGE="${REPO_NAME}:${VERSION}"
CALLER_IMAGE="${REPO_NAME}-caller:${VERSION}"

echo "Container tool: ${CONTAINER_CMD}"
echo "Version:        ${VERSION}"
echo "API image:      ${API_IMAGE}"
echo "Caller image:   ${CALLER_IMAGE}"
echo ""

echo "==> Building API image: ${API_IMAGE}"
"${CONTAINER_CMD}" build \
    -f "${SCRIPT_DIR}/Dockerfile" \
    -t "${API_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Building caller image: ${CALLER_IMAGE}"
"${CONTAINER_CMD}" build \
    -f "${SCRIPT_DIR}/Dockerfile.caller" \
    -t "${CALLER_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "Done. Images built:"
echo "  ${API_IMAGE}"
echo "  ${CALLER_IMAGE}"
