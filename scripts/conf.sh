#!/bin/bash

create_nginx_conf_file() {
    domain="$1"
    app_name="$2"

    cat <<EOF >proxy/nginx/conf.d/${app_name}.conf
server {
    listen 80;
    server_name ${domain};
    location / {
        proxy_pass http://${app_name};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
}
