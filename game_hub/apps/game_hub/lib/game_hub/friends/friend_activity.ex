# ==================================
# WIWIGA - Schema Friend Activity
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Friends.FriendActivity
# Description: Schema Ecto pour activités des amis

defmodule GameHub.Friends.FriendActivity do
  @moduledoc """
  Schema des activités des amis.

  ## Actions possibles
    - `game_won` : partie gagnée
    - `game_lost` : partie perdue
    - `friend_added` : ami ajouté
    - `level_up` : niveau atteint
    - `bet_placed` : mise placée
    - `achievement_unlocked` : succès débloqué
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :bigserial, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :user_id, :action, :metadata, :inserted_at]}

  schema "friend_activities" do
    field :user_id, :integer
    field :action, :string
    field :metadata, :map, default: %{}

    timestamps()
  end

  @valid_actions ~w(game_won game_lost friend_added level_up bet_placed achievement_unlocked)

  def create_changeset(activity, attrs) do
    activity
    |> cast(attrs, [:user_id, :action, :metadata])
    |> validate_required([:user_id, :action])
    |> validate_inclusion(:action, @valid_actions)
  end
end
