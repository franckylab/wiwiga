#!/bin/bash
echo "[WIWIGA] File watcher démarré - rebuild auto activé"
while true; do
  inotifywait -r -e modify,create,delete,move --include '\.\(dart\|yaml\)$' /app/lib /app/pubspec.yaml 2>/dev/null
  echo "[WIWIGA] Fichiers modifiés - rebuild en cours..."
  cd /app && flutter build web --profile 2>&1 | tail -5
  cp -r /app/build/web/* /usr/share/nginx/html/
  echo "[WIWIGA] Rebuild terminé - page prête à rafraîchir"
done
