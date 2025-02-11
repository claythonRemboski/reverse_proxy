#!/bin/bash

############################################################################
# Script para instalar um novo aplicativo na estrutura.
#  - Solicita as informações o nome do projeto/app
#  - Executa os containeres do projeto através do nome.
#  - Reinicia o proxy para mapear os novos containeres
#
# Autor: Claython Remboski
############################################################################

source scripts/utils/network_manager.sh
source scripts/utils/colors.sh
source scripts/utils/text.sh
source scripts/conf_creator.sh

set -e

# Carregar variáveis de ambiente
set -a
source env/proxy.env
set +a

#-----------------------------------------------------------------------------------
# Subir os containeres
blue "Digite o nome do app/projeto que será executado: "

read -r project_name

set -a && source app/"$project_name"/"$project_name".env && source env/proxy.env && set +a &&
    docker compose -f app/"$project_name"/docker-compose.yml up -d --build

#-----------------------------------------------------------------------------------
# Reiniciar nginx
green "Reiniciando nginx... "
docker exec nginx-proxy nginx -s reload
separator
green "Containeres do app $project_name executados com sucesso."

green "Não esqueça de configurar o DNS para $subdomain.$DOMAIN "
