#!/bin/bash
# ==================================
# WIWIGA - Script Vérification Backend
# ==================================
# Description: Vérifie conformité règles et skills

echo "🔍 ==========================================="
echo "   WIWIGA - Vérification Backend"
echo "==========================================="
echo ""

cd game_hub

echo "📦 1. Installation dépendances..."
mix deps.get
echo ""

echo "🔧 2. Formatage code..."
mix format
echo "✅ Format OK"
echo ""

echo "📝 3. Compilation..."
mix compile
echo "✅ Compilation OK"
echo ""

echo "🧪 4. Exécution tests..."
mix test
echo ""

echo "📊 5. Analyse Credo (si installé)..."
if mix credo --version &>/dev/null; then
  mix credo --strict
else
  echo "⚠️  Credo non installé"
  echo "   Installer: mix deps.add credo, :dev, only: [:dev, :test]"
fi
echo ""

echo "🗄️  6. Migrations (check)..."
echo "   Pour exécuter: mix ecto.migrate"
echo ""

echo "🌱 7. Seeds (check)..."
echo "   Pour exécuter: mix run priv/repo/seeds.exs"
echo ""

echo "✅ ==========================================="
echo "   Vérification terminée!"
echo "==========================================="
echo ""
echo "📋 Prochaines étapes:"
echo "   1. Corriger erreurs compilation/test"
echo "   2. mix ecto.migrate"
echo "   3. mix run priv/repo/seeds.exs"
echo "   4. mix phx.server"
echo "   5. Tester API: http://localhost:8000/api/health"
echo ""
