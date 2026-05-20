#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_CMD="$(command -v podman 2>/dev/null || command -v docker 2>/dev/null || true)"
if [[ -z "${CONTAINER_CMD}" ]]; then
    echo "Error: neither podman nor docker found in PATH" >&2
    exit 1
fi

LOCAL_REGISTRY="localhost:32000"
VERSION="$(cat "${SCRIPT_DIR}/VERSION" | tr -d '[:space:]')"
REPO_NAME="$(basename "$(git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null)" .git)"

SRC_API="${REPO_NAME}:${VERSION}"
SRC_CALLER="${REPO_NAME}-caller:${VERSION}"
DST_API="${LOCAL_REGISTRY}/${REPO_NAME}:${VERSION}"
DST_CALLER="${LOCAL_REGISTRY}/${REPO_NAME}-caller:${VERSION}"

echo "Container tool: ${CONTAINER_CMD}"
echo "Version:        ${VERSION}"
echo ""

echo "==> Tagging ${SRC_API} -> ${DST_API}"
"${CONTAINER_CMD}" tag "${SRC_API}" "${DST_API}"

echo "==> Tagging ${SRC_CALLER} -> ${DST_CALLER}"
"${CONTAINER_CMD}" tag "${SRC_CALLER}" "${DST_CALLER}"

echo "==> Pushing ${DST_API}"
"${CONTAINER_CMD}" push "${DST_API}"

echo "==> Pushing ${DST_CALLER}"
"${CONTAINER_CMD}" push "${DST_CALLER}"

echo ""
echo "Done. Images pushed:"
echo "  ${DST_API}"
echo "  ${DST_CALLER}"
