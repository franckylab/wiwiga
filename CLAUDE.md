# WIWIGA - Configuration Agent Qoder

> **Ce fichier est un alias. La configuration principale est dans `.qoder/AGENTS.md`.**

## ⚠️ RÈGLES DE CHARGEMENT AUTOMATIQUE — OBLIGATOIRES

**À CHAQUE INTERACTION**, l'agent DOIT systématiquement :

### 1. Charger les règles (TOUJOURS - avant toute action)
- ✅ `.qoder/rules/rl_development-best-practices.md` — 25 règles de développement
- ✅ `.qoder/rules/rl_naming-conventions.md` — Conventions de nommage
- ✅ `.qoder/rules/rl_file-structure.md` — Structure et architecture
- ✅ `.qoder/rules/rl_design-system.md` — Design system néon (frontend)
- ✅ `.qoder/rules/rl_responsive-design.md` — Breakpoints responsive (frontend)

### 2. Détecter le type de tâche et invoquer le skill approprié

| Type de tâche | Skill à charger |
|---------------|-----------------|
| **Backend Elixir/Phoenix** (modules, controllers, GenServer, migrations, WebSocket, transactions, auth) | `.qoder/skills/sk_backend-elixir-phoenix.md` |
| **Frontend Flutter** (écrans, widgets, providers, state management, UI, responsive) | `.qoder/skills/sk_frontend-flutter.md` |
| **Jeu de dés** (state machine, types Normal/Cible, multi-sets, animations) | `.qoder/skills/sk_dice-game-engine.md` |
| **Composants néon** (NeonButton, NeonCard, effets glow) | `.qoder/skills/sk_neon-components.md` |
| **Architecture OTP** (plugins, applications, supervision) | `sk_backend-elixir-phoenix.md` |
| **Transactions financières** (compte jetons, mises, gains) | `sk_backend-elixir-phoenix.md` |
| **Responsive design** (multi-écran, breakpoints) | `sk_frontend-flutter.md` + `rl_responsive-design.md` |

### 3. Règles d'exécution
1. **LIRE** les règles et skills **AVANT** de générer du code
2. **APPLIQUER** systématiquement les conventions détectées
3. **COMBINER** les ressources si la tâche est multi-domaine
4. **VÉRIFIER** la conformité avant de livrer le code
5. **NE JAMAIS** sauter cette étape de chargement

---

## Contexte Projet
- **Application**: WIWIGA - Hub de Jeux Multiplateforme
- **Auteur**: Franck Arlos CHENDJOU
- **Stack**: Elixir/Phoenix 1.7 Umbrella + Flutter 3.44.3 (Web/Android)
- **Architecture**: Hub Central + Plugins OTP
- **Monnaie interne**: Jetons (1 FCFA = 1 jeton)
- **Marché**: Cameroun (Mobile Money via Campay)

## Contraintes Critiques
1. Transactions ACID obligatoires pour opérations financières
2. Génération aléatoire côté serveur uniquement (`:crypto.strong_rand_bytes/1`)
3. Webhooks de paiement avec idempotence
4. Double vérification permissions (frontend + backend)
5. Conformité KYC, AML, jeu responsable
6. Termes "jetons" dans l'UI (jamais "FCFA" sauf écran d'achat)

---

**🚨 RAPPEL: Ce fichier est lu automatiquement à chaque session. Voir `.qoder/AGENTS.md` pour la configuration complète.**
