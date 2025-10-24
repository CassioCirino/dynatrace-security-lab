#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/CassioCirino/dynatrace-security-lab.git}"
TARGET_DIR="/opt/dynatrace-security-lab"
DOMAIN="${2:-}"

apt-get update -y
apt-get install -y curl git openssl jq

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y docker-compose-plugin
fi

rm -rf "$TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"

mkdir -p "$TARGET_DIR"/nginx/certs
mkdir -p "$TARGET_DIR"/logs
mkdir -p "$TARGET_DIR"/vuln-app/attack-scripts
chown -R "$(whoami)":"$(whoami)" "$TARGET_DIR"

if [ -z "$DOMAIN" ]; then
  PUBIP=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')
  DOMAIN="$PUBIP"
fi

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/CN=$DOMAIN" \
  -keyout "$TARGET_DIR/nginx/certs/self.key" \
  -out "$TARGET_DIR/nginx/certs/self.crt" >/dev/null 2>&1 || true
chmod 600 "$TARGET_DIR/nginx/certs/self.key" || true

touch "$TARGET_DIR/vuln-app/db.sqlite"
chmod 666 "$TARGET_DIR/vuln-app/db.sqlite" || true

cd "$TARGET_DIR"
docker compose down 2>/dev/null || true
docker compose up -d --build || true

cat >/etc/systemd/system/dynatrace-security-lab.service <<'SERVICE'
[Unit]
Description=Dynatrace Security Lab stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/dynatrace-security-lab
ExecStart=/usr/bin/docker compose up -d --build
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload || true
systemctl enable --now dynatrace-security-lab.service || true

echo "Installed at: $TARGET_DIR"
