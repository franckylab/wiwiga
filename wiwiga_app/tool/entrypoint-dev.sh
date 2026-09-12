#!/bin/bash
# ============================================================
# WIWIGA — Entrypoint frontend dev : TLS jamais bloquant.
# - Si l'hôte a généré un cert LAN (tool/gen-lan-cert.sh, monté en
#   /etc/nginx/certs-host), on l'utilise (SAN = IPs LAN réelles).
# - Sinon on garde/génère un cert local (localhost) : nginx démarre
#   toujours, HTTPS toujours disponible.
# Puis watcher rebuild + nginx au premier plan.
# ============================================================
set -e

mkdir -p /etc/nginx/certs
if [ -f /etc/nginx/certs-host/lan.crt ] && [ -f /etc/nginx/certs-host/lan.key ]; then
  cp /etc/nginx/certs-host/lan.crt /etc/nginx/certs/lan.crt
  cp /etc/nginx/certs-host/lan.key /etc/nginx/certs/lan.key
  echo "[WIWIGA] Certificat TLS LAN de l'hôte utilisé."
elif [ ! -f /etc/nginx/certs/lan.crt ] || [ ! -f /etc/nginx/certs/lan.key ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout /etc/nginx/certs/lan.key -out /etc/nginx/certs/lan.crt \
    -subj "/CN=wiwiga-dev" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null || \
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
    -keyout /etc/nginx/certs/lan.key -out /etc/nginx/certs/lan.crt \
    -subj "/CN=wiwiga-dev"
  echo "[WIWIGA] Certificat TLS local généré (localhost uniquement)."
fi
chmod 600 /etc/nginx/certs/lan.key
nginx -t

/auto-rebuild.sh &
exec nginx -g 'daemon off;'
