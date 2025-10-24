#!/usr/bin/env bash
set -euo pipefail

# USAGE:
# sudo bash install.sh --repo https://github.com/<user>/dynatrace-security-lab.git --domain example.com
# If domain omitted, a self-signed cert will be generated for the server IP.

print_help() {
  cat <<'EOF'
install.sh - deploy Dynatrace Security Lab (Docker) on Ubuntu-like systems.

Usage:
  sudo bash install.sh --repo <git_repo_url> [--domain <your.domain.or.ip>] [--no-https]

Options:
  --repo      Required. Git repo url (https) containing this project.
  --domain    Optional. Domain name for HTTPS. If omitted, self-signed cert for host IP will be used.
  --no-https  Optional. Skip nginx/https; only expose HTTP.
EOF
  exit 1
}

# default values
REPO_URL=""
DOMAIN=""
NO_HTTPS=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO_URL="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --no-https) NO_HTTPS=1; shift ;;
    -h|--help) print_help ;;
    *) echo "Unknown arg: $1"; print_help ;;
  esac
done

if [[ -z "$REPO_URL" ]]; then
  echo "ERROR: --repo is required."
  print_help
fi

LAB_DIR="/opt/dynatrace-security-lab"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"

echo "==> Installing prerequisites (apt update)..."
apt update -y
apt upgrade -y

echo "==> Installing docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
fi

echo "==> Installing docker compose plugin..."
apt install -y docker-compose-plugin

echo "==> Installing git, python3-pip, jq, openssl, curl"
apt install -y git python3-pip jq openssl curl

echo "==> Creating lab directory: $LAB_DIR"
rm -rf "$LAB_DIR"
mkdir -p "$LAB_DIR"
chown root:root "$LAB_DIR"

echo "==> Cloning repository: $REPO_URL"
git clone "$REPO_URL" "$LAB_DIR"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: docker-compose.yml not found in repo. Aborting."
  exit 1
fi

cd "$LAB_DIR"

# create db file and set permissive permissions (lab only)
if [[ -d "vuln-app" ]]; then
  touch vuln-app/db.sqlite
  chmod 666 vuln-app/db.sqlite
fi

# generate self-signed cert if domain not provided and not NO_HTTPS
if [[ $NO_HTTPS -eq 0 ]]; then
  if [[ -z "$DOMAIN" ]]; then
    HOST_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)
    if [[ -z "$HOST_IP" ]]; then
      # fallback to hostname
      HOST_IP=$(hostname -I | awk '{print $1}')
    fi
    DOMAIN="$HOST_IP"
    echo "No domain provided. Will generate self-signed cert for $DOMAIN"
  fi

  # generate certs
  mkdir -p nginx/certs
  openssl req -x509 -nodes -days 365 -newkey rsa:2048             -subj "/CN=$DOMAIN"             -keyout nginx/certs/self.key -out nginx/certs/self.crt
  chmod 600 nginx/certs/self.key
fi

echo "==> Starting docker compose stack..."
if [[ $NO_HTTPS -eq 1 ]]; then
  docker compose up -d --build
else
  docker compose up -d --build
fi

echo "==> Enabling service to start at boot..."
SERVICE_FILE="/etc/systemd/system/dynatrace-security-lab.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Dynatrace Security Lab docker compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$LAB_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now dynatrace-security-lab.service

echo "==> Done. Access the lab at:"
if [[ $NO_HTTPS -eq 1 ]]; then
  echo "  http://<server_ip_or_domain>:80"
else
  echo "  https://$DOMAIN  (self-signed certificate if domain not managed)"
fi

echo
echo "Next steps:"
echo "  - Install Dynatrace OneAgent on this host so Dynatrace can detect the vuln-app."
echo "  - In Dynatrace: enable Application Security (RAP) in Monitor mode for the vuln-app service."
echo
echo "Security WARNING: This environment intentionally contains vulnerabilities for training."
echo "Do NOT expose to internet except for controlled lab; use Security Group or firewall rules to restrict access."
