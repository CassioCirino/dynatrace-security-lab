#!/usr/bin/env bash
set -euo pipefail
REPO="https://github.com/CassioCirino/dynatrace-security-lab.git"
DEST="/opt/dynatrace-security-lab"

echo "[install] Atualizando e instalando dependências básicas..."
apt-get update -y
apt-get install -y curl git

# install docker (simple safe path)
if ! command -v docker >/dev/null 2>&1; then
  echo "[install] Instalando Docker..."
  curl -fsSL https://get.docker.com | bash
  usermod -aG docker "${SUDO_USER:-$USER}" || true
fi

# ensure docker compose plugin exists
if ! docker compose version >/dev/null 2>&1; then
  echo "[install] Instalando docker compose plugin..."
  apt-get install -y docker-compose-plugin || true
fi

# clean old install
if [ -d "$DEST" ]; then
  echo "[install] Removendo diretório antigo $DEST"
  rm -rf "$DEST"
fi

echo "[install] Clonando $REPO em $DEST"
git clone --depth 1 "$REPO" "$DEST"

cd "$DEST"

# create any missing dirs and set perms
mkdir -p vuln-app/data vuln-app/logs nginx
chmod -R 0777 vuln-app/data vuln-app/logs

echo "[install] Construindo e iniciando containers (docker compose)..."
docker compose up -d --build

echo "=================================================="
echo "Front-end disponível em: http://<EC2_IP>/"
echo "Se usar autorizações AWS, abra portas 80/443 no Security Group."
echo "Logs do app: /opt/dynatrace-security-lab/vuln-app/logs"
echo "Attack scripts: /opt/dynatrace-security-lab/vuln-app/attack-scripts"
echo "=================================================="
