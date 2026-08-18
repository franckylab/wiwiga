# ==================================
# WIWIGA - Migration Admin CRM Tables
# ==================================
# Migration: 20260825000005_add_admin_crm_tables.exs

defmodule GameHub.Repo.Migrations.AddAdminCrmTables do
  use Ecto.Migration

  def up do
    # Table player_notes
    create table(:player_notes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :admin_id, :integer, null: false
      add :note, :text, null: false
      add :category, :string, default: "general"

      timestamps()
    end

    create index(:player_notes, [:user_id])
    create index(:player_notes, [:admin_id])
    create index(:player_notes, [:category])

    # Table player_vip_tiers
    create table(:player_vip_tiers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tier, :string, null: false
      add :assigned_by, :integer, null: false
      add :assigned_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:player_vip_tiers, [:user_id])
    create index(:player_vip_tiers, [:tier])
  end

  def down do
    drop table(:player_vip_tiers)
    drop table(:player_notes)
  end
end
