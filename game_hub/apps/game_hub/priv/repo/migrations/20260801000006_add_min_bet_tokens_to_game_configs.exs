# ==================================
# WIWIGA - Migration Add Min Bet Tokens
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.AddMinBetTokensToGameConfigs
# Description: Ajout mise minimum en jetons par jeu

defmodule GameHub.Repo.Migrations.AddMinBetTokensToGameConfigs do
  use Ecto.Migration

  def change do
    # Table game_specific_configs (UI config)
    alter table(:game_specific_configs) do
      add :min_bet_tokens, :integer, default: 10
    end

    # Table game_configs (game engine config)
    alter table(:game_configs) do
      add :min_bet_tokens, :bigint
    end

    create constraint(:game_specific_configs, :min_bet_tokens_positive, check: "min_bet_tokens > 0")
  end
end
