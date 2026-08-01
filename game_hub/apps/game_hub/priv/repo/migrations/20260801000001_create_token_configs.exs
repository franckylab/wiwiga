# ==================================
# WIWIGA - Migration Token Configs
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.CreateTokenConfigs
# Description: Configuration du système de jetons virtuels

defmodule GameHub.Repo.Migrations.CreateTokenConfigs do
  use Ecto.Migration

  def change do
    create table(:token_configs) do
      # Taux de conversion: jetons par unité monétaire (FCFA)
      # Défaut: 10 jetons = 1 FCFA
      add :exchange_rate, :float, default: 10.0, null: false

      # Limites d'échange jetons → monnaie
      add :min_exchange_tokens, :integer, default: 100, null: false
      add :max_exchange_tokens, :integer, default: 100_000, null: false

      # Mises minimales en jetons par type de jeu
      add :min_bet_tokens_dice, :integer, default: 10, null: false
      add :min_bet_tokens_card, :integer, default: 10, null: false

      # Fonctionnalités activables
      add :transfer_enabled, :boolean, default: true, null: false
      add :gift_enabled, :boolean, default: true, null: false

      # Frais d'échange (optionnel)
      add :exchange_fee_percentage, :float, default: 0.0
      add :exchange_fee_fixed, :integer, default: 0

      # Paramètres additionnels (JSON flexible)
      add :settings, :map, default: %{}

      add :updated_by, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    # Contraintes
    create constraint(:token_configs, :exchange_rate_positive, check: "exchange_rate > 0")
    create constraint(:token_configs, :min_exchange_positive, check: "min_exchange_tokens > 0")
    create constraint(:token_configs, :max_exchange_positive, check: "max_exchange_tokens > 0")
    create constraint(:token_configs, :max_exchange_gte_min, check: "max_exchange_tokens >= min_exchange_tokens")
    create constraint(:token_configs, :min_bet_dice_positive, check: "min_bet_tokens_dice > 0")
    create constraint(:token_configs, :exchange_fee_valid, check: "exchange_fee_percentage >= 0 AND exchange_fee_percentage <= 1")
  end
end
