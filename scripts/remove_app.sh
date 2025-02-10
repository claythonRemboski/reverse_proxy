#!/bin/bash

############################################################################
# Script para remover um aplicativo instalado
#  - Baixa os containeres do aplicativo
#  - Apaga a pasta e arquivos relacionados ao projeto no diretório app
#  - 
# Autor: Claython Remboski
############################################################################
source scripts/utils/network_manager.sh
source env/proxy.env
source scripts/utils/colors.sh
source scripts/utils/text.sh

set -e # Parar em caso de erro

# Verificar se o arquivo .env existe
if [ ! -f "env/proxy.env" ]; then
    red "Arquivo proxy.env não encontrado!"
    exit 1
fi

# Coletar informações do projeto a ser removido
separator
green "Insira as informações do projeto a ser removido:"
blue "Nome do projeto (minusculo): "
read -r project_name

# Variáveis derivadas
network_name="${project_name}-network"
generated_file="proxy/nginx/conf.d/${project_name}.conf"

#Baixar os containeres:
set -a && source app/"$project_name"/"$project_name".env && source env/proxy.env && set +a &&
    docker compose -f app/"$project_name"/docker-compose.yml down

# -----------------------------------------------------------------------------------
# Remover diretório do projeto
if [ -d "app/$project_name" ]; then
    blue "Removendo diretório do projeto... "
    rm -rf "app/$project_name"
    green "Diretório app/$project_name removido."
else
    yellow "Diretório app/$project_name não encontrado. Ignorando."
fi
separator

# -----------------------------------------------------------------------------------
# Remover arquivo conf.d
if [ -f "$generated_file" ]; then
    blue "Removendo arquivo conf.d... "
    rm -f "$generated_file"
    green "Arquivo $generated_file removido."
else
    yellow "Arquivo $generated_file não encontrado. Ignorando."
fi
separator

# -----------------------------------------------------------------------------------
# Remover variáveis do .env
blue "Removendo variáveis de ambiente relacionadas ao projeto... "

remove_env_var() {
    local var_name="$1"
    sed -i "/^$var_name=/d" env/proxy.env
}

remove_env_var "${project_name^^}_SUBDOMAIN"
remove_env_var "${project_name^^}_DOMAIN"
remove_env_var "${project_name^^}_PORT"

green "Variáveis relacionadas ao projeto removidas do env/proxy.env."
separator

remove_network_from_service "proxy/docker-compose.yml" "$network_name"
remove_network_from_main "proxy/docker-compose.yml" "$network_name"
remove_network_in_docker_and_proxy_env "proxy/docker-compose.yml" "$network_name"

# -----------------------------------------------------------------------------------
# Remover rede Docker
if docker network inspect "$network_name" >/dev/null 2>&1; then
    blue "Removendo rede Docker $network_name... "
    docker network rm "$network_name"
    green "Rede Docker $network_name removida."
else
    yellow "Rede Docker $network_name não encontrada. Ignorando."
fi
separator

# -----------------------------------------------------------------------------------
# Nova seção: Limpeza de containers Docker
blue "Procurando e removendo containers relacionados ao projeto... "

# Encontrar e parar containers que contenham o nome do projeto
if docker ps -a --format '{{.Names}}' | grep -q "$project_name"; then
    blue "Parando containers relacionados ao projeto... "
    docker ps -a --format '{{.Names}}' | grep "$project_name" | xargs -r docker stop
    
    blue "Removendo containers relacionados ao projeto... "
    docker ps -a --format '{{.Names}}' | grep "$project_name" | xargs -r docker rm
    green "Containers removidos com sucesso."
else
    yellow "Nenhum container relacionado ao projeto encontrado."
fi
separator

green "Projeto $project_name removido com sucesso!"


# Verificar se haverá remoção:

# Limpeza geral do Docker
# echo -e "Executando limpeza geral do Docker... "
# echo -e "Isso removerá todos os recursos não utilizados (volumes, redes, containers e imagens).${RESET}"
# read -p "Deseja continuar? (s/N) " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Ss]$ ]]; then
#     echo -e "Executando docker system prune -af --volumes ${RESET}"
#     docker system prune -af --volumes
#     echo -e "Limpeza do Docker concluída.${RESET}"
# else
#     echo -e "Limpeza do Docker ignorada.${RESET}"
# fi
# separator

# -----------------------------------------------------------------------------------
# Remover template nginx
# if [ -f "$template_file" ]; then
#     echo -e "Removendo template nginx... ${RESET}"
#     rm -f "$template_file"
#     echo -e "Template $template_file removido.${RESET}"
# else
#     echo -e "Template $template_file não encontrado. Ignorando.${RESET}"
# fi
# separator
# -----------------------------------------------------------------------------------
# template_file="proxy/nginx/templates/${project_name}.conf.template"
