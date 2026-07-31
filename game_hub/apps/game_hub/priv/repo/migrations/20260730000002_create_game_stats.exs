# ==================================
# WIWIGA - Migration Game Stats
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260730000002_create_game_stats.exs
# Description: Agrégats de statistiques par joueur × jeu

defmodule GameHub.Repo.Migrations.CreateGameStats do
  use Ecto.Migration

  def change do
    create table(:game_stats) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_type, :string, null: false
      add :matches_played, :integer, default: 0, null: false
      add :wins, :integer, default: 0, null: false
      add :losses, :integer, default: 0, null: false
      add :total_wagered, :bigint, default: 0, null: false
      add :total_won_net, :bigint, default: 0, null: false
      add :biggest_win, :bigint, default: 0, null: false
      add :current_streak, :integer, default: 0, null: false
      add :best_streak, :integer, default: 0, null: false
      add :last_played_at, :utc_datetime

      timestamps()
    end

    # Un agrégat unique par joueur × jeu
    create unique_index(:game_stats, [:user_id, :game_type])

    # Index leaderboards (top wins / top gains / meilleure victoire)
    create index(:game_stats, [:game_type, :wins])
    create index(:game_stats, [:game_type, :total_won_net])
    create index(:game_stats, [:game_type, :biggest_win])
  end
end
