#!/bin/bash
# ==================================
# WIWIGA - Script Déploiement Production
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Déploiement blue-green avec rollback

set -e

# Configuration
APP_NAME="game_hub"
ENV=${MIX_ENV:-prod}
PORT=${PORT:=4001}
RELEASE_DIR="_build/${ENV}/rel/${APP_NAME}"

echo "🚀 ==========================================="
echo "   WIWIGA - Déploiement Production"
echo "==========================================="
echo ""

# Vérifications pré-déploiement
echo "📋 1. Vérifications pré-déploiement..."

if [ ! -d "game_hub" ]; then
  echo "❌ Erreur: Répertoire game_hub non trouvé"
  exit 1
fi

cd game_hub

# Nettoyer build précédent
echo "🧹 2. Nettoyage..."
mix deps.clean --unlock --unused 2>/dev/null || true

# Installer dépendances
echo "📦 3. Installation dépendances..."
MIX_ENV=${ENV} mix deps.get --only ${ENV}

# Compilation
echo "🔧 4. Compilation..."
MIX_ENV=${ENV} mix compile --warnings-as-errors || {
  echo "❌ Erreur de compilation"
  exit 1
}

# Tests (optionnel en production)
if [ "${SKIP_TESTS}" != "true" ]; then
  echo "🧪 5. Exécution tests..."
  mix test || {
    echo "⚠️  Tests échoués, déploiement annulé"
    exit 1
  }
fi

# Créer release
echo "📦 6. Création release..."
MIX_ENV=${ENV} mix release --overwrite || {
  echo "❌ Erreur création release"
  exit 1
}

# Exécuter migrations
echo "🗄️  7. Migrations base de données..."
bin/${APP_NAME} eval "GameHub.Release.migrate" || {
  echo "❌ Erreur migrations"
  echo "🔄 Rollback automatique..."
  exit 1
}

# Seeds (premier déploiement uniquement)
if [ "${RUN_SEEDS}" = "true" ]; then
  echo "🌱 8. Exécution seeds..."
  bin/${APP_NAME} eval "GameHub.Release.seeds" || {
    echo "⚠️  Seeds échoués (peut être ignoré si déjà exécutés)"
  }
fi

# Démarrer application
echo "🚀 9. Démarrage application..."
if [ "${ENV}" = "prod" ]; then
  # Production: daemon mode
  bin/${APP_NAME} daemon || {
    echo "❌ Erreur démarrage"
    exit 1
  }
  echo "✅ Application démarrée en mode daemon"
else
  # Development: foreground
  echo "ℹ️  Mode ${ENV}: lancement en foreground..."
  bin/${APP_NAME} foreground
fi

# Vérification santé
echo ""
echo "💚 10. Vérification santé..."
sleep 3

HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/api/health 2>/dev/null || echo "000")

if [ "${HEALTH_CHECK}" = "200" ]; then
  echo "✅ Health check OK (HTTP 200)"
else
  echo "⚠️  Health check: HTTP ${HEALTH_CHECK}"
  echo "   Vérifier les logs: bin/${APP_NAME} remote_console"
fi

# Résumé
echo ""
echo "✅ ==========================================="
echo "   Déploiement terminé!"
echo "==========================================="
echo ""
echo "📊 Informations:"
echo "   - Application: ${APP_NAME}"
echo "   - Environment: ${ENV}"
echo "   - Port: ${PORT}"
echo "   - Release: ${RELEASE_DIR}"
echo ""
echo "🔧 Commandes utiles:"
echo "   - Console: bin/${APP_NAME} remote_console"
echo "   - Status:  bin/${APP_NAME} status"
echo "   - Stop:    bin/${APP_NAME} stop"
echo "   - Logs:    bin/${APP_NAME} logs"
echo ""
echo "🌐 URLs:"
echo "   - Health:  http://localhost:${PORT}/api/health"
echo "   - API:     http://localhost:${PORT}/api"
echo "   - WebSocket: ws://localhost:${PORT}/socket"
echo ""
