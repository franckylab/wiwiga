# Conventions de Nommage WIWIGA

## Portée
Cette règle s'applique à tout le code WIWIGA (Backend Elixir + Frontend Flutter).

**Langue** : Réfléchis, dialogues et commentaires en **français**. Termes techniques (GenServer, Provider, Repository, Entity) en **anglais**.

---

## 1. Backend Elixir

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Modules | `PascalCase` anglais | `GameHub.Wallet`, `DiceGame` |
| Fonctions publiques | `snake_case` anglais | `place_bet()`, `roll_dice()` |
| Fonctions privées | `snake_case` avec préfixe `_` | `_validate_move()`, `_handle_tie()` |
| Variables | `snake_case` anglais | `user_id`, `bet_amount`, `dice_results` |
| Atomes | `snake_case` anglais | `:insufficient_funds`, `:game_started` |
| Tables PostgreSQL | `snake_case` pluriel anglais | `users`, `dice_game_results`, `wallets` |
| Colonnes | `snake_case` anglais | `balance_before`, `created_at`, `player_id` |
| Index | `snake_case` descriptif | `idx_users_phone`, `idx_games_status` |

---

## 2. Frontend Flutter

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Classes, widgets | `PascalCase` anglais | `WalletScreen`, `DiceWidget` |
| Fichiers Dart | `snake_case` anglais | `wallet_screen.dart`, `dice_game_provider.dart` |
| Variables locales | `camelCase` anglais | `walletBalance`, `isLoading` |
| Méthodes publiques | `camelCase` anglais | `rollDice()`, `placeBet()` |
| Méthodes privées | `_camelCase` anglais | `_validateAmount()`, `_handleError()` |
| Providers Riverpod | `camelCase` + "Provider" | `walletProvider`, `diceGameProvider` |
| Notifiers | `PascalCase` + "Notifier" | `WalletNotifier`, `DiceGameNotifier` |
| États | `PascalCase` + "State" | `WalletState`, `DiceGameState` |

---

## 3. Interface Utilisateur (UI)

- **TOUJOURS en français** : "Solde disponible", "Lancer les dés", "Dépôt effectué"
- **Termes techniques** : Peuvent rester en anglais si pas d'équivalent clair

```dart
// ✅ CORRECT
Text('Solde disponible')
SnackBar(content: Text('Dépôt initié avec succès!'))

// ❌ INCORRECT
Text('Available balance')
SnackBar(content: Text('Deposit initiated successfully!'))
```

---

## 4. Base de Données

| Convention | Exemple |
|-----------|---------|
| Tables pluriel `snake_case` | `users`, `games`, `dice_game_results` |
| Foreign keys | `{table}_id` → `user_id`, `game_id` |
| Timestamps | `created_at`, `updated_at`, `deleted_at` |
| Booléens | Préfixe `is_` ou `has_` → `is_active`, `has_verified_kyc` |

---

## 5. Messages de Commit Git

### Format
```
type: description en français
```

### Types
- `feat:` Nouvelle fonctionnalité
- `fix:` Correction de bug
- `docs:` Documentation
- `refactor:` Refactorisation
- `test:` Tests
- `chore:` Maintenance

### Exemples
```bash
feat: ajouter module de gestion du portefeuille avec transactions ACID
fix: corriger génération aléatoire des dés côté serveur
docs: ajouter conventions de nommage pour Elixir et Flutter
```

---

## 6. Anti-patterns

- ❌ Mélanger français et anglais dans le code
- ❌ Noms trop courts (`x`, `temp`, `data`)
- ❌ Abbreviations obscures (`usr`, `amt`, `cfg`)
- ❌ Incohérence de casing entre fichiers et classes

---

## 7. Checklist Pré-Commit

- [ ] Modules Elixir en `PascalCase`
- [ ] Fonctions Elixir en `snake_case`
- [ ] Widgets Flutter en `PascalCase`
- [ ] Fichiers Dart en `snake_case`
- [ ] Tables DB en `snake_case` pluriel
- [ ] Messages UI en français
- [ ] Commentaires et docstrings en français
- [ ] Messages de commit en français

---

**Ces conventions sont OBLIGATOIRES pour TOUT développement WIWIGA.**

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 23 Juin 2026
