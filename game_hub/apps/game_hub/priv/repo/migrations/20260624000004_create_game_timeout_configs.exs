# ==================================
# WIWIGA - Migration Game Timeout Configs
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Repo.Migrations.CreateGameTimeoutConfigs do
  use Ecto.Migration

  def up do
    create table(:game_timeout_configs, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_type, :string, null: false
      add :grace_period_seconds, :integer, default: 120, null: false
      add :action_on_timeout, :string, default: "forfeit", null: false
      add :forfeit_distribution, :string, default: "to_winner"
      add :reconnect_allowed, :boolean, default: true
      add :max_reconnect_attempts, :integer, default: 3
      add :is_active, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:game_timeout_configs, [:game_type])
    create index(:game_timeout_configs, [:is_active])

    # Contraintes CHECK
    execute """
      ALTER TABLE game_timeout_configs
      ADD CONSTRAINT grace_period_positive CHECK (grace_period_seconds > 0)
    """

    execute """
      ALTER TABLE game_timeout_configs
      ADD CONSTRAINT valid_action CHECK (action_on_timeout IN ('forfeit', 'refund', 'pause'))
    """

    execute """
      ALTER TABLE game_timeout_configs
      ADD CONSTRAINT valid_distribution CHECK (forfeit_distribution IN ('to_winner', 'split', 'pool'))
    """
  end

  def down do
    drop table(:game_timeout_configs)
  end
end
