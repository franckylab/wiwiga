# ==================================
# WIWIGA - Controller Admin Notifications
# ==================================
# Module: GameHubWeb.AdminNotificationsController
# Description: Gestion des notifications admin

defmodule GameHubWeb.AdminNotificationsController do
  @moduledoc """
  Controller pour les notifications admin.
  
  ## Endpoints
    GET  /api/admin/notifications             - Liste notifications
    PUT  /api/admin/notifications/:id/read    - Marquer comme lu
    POST /api/admin/notifications/broadcast   - Diffuser message
    GET  /api/admin/notifications/unread-count - Compteur non-lus
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Notifications
  alias GameHub.AuditLog

  @doc """
  GET /api/admin/notifications
  Liste les notifications avec filtres.
  """
  def list(conn, params) do
    case Notifications.list(params) do
      {:ok, notifications, total} ->
        page = Map.get(params, "page", "1") |> String.to_integer()
        limit = Map.get(params, "limit", "20") |> String.to_integer()

        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            notifications: notifications,
            total: total,
            page: page,
            limit: limit,
            total_pages: ceil(total / limit)
          }
        })
    end
  end

  @doc """
  PUT /api/admin/notifications/:id/read
  Marquer une notification comme lue.
  """
  def mark_read(conn, %{"id" => id}) do
    notification_id = String.to_integer(id)

    case Notifications.mark_read(notification_id) do
      {:ok, notification} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: notification})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Notification non trouvée"})
    end
  end

  @doc """
  POST /api/admin/notifications/broadcast
  Diffuser un message à tous les utilisateurs.
  """
  def broadcast(conn, params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    title = Map.get(params, "title", "Annonce")
    message = Map.get(params, "message", "")

    if message == "" do
      conn
      |> put_status(400)
      |> json(%{success: false, message: "Message requis"})
    else
      case Notifications.broadcast(title, message, admin_id) do
        {:ok, notification} ->
          # Broadcast via WebSocket
          try do
            GameHubWeb.Endpoint.broadcast!("user:notifications", "broadcast", %{
              title: title,
              message: message,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            })
          rescue
            _ -> :ok
          end

          AuditLog.log("admin_action", admin_id, "notifications", to_string(notification.id), %{
            "action" => "broadcast",
            "title" => title
          })

          conn
          |> put_status(201)
          |> json(%{success: true, data: notification, message: "Message diffusé"})

        {:error, _changeset} ->
          conn
          |> put_status(422)
          |> json(%{success: false, message: "Erreur de validation"})
      end
    end
  end

  @doc """
  GET /api/admin/notifications/unread-count
  Compteur de notifications non lues.
  """
  def unread_count(conn, _params) do
    count = Notifications.unread_count()

    conn
    |> put_status(200)
    |> json(%{success: true, data: %{unread_count: count}})
  end
end
