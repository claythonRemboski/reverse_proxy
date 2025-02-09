#!/bin/bash

# ======================================Frescuras =======================================
separator() {
    echo "========================================================="
}

stop() {
    echo -e "${YELLOW}Pressione Enter para continuar...${RESET}"
    read
}

jumpline() {
    printf "\n"
}

# Cores
RED="\033[31m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"
# =======================================================================================