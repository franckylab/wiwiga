# ==================================
# WIWIGA - Module Admin Notifications
# ==================================
# Module: GameHub.Admin.Notifications
# Description: Gestion des notifications admin

defmodule GameHub.Admin.Notifications do
  @moduledoc """
  Module de gestion des notifications pour l'administration.
  """

  alias GameHub.Repo
  alias GameHub.Admin.Notifications.Notification
  import Ecto.Query

  @doc """
  Crée une notification.
  """
  @spec create(map()) :: {:ok, Notification.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Liste les notifications avec filtres et pagination.
  """
  @spec list(map()) :: {:ok, list(), integer()}
  def list(filters \\ %{}) do
    page = Map.get(filters, "page", "1") |> String.to_integer()
    limit = Map.get(filters, "limit", "20") |> String.to_integer() |> min(100)
    offset = (page - 1) * limit

    query = from n in Notification, order_by: [desc: n.inserted_at]

    query = case Map.get(filters, "type") do
      nil -> query
      type -> from n in query, where: n.type == ^type
    end

    query = case Map.get(filters, "is_read") do
      nil -> query
      "true" -> from n in query, where: n.is_read == true
      "false" -> from n in query, where: n.is_read == false
      _ -> query
    end

    total = Repo.one(from n in query, select: count(n.id))
    notifications = Repo.all(from n in query, limit: ^limit, offset: ^offset)

    {:ok, notifications, total}
  end

  @doc """
  Marque une notification comme lue.
  """
  @spec mark_read(integer()) :: {:ok, Notification.t()} | {:error, term()}
  def mark_read(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, :not_found}
      notification ->
        notification
        |> Notification.mark_read_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Marque toutes les notifications comme lues.
  """
  @spec mark_all_read() :: {integer(), nil | term()}
  def mark_all_read do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Repo.update_all(
      from(n in Notification, where: n.is_read == false),
      set: [is_read: true, read_at: now]
    )
  end

  @doc """
  Compteur de notifications non lues.
  """
  @spec unread_count() :: integer()
  def unread_count do
    Repo.one(
      from n in Notification,
        where: n.is_read == false,
        select: count(n.id)
    )
  end

  @doc """
  Crée une notification de broadcast (pour tous les users).
  """
  @spec broadcast(String.t(), String.t(), integer()) :: {:ok, Notification.t()} | {:error, Ecto.Changeset.t()}
  def broadcast(title, message, admin_id) do
    create(%{
      type: "broadcast",
      title: title,
      message: message,
      target_type: "all",
      created_by: admin_id
    })
  end
end
