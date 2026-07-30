# Conventions de Nommage — WIWIGA

## Backend Elixir

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Module | PascalCase | `GameHub.GameMatch` |
| Fonction publique | snake_case | `create_match/1` |
| Fonction privée | snake_case prefix `_` | `_evaluate_set/1` |
| Variable | snake_case | `bet_amount` |
| Atome | snake_case | `:waiting_players` |
| Schema | PascalCase singulier | `GameRule`, `Friendship` |
| Migration | timestamp_snake | `20260729000001_create_game_rules.exs` |
| Channel | PascalCase + suffixe | `RoomChannel`, `FriendChannel` |
| Controller | PascalCase + suffixe | `RoomController` |
| Table DB | snake_case pluriel | `game_rules`, `friendships` |
| Champ DB | snake_case | `bet_amount`, `is_active` |

## Frontend Flutter/Dart

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Classe | PascalCase | `DiceMatchScreen` |
| Widget privé | prefix `_` | `_SetScoreboard` |
| Variable | camelCase | `betAmount` |
| Constante | camelCase ou SCREAMING | `NeonColors.primary` |
| Fichier Dart | snake_case | `dice_match_screen.dart` |
| Fichier modèle | snake_case + `_model` | `game_room_model.dart` |
| Fichier écran | snake_case + `_screen` | `create_game_screen.dart` |
| Fichier widget | snake_case descriptif | `friend_invite_sheet.dart` |
| Provider Riverpod | camelCase + `Provider` | `friendRepositoryProvider` |
| Repository | camelCase + `Repository` | `RoomRepository` |
| Route API | snake_case kebab | `/api/rooms/join-by-code` |

## Nommage Métier

| Concept | Terme | Description |
|---------|-------|-------------|
| Match | Match | Partie complète (N sets) |
| Set | Set | Sous-partie d'un match |
| Room | Salle | Salle d'attente avant match |
| Rule | Règle | Configuration de jeu (Normal/Cible) |
| Bet | Mise | Montant parié au niveau match |
| Commission | Commission | Prélèvement plateforme |

## Interdit

- ❌ Abréviations : `btn` → `button`, `msg` → `message`, `cfg` → `config`
- ❌ Hongrois : pas de `strName`, `intCount`
- ❌ Mix casing : pas de `createGameRoom` en Elixir (snake_case)
- ❌ Noms génériques : `data`, `info`, `temp`, `handle` sans contexte
