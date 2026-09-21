#!/bin/sh
# kubectl against the kind cluster "taskflow" (control-plane on Docker network "kind").
set -e
KCFG="${WORKSPACE}/k8s/kubeconfig.ci"
if [ ! -f "$KCFG" ]; then
  echo "Missing $KCFG — run scripts/lab07-setup.ps1 on the Docker host first." >&2
  exit 1
fi

sh "$(dirname "$0")/docker.sh" network connect kind "$(hostname)" 2>/dev/null || true

# shellcheck disable=SC2086
exec sh "$(dirname "$0")/docker.sh" run --rm --network kind \
  -v "$KCFG:/root/.kube/config:ro" \
  rancher/kubectl:v1.31.7 \
  --insecure-skip-tls-verify \
  "$@"
