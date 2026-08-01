# Structure et Architecture des Fichiers — WIWIGA

## Backend Elixir — Organisation par Responsabilité

```
game_hub/apps/
├── game_hub/                        # App domaine métier
│   ├── lib/game_hub/
│   │   ├── games/                   # Schemas et config jeux
│   │   │   ├── game_rule.ex         # Schema règles
│   │   │   ├── game_config.ex       # Config parties
│   │   │   └── game_timeout_config.ex
│   │   ├── friends/                 # Schemas amis
│   │   │   ├── friendship.ex
│   │   │   ├── friend_message.ex
│   │   │   └── friend_activity.ex
│   │   ├── wallet/                  # Schemas compte jetons
│   │   │   └── wallet_transaction.ex
│   │   ├── dice_game/               # Schemas résultats
│   │   │   └── dice_game_result.ex
│   │   ├── audit/                   # Schemas audit
│   │   │   └── audit_log.ex
│   │   ├── responsible_gaming/      # Schemas jeu responsable
│   │   │   └── responsible_gaming_limit.ex
│   │   ├── game_rules.ex            # Module central (cache ETS)
│   │   ├── game_match.ex            # State machine GenServer
│   │   ├── game_room.ex             # Salles GenServer
│   │   ├── friends.ex               # Module central amis
│   │   ├── matchmaking.ex           # Matchmaking 2 phases
│   │   ├── wallet.ex                # Compte jetons ACID
│   │   ├── auth.ex                  # Authentification
│   │   ├── commission.ex            # Calcul commissions
│   │   └── application.ex           # Supervision tree
│   └── priv/repo/migrations/        # Migrations Ecto
│
├── game_hub_web/                    # App web
│   └── lib/game_hub_web/
│       ├── controllers/             # REST API
│       │   ├── room_controller.ex
│       │   ├── friend_controller.ex
│       │   └── ...
│       ├── channels/                # WebSocket
│       │   ├── room_channel.ex
│       │   ├── friend_channel.ex
│       │   └── user_socket.ex
│       └── router.ex               # Routes
│
└── dice_game/                       # Plugin jeu de dés
    └── lib/dice_game/
        ├── engine.ex                # Moteur jeu
        └── application.ex
```

## Frontend Flutter — Séparation Design System / Métier

```
wiwiga_app/lib/
├── core/                            # Configuration globale
│   ├── config/app_config.dart       # URLs, timeout, etc.
│   ├── constants/api_constants.dart # Endpoints + WebSocket
│   └── theme/                       # Design system
│       ├── app_theme.dart           # Material Theme
│       ├── neon_theme.dart          # Couleurs néon + effets
│       └── typography.dart          # Inter + Orbitron
│
├── data/                            # Couche données
│   ├── models/                      # Modèles Dart (fromJson/toJson)
│   ├── repositories/                # Repositories (1 par domaine)
│   ├── providers/                   # Providers Riverpod
│   └── services/                    # API + WebSocket services
│
├── presentation/                    # Couche UI
│   ├── widgets/
│   │   ├── neon/                    # Design system (OBLIGATOIRE)
│   │   │   ├── neon_button.dart
│   │   │   ├── neon_card.dart
│   │   │   ├── neon_input.dart
│   │   │   ├── neon_effects.dart    # GlowBadge, ShimmerLoader
│   │   │   ├── neon_business.dart   # NeonModal, BalanceDisplay
│   │   │   └── neon_widgets.dart    # Barrel export
│   │   ├── game/                    # Widgets jeu
│   │   │   ├── dice_roller.dart
│   │   │   └── friend_invite_sheet.dart
│   │   └── navigation/
│   │       └── responsive_navigation.dart
│   │
│   └── screens/                     # Écrans par feature
│       ├── auth/
│       ├── lobby/
│       ├── game_lobby/
│       ├── game/                    # Création + attente
│       ├── dice_game/
│       ├── friends/
│       ├── wallet/
│       ├── profile/
│       ├── leaderboard/
│       ├── settings/
│       ├── transaction_history/
│       └── main/
│
└── main.dart                        # Entry point
```

## Règles de Placement

1. **Un schema = un fichier** dans le sous-dossier correspondant au domaine
2. **Un module central = un fichier** à la racine de `game_hub/` (ex: `friends.ex`, `wallet.ex`)
3. **Un contrôleur = un fichier** dans `controllers/`
4. **Un channel = un fichier** dans `channels/`
5. **Un écran = un fichier** dans `screens/{feature}/`
6. **Un widget réutilisable = un fichier** dans `widgets/{category}/`
7. **Un modèle Dart = un fichier** dans `data/models/`
8. **Un repository = un fichier** dans `data/repositories/`

## Fichiers Barrel

- `neon_widgets.dart` : ré-exporte tous les composants néon
- Pas de barrel pour les screens (import direct)

## Interdit

- ❌ Fichier > 700 lignes → découper en widgets privés
- ❌ Logique métier dans un widget Flutter → déplacer dans repository/provider
- ❌ Code Elixir hors de `apps/` → toute la logique dans les apps Umbrella
- ❌ Imports circulaires entre modules → restructurer les dépendances
