# WIWIGA - Agent Configuration

## 🚨 CHARGEMENT AUTOMATIQUE OBLIGATOIRE

**⚠️ AVANT TOUTE RÉPONSE OU GÉNÉRATION DE CODE**, l'agent DOIT :

1. **Lire et appliquer** les règles depuis `.qoder/rules/rl_development-best-practices.md`
2. **Lire et appliquer** les conventions depuis `.qoder/rules/rl_naming-conventions.md`
3. **Lire et appliquer** la structure depuis `.qoder/rules/rl_file-structure.md`
4. **Lire et appliquer** la responsivité depuis `.qoder/rules/rl_responsive-design.md`
5. **Invoquer le skill approprié** SELON LE TYPE DE TÂCHE (voir tableau ci-dessous)

**Ces étapes sont NON NÉGOCIABLES et doivent être exécutées AVANT de générer du code.**

---

## 📋 INVOCATION AUTOMATIQUE DES SKILLS

**DÉTECTER le type de tâche et INVOQUER le skill correspondant SANS ATTENDRE** :

| Si la tâche concerne... | INVOQUER IMMÉDIATEMENT |
|-------------------------|------------------------|
| Backend Elixir (module, endpoint, GenServer, migration, controller, WebSocket, transaction, authentification) | `.qoder/skills/sk_backend-elixir-phoenix.md` |
| Frontend Flutter (écran, provider, widget, hook, state management, UI, responsive) | `.qoder/skills/sk_frontend-flutter.md` |
| Jeu de dés (plugin OTP, logique jeu, animations, configuration, dice game) | `.qoder/skills/sk_dice-game-implementation.md` |
| Architecture OTP (plugins, applications isolées, supervision) | `.qoder/skills/sk_backend-elixir-phoenix.md` + `.qoder/rules/rl_development-best-practices.md` (Règle 1) |
| Transactions financières (wallet, paiement, dépôt, retrait, mise, gain) | `.qoder/skills/sk_backend-elixir-phoenix.md` + `.qoder/rules/rl_development-best-practices.md` (Règle 2) |
| Génération aléatoire (jeux de hasard, dés, cartes, RNG) | `.qoder/skills/sk_backend-elixir-phoenix.md` + `.qoder/rules/rl_development-best-practices.md` (Règle 3) |
| Responsive design (breakpoints, LayoutBuilder, ResponsiveConfig, multi-écran) | `.qoder/skills/sk_frontend-flutter.md` + `.qoder/rules/rl_responsive-design.md` |

**RÈGLES D'INVOCATION** :
1. ✅ **TOUJOURS** charger le skill **AVANT** de coder
2. ✅ **TOUJOURS** combiner avec les 4 fichiers de règles (voir section Chargement Automatique)
3. ✅ **COMBINER** les skills si la tâche touche plusieurs domaines (ex: backend + frontend)
4. ❌ **NE JAMAIS** ignorer cette section ou sauter le chargement
5. ❌ **NE JAMAIS** générer de code sans avoir lu les règles et skills d'abord

---

## Project Overview
**Application**: WIWIGA - Plateforme de Hub de Jeux Multiplateforme  
**Auteur**: Franck Arlos CHENDJOU  
**Stack**: Elixir/Phoenix (Backend) + Flutter (Frontend Web/Android)  
**Marché**: Cameroun (XAF, Mobile Money via Campay)  
**Architecture**: Hub Central + Plugins OTP isolés pour chaque jeu

## Design System Frontend
- **Palette** : Vert émeraude #2DD4BF (primaire), Orange #F59E0B (secondaire), Fond #1E293B
- **Style** : Néon gaming (glow effects, gradients CTA, bordures lumineuses)
- **Typographie** : Inter (body) + Orbitron (headlines/montants)
- **Navigation** : Adaptative 17 breakpoints (bottom nav → sidebar)
- **Animations** : Riches (100/200/300ms, glow, particules, shimmer)
- **Composants** : 10 widgets néon obligatoires (voir sk_neon-components.md)
- **Configuration** : Interface 100% paramétrable via dashboard admin (thème, fonctionnalités, jeux, paiements)
- **Règles** : Voir `.qoder/rules/rl_design-system.md`

## Critical Constraints
1. **Sécurité d'abord**: Transactions ACID obligatoires pour TOUTES opérations financières
2. **Conformité**: KYC, AML, jeu responsable, RGPD intégrés dès le jour 1
3. **Génération aléatoire côté serveur**: JAMAIS côté client pour les jeux
4. **Double vérification**: Frontend UX + Backend enforcement pour permissions
5. **Idempotence**: Obligatoire pour webhooks de paiement

## Development Workflow
- **Backend Elixir**: `mix format` → `mix credo` → `mix test` → commit
- **Frontend Flutter**: `dart format` → `dart analyze` → `flutter test` → commit
- **Couverture tests**: >90% backend financier, >80% frontend, 100% chemins critiques
- **Migration DB**: Toujours scripts UP + DOWN, tester en staging avant production

## Key Directories
```
game_hub/         # Backend Phoenix API (Elixir) - Umbrella app
├── apps/
│   ├── game_hub/           # Core business logic
│   ├── game_hub_web/       # Web interface (controllers, channels)
│   └── dice_game/          # Game plugin (OTP app)
wiwiga_app/       # Frontend Flutter app (web + Android)
.qoder/           # Qoder rules, skills, and configuration
docs/             # Documentation technique
scripts/          # Scripts DevOps (shell)
docker-compose.yml  # Docker orchestration (root)
```

## Docker Configuration
- **Single compose file**: `docker-compose.yml` at project root
- **Ports**: Backend 8000, PostgreSQL 8001, Redis 8002, Frontend 8004
- **Database**: wiwiga_dev (user: wiwiga_user, password: wiwiga_password)
- **Deprecated files**: `game_hub/docker-compose.yml` and `game_hub/Dockerfile` removed


