# WIWIGA - Guide d'Utilisation des Rules & Skills Qoder

## 📁 Structure des Fichiers

```
.qoder/
├── AGENTS.md                              # Configuration principale du projet
├── README.md                              # Ce guide
├── rules/
│   ├── rl_development-best-practices.md   # 25 règles obligatoires de développement
│   ├── rl_file-structure.md               # Architecture modulaire, structure fichiers
│   ├── rl_naming-conventions.md           # Conventions de nommage Elixir/Flutter
│   ├── rl_design-system.md                # Design system néon (frontend)
│   └── rl_responsive-design.md            # Breakpoints responsive
└── skills/
    ├── sk_backend-elixir-phoenix.md       # Skill backend Elixir/Phoenix
    ├── sk_frontend-flutter.md             # Skill frontend Flutter
    ├── sk_dice-game-engine.md             # Skill moteur jeu de dés
    ├── sk_dice-game-implementation.md     # Skill implémentation jeu de dés
    └── sk_neon-components.md              # Skill composants néon
```

## 🎯 Comment Utiliser

### Pour l'Agent Qoder

**Automatiquement chargé à chaque session**:
- `AGENTS.md` - Contexte projet, infrastructure Docker, système de jetons
- `rules/rl_development-best-practices.md` - 25 règles de développement

**Skills disponibles sur demande**:
- Backend Elixir/Phoenix → `sk_backend-elixir-phoenix.md`
- Frontend Flutter → `sk_frontend-flutter.md`
- Jeu de dés (moteur) → `sk_dice-game-engine.md`
- Jeu de dés (implémentation) → `sk_dice-game-implementation.md`
- Composants néon → `sk_neon-components.md`

## 📋 Résumé des Règles de Développement

| # | Règle | Application |
|---|-------|-------------|
| 1 | Architecture OTP Plugins | Chaque jeu = application OTP isolée |
| 2 | Transactions ACID | Opérations financières avec verrouillage pessimiste |
| 3 | Génération Aléatoire Sécurisée | `:crypto.strong_rand_bytes/1` côté serveur uniquement |
| 4 | Matchmaking Atomique | Redis SETNX pour éviter conditions de course |
| 5 | Validation Inputs | TOUJOURS valider et sanitiser |
| 6 | Authorisation Backend | Vérification propriété côté backend |
| 7 | Commission Configurée | Depuis DB, jamais hardcodée |
| 8 | Gestion Déconnexion | Politique configurable par jeu |
| 9 | Logs d'Audit | Obligatoires pour actions sensibles |
| 10 | Feature Flags | Déploiement progressif avec kill switch |
| 11 | Réconciliation Compte | Job cron horaire `balance = SUM(transactions)` |
| 12 | Migration DB Safe | Scripts UP + DOWN, compatible backward |
| 13 | WebSocket Events Structurés | Format standardisé avec validation |
| 14 | Flutter Riverpod | Providers immutables, pas de setState global |
| 15 | Sécurité En-têtes HTTP | 7 en-têtes obligatoires |
| 16 | Tests Backend | >90% couverture, 100% chemins critiques |
| 17 | Documentation Inline | `@doc` et `@moduledoc` obligatoires |
| 18 | Gestion Erreurs Flutter UX | Messages clairs, actionnables, français |
| 19 | Conformité Jeu Responsable | Obligations légales MINFI |
| 20 | Déploiement Docker | Docker Compose avec 4 services |
| 21 | Performance et Optimisation | Index, cache, pagination, monitoring |
| 22 | Anti-patterns Interdits | Liste explicite des erreurs à ne pas commettre |
| 23 | Réponses API Standardisées | Format JSON cohérent succès/erreur |
| 24 | Gestion Centralisée des Erreurs | Module `GameHub.Errors` avec codes standardisés |
| 25 | Jetons (monnaie interne) | `formatTokens()` dans l'UI, jamais "FCFA" |

## ⚠️ Contraintes Critiques (Non Négociables)

### Sécurité Financière
- ❌ JAMAIS de modification de solde sans transaction ACID
- ❌ JAMAIS de confiance dans les montants du client
- ❌ JAMAIS de webhooks sans idempotence
- ✅ TOUJOURS verrouillage pessimiste `FOR UPDATE`
- ✅ TOUJOURS logs d'audit pour transactions

### Sécurité Jeux
- ❌ JAMAIS de génération aléatoire côté client
- ❌ JAMAIS de `:rand.uniform` pour jeux de hasard
- ❌ JAMAIS de détermination du gagnant côté client
- ✅ TOUJOURS `:crypto.strong_rand_bytes/1` côté serveur
- ✅ TOUJOURS traçabilité complète des résultats

### Terminologie
- ❌ JAMAIS "FCFA" dans l'interface (sauf écran d'achat de jetons)
- ❌ JAMAIS "portefeuille" (utiliser "compte" ou "jetons")
- ✅ TOUJOURS "jetons" pour la monnaie interne
- ✅ Icône `monetization_on` (pas `account_balance_wallet`)

## 🔧 Workflow de Développement

### Backend Elixir (Docker)
```bash
# Compiler
docker exec wiwiga-backend mix compile

# Tests
docker exec wiwiga-backend mix test

# Migrations
docker exec wiwiga-backend mix ecto.migrate

# Qualité code
docker exec wiwiga-backend mix credo --strict
```

### Frontend Flutter (Docker)
```bash
# Analyser
dart analyze lib/

# Tests
flutter test

# Rebuild Docker
docker compose build frontend && docker compose up -d frontend
```

## 📚 Documentation de Référence

- **Configuration agent** : `.qoder/AGENTS.md`
- **Spécifications complètes** : `GAME_HUB_PROMPT_FR.md`
- **API** : `openapi.yaml`
- **README projet** : `README.md`

## 📝 Historique des Mises à Jour

- **2026-08-01** : Mise à jour globale post-migration jetons
  - AGENTS.md : ajout Docker, ports, AppConfig, GoRouter, système de jetons
  - Rules : "portefeuille" → "compte jetons", ajout règle 25 (jetons)
  - Skills : "FCFA" → "jetons" partout, formatTokens(), icône monetization_on
  - CLAUDE.md : simplifié comme alias vers AGENTS.md

- **2026-06-23** : Création initiale et enrichissement
  - AGENTS.md avec invocation automatique des skills
  - 25 règles de développement
  - 5 skills (Backend, Frontend, Dice Game Engine, Dice Game Implementation, Neon Components)

---

**Ce système de rules & skills est la source de vérité pour TOUT développement WIWIGA.**
