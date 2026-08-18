# ==================================
# WIWIGA - Schéma Admin Notification
# ==================================
# Module: GameHub.Admin.Notifications.Notification

defmodule GameHub.Admin.Notifications.Notification do
  @moduledoc """
  Schéma pour les notifications admin.
  
  Types:
  - `info`: Information générale
  - `alert`: Alerte système
  - `system`: Événement système
  - `broadcast`: Message diffusé aux users
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :type, :title, :message,
                                  :target_type, :target_id, :is_read, :read_at,
                                  :created_by, :inserted_at]}

  @types ~w(info alert system broadcast)

  @primary_key {:id, :id, autogenerate: true}
  schema "admin_notifications" do
    field :type, :string, default: "info"
    field :title, :string
    field :message, :string
    field :target_type, :string, default: "admin"
    field :target_id, :integer
    field :is_read, :boolean, default: false
    field :read_at, :utc_datetime
    field :created_by, :integer

    timestamps()
  end

  def types, do: @types

  def changeset(notification \\ %__MODULE__{}, attrs) do
    notification
    |> cast(attrs, [:type, :title, :message, :target_type, :target_id, :is_read, :read_at, :created_by])
    |> validate_required([:type, :title, :message])
    |> validate_inclusion(:type, @types)
  end

  def mark_read_changeset(notification) do
    notification
    |> change(%{
      is_read: true,
      read_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
end
