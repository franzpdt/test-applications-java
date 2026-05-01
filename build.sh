#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/.env"

CONTAINER_CMD="${CONTAINER_COMMAND:-docker}"
API_IMAGE="$DOCKER_REGISTRY/project-api"
CALLER_IMAGE="$DOCKER_REGISTRY/project-api-caller"

echo "==> Building API image: $API_IMAGE"
$CONTAINER_CMD build -t "$API_IMAGE" .

echo "==> Building caller image: $CALLER_IMAGE"
$CONTAINER_CMD build -t "$CALLER_IMAGE" -f Dockerfile.caller .

echo "==> Pushing images"
$CONTAINER_CMD push "$API_IMAGE"
$CONTAINER_CMD push "$CALLER_IMAGE"

echo "==> Done"
