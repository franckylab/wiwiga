#!/bin/bash
echo "[WIWIGA] File watcher démarré - rebuild auto activé (polling + inotify)"

# Fonction de build (mêmes defines que le Dockerfile.dev : les ARG de build
# n'existent plus au runtime, on relit l'environnement du conteneur —
# voir `environment:` du service frontend dans docker-compose.yml).
# Le SW est régénéré à chaque fois (web/ non monté : sinon le conteneur
# servirait un SW désynchronisé des clés).
do_build() {
  echo "[WIWIGA] Fichiers modifiés - rebuild en cours..."
  cd /app && \
  FIREBASE_API_KEY="${FIREBASE_API_KEY:-AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk}" \
  FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-wiwiga-d9a7e.firebaseapp.com}" \
  FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-wiwiga-d9a7e}" \
  FIREBASE_SENDER_ID="${FIREBASE_SENDER_ID:-660834792043}" \
  FIREBASE_APP_ID="${FIREBASE_APP_ID:-1:660834792043:web:c2737e7e778f743333f72e}" \
  ./tool/setup-fcm-web.sh && \
  flutter build web --profile \
    --dart-define=FLUTTER_WEB_CANVASKIT_URL="${FLUTTER_WEB_CANVASKIT_URL:-canvaskit/}" \
    --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk}" \
    --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-wiwiga-d9a7e.firebaseapp.com}" \
    --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-wiwiga-d9a7e}" \
    --dart-define=FIREBASE_SENDER_ID="${FIREBASE_SENDER_ID:-660834792043}" \
    --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID:-1:660834792043:web:c2737e7e778f743333f72e}" \
    --dart-define=FCM_VAPID_KEY="${FCM_VAPID_KEY:-BEgSTIDMIisP3WrsNPY6GxCTiag_e5qcEZyZ3k6-j5ipo35TUUmjoBs7E8Xgh2T7V9hPLRRgDsLkSdVFTH3dmaE}" \
    2>&1 | tail -20
  cp -r /app/build/web/* /usr/share/nginx/html/
  echo "[WIWIGA] Rebuild terminé - page prête à rafraîchir (F5)"
}

# Essayer inotify, fallback polling si inotify ne détecte pas (bind mount)
# Polling: vérifie le hash des fichiers toutes les 2s
LAST_HASH=""
while true; do
  # Tentative inotify avec timeout 2s (si supporté)
  if command -v inotifywait >/dev/null 2>&1; then
    if timeout 2 inotifywait -r -e modify,create,delete,move --include '\.(dart|yaml|json)$' /app/lib /app/pubspec.yaml /app/assets 2>/dev/null; then
      do_build
      continue
    fi
  fi

  # Polling fallback: hash des mtimes (bind mount → inotify peut ne pas propager)
  CURRENT_HASH=$(find /app/lib /app/pubspec.yaml /app/assets -type f \( -name "*.dart" -o -name "*.yaml" -o -name "*.json" \) 2>/dev/null | xargs stat -c '%n %Y' 2>/dev/null | md5sum | cut -d' ' -f1)
  if [ -z "$LAST_HASH" ]; then
    LAST_HASH="$CURRENT_HASH"
  elif [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
    LAST_HASH="$CURRENT_HASH"
    do_build
  fi
  sleep 2
done
