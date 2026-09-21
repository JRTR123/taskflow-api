#!/bin/sh
# kubectl against kind. Prefer in-cluster config on a Kubernetes agent pod.
set -e

if command -v kubectl >/dev/null 2>&1 && [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
  echo "Using in-cluster kubectl" >&2
  exec kubectl --insecure-skip-tls-verify "$@"
fi

KCFG="${WORKSPACE}/k8s/kubeconfig.ci"
if [ ! -f "$KCFG" ]; then
  echo "Missing $KCFG" >&2
  exit 1
fi

echo "Using kubeconfig server:" >&2
grep -E '^\s*server:' "$KCFG" >&2 || true

sh "$(dirname "$0")/docker.sh" network connect kind "$(hostname)" 2>/dev/null || true

# Host-path -v of a file written inside the agent container becomes a directory.
# volumes-from shares the real workspace file with this kubectl container.
# shellcheck disable=SC2086
exec sh "$(dirname "$0")/docker.sh" run --rm --network kind \
  --volumes-from "$(hostname)" \
  -e KUBECONFIG="$KCFG" \
  -w "$WORKSPACE" \
  rancher/kubectl:v1.31.7 \
  --insecure-skip-tls-verify \
  "$@"
