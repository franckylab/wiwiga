#!/bin/bash
# ==================================
# WIWIGA - Vérification Build Docker
# ==================================

echo "🔍 ==========================================="
echo "   Vérification Build Docker"
echo "==========================================="
echo ""

LOG_FILE="/tmp/docker-build-v7.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "⏳ Build pas encore terminé ou log non trouvé"
    echo "   Fichier attendu: $LOG_FILE"
    exit 1
fi

echo "📊 Analyse du build..."
echo ""

# Chercher erreurs
ERRORS=$(grep -i "error:" "$LOG_FILE" | grep -v "warning:" | wc -l)
COMPILE_ERRORS=$(grep "== Compilation error" "$LOG_FILE" | wc -l)
WARNINGS=$(grep -i "warning:" "$LOG_FILE" | wc -l)
SUCCESS=$(grep "Compiled" "$LOG_FILE" | wc -l)

echo "📈 Statistiques:"
echo "   Erreurs: $ERRORS"
echo "   Erreurs compilation: $COMPILE_ERRORS"
echo "   Warnings: $WARNINGS"
echo "   Compilation réussie: $SUCCESS"
echo ""

if [ "$COMPILE_ERRORS" -gt 0 ]; then
    echo "❌ ERREURS DE COMPILATION DÉTECTÉES:"
    echo "-----------------------------------"
    grep -B 5 -A 10 "== Compilation error" "$LOG_FILE" | tail -50
    echo ""
    echo "🔧 Fichiers à corriger:"
    grep "== Compilation error in file" "$LOG_FILE" | sed 's/.*in file //' | sort -u
    exit 1
elif [ "$SUCCESS" -gt 0 ]; then
    echo "✅ BUILD RÉUSSI!"
    echo ""
    echo "📦 Image créée:"
    docker images | grep wiwiga
    echo ""
    echo "🚀 Prochaines étapes:"
    echo "   1. docker compose up -d"
    echo "   2. ./docker-monitor.sh"
    echo "   3. curl http://localhost:8000/api/health"
    exit 0
else
    echo "⏳ Build toujours en cours..."
    echo "   Dernière sortie:"
    tail -20 "$LOG_FILE"
    exit 2
fi
