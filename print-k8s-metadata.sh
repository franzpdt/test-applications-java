#!/usr/bin/env bash
# print-k8s-metadata.sh
#
# Prints labels and annotations on the Kubernetes resources that belong to
# project-api: namespace, deployment, replicaset, pod, and service.
#
# Usage:
#   ./print-k8s-metadata.sh                     # auto-detects kubectl
#   ./print-k8s-metadata.sh -n <namespace>      # target a specific namespace

set -uo pipefail

NAMESPACE="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── detect kubectl ────────────────────────────────────────────────────────────
if command -v microk8s >/dev/null 2>&1; then
  KUBECTL=(microk8s kubectl)
elif command -v kubectl >/dev/null 2>&1; then
  KUBECTL=(kubectl)
elif command -v minikube >/dev/null 2>&1; then
  KUBECTL=(minikube kubectl --)
else
  echo "ERROR: no kubectl, microk8s, or minikube found on PATH." >&2
  exit 1
fi

echo "kubectl : ${KUBECTL[*]}"
echo "ns      : $NAMESPACE"

# ── helpers ───────────────────────────────────────────────────────────────────
SEP="$(printf '═%.0s' {1..60})"

header() {
  echo ""
  echo "$SEP"
  printf "  %-56s\n" "$1"
  echo "$SEP"
}

sub() {
  printf "  ── %s\n" "$1"
}

# Print labels and annotations from a resource via jsonpath.
# $1 = resource kind/name   e.g. "deployment/project-api"
# $2 = extra kubectl flags  e.g. "-n default" or "" for cluster-scoped
print_labels_and_annotations() {
  local resource="$1"
  local extra_flags="$2"

  sub "labels"
  # shellcheck disable=SC2086
  labels=$("${KUBECTL[@]}" get "$resource" $extra_flags \
    -o go-template='{{range $k,$v := .metadata.labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' \
    2>/dev/null || true)
  if [[ -n "$labels" ]]; then
    echo "$labels" | sort
  else
    echo "    (none)"
  fi

  sub "annotations"
  # shellcheck disable=SC2086
  annotations=$("${KUBECTL[@]}" get "$resource" $extra_flags \
    -o go-template='{{range $k,$v := .metadata.annotations}}{{$k}}={{$v}}{{"\n"}}{{end}}' \
    2>/dev/null || true)
  if [[ -n "$annotations" ]]; then
    echo "$annotations" | sort
  else
    echo "    (none)"
  fi
}

# Thin wrapper that also shows the resolved name.
print_resource() {
  local kind="$1"
  local name="$2"
  local ns_flag="$3"   # "-n <ns>" or "" for cluster-scoped

  header "${kind}: ${name}"
  if [[ -z "$name" ]]; then
    echo "  (not found)"
    return
  fi
  print_labels_and_annotations "${kind}/${name}" "$ns_flag"
}

# ── resolve resource names ────────────────────────────────────────────────────
NS_FLAG="-n $NAMESPACE"

DEPLOYMENT=$("${KUBECTL[@]}" get deployment -n "$NAMESPACE" \
  -l app=project-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

REPLICASET=$("${KUBECTL[@]}" get replicaset -n "$NAMESPACE" \
  -l app=project-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

POD=$("${KUBECTL[@]}" get pod -n "$NAMESPACE" \
  -l app=project-api --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

SERVICE=$("${KUBECTL[@]}" get service -n "$NAMESPACE" \
  -l app=project-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null ||
  # fallback: look up by name directly (service may not carry the app label)
  "${KUBECTL[@]}" get service project-api -n "$NAMESPACE" \
  -o jsonpath='{.metadata.name}' 2>/dev/null || true)

# ── print ─────────────────────────────────────────────────────────────────────

# Namespace is cluster-scoped — no -n flag for the resource itself
header "namespace: $NAMESPACE"
print_labels_and_annotations "namespace/$NAMESPACE" ""

print_resource "deployment"  "$DEPLOYMENT"  "$NS_FLAG"
print_resource "replicaset"  "$REPLICASET"  "$NS_FLAG"
print_resource "pod"         "$POD"         "$NS_FLAG"
print_resource "service"     "$SERVICE"     "$NS_FLAG"

echo ""
