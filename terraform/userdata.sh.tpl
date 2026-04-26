#!/bin/bash
###############################################################
# terraform/userdata.sh.tpl
# Runs ONCE on first EC2 boot via cloud-init.
# Installs Docker, clones repo, starts Hermes via Docker Compose.
###############################################################
set -euo pipefail
exec > >(tee /var/log/hermes-init.log | logger -t hermes-init) 2>&1

echo "=== Hermes Agent Bootstrap — $(date) ==="

# ── System updates ────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl git ca-certificates gnupg lsb-release \
  nginx certbot python3-certbot-nginx \
  awscli jq unzip

# ── Docker ────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker
usermod -aG docker ubuntu

# ── Clone repo ────────────────────────────────────────────────
DEPLOY_DIR="/opt/${project_name}"
git clone https://github.com/${github_repo}.git "$DEPLOY_DIR" || true
chown -R ubuntu:ubuntu "$DEPLOY_DIR"

# ── Write .env ────────────────────────────────────────────────
cat > "$DEPLOY_DIR/.env" <<'ENVEOF'
OPENROUTER_API_KEY=${openrouter_key}
HERMES_MODEL=${hermes_model}
ENVEOF

chown ubuntu:ubuntu "$DEPLOY_DIR/.env"
chmod 600 "$DEPLOY_DIR/.env"

# ── Nginx reverse-proxy ───────────────────────────────────────
cat > /etc/nginx/sites-available/hermes <<'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    # Hermes gateway UI (if gateway is started)
    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_read_timeout 600s;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/hermes /etc/nginx/sites-enabled/hermes
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ── Systemd service for Hermes ────────────────────────────────
cat > /etc/systemd/system/hermes.service <<SVCEOF
[Unit]
Description=Hermes Agent
After=docker.service network-online.target
Requires=docker.service

[Service]
User=ubuntu
WorkingDirectory=$DEPLOY_DIR
EnvironmentFile=$DEPLOY_DIR/.env
ExecStart=/usr/bin/docker compose up --build
ExecStop=/usr/bin/docker compose down
Restart=on-failure
RestartSec=30
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable hermes
systemctl start hermes

echo "=== Bootstrap complete — $(date) ==="
echo "=== Hermes Agent starting at http://$(curl -s ifconfig.me) ==="
