# Skill Moteur de Jeu de Dés — WIWIGA

## Quand Utiliser

Toute tâche impliquant :
- Logique de jeu de dés (lancers, évaluation, scores)
- Types de règles (Normal, Cible)
- Système multi-sets (match = N sets)
- State machine de match
- Animation de lancer de dés

## Architecture du Moteur

```
GameMatch (GenServer)
├── State machine : :waiting → :ready → :set_in_progress → :set_ended → :match_ended
├── Types : "normal" (high roll) | "cible" (target vote)
├── Sets : N sets, majorité pour gagner, set nul = rejouer
└── Dés : nombre configurable (défaut 2), crypto-safe

GameRules (Cache ETS)
├── Config par type : min/max sets, dés, mise
├── Commission : taux configurable
└── TTL : 5 min, invalidation sur update

GameRoom (GenServer)
├── Codes : WIWIGA-XXXX (4 chars alphanum)
├── Modes : :free (Partie sans mise - gratuit) | :staked (Partie avec mise) — betting supprimé 2026-08-30
├── Joueurs : 2-5 par room
└── TTL : 30 min inactivité → cleanup
```

## Type Normal — High Roll Séquentiel

```elixir
# Ordre tournant par set : set 1 → Joueur A, set 2 → Joueur B
def roll_dice(match_id, player_id) do
  GenServer.call(__MODULE__, {:roll_dice, match_id, player_id})
end

# Évaluation du set
defp evaluate_set(match) do
  sum_a = match.player_sums["player_a"]
  sum_b = match.player_sums["player_b"]
  
  cond do
    sum_a > sum_b -> {:winner, "player_a"}
    sum_b > sum_a -> {:winner, "player_b"}
    true -> :tie  # Set nul → rejouer
  end
end
```

## Type Cible — Target Prediction

```elixir
# Phase 1 : Vote des joueurs
def vote_target(match_id, player_id, target_value) do
  GenServer.call(__MODULE__, {:vote_target, match_id, player_id, target_value})
end

# Calcul de la cible (moyenne arrondie des votes)
defp calculate_target(votes, mode \\ "average") do
  case mode do
    "average" ->
      sum = votes |> Map.values() |> Enum.sum()
      round(sum / map_size(votes))
    "mode" ->
      votes |> Map.values() |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0)
  end
end

# Phase 2 : Évaluation (distance à la cible)
defp evaluate_cible_set(match, target) do
  dist_a = abs(match.player_sums["player_a"] - target)
  dist_b = abs(match.player_sums["player_b"] - target)
  
  cond do
    dist_a < dist_b -> {:winner, "player_a"}
    dist_b < dist_a -> {:winner, "player_b"}
    true -> :tie
  end
end
```

## Génération Aléatoire — CRYPTO-SECURE

```elixir
# ✅ CORRECT — Crypto-safe
defp roll_dice(count) do
  1..count
  |> Enum.map(fn _ ->
    <<byte>> = :crypto.strong_rand_bytes(1)
    rem(byte, 6) + 1
  end)
end

# ❌ INCORRECT — Pas sécurisé
defp roll_dice(count) do
  Enum.map(1..count, fn _ -> Enum.random(1..6) end)
end
```

## Configuration des Règles (depuis DB)

```elixir
# Config par défaut pour dice/normal
%{
  "min_sets" => 1, "max_sets" => 7, "default_sets" => 3,
  "min_dice" => 1, "max_dice" => 6, "default_dice" => 2,
  "commission_rate" => 0.05,
  "min_bet" => 100, "max_bet" => 50000,
  "tie_rule" => "replay",
  "turn_order" => "rotating",
  "target_vote_mode" => "average"
}

# Validation
def validate_match_config(game_type, rule_type, config) do
  rules = GameRules.get_rules_or_default(game_type, rule_type)
  
  with :ok <- validate_range(config.sets, rules.min_sets, rules.max_sets),
       :ok <- validate_range(config.dice, rules.min_dice, rules.max_dice),
       :ok <- validate_bet(config.bet, rules.min_bet, rules.max_bet) do
    {:ok, config}
  end
end
```

## Calcul des Gains

```elixir
def calculate_winnings(bet_amount, game_type) do
  rules = GameRules.get_rules_or_default(game_type, "normal")
  commission_rate = Decimal.new(rules.commission_rate)
  
  gross = Decimal.mult(Decimal.new(bet_amount), Decimal.new(2))
  commission = Decimal.mult(gross, commission_rate) |> Decimal.round(0)
  net = Decimal.sub(gross, commission)
  
  %{gross: gross, commission: commission, net: net}
end
```

## Frontend — Animation de Lancer

```dart
// Widget DiceRoller (lib/presentation/widgets/game/dice_roller.dart)
class DiceRoller extends StatefulWidget {
  final int diceCount;
  final void Function(List<int> results)? onRollComplete;
  final double diceSize;
}

// Animation : 8 frames à 100ms → valeurs aléatoires
// Résultat final : Random.secure() (crypto-safe côté client aussi)
// Effet : scale 0.9 → 1.0 pendant le lancer
```

## State Machine Match

```
         create_match()
              │
              ▼
      :waiting_players ◄── add_player()
              │
              ▼ (2+ joueurs)
           :ready
              │
         start_match()
              ▼
    ┌── :set_in_progress ──┐
    │         │              │
    │    roll_dice()    vote_target()  ← Type Cible
    │         │              │
    │         ▼              │
    │    :set_ended ─────────┘
    │         │
    │    evaluate_set()
    │    ┌────┴────┐
    │    │         │
    │  winner     tie → rejouer (retour :set_in_progress)
    │    │
    │    ▼
    │  check_match_winner()
    │    │
    │    ├── majorité atteinte → :match_ended
    │    └── sinon → prochain set
    └──────────────────────────────────────┘
```

## Checklist Moteur de Jeu

- [ ] Dés générés avec `:crypto.strong_rand_bytes/1`
- [ ] Ordre tournant respecté (set impair → Joueur A, set pair → Joueur B)
- [ ] Set nul = rejouer (pas de gagnant)
- [ ] Majorité de sets pour gagner le match
- [ ] Commission calculée depuis les règles DB
- [ ] Transaction ACID pour débit/crédit wallet
- [ ] PubSub broadcast pour événements temps réel
- [ ] Animation dés avec Random.secure() côté client
