#!/bin/bash

# ==========================================
# Funções Auxiliares (Nível 1)
# ==========================================

# Verifica a existência de uma rede Docker
# Parâmetros: $1 - Nome da rede
# Retorno: 0 se existe, 1 se não existe
check_network_exists() {
    local network="$1"
    docker network inspect "$network" >/dev/null 2>&1
    return $?
}

# ==========================================
# Funções de Operação (Nível 2)
# ==========================================

# Cria uma nova rede Docker se não existir
# Parâmetros: $1 - Nome da rede
# Retorno: 0 se criou, 1 se já existia
create_network_if_not_exists() {
    local network="$1"
    if ! check_network_exists "$network"; then
        echo "Criando rede $network..."
        docker network create "$network"
        echo "Rede $network criada."
        return 0
    fi
    echo "Rede $network já existe. Pulando criação."
}


#===============================================================================================================================================================

# Remove uma rede Docker se não estiver em uso
# Parâmetros: $1 - Nome da rede
# Retorno: 0 se removeu, 1 se em uso, 2 se não existe
remove_network_forced() {
    local network="$1"
    if check_network_exists "$network"; then
        echo "Removendo rede $network forçadamente..."
        docker network rm -f "$network" || docker network rm "$network"
        return 0
    fi
    echo "Rede $network não existe."
    return 2
}

# Atualiza as redes no arquivo docker-compose.yml
# Parâmetros: $1 - Arquivo docker-compose.yml
#            $2 - Lista de redes a serem configuradas
update_networks_in_compose() {
    local docker_compose_file="$1"
    local networks="$2"
    local tmp_file="/tmp/docker-compose.tmp"
    local in_services=false
    local in_nginx_proxy=false
    local networks_added=false

    # Process the file line by line
    while IFS= read -r line; do
        # Track which section we're in
        if [[ "$line" =~ ^services: ]]; then
            in_services=true
            echo "$line" >>"$tmp_file"
            continue
        elif [[ "$line" =~ ^networks: ]]; then
            in_services=false
            # Skip this line for now - we'll add networks section at the end
            continue
        fi

        # Handle services section
        if $in_services; then
            if [[ "$line" =~ ^[[:space:]]*nginx-proxy: ]]; then
                in_nginx_proxy=true
                echo "$line" >>"$tmp_file"
                continue
            elif [[ "$line" =~ ^[[:space:]]*[a-zA-Z] ]] && $in_nginx_proxy; then
                in_nginx_proxy=false
            fi

            # Skip existing networks in nginx-proxy service
            if $in_nginx_proxy && [[ "$line" =~ ^[[:space:]]*networks: ]]; then
                continue
            elif $in_nginx_proxy && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*[a-zA-Z] ]] && [[ "$line" =~ "networks:" ]]; then
                continue
            fi
        fi

        # If we're at the end of nginx-proxy service and haven't added networks
        if $in_nginx_proxy && [[ "$line" =~ ^[[:space:]]*restart: ]]; then
            echo "$line" >>"$tmp_file"
            if [ ! -z "$networks" ]; then
                echo "    networks:" >>"$tmp_file"
                for network in $networks; do
                    echo "      - $network" >>"$tmp_file"
                done
            fi
            continue
        fi

        # Write the current line if it's not part of the networks section
        if ! [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$ ]] || ! [[ "$line" =~ ^[[:space:]]*external:[[:space:]]*true[[:space:]]*$ ]]; then
            echo "$line" >>"$tmp_file"
        fi
    done <"$docker_compose_file"

    # Add the networks section at the end if networks exist
    if [ ! -z "$networks" ]; then
        echo "networks:" >>"$tmp_file"
        for network in $networks; do
            echo "  $network:" >>"$tmp_file"
            echo "    external: true" >>"$tmp_file"
        done
    fi

    mv "$tmp_file" "$docker_compose_file"
}

# Atualiza a variável DOCKER_NETWORKS no arquivo proxy.env
# Parâmetros: $1 - Arquivo proxy.env
#            $2 - Rede a ser removida
update_networks_in_env() {
    local env_file="$1"
    local network_to_remove="$2"
    local tmp_file="/tmp/proxy.env.tmp"

    # Lê o valor atual de DOCKER_NETWORKS
    local current_networks=$(grep "^DOCKER_NETWORKS=" "$env_file" | cut -d'"' -f2)

    # Remove a rede especificada e quaisquer espaços extras
    local new_networks=$(echo "$current_networks" | sed "s/$network_to_remove//g" | tr -s ' ' | sed 's/^ *//;s/ *$//')

    # Atualiza o arquivo
    sed "s/^DOCKER_NETWORKS=.*$/DOCKER_NETWORKS=\"$new_networks\"/" "$env_file" >"$tmp_file"
    mv "$tmp_file" "$env_file"
}
# ==========================================
# Funções Principais (Nível 3)
# ==========================================

# Adiciona novas redes ao Docker e ao docker-compose.yml
# Parâmetros: $1 - Arquivo docker-compose.yml
#            $2 - Lista de redes a serem adicionadas
add_networks() {
    local docker_compose_file="$1"
    local networks="$2"

    update_networks_in_compose "$docker_compose_file" "$networks"

    echo "Verificando redes Docker..."
    for network in $networks; do
        create_network_if_not_exists "$network"
    done
}

# Remove redes do Docker e do docker-compose.yml
# Parâmetros: $1 - Arquivo docker-compose.yml
#            $2 - Lista de redes a serem removidas
# Remove redes do Docker e do docker-compose.yml
# Parâmetros: $1 - Arquivo docker-compose.yml
#            $2 - Lista de redes a serem removidas
remove_network_in_docker_and_proxy_env() {
    local docker_compose_file="$1"
    local networks_to_remove="$2"
    local env_file="env/proxy.env"

    # Remove as redes do Docker
    remove_network_forced "$network"
    # Remove as redes do env
    update_networks_in_env "$env_file" "$network"
}

#=================================================================================================
#adiciona rede ao servico nginx
add_network_to_service() {
    file_path="$1"
    network_name="$2"

    # Verifica se networks já existe no arquivo (com 4 espaços no início para estar dentro do nginx-proxy)
    if ! grep -q "    networks:" "$file_path"; then
        # Adiciona networks após nginx-proxy
        sed -i '/nginx-proxy:/a\    networks:' "$file_path"
        # Adiciona a rede
        sed -i '/    networks:/a\      - '"$network_name" "$file_path"
    else
        # Verifica se a rede específica já existe
        if ! grep -q "      - $network_name" "$file_path"; then
            # Adiciona apenas a rede
            sed -i '/    networks:/a\      - '"$network_name" "$file_path"
        fi
    fi
}

# Remove uma rede do serviço nginx-proxy
remove_network_from_service() {
    file_path="$1"
    network_name="$2"

    # Remove a linha da rede específica
    sed -i "/      - $network_name/d" "$file_path"

    # Se não houver mais redes, remove a linha networks:
    if ! grep -q "      -" "$file_path"; then
        sed -i "/    networks:/d" "$file_path"
    fi
}

# Adiciona uma rede na seção principal de networks
add_network_to_main() {
    local docker_compose_file="$1"
    local network_name="$2"
    local tmp_file="/tmp/docker-compose.tmp"
    local networks_section_exists=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^networks: ]]; then
            networks_section_exists=true
            echo "$line" >>"$tmp_file"
            # Verifica se a rede já existe
            local network_exists=false
            while IFS= read -r network_line; do
                if [[ "$network_line" =~ ^[[:space:]]*$network_name: ]]; then
                    network_exists=true
                fi
                echo "$network_line" >>"$tmp_file"
            done
            if ! $network_exists; then
                echo "  $network_name:" >>"$tmp_file"
                echo "    external: true" >>"$tmp_file"
            fi
        else
            echo "$line" >>"$tmp_file"
        fi
    done <"$docker_compose_file"

    if ! $networks_section_exists; then
        echo "" >>"$tmp_file" # Linha em branco para separação
        echo "networks:" >>"$tmp_file"
        echo "  $network_name:" >>"$tmp_file"
        echo "    external: true" >>"$tmp_file"
    fi

    mv "$tmp_file" "$docker_compose_file"
}

# Remove uma rede da seção principal de networks
remove_network_from_main() {
    local docker_compose_file="$1"
    local network_name="$2"
    local tmp_file="/tmp/docker-compose.tmp"
    local in_networks=false
    local networks_empty=true

    while IFS= read -r line; do
        if [[ "$line" =~ ^networks: ]]; then
            in_networks=true
            echo "$line" >>"$tmp_file"
        elif $in_networks && [[ "$line" =~ ^[[:space:]]*[a-zA-Z] ]]; then
            if ! [[ "$line" =~ ^[[:space:]]*$network_name: ]]; then
                echo "$line" >>"$tmp_file"
                networks_empty=false
            else
                # Pula a linha external: true
                read -r
            fi
        elif ! $in_networks; then
            echo "$line" >>"$tmp_file"
        fi
    done <"$docker_compose_file"

    # Remove a seção networks se estiver vazia
    if $networks_empty; then
        sed -i '/^networks:$/d' "$tmp_file"
    fi

    mv "$tmp_file" "$docker_compose_file"
}
