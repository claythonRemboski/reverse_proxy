#!/bin/bash
############################################################################
# Script para iniciar o container de proxy reverso.
#  - Instala do docker e docker compose se necessário
#  - Cria o proxy.env se não existir.
#  - Cria as redes docker que estiverem definidas no proxy.env
#  - Atualiza o docker-compose.yml do proxy reverso com as redes definidas no env
#  - Sobe o container, que vai direcionar cada acesso ao domínio para o projeto correto de acordo com o subdomínio.

# Autor: Claython Remboski
# Data: 29/12/2024
############################################################################

source scripts/utils/network_manager.sh
source scripts/utils/colors.sh
source scripts/utils/text.sh

set -e

# Verificar instalação do Docker
command -v docker2 >/dev/null 2>&1 || {
    yellow  "Docker não instalado, iniciando instalação, incluindo Docker Compose."
    source scripts/utils/docker_installer.sh
    exit 1
}

# Verificar arquivo proxy.env
if [ ! -f "env/proxy.env" ]; then
    echo "Arquivo .env não encontrado. Copiando do exemplo..."
    cp env/.env.example env/proxy.env
fi

# Carregar variáveis de ambiente
set -a
source env/proxy.env
set +a

create_network_if_not_exists "home-network"

# Iniciar containers
echo "Iniciando containers..."

docker compose -f app/home/docker-compose.yml up -d

docker compose -f proxy/docker-compose.yml up -d

separator

green "Sistema iniciado com sucesso!"

# verificar se vai remover:
# # Instalação do yq
# if ! command -v yq >/dev/null 2>&1; then
#     echo "yq não encontrado. Instalando..."
#     sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
# fi
