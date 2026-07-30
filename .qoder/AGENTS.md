# WIWIGA — Configuration Agent Qoder

## Projet

- **Application** : WIWIGA — Hub de Jeux Multiplateforme
- **Auteur** : Franck Arlos CHENDJOU
- **Stack** : Elixir/Phoenix 1.7 Umbrella (backend) + Flutter 3.44.3 (frontend)
- **Architecture** : Hub Central + Plugins OTP
- **Marché** : Cameroun (XAF, Mobile Money via Campay)
- **Langue** : Français pour toute documentation et code comments

## Structure du Projet

```
wiwiga/
├── game_hub/                          # Backend Elixir Umbrella
│   ├── apps/
│   │   ├── game_hub/                  # App principale (domaine métier)
│   │   │   ├── lib/game_hub/
│   │   │   │   ├── games/             # Schemas (GameRule, GameConfig)
│   │   │   │   ├── friends/           # Schemas (Friendship, FriendMessage, FriendActivity)
│   │   │   │   ├── wallet/            # Schemas (WalletTransaction)
│   │   │   │   ├── dice_game/         # Schemas (DiceGameResult)
│   │   │   │   ├── audit/             # Schemas (AuditLog)
│   │   │   │   ├── responsible_gaming/# Schemas (Limit)
│   │   │   │   ├── game_rules.ex      # Cache ETS règles de jeu
│   │   │   │   ├── game_match.ex      # State machine multi-sets
│   │   │   │   ├── game_room.ex       # GenServer salles de jeu
│   │   │   │   ├── friends.ex         # Module central amis
│   │   │   │   ├── matchmaking.ex     # Matchmaking 2 phases
│   │   │   │   ├── wallet.ex          # Portefeuille ACID
│   │   │   │   └── auth.ex            # Authentification
│   │   │   └── priv/repo/migrations/  # Migrations Ecto
│   │   ├── game_hub_web/              # App web (controllers, channels, router)
│   │   │   └── lib/game_hub_web/
│   │   │       ├── controllers/       # REST API
│   │   │       └── channels/          # WebSocket Phoenix
│   │   └── dice_game/                 # Plugin jeu de dés
│   └── config/                        # Config Elixir (dev, test, prod)
│
├── wiwiga_app/                        # Frontend Flutter
│   ├── lib/
│   │   ├── core/                      # Config, thèmes, constantes
│   │   │   ├── config/               # AppConfig
│   │   │   ├── constants/            # ApiConstants, WebSocketChannels
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
│   └── test/                          # Tests Flutter
│
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
| BalanceDisplay | `widgets/game/` | Formatage FCFA + animation |
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

## Contraintes Critiques

1. **Transactions ACID** obligatoires pour toutes les opérations financières (wallet, mises, gains)
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

### 3. Règles d'exécution
1. LIRE les règles et skills AVANT de générer du code
2. APPLIQUER systématiquement les conventions détectées
3. COMBINER les ressources si la tâche est multi-domaine
4. VÉRIFIER la conformité avant de livrer le code
