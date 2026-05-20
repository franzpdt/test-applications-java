#!/usr/bin/env bash
set -euo pipefail

LOCAL_REGISTRY="localhost:32000"
API_IMAGE="$LOCAL_REGISTRY/project-api:latest"
CALLER_IMAGE="$LOCAL_REGISTRY/project-api-caller:latest"
CONTAINER_CMD="${CONTAINER_COMMAND:-podman}"

echo "==> Tagging project-api for local registry"
$CONTAINER_CMD tag project-api:latest "$API_IMAGE"

echo "==> Tagging project-api-caller for local registry"
$CONTAINER_CMD tag project-api-caller:latest "$CALLER_IMAGE"

echo "==> Pushing $API_IMAGE"
$CONTAINER_CMD push "$API_IMAGE"

echo "==> Pushing $CALLER_IMAGE"
$CONTAINER_CMD push "$CALLER_IMAGE"

echo "==> Done"
