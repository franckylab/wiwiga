# ==================================
# WIWIGA - Migration User Stats (agrégats profil)
# ==================================
# Table user_stats: agrégation toutes catégories pour le profil
# Calculée depuis game_stats après chaque partie

defmodule GameHub.Repo.Migrations.CreateUserStats do
  use Ecto.Migration

  def change do
    create table(:user_stats) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :games_played, :integer, default: 0, null: false
      add :wins, :integer, default: 0, null: false
      add :losses, :integer, default: 0, null: false
      add :draws, :integer, default: 0, null: false
      add :total_winnings, :bigint, default: 0, null: false
      add :total_bets, :bigint, default: 0, null: false
      add :current_streak, :integer, default: 0, null: false
      add :best_streak, :integer, default: 0, null: false
      add :xp_points, :integer, default: 0, null: false
      add :rank_tier, :string, default: "bronze", null: false
      add :last_game_at, :utc_datetime

      timestamps()
    end

    create unique_index(:user_stats, [:user_id])
  end
end
