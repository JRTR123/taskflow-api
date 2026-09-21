#!/bin/sh
# kubectl against the kind cluster "taskflow".
set -e
KCFG="${WORKSPACE}/k8s/kubeconfig.ci"
if [ ! -f "$KCFG" ]; then
  echo "Missing $KCFG — pipeline must generate it from taskflow-control-plane." >&2
  exit 1
fi

echo "Using kubeconfig server:"
grep -E '^\s*server:' "$KCFG" || true

sh "$(dirname "$0")/docker.sh" network connect kind "$(hostname)" 2>/dev/null || true

# rancher/kubectl does not run as root, so do not mount into /root/.kube
# shellcheck disable=SC2086
exec sh "$(dirname "$0")/docker.sh" run --rm --network kind \
  -e KUBECONFIG=/kubeconfig \
  -v "$KCFG:/kubeconfig:ro" \
  rancher/kubectl:v1.31.7 \
  --insecure-skip-tls-verify \
  "$@"
