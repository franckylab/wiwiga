# WIWIGA - Configuration Agent Qoder

## ⚠️ RÈGLES DE CHARGEMENT AUTOMATIQUE — OBLIGATOIRES

**À CHAQUE INTERACTION**, l'agent DOIT systématiquement :

### 1. Charger les règles (TOUJOURS - avant toute action)
- ✅ `.qoder/rules/rl_development-best-practices.md` — 25 règles de développement
- ✅ `.qoder/rules/rl_naming-conventions.md` — Conventions de nommage
- ✅ `.qoder/rules/rl_file-structure.md` — Structure et architecture
- ✅ `.qoder/rules/rl_responsive-design.md` — 17 breakpoints responsives

### 2. Détecter le type de tâche et invoquer le skill approprié

| Type de tâche | Skill à charger |
|---------------|-----------------|
| **Backend Elixir/Phoenix** (modules, controllers, GenServer, migrations, WebSocket, transactions, auth) | `.qoder/skills/sk_backend-elixir-phoenix.md` |
| **Frontend Flutter** (écrans, widgets, providers, state management, UI, responsive) | `.qoder/skills/sk_frontend-flutter.md` |
| **Jeu de dés** (plugin OTP, logique de jeu, configuration, animations) | `.qoder/skills/sk_dice-game-implementation.md` |
| **Architecture OTP** (plugins, applications, supervision) | `sk_backend-elixir-phoenix.md` + Règle 1 |
| **Transactions financières** (wallet, paiements, mises, gains) | `sk_backend-elixir-phoenix.md` + Règle 2 |
| **Génération aléatoire** (RNG, jeux de hasard) | `sk_backend-elixir-phoenix.md` + Règle 3 |
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
- **Stack**: Elixir/Phoenix + Flutter (Web/Android)
- **Architecture**: Hub Central + Plugins OTP
- **Marché**: Cameroun (XAF, Mobile Money via Campay)

## Contraintes Critiques
1. Transactions ACID obligatoires pour opérations financières
2. Génération aléatoire côté serveur uniquement (`:crypto.strong_rand_bytes/1`)
3. Webhooks de paiement avec idempotence
4. Double vérification permissions (frontend + backend)
5. Conformité KYC, AML, jeu responsable

---

**🚨 RAPPEL: Ce fichier est lu automatiquement à chaque session. Les instructions ci-dessus s'appliquent SANS EXCEPTION.**
