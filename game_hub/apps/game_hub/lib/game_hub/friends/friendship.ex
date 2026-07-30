# ==================================
# WIWIGA - Schema Friendship
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Friends.Friendship
# Description: Schema Ecto pour relations d'amitié

defmodule GameHub.Friends.Friendship do
  @moduledoc """
  Schema des relations d'amitié.

  ## Status
    - `pending` : demande envoyée, en attente
    - `accepted` : demande acceptée
    - `blocked` : utilisateur bloqué
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :bigserial, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :user_id, :friend_id, :status, :inserted_at]}

  schema "friendships" do
    field :user_id, :integer
    field :friend_id, :integer
    field :status, :string, default: "pending"

    timestamps()
  end

  @valid_statuses ~w(pending accepted blocked)

  def create_changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:user_id, :friend_id, :status])
    |> validate_required([:user_id, :friend_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_not_self()
    |> unique_constraint([:user_id, :friend_id])
  end

  def accept_changeset(friendship) do
    friendship
    |> change(%{status: "accepted"})
  end

  def block_changeset(friendship) do
    friendship
    |> change(%{status: "blocked"})
  end

  defp validate_not_self(changeset) do
    user_id = get_field(changeset, :user_id)
    friend_id = get_field(changeset, :friend_id)

    if user_id && friend_id && user_id == friend_id do
      add_error(changeset, :friend_id, "ne peut pas s'ajouter soi-même")
    else
      changeset
    end
  end
end
