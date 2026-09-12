#!/usr/bin/env bash
# ============================================================
# WIWIGA — Build web avec config Firebase + clé VAPID (push web)
# Usage: FCM_VAPID_KEY=<clé publique VAPID> ./tool/build-web-fcm.sh
# Autres vars surchargeables (défauts = projet wiwiga-d9a7e) :
#   FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, FIREBASE_PROJECT_ID,
#   FIREBASE_SENDER_ID, FIREBASE_APP_ID
# Sans FCM_VAPID_KEY : build OK mais getToken() retourne null
# (inbox in_app en repli, cf. docs/FCM_SETUP.md §4).
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
FCM_VAPID_KEY="${FCM_VAPID_KEY:-}"
# CanvasKit auto-hébergé (bundle build/web/canvaskit/) : évite le CDN
# www.gstatic.com (QUIC bloqué / réseau instable côté client).
CANVASKIT_URL="${FLUTTER_WEB_CANVASKIT_URL:-canvaskit/}"

if [ -z "$FCM_VAPID_KEY" ]; then
  echo "[WIWIGA] AVERTISSEMENT : FCM_VAPID_KEY vide — push web désactivé (repli inbox)."
fi

# Service worker synchronisé avec la même config
FIREBASE_API_KEY="$FIREBASE_API_KEY" FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" FIREBASE_SENDER_ID="$FIREBASE_SENDER_ID" \
FIREBASE_APP_ID="$FIREBASE_APP_ID" ./tool/setup-fcm-web.sh

export PATH="/home/franckylab/projets/flutter/bin:$PATH"
flutter build web \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_SENDER_ID="$FIREBASE_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  --dart-define=FCM_VAPID_KEY="$FCM_VAPID_KEY" \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL="$CANVASKIT_URL"

echo "[WIWIGA] Build web OK : $APP_DIR/build/web"
