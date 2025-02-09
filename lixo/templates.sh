#!/bin/bash

# ======================================Frescuras =======================================
separator() {
    echo "========================================================="
}

jumpline() {
    printf "\n"
}

stop() {
    echo -e "${YELLOW}Pressione Enter para continuar...${YELLOW}"
    read -p 
}

# Cores
RED="\033[31m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"
# =======================================================================================

set -e # Parar em caso de erro

# Carregar variáveis de ambiente
if [ -f "env/proxy.env" ]; then
    set -a
    source env/proxy.env
    set +a
else
    echo -e "${RED}Arquivo proxy.env não encontrado!${RESET}"
    exit 1
fi

# Limpar diretório conf.d
mkdir -p proxy/nginx/conf.d

rm -f proxy/nginx/conf.d/*.conf

# Processar templates
for template in proxy/nginx/templates/*.conf.template; do
    if [ -f "$template" ]; then
        filename=$(basename "$template" .template)
        output_file="proxy/nginx/conf.d/${filename}"
        echo "Processando template: $filename"
        envsubst '${N8N_DOMAIN} ${LARAVEL_DOMAIN} ${DOMAIN_PROTOCOL} ${N8N_PORT} ${LARAVEL_PORT}' <"$template" >"$output_file"
    fi
done

echo "Templates processados com sucesso!"
