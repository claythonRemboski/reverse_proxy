#!/bin/bash

############################################################################
# Lista de cores para implementar nos scripts
############################################################################

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

red() {
    local message=$1
    echo -e "${RED}${message}${RESET}"
}

green() {
    local message=$1
    echo -e "${GREEN}${message}${RESET}"
}

blue() {
    local message=$1
    echo -e "${BLUE}${message}${RESET}"
}

yellow() {
    local message=$1
    echo -e "${YELLOW}${message}${RESET}"
}