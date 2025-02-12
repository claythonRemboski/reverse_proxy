# Manual de uso

Este projeto é um proxy reverso com NGINX e Docker, que visa facilitar a gestão de diversos aplicativos em um único servidor através de subdomínios.
Para simplificar o uso, foram criados diversos scripts que: instalam o app, baixando o projeto de um link de repositório fornecido (como github ou gitlab), sobem os containeres e fazem o mapeamento do subdomínio escolhido para o projeto instalado, direcionando cada acesso para seu respectivo aplicativo.

---

### Atenção: sempre executar os comandos na raiz do projeto
---
## *Extra: _ALIAS_ para facilitar a execução dos scripts.

Nos diversos projetos que crio e dou manutenção, tenho por costume criar diversos scripts com o objetivo de facilitar minha utilização. E por deixar todos sempre em uma pasta específica, fica cansativo pra mim ter que digitar o nome da pasta e o nome do script.sh todas as vezes que eu utilizar algum deles.

Sendo assim, criei uma alias para ser inserido no ~/.bashrc do linux. Esse alias faz com que ao digitar "make" e um nome de script, será procurada uma pasta chamada scripts, à partir do local onde foi executado o comando, e executará o script se existir.

Ou seja, ao invés de executar `bash scripts/new_app.sh`, basta digitar `make new_app` na raiz do projeto e o script será executado.

Para utilizar essa funcionalidade, basta copiar o trecho de código abaixo, colar no seu terminal linux e o alias será criado automaticamente.

```bash
# Adicionar o alias "make" ao ~/.bashrc
alias_name="make"
function_definition='make() {
    script_name="$1"
    script_path="$(pwd)/scripts/$script_name.sh"
        if [ -f "$script_path" ]; then
            bash "$script_path"
        else
            echo "Script '\''$script_name.sh'\'' não encontrado!"
    fi
}'
bashrc_file="$HOME/.bashrc"

if ! grep -q "^$alias_name()" "$bashrc_file"; then
    echo -e "\n# Função '$alias_name' para executar scripts personalizados\n$function_definition" >> "$bashrc_file"
    echo "Função '$alias_name' adicionada ao $bashrc_file."
else
    echo "A função '$alias_name' já está configurada no $bashrc_file."
fi
source "$bashrc_file" && echo "Função '$alias_name' pronta para uso."
```
---

## 1. Resumo da forma de uso:

### 1.1 - Para ambiente local:

- Para testes locais, é preciso adicionar os subdomínios utilizados ao arquivo hosts do linux. O padrão iniciado com o projeto é o subdomínio `home`.
    - Acesse o arquivo com o comando `sudo nano /etc/hosts`.
    - Acrescente uma linha ao arquivo, pode ser após a linha onde está escrito `127.0.0.1 localhost`
    - Nessa linha inclua `127.0.0.1 home.localhost`.
    - Para novos dominios, basta acrescentar um espaço e colocar no padrão: `subdominio.localhost`.

### 1.2 - Para ambiente de produção:





## 2. Guia de comandos disponíveis.
- Todo comando será `make nomedoarquivo` ou `bash scripts/nomedoarquivo.sh`

- Para iniciar o proxy reverso:
  - `make start` ou `bash scripts/start.sh`

- Para processar os templates de cada projeto (pega os templates e cria um arquivos.conf utilizados para conectar cada projeto à sua rede e fazer o mapeamento do subdominio para o projeto):
  - `make templates`

- Para criar um novo app:
  - `make newapp`
- Para iniciar container do proxy:
  - `make process-templates`

- Para instalar o docker no sistema se necessário:
  - `make docker-install`

------------------------------------------------------------------------------------------------
## Padrão de template nginx:
- todas as informações serão preenchidas e geradas automaticamente para o projeto após a execução do comando newapp.
- projeto exemplo: n8n.
  - subdominio para o n8n: automation.
  - dominio atual: claythonremboski.online

- Nome do template: n8n.conf.template (nomeprojeto.conf.template)

- Informações que serão geradas e preenchidas automaticamente no env do projeto:
  - DOMAIN_PROTOCOL: http ou https
  - NOMEDOPROJETO_DOMAIN: domínio completo com subdomínio, e será utilizado no server name. Ex:
    - N8N_DOMAIN=automation.claythonremboski.online
  - NOMEDOPROJETO_PORT: porta onde rodará o projeto.
    - N8N_PORT=5678


- Modelo exemplo nginx:
```
server {
    listen 80;
    server_name ${N8N_DOMAIN};

    location / {
        proxy_pass ${DOMAIN_PROTOCOL}://n8n:${N8N_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_read_timeout 300;
    }
}
```

------------------------------------------------------------------------------------------------
- Ao baixar pela primeira vez o projeto, executar `bash scripts/start.sh` para criar a estrutura inicial do nginx.

- Comando para listar as variaveis de ambiente e verificar se está tudo certo na pasta n8n:
  - `docker compose --env-file ../../env/proxy.env --env-file n8n.env config`
  - `docker compose --env-file ../../env/proxy.env --env-file n8n.env config | awk '/environment:/,/^[^ ]/' | sed -e 's/- //g' -e '/environment:/d'`
  - cat -A ../../env/proxy.env ./n8n.env
  - converter arquivos para unix format: `dos2unix ../../env/proxy.env ./n8n.env`

- find sem git:`find . -path '*/.git*' -prune -o -print`

- docker compose não resolve nomes compostos do env, precisa referenciar cada uma das variaveis (ex: dominio do n8n)