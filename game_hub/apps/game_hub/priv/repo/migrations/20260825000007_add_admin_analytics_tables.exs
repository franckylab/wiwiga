# ==================================
# WIWIGA - Migration Admin Analytics Tables
# ==================================
# Tables: game_configs, bonuses, bonus_claims

defmodule GameHub.Repo.Migrations.AddAdminAnalyticsTables do
  use Ecto.Migration

  def change do
    # Configuration des jeux (peut exister déjà via migration initiale)
    create_if_not_exists table(:game_configs) do
      add :game_type, :string, null: false
      add :commission_rate, :float, default: 0.05
      add :min_bet, :integer, default: 100
      add :max_bet, :integer, default: 1_000_000
      add :max_players, :integer, default: 10
      add :is_enabled, :boolean, default: true
      add :settings, :map, default: %{}
      timestamps()
    end

    create_if_not_exists unique_index(:game_configs, [:game_type])

    # Bonus et promotions
    create table(:bonuses) do
      add :name, :string, null: false
      add :type, :string, null: false, default: "deposit"
      add :description, :text, default: ""
      add :value, :integer, default: 0
      add :min_deposit, :integer, default: 0
      add :max_bonus, :integer, default: 0
      add :wagering_requirement, :integer, default: 1
      add :starts_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :usage_count, :integer, default: 0
      add :total_cost, :integer, default: 0
      add :created_by, :integer
      timestamps()
    end

    create index(:bonuses, [:type])
    create index(:bonuses, [:is_active])

    # Claims de bonus par les joueurs
    create table(:bonus_claims) do
      add :bonus_id, references(:bonuses, on_delete: :delete_all), null: false
      add :user_id, :integer, null: false
      add :claimed_at, :utc_datetime
      add :wagered_amount, :integer, default: 0
      add :won_amount, :integer, default: 0
      add :status, :string, default: "active"
      timestamps()
    end

    create index(:bonus_claims, [:bonus_id])
    create index(:bonus_claims, [:user_id])
    create index(:bonus_claims, [:status])

    # Données par défaut pour les types de jeu connus
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    execute """
    INSERT INTO game_configs (game_type, name, commission_rate, min_bet, max_bet, commission_mode, is_active, config, inserted_at, updated_at)
    VALUES
      ('dice', 'Jeu de Dés', 0.05, 100, 500000, 'percentage', true, '{"dice_count": 3}', '#{now}', '#{now}'),
      ('ludo', 'Ludo', 0.04, 100, 300000, 'percentage', true, '{}', '#{now}', '#{now}'),
      ('cards', 'Cards', 0.06, 200, 1000000, 'percentage', true, '{}', '#{now}', '#{now}')
    ON CONFLICT (game_type) DO NOTHING
    """
  end
end
