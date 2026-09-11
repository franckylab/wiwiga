# ==================================
# WIWIGA - Schéma Delivery (tentatives par canal)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Delivery

defmodule GameHub.Notifications.Delivery do
  @moduledoc """
  Schéma des tentatives de livraison par canal/provider.

  Sépare l'intention (`Notification`) des tentatives (`Delivery`)
  pour tracer retries, failover et webhooks de réception (DLR).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :notification_id,
             :channel,
             :provider_id,
             :provider_name,
             :attempt_number,
             :status,
             :provider_message_id,
             :error_code,
             :error_message,
             :next_retry_at,
             :sent_at,
             :delivered_at,
             :inserted_at
           ]}

  @statuses ~w(queued processing sent delivered failed retrying cancelled)
  @channels ~w(in_app push sms email)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_deliveries" do
    field :notification_id, :integer
    field :channel, :string
    field :provider_id, :integer
    field :provider_name, :string
    field :attempt_number, :integer, default: 1
    field :status, :string, default: "queued"
    field :provider_message_id, :string
    field :error_code, :string
    field :error_message, :string
    field :next_retry_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :oban_job_id, :integer

    timestamps()
  end

  @doc """
  Changeset de création d'une tentative.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(delivery \\ %__MODULE__{}, attrs) do
    delivery
    |> cast(attrs, [
      :notification_id,
      :channel,
      :provider_id,
      :provider_name,
      :attempt_number,
      :status,
      :provider_message_id,
      :error_code,
      :error_message,
      :next_retry_at,
      :sent_at,
      :delivered_at,
      :oban_job_id
    ])
    |> validate_required([:notification_id, :channel])
    |> validate_inclusion(:channel, @channels)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempt_number, greater_than: 0)
  end
end
