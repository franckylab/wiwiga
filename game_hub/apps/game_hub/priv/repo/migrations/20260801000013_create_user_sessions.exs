# ==================================
# WIWIGA - Migration User Sessions
# ==================================
# Table user_sessions: tracking des sessions actives
# Permet affichage + révocation dans Sécurité

defmodule GameHub.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def change do
    create table(:user_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :device_id, :string
      add :user_agent, :string
      add :ip_address, :string
      add :last_active_at, :utc_datetime, null: false
      add :is_current, :boolean, default: false, null: false

      timestamps()
    end

    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:user_id, :is_current])
    create index(:user_sessions, [:device_id])
  end
end
