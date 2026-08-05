# ==================================
# WIWIGA - Migration User Preferences (JSONB)
# ==================================
# Ajoute la colonne preferences JSONB aux users
# Stocke: son, vibration, notifications, langue, thème, taille police

defmodule GameHub.Repo.Migrations.AddPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :preferences, :map, default: %{}
    end
  end
end
