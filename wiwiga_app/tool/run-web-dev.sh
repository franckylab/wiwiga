#!/usr/bin/env bash
# ============================================================
# WIWIGA — Lancement dev Web avec config Firebase complète
# Usage: FCM_VAPID_KEY=<clé publique VAPID> ./tool/run-web-dev.sh
# Arguments supplémentaires transmis à `flutter run`
# (ex. --web-browser-flag=--headless=new pour un test sans UI).
# Sans FCM_VAPID_KEY : getToken() retourne null sur Web et AUCUN
# token n'est envoyé au backend (table device_tokens vide) —
# d'où l'échec explicite ci-dessous au lieu d'un silence.
# Clé publique VAPID : console Firebase → Cloud Messaging →
# Web Push certificates. (La clé PRIVÉE ne sert qu'à la console.)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
cd "$APP_DIR"

FIREBASE_API_KEY="${FIREBASE_API_KEY:-AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk}"
FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-wiwiga-d9a7e.firebaseapp.com}"
FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-wiwiga-d9a7e}"
FIREBASE_SENDER_ID="${FIREBASE_SENDER_ID:-660834792043}"
FIREBASE_APP_ID="${FIREBASE_APP_ID:-1:660834792043:web:c2737e7e778f743333f72e}"
CANVASKIT_URL="${FLUTTER_WEB_CANVASKIT_URL:-canvaskit/}"
FCM_VAPID_KEY="${FCM_VAPID_KEY:-}"

if [ -z "$FCM_VAPID_KEY" ]; then
  echo "[WIWIGA] ERREUR : FCM_VAPID_KEY vide." >&2
  echo "  Sur Web, getToken() retourne null sans elle et aucun token push" >&2
  echo "  n'est enregistré (device_tokens reste vide)." >&2
  echo "  Relance avec : FCM_VAPID_KEY=<clé publique VAPID> ./tool/run-web-dev.sh" >&2
  exit 1
fi

# Service worker synchronisé avec la même config
FIREBASE_API_KEY="$FIREBASE_API_KEY" FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" FIREBASE_SENDER_ID="$FIREBASE_SENDER_ID" \
FIREBASE_APP_ID="$FIREBASE_APP_ID" ./tool/setup-fcm-web.sh

export PATH="/home/franckylab/projets/flutter/bin:$PATH"
echo "[WIWIGA] Dev Web : rebuild COMPLET (les --dart-define sont compilés :"
echo "  un hot reload (r) ou hot restart (R) NE suffit PAS après changement"
echo "  de clé — toujours arrêter (q) puis relancer ce script)."
exec flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_SENDER_ID="$FIREBASE_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  --dart-define=FCM_VAPID_KEY="$FCM_VAPID_KEY" \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL="$CANVASKIT_URL" \
  "$@"
