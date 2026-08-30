# ==================================
# WIWIGA - Schema Événement Activité Jeu
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameStats.ActivityEvent
# Description: Flux d'activité public (victoires récentes)

defmodule GameHub.GameStats.ActivityEvent do
  @moduledoc """
  Événement public du flux d'activité d'un jeu.

  Seules les victoires en Partie avec mise (`:staked`, alias historique `:betting`) sont enregistrées (event_type "win").
  Rétention applicative courte (purge des événements > 90 jours).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :game_type, :user_id, :event_type, :amount, :inserted_at]}

  schema "game_activity_events" do
    field :game_type, :string
    field :user_id, :integer
    field :event_type, :string, default: "win"
    field :amount, :integer, default: 0

    timestamps(updated_at: false)
  end

  @doc """
  Changeset pour création d'un événement.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:game_type, :user_id, :event_type, :amount])
    |> validate_required([:game_type, :user_id, :event_type])
    |> validate_inclusion(:event_type, ~w(win))
    |> validate_number(:amount, greater_than_or_equal_to: 0)
  end
end
