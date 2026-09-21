#!/bin/sh
# Run a sibling container with access to the Jenkins workspace.
set -e

extra=""
if [ -f /.dockerenv ]; then
  extra="--volumes-from $(hostname)"
else
  extra="-v ${WORKSPACE}:${WORKSPACE}"
fi

# shellcheck disable=SC2086
exec sh "$(dirname "$0")/docker.sh" run --rm $extra -w "$WORKSPACE" "$@"
