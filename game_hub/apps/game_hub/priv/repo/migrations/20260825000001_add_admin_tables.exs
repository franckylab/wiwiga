# ==================================
# WIWIGA - Migration Admin Tables
# ==================================
# Tables: admin_alerts, admin_notifications,
#         ip_whitelist, user_bans, admin_api_keys

defmodule GameHub.Repo.Migrations.AddAdminTables do
  use Ecto.Migration

  def up do
    # === Alertes Admin ===
    create table(:admin_alerts, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :alert_type, :string, null: false
      add :severity, :string, null: false, default: "warning"
      add :title, :string, null: false
      add :message, :text, null: false
      add :metadata, :map, default: %{}
      add :is_resolved, :boolean, default: false
      add :resolved_by, :integer
      add :resolved_at, :utc_datetime
      add :acknowledged_by, :integer
      add :acknowledged_at, :utc_datetime
      timestamps()
    end

    create index(:admin_alerts, [:severity])
    create index(:admin_alerts, [:is_resolved])
    create index(:admin_alerts, [:alert_type])
    create index(:admin_alerts, [:inserted_at])

    # === Notifications Admin ===
    create table(:admin_notifications, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :type, :string, null: false, default: "info"
      add :title, :string, null: false
      add :message, :text, null: false
      add :target_type, :string, default: "admin"
      add :target_id, :integer
      add :is_read, :boolean, default: false
      add :read_at, :utc_datetime
      add :created_by, :integer
      timestamps()
    end

    create index(:admin_notifications, [:type])
    create index(:admin_notifications, [:is_read])
    create index(:admin_notifications, [:target_type, :target_id])
    create index(:admin_notifications, [:inserted_at])

    # === IP Whitelist ===
    create table(:ip_whitelist, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :ip_address, :string, null: false
      add :description, :string
      add :is_active, :boolean, default: true
      add :created_by, :integer
      timestamps()
    end

    create unique_index(:ip_whitelist, [:ip_address])

    # === User Bans ===
    create table(:user_bans, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reason, :text, null: false
      add :banned_by, :integer, null: false
      add :expires_at, :utc_datetime
      add :is_permanent, :boolean, default: false
      add :is_active, :boolean, default: true
      add :lifted_by, :integer
      add :lifted_at, :utc_datetime
      add :lift_reason, :text
      timestamps()
    end

    create index(:user_bans, [:user_id])
    create index(:user_bans, [:is_active])
    create unique_index(:user_bans, [:user_id], where: "is_active = true", name: :user_bans_user_id_active_unique)

    # === Admin API Keys ===
    create table(:admin_api_keys, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :name, :string, null: false
      add :key_hash, :string, null: false
      add :permissions, {:array, :string}, default: []
      add :is_active, :boolean, default: true
      add :created_by, :integer
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :usage_count, :integer, default: 0
      timestamps()
    end

    create unique_index(:admin_api_keys, [:key_hash])
    create index(:admin_api_keys, [:is_active])
  end

  def down do
    drop table(:admin_api_keys)
    drop table(:user_bans)
    drop table(:ip_whitelist)
    drop table(:admin_notifications)
    drop table(:admin_alerts)
  end
end
