#!/bin/bash

############################################################################
# Script para instalar um novo aplicativo na estrutura.
#  - Solicita as informações básicas do projeto (nome,subdomínio, link do repositório)
#  - Cria pasta do projeto em app
#  - Clona o repositório dentro da pasta do app
#  - Verifica se deseja instalar uma branch específica e faz a instalação se necessário.
#  - Adiciona informações ao env do proxy.
#  - Cria template do nginx para o projeto.
#  - Verifica e cria se necessário a rede.
#  - Sobe os containeres se for solicitado.
#  - Reinicia o nginx e exibe informações finais.
#
# Autor: Claython Remboski
############################################################################

source scripts/utils/network_manager.sh
source scripts/utils/colors.sh
source scripts/utils/text.sh
source scripts/conf_creator.sh

set -e

# Verificar se o arquivo .env existe
if [ ! -f "env/proxy.env" ]; then
    red "Arquivo proxy.env não encontrado!"
    exit 1
fi

# Carregar variáveis de ambiente
set -a
source env/proxy.env
set +a

separator
# Coletar informações do novo projeto
green "Insira as informações do novo projeto:"

blue "Nome do projeto (minusculo): "
read -r project_name
jumpline

blue "Subdomínio (sem o domínio principal): "
read -r subdomain
jumpline

blue "Link para git clone do rep: "
read -r gitrepo
jumpline
separator

#-----------------------------------------------------------------------------------
# Criar diretório do projeto
blue "Criando diretório do projeto... "
mkdir -p "app/$project_name"
separator

#-----------------------------------------------------------------------------------
# Verificar se o repositório já foi clonado
if [ -d "app/$project_name/.git" ]; then
    yellow "O repositório já existe em app/$project_name. Clone ignorado."
else
    # Solicitar opcionalmente a branch
    blue "Deseja clonar uma branch específica? (deixe vazio para clonar o repositório completo): "
    read -r branch_name

    blue "Clonando repositório $gitrepo"

    # Montar comando de clone
    if [ -n "$branch_name" ]; then
        blue "Clonando a branch ${branch_name}..."
        git clone -b "$branch_name" --single-branch "$gitrepo" "app/$project_name"
    else
        blue "Clonando o repositório completo..."
        git clone "$gitrepo" "app/$project_name"
    fi

    # Verificar se o clone foi bem-sucedido
    if [ $? -ne 0 ]; then
        red "Falha ao clonar o repositório. Você precisará baixá-lo manualmente."
        exit 1
    fi
fi

#-----------------------------------------------------------------------------------

green "Atualizando variaveis de ambiente."
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

green "Criando template nginx... "

# Localizar arquivo .template no diretório do projeto e copiá-lo
template_file=$(find app/${project_name} -maxdepth 1 -name "${project_name}.conf" -print -quit)

if [ -n "$template_file" ]; then
    cp "$template_file" "proxy/nginx/conf.d/${project_name}.conf"
    green "Arquivo conf nginx copiado para proxy/nginx/conf.d/${project_name}.conf "
else
    red "Nenhum arquivo .nginx encontrado em app/${project_name}"
    jumpline
    yellow "Criando arquivo padrão "
    create_nginx_conf_file "$subdomain.$DOMAIN" "$project_name"
    green "Arquivo conf nginx criado, verificar se é preciso editar. "

fi
separator

#-----------------------------------------------------------------------------------
# Verificar se a rede já está listada no DOCKER_NETWORKS e no env
green "Verificando rede para o app ${project_name} "

network_name="${project_name}-network"

add_network_to_service "proxy/docker-compose.yml" "$network_name"
add_network_to_main "proxy/docker-compose.yml" "$network_name"

create_network_if_not_exists "$network_name"

#-----------------------------------------------------------------------------------
# Subir os containeres
green "Deseja já criar os containeres do projeto?(s/n) "
yellow "será executado o comando docker compose up -d --build "

read -r confirmation

if [[ "$confirmation" == "s" ]]; then
    set -a && source app/"$project_name"/"$project_name".env && source env/proxy.env && set +a &&
        docker compose -f app/"$project_name"/docker-compose.yml up -d --build
fi

#-----------------------------------------------------------------------------------
# Reiniciar nginx
green "Reiniciando nginx... "
docker exec nginx-proxy nginx -s reload
separator
green "Projeto $project_name criado com sucesso!"

green "Não esqueça de configurar o DNS para $subdomain.$DOMAIN "
