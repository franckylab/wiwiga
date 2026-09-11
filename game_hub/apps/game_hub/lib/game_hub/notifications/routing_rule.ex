# ==================================
# WIWIGA - Schéma Règle de Routage
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.RoutingRule
# Description: Routage événement → canaux, administrable.
#              `is_active: false` = kill-switch (même l'inbox est coupée).

defmodule GameHub.Notifications.RoutingRule do
  @moduledoc """
  Règle de routage d'un événement vers ses canaux.

  Sans ligne DB, `Notifications.routing_for/1` applique le repli
  hardcodé (`in_app` uniquement) — l'envoi ne casse jamais.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :event_key, :channels, :is_active, :inserted_at]}

  @channels ~w(in_app push sms email)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_routing_rules" do
    field :event_key, :string
    field :channels, {:array, :string}, default: ["in_app"]
    field :is_active, :boolean, default: true
    field :created_by, :integer

    timestamps()
  end

  @doc """
  Changeset de création/mise à jour (au moins 1 canal).
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(rule \\ %__MODULE__{}, attrs) do
    rule
    |> cast(attrs, [:event_key, :channels, :is_active, :created_by])
    |> validate_required([:event_key, :channels])
    |> validate_length(:channels, min: 1)
    |> validate_subset(:channels, @channels)
    |> unique_constraint(:event_key)
  end

  @doc """
  Canaux valides.
  """
  @spec channels() :: list(String.t())
  def channels, do: @channels
end
