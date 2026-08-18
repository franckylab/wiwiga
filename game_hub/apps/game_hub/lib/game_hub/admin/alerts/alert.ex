# ==================================
# WIWIGA - Schéma Admin Alert
# ==================================
# Module: GameHub.Admin.Alerts.Alert

defmodule GameHub.Admin.Alerts.Alert do
  @moduledoc """
  Schéma pour les alertes d'administration.
  
  Types d'alertes:
  - `financial`: seuil financier dépassé
  - `system`: problème système (latence, mémoire)
  - `security`: activité suspecte
  - `payment`: erreur paiement
  - `game`: anomalie jeu
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :alert_type, :severity, :title, :message,
                                  :metadata, :is_resolved, :resolved_by, :resolved_at,
                                  :acknowledged_by, :acknowledged_at, :inserted_at, :updated_at]}

  @severities ~w(info warning critical)
  @alert_types ~w(financial system security payment game)

  @primary_key {:id, :id, autogenerate: true}
  schema "admin_alerts" do
    field :alert_type, :string
    field :severity, :string, default: "warning"
    field :title, :string
    field :message, :string
    field :metadata, :map, default: %{}
    field :is_resolved, :boolean, default: false
    field :resolved_by, :integer
    field :resolved_at, :utc_datetime
    field :acknowledged_by, :integer
    field :acknowledged_at, :utc_datetime

    timestamps()
  end

  def severities, do: @severities
  def alert_types, do: @alert_types

  def changeset(alert \\ %__MODULE__{}, attrs) do
    alert
    |> cast(attrs, [
      :alert_type, :severity, :title, :message, :metadata,
      :is_resolved, :resolved_by, :resolved_at,
      :acknowledged_by, :acknowledged_at
    ])
    |> validate_required([:alert_type, :severity, :title, :message])
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:alert_type, @alert_types)
  end

  def resolve_changeset(alert, admin_id) do
    alert
    |> change(%{
      is_resolved: true,
      resolved_by: admin_id,
      resolved_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def acknowledge_changeset(alert, admin_id) do
    alert
    |> change(%{
      acknowledged_by: admin_id,
      acknowledged_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
