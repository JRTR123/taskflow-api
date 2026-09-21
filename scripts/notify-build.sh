#!/bin/sh
# Post a Slack (or generic webhook) message. Credentials must be injected as env.
# NOTIFY_WEBHOOK = incoming webhook URL
set -e

status="${1:-unknown}"
branch="${GIT_BRANCH:-${BRANCH_NAME:-unknown}}"
url="${BUILD_URL:-}"
job="${JOB_NAME:-taskflow}"
color="good"
if [ "$status" != "success" ]; then
  color="danger"
fi

text="${job} ${status} on ${branch} ${url}"
echo "$text"

if [ -z "${NOTIFY_WEBHOOK}" ]; then
  echo "NOTIFY_WEBHOOK not set; skipping remote notify"
  exit 0
fi

curl -sf -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"${text}\",\"attachments\":[{\"color\":\"${color}\",\"text\":\"${text}\"}]}" \
  "${NOTIFY_WEBHOOK}"
