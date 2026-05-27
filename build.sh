#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/.env"

CONTAINER_CMD="${CONTAINER_COMMAND:-docker}"
API_IMAGE="$DOCKER_REGISTRY/project-api"
CALLER_IMAGE="$DOCKER_REGISTRY/project-api-caller"

# Parse process-scope env vars from service.environment.variables.txt and
# forward them as --build-arg so they are injected only into the JVM process
# environment via the generated entrypoint wrapper (not as container-wide ENV).
PROCESS_ENV_BUILD_ARGS=()
ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/service.environment.variables.txt"
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# || -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^Environment=([^=]+)=(.*)$ ]]; then
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        var_value="${var_value#\"}"   # strip leading "
        var_value="${var_value%\"}"   # strip trailing "
        PROCESS_ENV_BUILD_ARGS+=("--build-arg" "${var_name}=${var_value}")
    fi
done < "$ENV_FILE"

echo "==> Building API image: $API_IMAGE"
$CONTAINER_CMD build "${PROCESS_ENV_BUILD_ARGS[@]}" -t "$API_IMAGE" .

echo "==> Building caller image: $CALLER_IMAGE"
$CONTAINER_CMD build -t "$CALLER_IMAGE" -f Dockerfile.caller .

echo "==> Pushing images"
$CONTAINER_CMD push "$API_IMAGE"
$CONTAINER_CMD push "$CALLER_IMAGE"

echo "==> Done"
