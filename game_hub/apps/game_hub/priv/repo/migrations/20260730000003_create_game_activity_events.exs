# ==================================
# WIWIGA - Migration Game Activity Events
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260730000003_create_game_activity_events.exs
# Description: Flux d'activité public (victoires récentes)

defmodule GameHub.Repo.Migrations.CreateGameActivityEvents do
  use Ecto.Migration

  def change do
    create table(:game_activity_events) do
      add :game_type, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_type, :string, default: "win", null: false
      add :amount, :bigint, default: 0, null: false

      timestamps(updated_at: false)
    end

    # Flux récent par jeu (rétention applicative courte)
    create index(:game_activity_events, [:game_type, :inserted_at])
    create index(:game_activity_events, [:inserted_at])
  end
end
