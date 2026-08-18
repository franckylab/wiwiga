# ==================================
# WIWIGA - Migration Config Change Logs
# ==================================
# Historique des modifications de configuration
# avec support de rollback

defmodule GameHub.Repo.Migrations.AddConfigChangeLogs do
  use Ecto.Migration

  def up do
    create table(:config_change_logs, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :config_type, :string, null: false
      add :config_id, :integer
      add :changed_by, :integer, null: false
      add :old_values, :map, default: %{}
      add :new_values, :map, default: %{}
      add :change_summary, :string
      timestamps()
    end

    create index(:config_change_logs, [:config_type])
    create index(:config_change_logs, [:config_type, :config_id])
    create index(:config_change_logs, [:changed_by])
    create index(:config_change_logs, [:inserted_at])
  end

  def down do
    drop table(:config_change_logs)
  end
end
