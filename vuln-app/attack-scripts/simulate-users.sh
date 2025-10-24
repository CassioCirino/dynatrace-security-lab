#!/usr/bin/env bash
# small script to fire user-like requests to the app (useful if you want to run from server)
BASE="http://127.0.0.1:3000"
for i in $(seq 1 50); do
  curl -s "${BASE}/" > /dev/null
  curl -s "${BASE}/search?q=user${RANDOM}" > /dev/null
  sleep 0.05
done
echo "Simulated 50 requests"
