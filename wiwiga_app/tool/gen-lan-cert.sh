#!/usr/bin/env bash
# ============================================================
# WIWIGA — Certificat TLS auto-signé pour le dev LAN (notifications
# push sur d'autres machines : les navigateurs exigent HTTPS ou
# localhost, http://192.168.x.x verrouille les notifications).
# Génère wiwiga_app/certs/lan.crt + lan.key (SAN = IPs locales +
# localhost), montés dans le conteneur (voir docker-compose.yml).
# Usage: ./tool/gen-lan-cert.sh [IP_SUPPLÉMENTAIRE...]
# À relancer si l'IP LAN change (DHCP). Ne JAMAIS commiter certs/
# (gitignoré) ni utiliser ce cert hors dev local.
# Sur chaque machine cliente : accepter l'avertissement certificat
# une fois (Avancé → Continuer), puis autoriser les notifications.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$APP_DIR/certs"

IPS="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | grep -v '^127\.' || true)"
SAN="DNS:localhost"
# shellcheck disable=SC2068
for ip in $IPS $@; do
  SAN="$SAN,IP:$ip"
done
SAN="$SAN,IP:127.0.0.1"

mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
  -keyout "$CERT_DIR/lan.key" -out "$CERT_DIR/lan.crt" \
  -subj "/CN=wiwiga-dev-lan" \
  -addext "subjectAltName=$SAN"
chmod 600 "$CERT_DIR/lan.key"

echo "[WIWIGA] Certificat LAN : $CERT_DIR/lan.crt"
echo "[WIWIGA] SAN : $SAN"
echo "[WIWIGA] Recréez le frontend : docker compose up -d --force-recreate frontend"
