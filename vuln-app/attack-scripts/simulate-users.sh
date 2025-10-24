#!/usr/bin/env bash
BASE="${1:-http://localhost:3000}"
COUNT="${2:-200}"
DELAY="${3:-0.05}"
echo "[SIM] generating ${COUNT} requests to $BASE"
for i in $(seq 1 $COUNT); do
  case $((i % 4)) in
    0) curl -s "${BASE}/" >/dev/null;;
    1) curl -s "${BASE}/product?id=1" >/dev/null;;
    2) curl -s "${BASE}/search?q=user${i}" >/dev/null;;
    3) curl -s "${BASE}/cmd?cmd=echo+hi${i}" >/dev/null;;
  esac
  sleep "$DELAY"
done
echo "[SIM] done"
