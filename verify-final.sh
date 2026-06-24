#!/bin/bash
# ==================================
# WIWIGA - Vérification Finale Complète
# ==================================
# Description: Vérifie que tous les modules, migrations et tests sont présents

echo "🔍 ==========================================="
echo "   WIWIGA - Vérification Finale"
echo "==========================================="
echo ""

ERRORS=0

# 1. Vérifier modules principaux
echo "📦 1. Vérification modules..."

MODULES=(
  "game_hub/apps/game_hub/lib/game_hub/application.ex"
  "game_hub/apps/game_hub/lib/game_hub/repo.ex"
  "game_hub/apps/game_hub/lib/game_hub/auth.ex"
  "game_hub/apps/game_hub/lib/game_hub/guardian.ex"
  "game_hub/apps/game_hub/lib/game_hub/errors.ex"
  "game_hub/apps/game_hub/lib/game_hub/commission.ex"
  "game_hub/apps/game_hub/lib/game_hub/matchmaking.ex"
  "game_hub/apps/game_hub/lib/game_hub/authorization.ex"
  "game_hub/apps/game_hub/lib/game_hub/validators.ex"
  "game_hub/apps/game_hub/lib/game_hub/feature_flags.ex"
  "game_hub/apps/game_hub/lib/game_hub/responsible_gaming.ex"
  "game_hub/apps/game_hub/lib/game_hub/game_timeout.ex"
  "game_hub/apps/game_hub/lib/game_hub/audit_log.ex"
  "game_hub/apps/game_hub/lib/game_hub/wallet_reconciliation.ex"
  "game_hub/apps/game_hub/lib/game_hub/sms_otp.ex"
  "game_hub/apps/game_hub/lib/game_hub/idempotency_key.ex"
  "game_hub/apps/game_hub/lib/game_hub/wallet.ex"
)

for module in "${MODULES[@]}"; do
  if [ -f "$module" ]; then
    echo "  ✅ $(basename $module)"
  else
    echo "  ❌ MANQUANT: $module"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# 2. Vérifier schemas
echo "📊 2. Vérification schemas..."

SCHEMAS=(
  "game_hub/apps/game_hub/lib/game_hub/users/user.ex"
  "game_hub/apps/game_hub/lib/game_hub/wallet/wallet_transaction.ex"
  "game_hub/apps/game_hub/lib/game_hub/games/game_config.ex"
  "game_hub/apps/game_hub/lib/game_hub/games/game_timeout_config.ex"
  "game_hub/apps/game_hub/lib/game_hub/audit/audit_log.ex"
  "game_hub/apps/game_hub/lib/game_hub/feature_flags/feature_flag.ex"
  "game_hub/apps/game_hub/lib/game_hub/responsible_gaming/responsible_gaming_limit.ex"
  "game_hub/apps/game_hub/lib/game_hub/dice_game/dice_game_result.ex"
)

for schema in "${SCHEMAS[@]}"; do
  if [ -f "$schema" ]; then
    echo "  ✅ $(basename $schema)"
  else
    echo "  ❌ MANQUANT: $schema"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# 3. Vérifier controllers & plugs
echo "🌐 3. Vérification web..."

WEB_FILES=(
  "game_hub/apps/game_hub_web/lib/game_hub_web/router.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/security_headers.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/admin_auth_plug.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/cors_plug.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/controllers/game_controller.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/controllers/admin_controller.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/controllers/health_controller.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/controllers/payment_webhook_controller.ex"
  "game_hub/apps/game_hub_web/lib/game_hub_web/channels/game_channel.ex"
)

for file in "${WEB_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $(basename $file)"
  else
    echo "  ❌ MANQUANT: $file"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# 4. Vérifier migrations
echo "🗄️  4. Vérification migrations..."

MIGRATION_COUNT=$(ls game_hub/priv/repo/migrations/*.exs 2>/dev/null | wc -l)
echo "  📊 Migrations trouvées: $MIGRATION_COUNT"

if [ "$MIGRATION_COUNT" -ge 8 ]; then
  echo "  ✅ Nombre de migrations OK (>= 8)"
else
  echo "  ❌ Nombre de migrations insuffisant (< 8)"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# 5. Vérifier tests
echo "🧪 5. Vérification tests..."

TEST_COUNT=$(find game_hub/apps/game_hub/test -name "*_test.exs" 2>/dev/null | wc -l)
echo "  📊 Fichiers de tests trouvés: $TEST_COUNT"

if [ "$TEST_COUNT" -ge 4 ]; then
  echo "  ✅ Tests suffisants (>= 4)"
else
  echo "  ⚠️  Tests limités (< 4)"
fi

echo ""

# 6. Vérifier documentation
echo "📚 6. Vérification documentation..."

DOCS=(
  "README.md"
  "API_DOCUMENTATION.md"
  "BACKEND_FINAL_REPORT.md"
  "IMPLEMENTATION_COMPLETE.md"
  "BACKEND_DEPLOYMENT_GUIDE.md"
)

for doc in "${DOCS[@]}"; do
  if [ -f "$doc" ]; then
    echo "  ✅ $doc"
  else
    echo "  ❌ MANQUANT: $doc"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# 7. Vérifier scripts
echo "🔧 7. Vérification scripts..."

SCRIPTS=(
  "deploy.sh"
  "verify-backend.sh"
  "start-backend.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then
      echo "  ✅ $script (exécutable)"
    else
      echo "  ⚠️  $script (non exécutable)"
    fi
  else
    echo "  ❌ MANQUANT: $script"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""

# 8. Vérifier CI/CD
echo "🚀 8. Vérification CI/CD..."

if [ -f ".github/workflows/ci.yml" ]; then
  echo "  ✅ GitHub Actions workflow"
else
  echo "  ⚠️  CI/CD workflow manquant"
fi

echo ""

# 9. Vérifier game plugin
echo "🎮 9. Vérification game plugin..."

if [ -f "game_hub/apps/dice_game/lib/dice_game/engine.ex" ]; then
  echo "  ✅ DiceGame Engine"
  
  # Vérifier RNG crypto
  if grep -q "crypto.strong_rand_bytes" game_hub/apps/dice_game/lib/dice_game/engine.ex; then
    echo "  ✅ RNG crypto sécurisé"
  else
    echo "  ❌ RNG non sécurisé détecté"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ❌ DiceGame Engine manquant"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# 10. Compter fichiers totaux
echo "📊 10. Statistiques..."

TOTAL_EX=$(find game_hub/apps -name "*.ex" -o -name "*.exs" | grep -v deps | grep -v _build | wc -l)
TOTAL_LINES=$(find game_hub/apps -name "*.ex" | grep -v deps | grep -v _build | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

echo "  📁 Fichiers Elixir: $TOTAL_EX"
echo "  📝 Lignes de code: ~$TOTAL_LINES"

echo ""

# Résumé final
echo "✅ ==========================================="
if [ $ERRORS -eq 0 ]; then
  echo "   ✅ VÉRIFICATION RÉUSSIE!"
  echo "   Tous les modules sont présents et conformes"
else
  echo "   ⚠️  $ERRORS erreur(s) détectée(s)"
  echo "   Vérifier les éléments marqués ❌"
fi
echo "==========================================="
echo ""

exit $ERRORS
