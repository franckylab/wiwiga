defmodule GameHub.Repo.Migrations.PureJetonsGamingLimits do
  use Ecto.Migration

  @doc """
  Passe les limites gaming de centimes (FCFA*100) à jetons purs (1:1).

  Avant: 500000 centimes = 5000 FCFA affiché comme 500000 jetons (x100)
  Après: 5000 jetons = 5000 FCFA (1:1)

  Frontière paiement (min_deposit, max_deposit, etc.) reste en FCFA (centimes) → non touché.
  """
  def up do
    # Gaming limites platform_configs → /100 (centimes → jetons)
    execute("UPDATE platform_configs SET value = (value::bigint / 100)::text WHERE category = 'gaming' AND key IN ('default_daily_loss_limit', 'max_bet_per_round') AND value ~ '^[0-9]+$'")
    execute("UPDATE platform_configs SET value = (value::bigint / 100)::text WHERE category = 'ranking' AND key LIKE 'leaderboard_reward_top%' AND value ~ '^[0-9]+$'")
    execute("UPDATE platform_configs SET value = (value::bigint / 100)::text WHERE category = 'notification' AND key = 'alert_large_loss' AND value ~ '^[0-9]+$'")
    # Game configs (mises) → jetons purs
    execute("UPDATE game_configs SET min_bet = min_bet / 100, max_bet = max_bet / 100 WHERE min_bet >= 100")
    execute("UPDATE game_configs SET min_bet_tokens = min_bet_tokens / 100 WHERE min_bet_tokens >= 100")
    # Game rules configs JSONB min_bet/max_bet
    execute("UPDATE game_rules SET config = jsonb_set(config, '{min_bet}', to_jsonb((config->>'min_bet')::bigint / 100), false) WHERE config ? 'min_bet' AND (config->>'min_bet')::bigint >= 100")
    execute("UPDATE game_rules SET config = jsonb_set(config, '{max_bet}', to_jsonb((config->>'max_bet')::bigint / 100), false) WHERE config ? 'max_bet' AND (config->>'max_bet')::bigint >= 100")
    # Game stats (mises/gains) — garder centimes historique, mais futurs inserts seront jetons
  end

  def down do
    execute("UPDATE platform_configs SET value = (value::bigint * 100)::text WHERE category = 'gaming' AND key IN ('default_daily_loss_limit', 'max_bet_per_round') AND value ~ '^[0-9]+$'")
    execute("UPDATE platform_configs SET value = (value::bigint * 100)::text WHERE category = 'ranking' AND key LIKE 'leaderboard_reward_top%' AND value ~ '^[0-9]+$'")
    execute("UPDATE platform_configs SET value = (value::bigint * 100)::text WHERE category = 'notification' AND key = 'alert_large_loss' AND value ~ '^[0-9]+$'")
    execute("UPDATE game_configs SET min_bet = min_bet * 100, max_bet = max_bet * 100 WHERE min_bet < 1000")
    execute("UPDATE game_configs SET min_bet_tokens = min_bet_tokens * 100 WHERE min_bet_tokens < 1000")
    execute("UPDATE game_rules SET config = jsonb_set(config, '{min_bet}', to_jsonb((config->>'min_bet')::bigint * 100), false) WHERE config ? 'min_bet'")
    execute("UPDATE game_rules SET config = jsonb_set(config, '{max_bet}', to_jsonb((config->>'max_bet')::bigint * 100), false) WHERE config ? 'max_bet'")
  end
end
