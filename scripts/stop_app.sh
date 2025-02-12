#!/bin/bash

############################################################################
# Script para instalar um novo aplicativo na estrutura.
#  - Solicita o nome do projeto/app
#  - Baixa os containeres do projeto através do nome.
#  - Reinicia o proxy para mapear os containeres
#
# Autor: Claython Remboski
############################################################################

source scripts/utils/colors.sh
source scripts/utils/text.sh

set -e

# Carregar variáveis de ambiente
set -a
source env/proxy.env
set +a

#-----------------------------------------------------------------------------------
# Subir os containeres
blue "Digite o nome do app/projeto que será parado: "

read -r project_name

docker compose -f app/"$project_name"/docker-compose.yml down

#-----------------------------------------------------------------------------------
# Reiniciar nginx
green "Reiniciando nginx... "
docker exec nginx-proxy nginx -s reload
separator
yellow "Containeres do app $project_name parados com sucesso."
