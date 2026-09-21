#!/bin/sh
# Fail the build when recent Jenkins success rate (Prometheus, Lab 09) is below 90%.
# Approximates "last 20 builds" via increase() on jenkins_runs_* counters.
set -e

PROM_URL="${PROM_URL:-http://host.docker.internal:9090}"
THRESHOLD="${HEALTH_GATE_THRESHOLD:-0.90}"

query() {
  curl -sf --get "${PROM_URL}/api/v1/query" --data-urlencode "query=$1" \
    | sed -n 's/.*"value":\[[^,]*,"\([^"]*\)"\].*/\1/p'
}

success=$(query 'sum(increase(jenkins_runs_success_total[24h]))')
total=$(query 'sum(increase(jenkins_runs_total_total[24h]))')

if [ -z "$success" ] || [ -z "$total" ]; then
  success=$(query 'sum(jenkins_runs_success_total)')
  total=$(query 'sum(jenkins_runs_total_total)')
fi

echo "Prometheus ${PROM_URL}"
echo "success=${success:-none} total=${total:-none} threshold=${THRESHOLD}"

if [ -z "$total" ] || [ "$total" = "0" ]; then
  echo "HEALTH GATE SKIPPED: not enough Prometheus samples yet"
  exit 0
fi

rate=$(awk -v s="$success" -v t="$total" 'BEGIN { if (t+0 <= 0) { print 1; exit } printf "%.4f", s/t }')
echo "success rate (24h) = ${rate}"

awk -v r="$rate" -v th="$THRESHOLD" 'BEGIN { exit (r+0 < th+0) ? 1 : 0 }' || {
  echo "HEALTH GATE BLOCKED: success rate ${rate} is below ${THRESHOLD} (last ~20 builds / 24h window)"
  exit 1
}

echo "HEALTH GATE PASSED"
