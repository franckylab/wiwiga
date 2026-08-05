# ==================================
# WIWIGA - Schema User Session
# ==================================
# Module: GameHub.Users.UserSession
# Description: Session active utilisateur (tracking appareils)

defmodule GameHub.Users.UserSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "user_sessions" do
    belongs_to :user, GameHub.Users.User
    field :device_id, :string
    field :user_agent, :string
    field :ip_address, :string
    field :last_active_at, :utc_datetime
    field :is_current, :boolean, default: false

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :device_id, :user_agent, :ip_address, :last_active_at, :is_current])
    |> validate_required([:user_id, :last_active_at])
  end
end
