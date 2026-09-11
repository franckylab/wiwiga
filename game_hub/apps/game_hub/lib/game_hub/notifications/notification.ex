# ==================================
# WIWIGA - Schéma Notification (inbox joueur)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Notification

defmodule GameHub.Notifications.Notification do
  @moduledoc """
  Schéma d'intention de notification + inbox joueur.

  Chaque ligne = un événement destiné à un utilisateur, avec
  `idempotency_key` unique (`event_id + user_id + template_key + channel`)
  pour permettre les retries sans doublon.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :event_type,
             :user_id,
             :template_key,
             :template_version,
             :title,
             :body,
             :category,
             :priority,
             :status,
             :action,
             :is_read,
             :read_at,
             :scheduled_at,
             :inserted_at
           ]}

  @priorities ~w(urgent high normal low)
  @statuses ~w(queued processing sent delivered failed retrying cancelled)
  @categories ~w(security transactional social game marketing)

  @primary_key {:id, :id, autogenerate: true}
  schema "notifications" do
    field :event_type, :string
    field :user_id, :integer
    field :template_key, :string
    field :template_version, :integer, default: 1
    field :title, :string
    field :body, :string
    field :variables, :map, default: %{}
    field :category, :string, default: "transactional"
    field :priority, :string, default: "normal"
    field :status, :string, default: "queued"
    field :idempotency_key, :string
    field :scheduled_at, :utc_datetime
    field :read_at, :utc_datetime
    field :is_read, :boolean, default: false
    field :action, :string

    timestamps()
  end

  @doc """
  Changeset de création d'une notification.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(notification \\ %__MODULE__{}, attrs) do
    notification
    |> cast(attrs, [
      :event_type,
      :user_id,
      :template_key,
      :template_version,
      :title,
      :body,
      :variables,
      :category,
      :priority,
      :status,
      :idempotency_key,
      :scheduled_at,
      :read_at,
      :is_read,
      :action
    ])
    |> validate_required([:event_type, :user_id, :template_key, :title, :body, :idempotency_key])
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:category, @categories)
    |> unique_constraint(:idempotency_key)
  end

  @doc """
  Changeset de marquage comme lue.
  """
  @spec mark_read_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def mark_read_changeset(notification) do
    change(notification, %{
      is_read: true,
      read_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  @doc """
  Changeset de mise à jour du statut de traitement.
  """
  @spec status_changeset(%__MODULE__{}, String.t()) :: Ecto.Changeset.t()
  def status_changeset(notification, status) do
    notification
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end
end
