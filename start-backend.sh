#!/bin/bash
# ============================================================
# Script: start-backend.sh
# Description: Démarrage rapide du backend WIWIGA
# Auteur: WIWIGA Team
# Date: 2026-06-23
# ============================================================

echo "🚀 Démarrage du backend WIWIGA..."

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Docker non installé"
    echo ""
    echo "Option 1: Installer Docker"
    echo "  sudo apt install docker.io docker-compose"
    echo ""
    echo "Option 2: Installer Elixir directement"
    echo "  sudo apt install elixir erlang-dev"
    echo "  cd game_hub && mix deps.get && mix phx.server"
    exit 1
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose non installé"
    echo "  sudo apt install docker-compose"
    exit 1
fi

cd /mnt/DONNEES/projets/wiwiga/game_hub

echo "📦 Construction des images Docker..."
docker-compose build

echo "🗄️  Démarrage de PostgreSQL + Redis..."
docker-compose up -d postgres redis

echo "⏳ Attente que les services soient prêts..."
sleep 10

echo "🎮 Démarrage de l'application Phoenix..."
docker-compose up web

echo "✅ Backend WIWIGA démarré sur http://localhost:4000"
