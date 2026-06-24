# Structure de Fichiers et Bannières WIWIGA

## Portée
Cette règle définit la structure modulaire et les bannières obligatoires pour tous les fichiers WIWIGA.

---

## 1. Bannières de Fichier Obligatoires

### Backend Elixir

**Nouveau fichier complexe** (modules, services, controllers) :
```elixir
# ==================================
# WIWIGA - Module de gestion du portefeuille
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Wallet
# Description: Gestion ACID des transactions financières

defmodule GameHub.Wallet do
  # Implementation
end
```

**Nouveau fichier simple** (schemas, config) :
```elixir
# ==================================
# WIWIGA - Schéma utilisateur
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.User do
  # Implementation
end
```

### Frontend Flutter

**Nouveau fichier complexe** (écrans, providers) :
```dart
/// ==================================
/// WIWIGA - Écran de portefeuille
/// ==================================
/// Auteur: Franck Arlos CHENDJOU
/// Description: Interface de gestion du solde et transactions

import 'package:flutter/material.dart';
```

**Nouveau fichier simple** (widgets, utils) :
```dart
/// ==================================
/// WIWIGA - Widget bouton personnalisé
/// ==================================
/// Auteur: Franck Arlos CHENDJOU

import 'package:flutter/material.dart';
```

---

## 2. Architecture Backend Elixir (OTP Umbrella)

### Structure par Module OTP
```
apps/
├── game_hub/                      # Application hub central
│   ├── lib/
│   │   ├── game_hub.ex            # Point d'entrée
│   │   ├── game_hub/
│   │   │   ├── wallet.ex          # Module portefeuille
│   │   │   ├── auth.ex            # Module authentification
│   │   │   ├── matchmaking.ex     # Module matchmaking
│   │   │   ├── commission.ex      # Module commission
│   │   │   └── errors.ex          # Gestion erreurs centralisée
│   │   └── game_hub_web/
│   │       ├── endpoint.ex        # Configuration endpoint
│   │       ├── router.ex          # Routes API
│   │       └── channels/
│   │           └── game_channel.ex # WebSocket
│   ├── test/
│   └── mix.exs
│
├── dice_game/                     # Plugin jeu de dés (OTP isolé)
│   ├── lib/
│   │   ├── dice_game.ex           # Point d'entrée GenServer
│   │   ├── dice_game/
│   │   │   ├── config.ex          # Schema Ecto config
│   │   │   ├── result.ex          # Schema Ecto résultats
│   │   │   ├── game_engine.ex     # Logique métier pure
│   │   │   └── security.ex        # Génération aléatoire crypto
│   │   └── dice_game_web/
│   │       └── channels/
│   │           └── game_channel.ex
│   ├── test/
│   └── mix.exs
│
└── future_game/                   # Futurs jeux (même structure)
    └── ...
```

### Organisation des Modules
```
lib/game_hub/
├── wallet.ex                      # Logique métier portefeuille
├── wallet/
│   ├── transaction.ex             # Schema transaction
│   ├── reconciliation.ex          # Job réconciliation
│   └── idempotency.ex             # Clés d'idempotence
├── auth/
│   ├── otp.ex                     # Vérification OTP
│   ├── jwt.ex                     # Gestion tokens JWT
│   └── session.ex                 # Sessions utilisateur
└── games/
    ├── registry.ex                # Registre plugins OTP
    ├── plugin.ex                  # Interface GamePlugin
    └── timeout.ex                 # Gestion déconnexions
```

---

## 3. Architecture Frontend Flutter

### Structure par Feature
```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   ├── app_config.dart        # Configuration globale
│   │   ├── theme.dart             # Thème Material 3
│   │   └── constants.dart         # Constantes applicatives
│   ├── network/
│   │   ├── api_client.dart        # Client HTTP
│   │   ├── websocket_client.dart  # Client WebSocket Phoenix
│   │   └── interceptors/
│   │       └── auth_interceptor.dart
│   ├── storage/
│   │   ├── secure_storage.dart    # FlutterSecureStorage
│   │   └── preferences.dart       # SharedPreferences
│   └── utils/
│       ├── validators.dart        # Validateurs formulaires
│       ├── formatters.dart        # Formateurs (devise, dates)
│       └── extensions.dart        # Extensions Dart
│
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── wallet_model.dart
│   │   ├── game_model.dart
│   │   └── transaction_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── wallet_repository.dart
│   │   └── game_repository.dart
│   └── datasources/
│       ├── remote_datasource.dart
│       └── local_datasource.dart
│
├── domain/
│   ├── entities/
│   │   ├── user.dart
│   │   ├── wallet.dart
│   │   └── game.dart
│   ├── usecases/
│   │   ├── login_usecase.dart
│   │   ├── deposit_usecase.dart
│   │   └── join_room_usecase.dart
│   └── repositories/
│       ├── auth_repository_interface.dart
│       └── wallet_repository_interface.dart
│
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── wallet_provider.dart
│   │   └── game_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── otp_verification_screen.dart
│   │   ├── wallet/
│   │   │   ├── wallet_screen.dart
│   │   │   ├── deposit_screen.dart
│   │   │   └── withdrawal_screen.dart
│   │   ├── lobby/
│   │   │   ├── lobby_screen.dart
│   │   │   ├── create_room_screen.dart
│   │   │   └── join_room_screen.dart
│   │   ├── game/
│   │   │   └── game_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── settings_screen.dart
│   └── widgets/
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── loading_indicator.dart
│       └── error_banner.dart
│
└── games/
    ├── dice_game/
    │   ├── dice_game_screen.dart
    │   ├── dice_animation.dart
    │   ├── dice_game_provider.dart
    │   └── dice_config_selector.dart
    └── future_game/
        └── ...
```

---

## 4. Barrel Exports (Export Centralisés)

### Backend Elixir
Créer des modules de ré-export pour faciliter les imports :

```elixir
# lib/game_hub/wallet/index.ex
defmodule GameHub.Wallet do
  alias GameHub.Wallet.Transaction
  alias GameHub.Wallet.Reconciliation
  alias GameHub.Wallet.Idempotency
  
  # Ré-export des fonctions publiques
  defdelegate place_bet(user_id, amount, key), to: WalletEngine
  defdelegate deposit(user_id, amount, key), to: WalletEngine
  defdelegate withdraw(user_id, amount, key), to: WalletEngine
end
```

### Frontend Flutter
Utiliser des fichiers barrel pour centraliser les exports :

```dart
// presentation/screens/wallet/index.dart
export 'wallet_screen.dart';
export 'deposit_screen.dart';
export 'withdrawal_screen.dart';

// presentation/providers/index.dart
export 'auth_provider.dart';
export 'wallet_provider.dart';
export 'game_provider.dart';
```

---

## 5. Ordre des Imports

### Backend Elixir
```elixir
# 1. Modules OTP externes
use GenServer
use GameHub.Web, :controller

# 2. Modules du hub central
alias GameHub.Repo
alias GameHub.Wallet
alias GameHub.Errors

# 3. Modules du domaine métier
alias GameHub.Games.DiceGameConfig
alias GameHub.Games.DiceGameResult

# 4. Modules locaux
alias __MODULE__.Transaction
alias __MODULE__.Idempotency
```

### Frontend Flutter
```dart
// 1. Packages externes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 2. Core (config, network, utils)
import 'package:wiwiga/core/config/app_config.dart';
import 'package:wiwiga/core/network/api_client.dart';

// 3. Domain (entities, usecases)
import 'package:wiwiga/domain/entities/user.dart';

// 4. Data (repositories)
import 'package:wiwiga/data/repositories/wallet_repository.dart';

// 5. Presentation (providers, screens)
import 'package:wiwiga/presentation/providers/wallet_provider.dart';

// 6. Imports relatifs
import '../widgets/custom_button.dart';
import './wallet_state.dart';
```

---

## 6. Checklist de Création de Fichier

### Nouveau Module Backend
- [ ] Bannière de fichier avec nom du module
- [ ] `@moduledoc` en français
- [ ] `@doc` sur toutes les fonctions publiques
- [ ] `@spec` avec types corrects
- [ ] Barrel export dans `index.ex`
- [ ] Tests unitaires correspondants

### Nouvel Écran Flutter
- [ ] Bannière de fichier avec description
- [ ] Documentation en français
- [ ] Provider Riverpod associé
- [ ] Gestion des états (loading, error, success)
- [ ] Messages UI en français
- [ ] Tests widget correspondants

### Nouvelle Migration
- [ ] Bannière de fichier
- [ ] Fonction `up` ET `down`
- [ ] Index sur foreign keys
- [ ] Contraintes CHECK si nécessaire
- [ ] Documenter dans les commentaires

---

**Cette structure est OBLIGATOIRE pour TOUT développement WIWIGA.**

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 23 Juin 2026
