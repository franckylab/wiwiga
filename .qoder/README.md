# WIWIGA - Guide d'Utilisation des Rules & Skills Qoder

## 📁 Structure des Fichiers

```
.qoder/
├── AGENTS.md                              # Configuration principale du projet
├── rules/
│   └── development-best-practices.md     # 20 règles obligatoires de développement
└── skills/
    ├── backend-elixir-phoenix.md         # Skill backend Elixir/Phoenix
    ├── frontend-flutter.md               # Skill frontend Flutter
    └── dice-game-implementation.md       # Skill jeu de dés (premier jeu)
```

## 🎯 Comment Utiliser

### Pour l'Agent Qoder

**Automatiquement chargé à chaque session**:
- `AGENTS.md` - Contexte projet et contraintes critiques
- `rules/development-best-practices.md` - 20 règles de développement

**Skills disponibles sur demande**:
- Quand vous demandez du backend → `backend-elixir-phoenix.md`
- Quand vous demandez du frontend → `frontend-flutter.md`
- Quand vous travaillez sur le jeu de dés → `dice-game-implementation.md`

### Pour les Développeurs

#### 1. Avant de Commencer un Task

```bash
# Lire la configuration projet
cat .qoder/AGENTS.md

# Vérifier les règles applicables
cat .qoder/rules/development-best-practices.md
```

#### 2. Quand Qoder Génère du Code

L'agent va automatiquement:
1. Consulter `AGENTS.md` pour le contexte
2. Charger les règles pertinentes depuis `development-best-practices.md`
3. Appliquer le skill approprié selon le type de tâche
4. Suivre les templates et patterns définis

#### 3. Vérification de Conformité

**Backend Elixir**:
- [ ] `mix format` exécuté
- [ ] `mix credo --strict` sans erreurs
- [ ] `mix test` tous verts
- [ ] Docstrings `@doc` présentes
- [ ] Transactions ACID pour opérations financières
- [ ] Logs d'audit pour actions sensibles

**Frontend Flutter**:
- [ ] `dart format` exécuté
- [ ] `dart analyze` sans erreurs
- [ ] `flutter test` tous verts
- [ ] Error states gérés
- [ ] Messages d'erreur en français
- [ ] Accessibilité vérifiée

## 📋 Résumé des 25 Règles de Développement

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
| 11 | Réconciliation Portefeuille | Job cron horaire `balance = SUM(transactions)` |
| 12 | Migration DB Safe | Scripts UP + DOWN, compatible backward |
| 13 | WebSocket Events Structurés | Format standardisé avec validation |
| 14 | Flutter Riverpod | Providers immutables, pas de setState global |
| 15 | Sécurité En-têtes HTTP | 7 en-têtes obligatoires |
| 16 | Tests Backend | >90% couverture, 100% chemins critiques |
| 17 | Documentation Inline | `@doc` et `@moduledoc` obligatoires |
| 18 | Gestion Erreurs Flutter UX | Messages clairs, actionnables, français |
| 19 | Conformité Jeu Responsable | Obligations légales MINFI |
| 20 | Déploiement Blue-Green | Progressif avec rollback possible |
| 21 | **Performance et Optimisation** | Index, cache, pagination, monitoring |
| 22 | **Anti-patterns Interdits** | Liste explicite des erreurs à ne pas commettre |
| 23 | **Réponses API Standardisées** | Format JSON cohérent succès/erreur |
| 24 | **Gestion Centralisée des Erreurs** | Module `GameHub.Errors` avec codes standardisés |
| 25 | **🔥 Responsivité Progressive** | 17 breakpoints (50px-2300px+), scaling proportionnel |

### Fichiers de Règles Supplémentaires

| Fichier | Contenu | Lignes |
|---------|---------|--------|
| `naming-conventions.md` | Conventions de nommage Elixir/Flutter, commits, UI française | 120 |
| `file-structure.md` | Bannières obligatoires, architecture modulaire, barrel exports, ordre des imports | 330 |
| `responsive-design.md` | **17 breakpoints, ResponsiveConfig, LayoutBuilder adaptatif** | **848** |

## 🚀 Exemples d'Utilisation

### Exemple 1: Créer un Module Backend

**Prompt**: "Crée le module de gestion de portefeuille pour WIWIGA"

**Ce que Qoder va faire**:
1. Lire `AGENTS.md` → comprendre stack Elixir/Phoenix
2. Charger Règle 2 (Transactions ACID) depuis `development-best-practices.md`
3. Appliquer skill `backend-elixir-phoenix.md` → section 3
4. Générer code avec:
   - Verrouillage pessimiste `FOR UPDATE`
   - Clé d'idempotence pour webhooks
   - Logs d'audit
   - Documentation `@doc` complète

### Exemple 2: Développer un Écran Flutter

**Prompt**: "Crée l'écran de dépôt Mobile Money"

**Ce que Qoder va faire**:
1. Lire `AGENTS.md` → comprendre Flutter + Riverpod
2. Charger Règle 14 (Riverpod) et Règle 18 (UX erreurs)
3. Appliquer skill `frontend-flutter.md` → section 2-3
4. Générer code avec:
   - Provider Riverpod immutable
   - Validation formulaire inline
   - Messages d'erreur en français
   - Error states gérés
   - Loading states

### Exemple 3: Implémenter le Jeu de Dés

**Prompt**: "Implémente le plugin de jeu de dés"

**Ce que Qoder va faire**:
1. Lire `AGENTS.md` → comprendre architecture OTP plugins
2. Charger Règle 1 (OTP Plugins) et Règle 3 (Aléatoire sécurisé)
3. Appliquer skill `dice-game-implementation.md` complet
4. Générer:
   - Module OTP `GameHub.Games.DiceGame`
   - Génération `:crypto.strong_rand_bytes/1`
   - Schema Ecto `DiceGameConfig`
   - Migrations UP + DOWN
   - Provider Flutter Riverpod
   - Écran avec animations

## ⚠️ Contraintes Critiques (Non Négociables)

### Sécurité Financière
- ❌ JAMAIS de modification de balance sans transaction ACID
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

### Conformité Légale
- ✅ Vérification âge >= 18 obligatoire
- ✅ KYC avant retraits élevés
- ✅ Limites de dépôt/perte configurables
- ✅ Auto-exclusion disponible
- ✅ Rappels de réalité toutes les 30min

## 📊 Métriques de Qualité

### Backend
- **Couverture tests**: >90% modules financiers, 100% chemins critiques
- **Qualité code**: `mix credo --strict` sans erreurs
- **Performance API**: <200ms p95
- **Latence WebSocket**: <100ms p95

### Frontend
- **Couverture tests**: >80%
- **Performance**: 60 FPS, <2s chargement initial
- **Accessibilité**: WCAG 2.1 AA
- **Qualité code**: `dart analyze` sans erreurs

### Base de Données
- **Performance requêtes**: <50ms p95
- **Réconciliation**: Job horaire sans erreurs
- **Migrations**: 100% réversibles (UP + DOWN)

## 🔧 Workflow de Développement

### Backend Elixir
```bash
# 1. Formater le code
mix format

# 2. Vérifier qualité
mix credo --strict

# 3. Exécuter tests
mix test

# 4. Vérifier couverture
mix test --cover

# 5. Commit
git commit -m "feat: implement wallet module with ACID transactions"
```

### Frontend Flutter
```bash
# 1. Formater le code
dart format lib/

# 2. Analyser
dart analyze

# 3. Exécuter tests
flutter test

# 4. Vérifier couverture
flutter test --coverage

# 5. Commit
git commit -m "feat: add wallet screen with Riverpod state management"
```

## 📚 Documentation de Référence

- **Spécifications complètes**: `GAME_HUB_PROMPT_FR.md` (2082 lignes)
- **Règles de développement**: `.qoder/rules/development-best-practices.md`
- **Skill Backend**: `.qoder/skills/backend-elixir-phoenix.md`
- **Skill Frontend**: `.qoder/skills/frontend-flutter.md`
- **Skill Jeu de Dés**: `.qoder/skills/dice-game-implementation.md`

## 🎓 Bonnes Pratiques d'Utilisation

### Pour les Développeurs
1. **Lire les règles avant de coder** - Surtout Règle 2 (ACID) et Règle 3 (Aléatoire)
2. **Utiliser les templates** - Les skills contiennent des patterns éprouvés
3. **Respecter la checklist** - Pré-commit obligatoire
4. **Tester localement** - Avant de demander à Qoder de générer

### Pour Qoder
1. **Toujours consulter AGENTS.md** - Contexte projet critique
2. **Appliquer les règles pertinentes** - Selon le type de tâche
3. **Utiliser les skills appropriés** - Backend vs Frontend vs Jeu
4. **Vérifier la checklist** - Avant de livrer le code
5. **Documenter en français** - `@doc`, commentaires, messages d'erreur

## 🚨 Escalation en Cas de Problème

Si Qoder génère du code qui viole les règles:

1. **Identifier la règle violée** - Référence dans `development-best-practices.md`
2. **Signaler à l'agent** - "Ce code viole la Règle X"
3. **Demander correction** - "Refacto selon la Règle X"
4. **Vérifier avec checklist** - Tous les points sont-ils respectés?

## 📝 Historique des Mises à Jour

- **2026-06-23**: Création initiale et enrichissement depuis ElisaSchool par Franck Arlos CHENDJOU
  - AGENTS.md avec invocation automatique des skills
  - 25 règles de développement (20 initiales + 5 enrichies)
  - 3 skills (Backend, Frontend, Dice Game)
  - `naming-conventions.md` - Conventions de nommage Elixir/Flutter
  - `file-structure.md` - Bannières obligatoires, architecture modulaire, imports
  - `responsive-design.md` - **17 breakpoints (50px-2300px+), scaling proportionnel complet**
  - Règles 21-24 : Performance, anti-patterns, réponses API, gestion erreurs
  - Règle 25 : **Responsivité Progressive avec 17 niveaux et Mobile Android optimisé**

---

**Ce système de rules & skills est la source de vérité pour TOUT développement WIWIGA. Tout code non conforme doit être refacturé.**

**Auteur**: Franck Arlos CHENDJOU  
**Projet**: WIWIGA - Plateforme de Hub de Jeux  
**Date**: 23 Juin 2026
