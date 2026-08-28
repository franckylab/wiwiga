#!/bin/bash
echo "[WIWIGA] File watcher démarré - rebuild auto activé (polling + inotify)"

# Fonction de build
do_build() {
  echo "[WIWIGA] Fichiers modifiés - rebuild en cours..."
  cd /app && flutter build web --profile 2>&1 | tail -20
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
