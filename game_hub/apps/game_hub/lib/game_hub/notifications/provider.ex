# ==================================
# WIWIGA - Schéma Provider Notification
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Provider
# Description: Configuration persistante des providers multi-canaux

defmodule GameHub.Notifications.Provider do
  @moduledoc """
  Schéma de configuration des providers de notification.

  ## Canaux
    - `in_app` : inbox + WebSocket (toujours disponible, sans provider externe)
    - `push` : FCM v1 (fcm_v1), OneSignal (onesignal)
    - `sms` : Orange CM (orange_cm), MTN CM (mtn_cm), eSMS Africa (esms_africa), Twilio (twilio)
    - `email` : SMTP (smtp), SendGrid (sendgrid), SES (ses), Postmark (postmark), Brevo (brevo)

  ## Sécurité
  Le champ `config` contient les secrets (clé API, sender ID...).
  Il sera chiffré via Cloak en Phase 1. Ne jamais logger son contenu.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :channel,
             :name,
             :display_name,
             :is_active,
             :is_default,
             :priority,
             :rate_limit_per_min,
             :quota_monthly,
             :supports_delivery_webhook,
             :last_health_check_at,
             :last_health_status,
             :last_error,
             :config_keys,
             :secrets_set,
             :inserted_at
           ]}

  @channels ~w(in_app push sms email)
  @statuses ~w(healthy degraded down unchecked)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_providers" do
    field :channel, :string
    field :name, :string
    field :display_name, :string
    field :is_active, :boolean, default: false
    field :is_default, :boolean, default: false
    field :priority, :integer, default: 100
    field :config, :map, default: %{}
    field :rate_limit_per_min, :integer, default: 60
    field :quota_monthly, :integer
    field :supports_delivery_webhook, :boolean, default: false
    field :last_health_check_at, :utc_datetime
    field :last_health_status, :string, default: "unchecked"
    field :last_error, :string
    field :created_by, :integer

    # Compteurs non sensibles calculés (jamais persistés)
    field :config_keys, :integer, virtual: true
    field :secrets_set, :integer, virtual: true

    timestamps()
  end

  @doc """
  Retourne les canaux supportés.
  """
  @spec channels() :: list(String.t())
  def channels, do: @channels

  @doc """
  Retourne les statuts de santé possibles.
  """
  @spec health_statuses() :: list(String.t())
  def health_statuses, do: @statuses

  @doc """
  Changeset de création/mise à jour d'un provider.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(provider \\ %__MODULE__{}, attrs) do
    provider
    |> cast(attrs, [
      :channel,
      :name,
      :display_name,
      :is_active,
      :is_default,
      :priority,
      :config,
      :rate_limit_per_min,
      :quota_monthly,
      :supports_delivery_webhook,
      :last_health_check_at,
      :last_health_status,
      :last_error,
      :created_by
    ])
    |> validate_required([:channel, :name, :display_name])
    |> validate_inclusion(:channel, @channels)
    |> validate_length(:name, min: 2, max: 60)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:rate_limit_per_min, greater_than: 0)
    |> validate_inclusion(:last_health_status, @statuses)
    |> unique_constraint([:channel, :name])
  end

  @doc """
  Changeset de mise à jour du statut de santé (health check).
  """
  @spec health_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def health_changeset(provider, attrs) do
    provider
    |> cast(attrs, [:last_health_check_at, :last_health_status, :last_error])
    |> validate_inclusion(:last_health_status, @statuses)
  end
end
