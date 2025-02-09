#!/bin/bash

# ====================================== Frescuras =======================================
separator() {
    echo "========================================================="
}

# Cores
RED="\033[31m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"
# =======================================================================================
source scripts/manage-network-functions.sh
source env/proxy.env

set -e # Parar em caso de erro

# Verificar se o arquivo .env existe
if [ ! -f "env/proxy.env" ]; then
    echo -e "${RED}Arquivo proxy.env não encontrado!${RESET}"
    exit 1
fi

# Coletar informações do projeto a ser removido
separator
echo -e "${GREEN}Insira as informações do projeto a ser removido:${RESET}"
echo -e "${CYAN}Nome do projeto (minusculo): ${RESET}"
read -r project_name

# Variáveis derivadas
network_name="${project_name}-network"
template_file="proxy/nginx/templates/${project_name}.conf.template"
generated_file="proxy/nginx/conf.d/${project_name}.conf"

#Baixar os containeres:
set -a && source app/"$project_name"/"$project_name".env && source env/proxy.env && set +a &&
    docker compose -f app/"$project_name"/docker-compose.yml down

# -----------------------------------------------------------------------------------
# Remover diretório do projeto
if [ -d "app/$project_name" ]; then
    echo -e "${CYAN}Removendo diretório do projeto... ${RESET}"
    rm -rf "app/$project_name"
    echo -e "${GREEN}Diretório app/$project_name removido.${RESET}"
else
    echo -e "${YELLOW}Diretório app/$project_name não encontrado. Ignorando.${RESET}"
fi
separator

# -----------------------------------------------------------------------------------
# Remover template nginx
if [ -f "$template_file" ]; then
    echo -e "${CYAN}Removendo template nginx... ${RESET}"
    rm -f "$template_file"
    echo -e "${GREEN}Template $template_file removido.${RESET}"
else
    echo -e "${YELLOW}Template $template_file não encontrado. Ignorando.${RESET}"
fi
separator

# -----------------------------------------------------------------------------------
# Remover arquivo conf.d
if [ -f "$generated_file" ]; then
    echo -e "${CYAN}Removendo arquivo conf.d... ${RESET}"
    rm -f "$generated_file"
    echo -e "${GREEN}Arquivo $generated_file removido.${RESET}"
else
    echo -e "${YELLOW}Arquivo $generated_file não encontrado. Ignorando.${RESET}"
fi
separator

# -----------------------------------------------------------------------------------
# Remover variáveis do .env
echo -e "${CYAN}Removendo variáveis de ambiente relacionadas ao projeto... ${RESET}"

remove_env_var() {
    local var_name="$1"
    sed -i "/^$var_name=/d" env/proxy.env
}

remove_env_var "${project_name^^}_SUBDOMAIN"
remove_env_var "${project_name^^}_DOMAIN"
remove_env_var "${project_name^^}_PORT"

echo -e "${GREEN}Variáveis relacionadas ao projeto removidas do env/proxy.env.${RESET}"
separator

remove_network_from_service "proxy/docker-compose.yml" "$network_name"
remove_network_from_main "proxy/docker-compose.yml" "$network_name"
remove_network_in_docker_and_proxy_env "proxy/docker-compose.yml" "$network_name"

# -----------------------------------------------------------------------------------
# Remover rede Docker
if docker network inspect "$network_name" >/dev/null 2>&1; then
    echo -e "${CYAN}Removendo rede Docker $network_name... ${RESET}"
    docker network rm "$network_name"
    echo -e "${GREEN}Rede Docker $network_name removida.${RESET}"
else
    echo -e "${YELLOW}Rede Docker $network_name não encontrada. Ignorando.${RESET}"
fi
separator

# -----------------------------------------------------------------------------------
# Nova seção: Limpeza de containers Docker
echo -e "${CYAN}Procurando e removendo containers relacionados ao projeto... ${RESET}"

# Encontrar e parar containers que contenham o nome do projeto
if docker ps -a --format '{{.Names}}' | grep -q "$project_name"; then
    echo -e "${CYAN}Parando containers relacionados ao projeto... ${RESET}"
    docker ps -a --format '{{.Names}}' | grep "$project_name" | xargs -r docker stop
    
    echo -e "${CYAN}Removendo containers relacionados ao projeto... ${RESET}"
    docker ps -a --format '{{.Names}}' | grep "$project_name" | xargs -r docker rm
    echo -e "${GREEN}Containers removidos com sucesso.${RESET}"
else
    echo -e "${YELLOW}Nenhum container relacionado ao projeto encontrado.${RESET}"
fi
separator

# Limpeza geral do Docker
# echo -e "${CYAN}Executando limpeza geral do Docker... ${RESET}"
# echo -e "${YELLOW}Isso removerá todos os recursos não utilizados (volumes, redes, containers e imagens).${RESET}"
# read -p "Deseja continuar? (s/N) " -n 1 -r
# echo
# if [[ $REPLY =~ ^[Ss]$ ]]; then
#     echo -e "${CYAN}Executando docker system prune -af --volumes ${RESET}"
#     docker system prune -af --volumes
#     echo -e "${GREEN}Limpeza do Docker concluída.${RESET}"
# else
#     echo -e "${YELLOW}Limpeza do Docker ignorada.${RESET}"
# fi
# separator

# -----------------------------------------------------------------------------------
echo -e "${GREEN}Projeto $project_name removido com sucesso!${RESET}"