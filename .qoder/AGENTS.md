# WIWIGA — Configuration Agent Qoder

## Projet

- **Application** : WIWIGA — Hub de Jeux Multiplateforme
- **Auteur** : Franck Arlos CHENDJOU
- **Stack** : Elixir/Phoenix 1.7 Umbrella (backend) + Flutter 3.44.3 (frontend web/Android)
- **Architecture** : Hub Central + Plugins OTP
- **Marché** : Cameroun (Mobile Money via Campay)
- **Monnaie interne** : Jetons (1 FCFA = 1 jeton, conversion fixe)
- **Langue** : Français pour toute documentation et commentaires de code

## Infrastructure & Déploiement

### Docker Compose (4 services)

| Service | Port hôte | Port interne | Rôle |
|---------|-----------|--------------|------|
| `postgres` | 8001 | 5432 | Base de données PostgreSQL |
| `redis` | 8002 | 6379 | Cache + matchmaking |
| `backend` | 8000 | 4001 | API REST + WebSocket Phoenix |
| `frontend` | 8003 | 80 | Flutter Web (nginx) |

### Commandes courantes

```bash
# Compiler le backend
docker exec wiwiga-backend mix compile

# Exécuter les migrations
docker exec wiwiga-backend mix ecto.migrate

# Redémarrer le backend
docker restart wiwiga-backend

# Rebuild le frontend
docker compose build frontend && docker compose up -d frontend
```

### Configuration API (AppConfig)

Le frontend détecte automatiquement son environnement :
- **Web release (Docker)** : `Uri.base` → même origine (proxy nginx)
- **Web dev** : `http://localhost:4001`
- **Natif debug** : `http://10.0.2.2:4001` (Android emulator)
- **Natif release** : `https://api.wiwiga.com`

nginx proxy `/api/` et `/socket/` vers `backend:4001`.

## Système de Jetons

Toute l'interface utilise le terme **jetons** (jamais FCFA) pour les montants internes :
- Solde du compte : affiché en jetons
- Mises, gains, commissions : en jetons
- Achat de jetons : équivalent FCFA affiché uniquement dans l'écran d'achat
- Formatage : `formatTokens(int amount)` → `"1 000 jetons"`
- Icône : `monetization_on` (jamais `account_balance_wallet`)

## Structure du Projet

```
wiwiga/
├── game_hub/                          # Backend Elixir Umbrella
│   ├── apps/
│   │   ├── game_hub/                  # App principale (domaine métier)
│   │   │   ├── lib/game_hub/
│   │   │   │   ├── games/             # Schemas (GameRule, GameConfig)
│   │   │   │   ├── friends/           # Schemas (Friendship, FriendMessage)
│   │   │   │   ├── wallet/            # Schemas (WalletTransaction)
│   │   │   │   ├── dice_game/         # Schemas (DiceGameResult)
│   │   │   │   ├── audit/             # Schemas (AuditLog)
│   │   │   │   ├── responsible_gaming/# Schemas (Limit)
│   │   │   │   ├── game_rules.ex      # Cache ETS règles de jeu
│   │   │   │   ├── game_match.ex      # State machine multi-sets
│   │   │   │   ├── game_room.ex       # GenServer salles de jeu
│   │   │   │   ├── friends.ex         # Module central amis
│   │   │   │   ├── matchmaking.ex     # Matchmaking 2 phases
│   │   │   │   ├── wallet.ex          # Compte jetons ACID
│   │   │   │   └── auth.ex            # Authentification JWT
│   │   │   └── priv/repo/migrations/  # Migrations Ecto
│   │   ├── game_hub_web/              # App web (controllers, channels, router)
│   │   │   └── lib/game_hub_web/
│   │   │       ├── controllers/       # REST API
│   │   │       └── channels/          # WebSocket Phoenix
│   │   └── dice_game/                 # Plugin jeu de dés
│   └── config/                        # Config Elixir (dev, test, prod)
│
├── wiwiga_app/                        # Frontend Flutter (Web + Android)
│   ├── lib/
│   │   ├── core/                      # Config, thèmes, constantes
│   │   │   ├── config/               # AppConfig (détection env auto)
│   │   │   ├── constants/            # ApiConstants, WebSocketChannels
│   │   │   ├── router/              # GoRouter (navigation déclarative)
│   │   │   └── theme/               # NeonTheme, AppTheme, Typography
│   │   ├── data/                      # Couche données
│   │   │   ├── models/              # Modèles Dart
│   │   │   ├── repositories/        # Repositories
│   │   │   ├── providers/           # Providers Riverpod
│   │   │   └── services/            # API + WebSocket
│   │   ├── presentation/              # Couche UI
│   │   │   ├── widgets/neon/        # Design system néon (10 composants)
│   │   │   ├── widgets/game/        # Widgets jeu (DiceRoller, FriendInvite)
│   │   │   ├── widgets/navigation/  # Navigation responsive
│   │   │   └── screens/             # Écrans par feature
│   │   └── main.dart
│   ├── nginx.conf                     # Proxy nginx → backend:4001
│   └── test/                          # Tests Flutter
│
├── monitoring/                        # Grafana + Prometheus + Logstash
├── docker-compose.yml                 # Orchestration 4 services
└── .qoder/                            # Configuration Qoder
    ├── AGENTS.md                      # Ce fichier
    ├── rules/                         # Règles de développement
    └── skills/                        # Skills métier
```

## Design System Frontend

10 composants néon obligatoires :

| Composant | Fichier | Usage |
|-----------|---------|-------|
| NeonButton | `widgets/neon/neon_button.dart` | Boutons avec glow, variantes primary/secondary/outline |
| NeonCard | `widgets/neon/neon_card.dart` | Cartes avec bordure lumineuse hover |
| NeonInput | `widgets/neon/neon_input.dart` | Champs de saisie avec border glow focus |
| GlowBadge | `widgets/neon/neon_effects.dart` | Badges avec pulse animation |
| BalanceDisplay | `widgets/game/` | Formatage jetons + animation |
| GameCard | `widgets/game/` | Cartes de jeu avec hover complet |
| NeonModal | `widgets/neon/neon_business.dart` | Modals avec backdrop blur |
| ShimmerLoader | `widgets/neon/neon_effects.dart` | Loading animé |
| VictoryEffect | `widgets/game/` | Particules + animation gains |
| ResponsiveNavigation | `widgets/navigation/` | Bottom nav/sidebar selon breakpoint |

**Palette néon** :
- Primary : `#2DD4BF` (vert émeraude)
- Secondary : `#F59E0B` (orange/doré)
- Accent : `#00D9FF` (cyan)
- Background : `#1E293B` (gris-bleu profond)
- Surface : `#0F172A` (plus sombre)

**Typographie** : Inter (corps) + Orbitron (titres gaming) via `google_fonts`

## Navigation Frontend

- **GoRouter** pour la navigation déclarative (pas de `Navigator.push`)
- **Routes principales** : `/splash`, `/auth`, `/home` (shell 5 onglets), `/tokens`, etc.
- **initialLocation** : `/splash`
- **Splash screen** : `addStatusListener` + `addPostFrameCallback` pour navigation fiable

## Contraintes Critiques

1. **Transactions ACID** obligatoires pour toutes les opérations financières (compte jetons, mises, gains)
2. **Génération aléatoire** côté serveur uniquement (`:crypto.strong_rand_bytes/1`)
3. **Webhooks de paiement** avec idempotence (IdempotencyKey)
4. **Double vérification permissions** (frontend + backend)
5. **Conformité** : KYC, AML, jeu responsable (limites configurables)
6. **Format réponse API** : `%{success: true/false, data: ..., message: ...}`

## Chargement Automatique

À chaque interaction, l'agent DOIT :

### 1. Charger les règles pertinentes
| Règle | Fichier | Quand |
|-------|---------|-------|
| Bonnes pratiques | `rules/rl_development-best-practices.md` | Toujours |
| Conventions nommage | `rules/rl_naming-conventions.md` | Toujours |
| Structure fichiers | `rules/rl_file-structure.md` | Toujours |
| Design system néon | `rules/rl_design-system.md` | Tâche frontend |
| Responsive design | `rules/rl_responsive-design.md` | Tâche UI |

### 2. Invoquer le skill métier
| Type de tâche | Skill |
|---------------|-------|
| Backend Elixir/Phoenix | `skills/sk_backend-elixir-phoenix.md` |
| Frontend Flutter | `skills/sk_frontend-flutter.md` |
| Jeu de dés / match | `skills/sk_dice-game-engine.md` |
| Composants néon | `skills/sk_neon-components.md` |

### 3. Règles d'exécution
1. LIRE les règles et skills AVANT de générer du code
2. APPLIQUER systématiquement les conventions détectées
3. COMBINER les ressources si la tâche est multi-domaine
4. VÉRIFIER la conformité avant de livrer le code
