#!/bin/bash
# ==================================
# WIWIGA - Monitoring Docker
# ==================================
# Description: Affiche statut et logs des services
# Utilisation: ./docker-monitor.sh

set -e

echo "📊 ==========================================="
echo "   WIWIGA - Monitor Docker"
echo "==========================================="
echo ""

# Déterminer commande docker-compose
if command -v docker-compose &> /dev/null; then
    DC_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DC_CMD="docker compose"
else
    echo "❌ Docker Compose non disponible"
    exit 1
fi

echo "📦 STATUT DES SERVICES"
echo "-------------------------------"
$DC_CMD ps
echo ""

echo "💾 UTILISATION RESSOURCES"
echo "-------------------------------"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  $(docker ps --filter "name=wiwiga" --format "{{.Names}}") 2>/dev/null || echo "Aucun container actif"
echo ""

echo "🔍 SANTÉ DES SERVICES"
echo "-------------------------------"

# PostgreSQL
if docker ps --filter "name=wiwiga_postgres" --format "{{.Status}}" | grep -q "Up"; then
    echo "✅ PostgreSQL: UP"
    echo "   Taille DB: $($DC_CMD exec postgres psql -U wiwiga_user -d wiwiga_dev -t -c "SELECT pg_size_pretty(pg_database_size('wiwiga_dev'));" 2>/dev/null | xargs)"
else
    echo "❌ PostgreSQL: DOWN"
fi

# Redis
if docker ps --filter "name=wiwiga_redis" --format "{{.Status}}" | grep -q "Up"; then
    echo "✅ Redis: UP"
    echo "   Mémoire: $($DC_CMD exec redis redis-cli INFO memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | xargs)"
else
    echo "❌ Redis: DOWN"
fi

# Backend
if docker ps --filter "name=wiwiga_backend" --format "{{.Status}}" | grep -q "Up"; then
    echo "✅ Backend: UP"
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/health 2>/dev/null || echo "000")
    echo "   Health: HTTP $HEALTH"
else
    echo "❌ Backend: DOWN"
fi

echo ""
echo "📝 DERNIERS LOGS (Backend)"
echo "-------------------------------"
$DC_CMD logs --tail 20 backend 2>/dev/null || echo "Pas de logs"
echo ""
echo "==========================================="
echo "   Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
echo "==========================================="
