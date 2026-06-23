# WIWIGA - Agent Configuration

## Project Overview
**Application**: WIWIGA - Plateforme de Hub de Jeux Multiplateforme  
**Auteur**: Franck Arlos CHENDJOU  
**Stack**: Elixir/Phoenix (Backend) + Flutter (Frontend Web/Android)  
**Marché**: Cameroun (XAF, Mobile Money via Campay)  
**Architecture**: Hub Central + Plugins OTP isolés pour chaque jeu

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
backend/          # Phoenix API (Elixir)
frontend/         # Flutter app (web + Android)
docs/             # Documentation technique
scripts/          # Scripts DevOps
```

## ⚠️ INVOCATION AUTOMATIQUE DES SKILLS — OBLIGATOIRE

**Avant toute tâche de développement ou modification**, l'IA DOIT invoquer proactivement le skill approprié **sans attendre que l'utilisateur le demande** :

| Tâche détectée | Skill à invoquer |
|----------------|------------------|
| Backend Elixir (module, endpoint, GenServer, migration, controller) | Utiliser `.qoder/skills/backend-elixir-phoenix.md` |
| Frontend Flutter (écran, provider, widget, hook) | Utiliser `.qoder/skills/frontend-flutter.md` |
| Jeu de dés (plugin OTP, logique jeu, animations, configuration) | Utiliser `.qoder/skills/dice-game-implementation.md` |

**Règles** :
1. **TOUJOURS** charger le skill **avant** de coder
2. **TOUJOURS** combiner avec `.qoder/rules/development-best-practices.md`
3. **Combiner** si nécessaire (ex: module backend + frontend)
4. **Ne JAMAIS** ignorer cette section

---

## Agent Skills Available
- Backend Elixir/Phoenix architecture
- Flutter multiplateforme (web + Android)
- WebSocket temps réel (Phoenix Channels)
- PostgreSQL transactions ACID
- Redis cache & matchmaking
- Paiements Mobile Money (Campay)
- Architecture OTP plugins
- Sécurité & conformité jeux d'argent
