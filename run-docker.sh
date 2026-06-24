#!/bin/bash
# ==================================
# WIWIGA - Script Exécution Docker
# ==================================
# Description: Lance tout l'environnement avec Docker Compose
# Utilisation: ./run-docker.sh

set -e

echo "🚀 ==========================================="
echo "   WIWIGA - Lancement avec Docker"
echo "==========================================="
echo ""

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

echo "✅ Docker détecté: $(docker --version)"
echo ""

# Déterminer commande docker-compose
if command -v docker-compose &> /dev/null; then
    DC_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DC_CMD="docker compose"
else
    echo "❌ Docker Compose non disponible"
    echo "   Installer: sudo apt install docker-compose-plugin"
    exit 1
fi

echo "✅ Docker Compose: $($DC_CMD version)"
echo ""

# Arrêter containers existants
echo "🔄 Nettoyage containers existants..."
$DC_CMD down 2>/dev/null || true
echo ""

# Build images
echo "🔨 Build des images Docker..."
$DC_CMD build --no-cache
echo ""

# Lancer services
echo "🚀 Lancement des services..."
$DC_CMD up -d
echo ""

# Attendre que les services soient prêts
echo "⏳ Attente initialisation services..."
sleep 10

# Vérifier santé PostgreSQL
echo "🔍 Vérification PostgreSQL..."
for i in {1..30}; do
    if $DC_CMD exec postgres pg_isready -U wiwiga &> /dev/null; then
        echo "✅ PostgreSQL prêt"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL ne démarre pas"
        $DC_CMD logs postgres
        exit 1
    fi
    sleep 2
done

# Vérifier santé Redis
echo "🔍 Vérification Redis..."
for i in {1..30}; do
    if $DC_CMD exec redis redis-cli ping &> /dev/null; then
        echo "✅ Redis prêt"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Redis ne démarre pas"
        $DC_CMD logs redis
        exit 1
    fi
    sleep 2
done

# Exécuter migrations
echo "🗄️  Exécution migrations..."
$DC_CMD exec backend mix ecto.create || true
$DC_CMD exec backend mix ecto.migrate
echo ""

# Charger données initiales
echo "🌱 Chargement données initiales..."
$DC_CMD exec backend mix run priv/repo/seeds.exs
echo ""

# Vérifier santé API
echo "🔍 Vérification API..."
sleep 5
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/health)

if [ "$HEALTH" = "200" ]; then
    echo "✅ API opérationnelle (HTTP 200)"
else
    echo "⚠️  API retourne HTTP $HEALTH"
    echo "   Voir logs: $DC_CMD logs backend"
fi

echo ""
echo "✅ ==========================================="
echo "   WIWIGA Backend - Opérationnel!"
echo "==========================================="
echo ""
echo "📊 Services actifs:"
$DC_CMD ps
echo ""
echo "🌐 URLs:"
echo "   API: http://localhost:8000/api"
echo "   Health: http://localhost:8000/api/health"
echo "   WebSocket: ws://localhost:8000/socket"
echo ""
echo "📝 Commandes utiles:"
echo "   Voir logs: $DC_CMD logs -f backend"
echo "   Console Elixir: $DC_CMD exec backend mix phx.remote"
echo "   Tests: $DC_CMD exec backend mix test"
echo "   Arrêter: $DC_CMD down"
echo "   Redémarrer: $DC_CMD restart backend"
echo ""
