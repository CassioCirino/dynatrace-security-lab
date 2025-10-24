#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/CassioCirino/dynatrace-security-lab.git"
INSTALL_DIR="/opt/dynatrace-security-lab"

log() { echo -e "\e[1;34m[install]\e[0m $*"; }
err() { echo -e "\e[1;31m[install]\e[0m $*" >&2; }

if [ "$EUID" -ne 0 ]; then
  err "Por favor execute como root: curl ... | sudo bash"
  exit 1
fi

log "🔧 Atualizando pacotes e instalando dependências básicas..."
apt-get update -qq
apt-get install -y -qq git curl gnupg ca-certificates openssl

# =====================================================================
# Instalação segura e compatível do Docker (Ubuntu 22.04 e 24.04)
# =====================================================================
log "🐳 Instalando Docker Engine (compatível com Ubuntu 24.04)..."

apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 containerd runc || true

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

# =====================================================================
# Clonagem e preparação do ambiente
# =====================================================================
log "📦 Clonando repositório do laboratório..."
rm -rf "$INSTALL_DIR"
git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

mkdir -p nginx/certs vuln-app/logs vuln-app/db

IP=$(curl -s --fail icanhazip.com || hostname -I | awk '{print $1}' || echo "127.0.0.1")

# =====================================================================
# Certificado HTTPS
# =====================================================================
if [ ! -f nginx/certs/lab.crt ]; then
  log "🔐 Gerando certificado self-signed..."
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout nginx/certs/lab.key \
    -out nginx/certs/lab.crt \
    -subj "/CN=$IP"
fi

# =====================================================================
# Subindo containers Docker
# =====================================================================
log "🚀 Subindo containers Docker..."
docker compose up -d --build

# =====================================================================
# Mensagem final
# =====================================================================
cat <<EOM

============================================================
✅ Dynatrace Security Lab instalado com sucesso!

Acesse a aplicação:
   🔗 https://$IP/

Para verificar os containers:
   docker ps

Logs da aplicação:
   /opt/dynatrace-security-lab/vuln-app/logs/app.log
============================================================
EOM
