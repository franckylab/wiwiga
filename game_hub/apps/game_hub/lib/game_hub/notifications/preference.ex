# ==================================
# WIWIGA - Schéma Préférence Notification
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Preference

defmodule GameHub.Notifications.Preference do
  @moduledoc """
  Schéma des préférences utilisateur (matrice catégorie × canal).

  La catégorie `security` est non-désactivable (OTP, alertes).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :user_id, :category, :channel, :enabled]}

  @categories ~w(security transactional social game marketing)
  @channels ~w(in_app push sms email)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_preferences" do
    field :user_id, :integer
    field :category, :string
    field :channel, :string
    field :enabled, :boolean, default: true

    timestamps()
  end

  @doc """
  Retourne les catégories configurables.
  """
  @spec categories() :: list(String.t())
  def categories, do: @categories

  @doc """
  Changeset de création/mise à jour d'une préférence.
  La catégorie security reste toujours activée.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(preference \\ %__MODULE__{}, attrs) do
    preference
    |> cast(attrs, [:user_id, :category, :channel, :enabled])
    |> validate_required([:user_id, :category, :channel])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:channel, @channels)
    |> force_security_enabled()
    |> unique_constraint([:user_id, :category, :channel])
  end

  # La sécurité n'est jamais désactivable (OTP, alertes fraude).
  defp force_security_enabled(changeset) do
    case get_field(changeset, :category) do
      "security" -> put_change(changeset, :enabled, true)
      _ -> changeset
    end
  end
end
