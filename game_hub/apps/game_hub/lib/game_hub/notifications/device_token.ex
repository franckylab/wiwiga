# ==================================
# WIWIGA - Schéma Device Token (push)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.DeviceToken

defmodule GameHub.Notifications.DeviceToken do
  @moduledoc """
  Schéma des tokens push (FCM/APNs/Web Push).

  Un token invalide (`NotRegistered`) est marqué `is_valid: false`
  au lieu d'être supprimé, pour audit.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :user_id, :platform, :app_version, :is_valid, :last_seen_at]}

  @platforms ~w(android ios web)

  @primary_key {:id, :id, autogenerate: true}
  schema "device_tokens" do
    field :user_id, :integer
    field :platform, :string
    field :token, :string
    field :app_version, :string
    field :last_seen_at, :utc_datetime
    field :is_valid, :boolean, default: true

    timestamps()
  end

  @doc """
  Changeset d'enregistrement/mise à jour d'un token.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(device_token \\ %__MODULE__{}, attrs) do
    device_token
    |> cast(attrs, [:user_id, :platform, :token, :app_version, :last_seen_at, :is_valid])
    |> validate_required([:user_id, :platform, :token])
    |> validate_inclusion(:platform, @platforms)
    |> validate_length(:token, min: 10)
    |> unique_constraint(:token)
  end

  @doc """
  Changeset d'invalidation (token expiré côté provider).
  """
  @spec invalidate_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def invalidate_changeset(device_token) do
    change(device_token, %{is_valid: false})
  end
end
