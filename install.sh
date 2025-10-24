#!/usr/bin/env bash
set -euo pipefail
REPO_URL="https://github.com/CassioCirino/dynatrace-security-lab.git"
INSTALL_DIR="/opt/dynatrace-security-lab"

apt-get update -y && apt-get install -y git docker.io docker-compose-plugin openssl curl

rm -rf "$INSTALL_DIR"
git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

mkdir -p nginx/certs vuln-app/logs vuln-app/db

IP=$(curl -s icanhazip.com || hostname -I | awk '{print $1}')
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/certs/lab.key -out nginx/certs/lab.crt -subj "/CN=$IP"

docker compose up -d --build

echo "✅ Instalação concluída! Acesse https://$IP/"
