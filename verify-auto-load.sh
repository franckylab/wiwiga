#!/bin/bash
# Script de vérification du chargement automatique des règles et skills

echo "🔍 Vérification du système de chargement automatique WIWIGA"
echo "============================================================"
echo ""

# Vérifier l'existence des fichiers critiques
echo "📁 Vérification des fichiers de configuration agent..."
files_ok=true

# Fichiers AGENTS.md et CLAUDE.md
if [ -f ".qoder/AGENTS.md" ]; then
    echo "✅ .qoder/AGENTS.md existe"
else
    echo "❌ .qoder/AGENTS.md manquant"
    files_ok=false
fi

if [ -f "CLAUDE.md" ]; then
    echo "✅ CLAUDE.md existe"
else
    echo "❌ CLAUDE.md manquant"
    files_ok=false
fi

echo ""
echo "📋 Vérification des règles (préfixe rl_)..."

# Vérifier les règles
rules=(
    ".qoder/rules/rl_development-best-practices.md"
    ".qoder/rules/rl_naming-conventions.md"
    ".qoder/rules/rl_file-structure.md"
    ".qoder/rules/rl_responsive-design.md"
)

for rule in "${rules[@]}"; do
    if [ -f "$rule" ]; then
        size=$(wc -l < "$rule")
        echo "✅ $rule ($size lignes)"
    else
        echo "❌ $rule manquant"
        files_ok=false
    fi
done

echo ""
echo "🎯 Vérification des skills (préfixe sk_)..."

# Vérifier les skills
skills=(
    ".qoder/skills/sk_backend-elixir-phoenix.md"
    ".qoder/skills/sk_frontend-flutter.md"
    ".qoder/skills/sk_dice-game-implementation.md"
)

for skill in "${skills[@]}"; do
    if [ -f "$skill" ]; then
        size=$(wc -l < "$skill")
        echo "✅ $skill ($size lignes)"
    else
        echo "❌ $skill manquant"
        files_ok=false
    fi
done

echo ""
echo "🔗 Vérification des références dans AGENTS.md..."

# Vérifier que AGENTS.md contient les instructions de chargement
if grep -q "CHARGEMENT AUTOMATIQUE OBLIGATOIRE" .qoder/AGENTS.md; then
    echo "✅ Section chargement automatique présente dans AGENTS.md"
else
    echo "❌ Section chargement automatique absente de AGENTS.md"
    files_ok=false
fi

if grep -q "rl_development-best-practices.md" .qoder/AGENTS.md; then
    echo "✅ Référence aux règles dans AGENTS.md"
else
    echo "❌ Références aux règles manquantes dans AGENTS.md"
    files_ok=false
fi

if grep -q "sk_backend-elixir-phoenix.md" .qoder/AGENTS.md; then
    echo "✅ Référence aux skills dans AGENTS.md"
else
    echo "❌ Références aux skills manquantes dans AGENTS.md"
    files_ok=false
fi

echo ""
echo "🔗 Vérification des références dans CLAUDE.md..."

if [ -f "CLAUDE.md" ]; then
    if grep -q "CHARGEMENT AUTOMATIQUE" CLAUDE.md; then
        echo "✅ Section chargement automatique présente dans CLAUDE.md"
    else
        echo "❌ Section chargement automatique absente de CLAUDE.md"
        files_ok=false
    fi
fi

echo ""
echo "============================================================"
if [ "$files_ok" = true ]; then
    echo "✅ VÉRIFICATION RÉUSSIE - Tous les fichiers sont en place"
    echo ""
    echo "📊 Résumé:"
    echo "   - 2 fichiers de configuration agent (AGENTS.md + CLAUDE.md)"
    echo "   - 4 fichiers de règles (rl_*)"
    echo "   - 3 fichiers de skills (sk_*)"
    echo ""
    echo "🚀 Le chargement automatique est configuré et fonctionnel!"
else
    echo "❌ VÉRIFICATION ÉCHOUÉE - Certains fichiers sont manquants"
    exit 1
fi
