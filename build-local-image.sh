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

# Parse env vars from service.environment.variables.txt and forward them as
# --build-arg so they are baked into the image environment (Dockerfile.war
# declares ARG/ENV for each recognised variable).
ENV_BUILD_ARGS=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# || -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^Environment=([^=]+)=(.*)$ ]]; then
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        var_value="${var_value#\"}"   # strip leading "
        var_value="${var_value%\"}"   # strip trailing "
        ENV_BUILD_ARGS+=("--build-arg" "${var_name}=${var_value}")
    fi
done < "${SCRIPT_DIR}/service.environment.variables.txt"

echo "==> Building API image: ${API_IMAGE}"
"${CONTAINER_CMD}" build \
    ${NO_CACHE} \
    "${ENV_BUILD_ARGS[@]}" \
    -f "${SCRIPT_DIR}/Dockerfile.war" \
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
