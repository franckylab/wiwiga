# ==================================
# WIWIGA - Migration Table Audit Logs
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    create table(:audit_logs, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :string
      add :changes, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :string
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:entity_type, :entity_id])
    create index(:audit_logs, [:inserted_at])
  end

  def down do
    drop table(:audit_logs)
  end
end
