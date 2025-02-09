#!/bin/bash

sudo apt-get update

sudo apt-get install -y ca-certificates curl git

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo groupadd docker

sudo usermod -aG docker $USER

newgrp docker

if ! systemctl is-active --quiet docker; then
  echo "Docker não está ativo. Tentando iniciar o Docker..."
  sudo systemctl start docker
fi

if systemctl is-active --quiet docker; then
  echo "Docker está ativo e funcionando."
  docker-compose up -d
  echo "Serviços Docker iniciados com sucesso."
else
  echo "Não foi possível iniciar o Docker. Verifique a instalação do Docker."
fi

echo "Docker e Git foram instalados com sucesso. Por favor, faça logout e login novamente para aplicar as mudanças de grupo."
