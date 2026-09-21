#!/bin/sh
# docker CLI that falls back to passwordless sudo when sock perms deny the Jenkins user.
set -e

if docker info >/dev/null 2>&1; then
  DOCKER="docker"
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER="sudo -n -E docker"
else
  echo "ERROR: cannot talk to the Docker daemon socket" >&2
  id
  ls -l /var/run/docker.sock 2>/dev/null || true
  echo "Fix on linux-build: sudo usermod -aG docker \$(id -un) && restart the agent" >&2
  echo "Lab workaround: sudo chmod 666 /var/run/docker.sock" >&2
  exit 1
fi

# shellcheck disable=SC2086
exec $DOCKER "$@"
