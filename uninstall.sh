#!/usr/bin/env bash
set -euo pipefail

# uninstall-dynatrace-lab.sh
# Uso:
#   ./uninstall-dynatrace-lab.sh          -> modo dry-run (mostra o que faria)
#   sudo ./uninstall-dynatrace-lab.sh --force   -> executa as ações
#   sudo ./uninstall-dynatrace-lab.sh --force --remove-docker -> além de remover o lab, remove pacotes docker

PROJECT_DIR="/opt/dynatrace-security-lab"   # pasta onde o lab foi instalado (ajuste se necessário)
CONTAINERS=("vuln-app" "vuln-nginx")
VOLUMES=("vuln-data" "vuln-logs")
# imagens/nomes que costumam ser criados. Ajuste se necessário.
IMAGES=("vuln-app" "vuln-nginx")
EXTRA_DIRS=(
  "${PROJECT_DIR}"
  # entradas relativas caso alguém tenha extraído localmente (ajuste se necessário)
  "$PWD/vuln-app"
  "$PWD/nginx"
)

DOCKER_REMOVE_PACKAGES=false
FORCE=false
DRYRUN=true

function usage() {
  cat <<EOF
Usage: $0 [--force] [--remove-docker] [--help]

--force         Execute actions (default: dry-run)
--remove-docker Also purge Docker packages and remove /var/lib/docker (destrutivo)
--help          Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; DRYRUN=false; shift;;
    --remove-docker) DOCKER_REMOVE_PACKAGES=true; shift;;
    --help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

echo "=== uninstall-dynatrace-lab.sh ==="
echo "Project dir: $PROJECT_DIR"
echo "Containers: ${CONTAINERS[*]}"
echo "Volumes: ${VOLUMES[*]}"
echo "Images: ${IMAGES[*]}"
echo "Extra dirs to consider for deletion: ${EXTRA_DIRS[*]}"
echo "Dry-run: ${DRYRUN}"
echo "Will remove docker packages: ${DOCKER_REMOVE_PACKAGES}"
echo

# Helper: run or echo
function do_cmd() {
  if [ "$DRYRUN" = true ]; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC] $*"
    eval "$@"
  fi
}

# 1) Stop & remove containers
echo "-> Parando e removendo containers se existirem..."
for c in "${CONTAINERS[@]}"; do
  CID=$(docker ps -a --filter "name=^/${c}$" --format '{{.ID}}' 2>/dev/null || true)
  if [ -n "$CID" ]; then
    do_cmd "docker stop ${CID} || true"
    do_cmd "docker rm -f ${CID} || true"
  else
    echo "  container '${c}' não encontrado (ok)."
  fi
done

# 2) docker compose down (se houver docker-compose.yml no PROJECT_DIR)
if [ -f "${PROJECT_DIR}/docker-compose.yml" ]; then
  echo "-> Encontrado docker-compose.yml em ${PROJECT_DIR}, executando 'docker compose down --rmi all -v --remove-orphans'..."
  # prefer docker compose (plugin) when disponível
  if command -v docker >/dev/null 2>&1; then
    do_cmd "cd ${PROJECT_DIR} && docker compose down --rmi all -v --remove-orphans || true"
  else
    echo "  docker não encontrado; pulando docker compose down."
  fi
fi

# 3) Remove images por nome (forçado)
echo "-> Tentando remover imagens listadas..."
for img in "${IMAGES[@]}"; do
  exists=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null | grep -E "^${img}:" || true)
  if [ -n "$exists" ]; then
    do_cmd "docker image rm -f ${img} || true"
  else
    echo "  imagem '${img}' não encontrada (ok)."
  fi
done

# 4) Remove volumes Docker explicitamente
echo "-> Removendo volumes Docker listados..."
for v in "${VOLUMES[@]}"; do
  VID=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -x "${v}" || true)
  if [ -n "$VID" ]; then
    do_cmd "docker volume rm ${v} || true"
  else
    echo "  volume '${v}' não encontrado (ok)."
  fi
done

# 5) Remover quaisquer containers órfãos com nomes parecidos (opcional)
echo "-> Removendo containers que contenham 'vuln' no nome (precaução)..."
orphans=$(docker ps -a --format '{{.ID}} {{.Names}}' 2>/dev/null | awk '/vuln/{print $1}' || true)
if [ -n "$orphans" ]; then
  for oc in $orphans; do
    do_cmd "docker rm -f ${oc} || true"
  done
else
  echo "  nenhum container órfão com 'vuln' detectado."
fi

# 6) Apagar diretórios/arquivos do projeto
echo "-> Apagando diretórios do projeto (após confirmação)..."
for d in "${EXTRA_DIRS[@]}"; do
  if [ -e "$d" ]; then
    do_cmd "rm -rf \"$d\""
  else
    echo "  não existe: $d"
  fi
done

# 7) Limpeza de logs conhecidos (caminhos mencionados no install.sh)
KNOWN_LOGS=(
  "/opt/dynatrace-security-lab/vuln-app/logs"
  "/opt/dynatrace-security-lab/vuln-app/data"
)
echo "-> Limpando logs conhecidos/paths do lab..."
for p in "${KNOWN_LOGS[@]}"; do
  if [ -e "$p" ]; then
    do_cmd "rm -rf \"$p\""
  fi
done

# 8) Opcional: remover Docker e componentes (muito destrutivo)
if [ "$DOCKER_REMOVE_PACKAGES" = true ]; then
  echo "-> Opcional: irá tentar purgar pacotes Docker (docker-ce, containerd, docker.io, compose plugin) e remover dados em /var/lib/docker"
  # pacotes comuns a remover
  PKGS=("docker-ce" "docker-ce-cli" "containerd.io" "docker.io" "docker-compose-plugin")
  # Purge in Debian/Ubuntu style
  cmd="apt-get purge -y ${PKGS[*]} || true; apt-get autoremove -y || true; apt-get autoclean -y || true"
  do_cmd "$cmd"
  do_cmd "rm -rf /var/lib/docker /var/lib/containerd /etc/docker || true"
  do_cmd "groupdel docker || true"
  # try removing docker-compose binary if present
  do_cmd "which docker-compose >/dev/null 2>&1 && rm -f \$(which docker-compose) || true"
fi

echo
if [ "$DRYRUN" = true ]; then
  echo "DRY-RUN completo. Revise as ações acima. Para executar, rode com --force."
else
  echo "Execução completa (ou tentada). Revise logs acima para erros."
fi

echo "Fim."
