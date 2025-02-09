#!/bin/bash

source scripts/manage-network-functions.sh
source scripts/appearance.sh
source scripts/conf.sh

set -e

# Verificar se o arquivo .env existe
if [ ! -f "env/proxy.env" ]; then
    echo "${RED}Arquivo proxy.env não encontrado!${RESET}"
    exit 1
fi

# Carregar variáveis de ambiente
set -a
source env/proxy.env
set +a

separator
# Coletar informações do novo projeto
echo -e "${GREEN}Insira as informações do novo projeto:${RESET}"

echo -e "${CYAN}Nome do projeto (minusculo): ${RESET}"
read -r project_name
jumpline

echo -e "${CYAN}Subdomínio (sem o domínio principal): ${RESET}"
read -r subdomain
jumpline

echo -e "${CYAN}Link para git clone do rep: ${RESET}"
read -r gitrepo
jumpline
separator

#-----------------------------------------------------------------------------------
# Criar diretório do projeto
echo -e "${CYAN}Criando diretório do projeto... ${RESET}"
mkdir -p "app/$project_name"
separator

#-----------------------------------------------------------------------------------
# Verificar se o repositório já foi clonado
if [ -d "app/$project_name/.git" ]; then
    echo -e "${YELLOW}O repositório já existe em app/$project_name. Clone ignorado.${RESET}"
else
    # Solicitar opcionalmente a branch
    echo -e "${CYAN}Deseja clonar uma branch específica? (deixe vazio para clonar o repositório completo): ${RESET}"
    read -r branch_name

    echo "Clonando repositório $gitrepo"

    # Montar comando de clone
    if [ -n "$branch_name" ]; then
        echo -e "${CYAN}Clonando a branch ${branch_name}...${RESET}"
        git clone -b "$branch_name" --single-branch "$gitrepo" "app/$project_name"
    else
        echo -e "${CYAN}Clonando o repositório completo...${RESET}"
        git clone "$gitrepo" "app/$project_name"
    fi

    # Verificar se o clone foi bem-sucedido
    if [ $? -ne 0 ]; then
        echo -e "${RED}Falha ao clonar o repositório. Você precisará baixá-lo manualmente.${RESET}"
        exit 1
    fi
fi

#-----------------------------------------------------------------------------------

echo -e "${GREEN}Atualizando variaveis de ambiente.${RESET}"
# Adicionar variáveis ao proxy.env
echo "" >>env/proxy.env

add_or_update_env_var() {
    local var_name="$1"
    local var_value="$2"
    local file="env/proxy.env"

    if grep -q "^$var_name=" "$file"; then
        # Atualiza a variável existente
        sed -i "s|^$var_name=.*|$var_name=$var_value|" "$file"
    else
        # Adiciona a variável se ela não existir
        echo "$var_name=$var_value" >>"$file"
    fi
}

add_or_update_env_var "${project_name^^}_SUBDOMAIN" "$subdomain"
add_or_update_env_var "${project_name^^}_DOMAIN" "$subdomain.$DOMAIN"
separator

#-----------------------------------------------------------------------------------
# Criar template nginx

echo -e "${GREEN}Criando template nginx... ${RESET}"

# Localizar arquivo .template no diretório do projeto e copiá-lo
template_file=$(find app/${project_name} -maxdepth 1 -name "${project_name}.conf" -print -quit)

if [ -n "$template_file" ]; then
    cp "$template_file" "proxy/nginx/conf.d/${project_name}.conf"
    echo -e "${GREEN}Arquivo conf nginx copiado para proxy/nginx/conf.d/${project_name}.conf ${RESET}"
else
    echo -e "${RED}Nenhum arquivo .nginx encontrado em app/${project_name}${RESET}"
    jumpline
    echo -e "${YELLOW}Criando arquivo padrão ${RESET}"
    create_nginx_conf_file "$subdomain.$DOMAIN" "$project_name"
    echo -e "${GREEN}Arquivo conf nginx criado, verificar se é preciso editar. ${RESET}"

fi
separator

#-----------------------------------------------------------------------------------
# Verificar se a rede já está listada no DOCKER_NETWORKS e no env
echo -e "${GREEN}Verificando rede para o app ${project_name} ${RESET}"

network_name="${project_name}-network"

add_network_to_service "proxy/docker-compose.yml" "$network_name"
add_network_to_main "proxy/docker-compose.yml" "$network_name"

create_network_if_not_exists "$network_name"

#-----------------------------------------------------------------------------------
# Subir os containeres
echo -e "${GREEN}Deseja já criar os containeres do projeto?(s/n) ${RESET}"
echo -e "${YELLOW}será executado o comando docker compose up -d --build ${RESET}"

read -r confirmation

if [[ "$confirmation" == "s" ]]; then
    set -a && source app/"$project_name"/"$project_name".env && source env/proxy.env && set +a &&
        docker compose -f app/"$project_name"/docker-compose.yml up -d --build
fi

#-----------------------------------------------------------------------------------
# Reiniciar nginx
echo -e "${GREEN}Reiniciando nginx... ${RESET}"
docker exec nginx-proxy nginx -s reload
separator
echo -e "Projeto $project_name criado com sucesso!"
echo -e "Não esqueça de:"
echo -e "${GREEN}1. Configurar o DNS para $subdomain.$DOMAIN ${RESET}"
echo -e "${GREEN}2. Adicionar a rede $network_name ao seu docker-compose.yml ${RESET}"
echo -e "${GREEN}3. Configurar seu projeto em app/$project_name ${RESET}"
