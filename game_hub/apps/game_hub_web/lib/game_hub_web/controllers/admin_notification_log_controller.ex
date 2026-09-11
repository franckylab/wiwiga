# ==================================
# WIWIGA - Controller Admin Logs Notifications
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminNotificationLogController

defmodule GameHubWeb.AdminNotificationLogController do
  @moduledoc """
  Controller admin logs, stats et replay.

  ## Endpoints
      GET  /api/admin/notification-logs
      GET  /api/admin/notification-logs/stats
      GET  /api/admin/notification-logs/:id
      POST /api/admin/notification-logs/:id/replay
      POST /api/admin/notification-logs/seed-defaults
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications
  alias GameHub.AuditLog

  @doc """
  GET /api/admin/notification-logs
  """
  def index(conn, params) do
    {:ok, items, total} = Notifications.list_logs(params)
    page = params |> Map.get("page", "1") |> parse_int(1)
    limit = params |> Map.get("limit", "20") |> parse_int(20)

    conn
    |> put_status(200)
    |> json(%{success: true, data: %{logs: items, total: total, page: page, limit: limit}})
  end

  @doc """
  GET /api/admin/notification-logs/stats
  """
  def stats(conn, _params) do
    conn |> put_status(200) |> json(%{success: true, data: Notifications.stats()})
  end

  @doc """
  GET /api/admin/notification-logs/timeseries?days=14
  Série quotidienne pour les graphiques (total, envoyées, échouées, attente).
  """
  def timeseries(conn, params) do
    days =
      case Integer.parse(to_string(Map.get(params, "days", "14"))) do
        {n, _} -> n
        :error -> 14
      end

    conn |> put_status(200) |> json(%{success: true, data: Notifications.timeseries(days)})
  end

  @doc """
  GET /api/admin/notification-logs/:id
  """
  def show(conn, %{"id" => id}) do
    case Notifications.get_log(String.to_integer(id)) do
      {:ok, detail} ->
        conn |> put_status(200) |> json(%{success: true, data: detail})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Notification non trouvée"})
    end
  end

  @doc """
  POST /api/admin/notification-logs/:id/replay
  """
  def replay(conn, %{"id" => id}) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.replay(String.to_integer(id)) do
      {:ok, notification} ->
        AuditLog.log("admin_action", to_int(admin_id), "notifications", id, %{"action" => "replay"})

        conn |> put_status(201) |> json(%{success: true, data: notification, message: "Notification rejouée"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{success: false, message: "Replay échoué : #{inspect(reason)}"})
    end
  end

  @doc """
  POST /api/admin/notification-logs/seed-defaults
  """
  def seed_defaults(conn, _params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    {:ok, result} = Notifications.seed_defaults()
    AuditLog.log("admin_action", to_int(admin_id), "notifications", "seed", %{"action" => "seed_defaults"})

    conn |> put_status(200) |> json(%{success: true, data: result, message: "Providers et templates par défaut installés"})
  end

  @doc """
  POST /api/admin/notification-logs/broadcast
  Diffuse une annonce à TOUS les utilisateurs actifs (lots async).
  Body: {title, message, category?, scheduled_at?}
  - category : transactional (défaut) | marketing (opt-out + heures creuses)
  - scheduled_at : ISO8601 UTC (envoi planifié, sinon immédiat)
  """
  def broadcast(conn, params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    title = params |> Map.get("title", "Annonce") |> to_string()
    message = params |> Map.get("message", "") |> to_string()
    category = params |> Map.get("category", "transactional") |> to_string()

    with {:message, true} <- {:message, message != ""},
         {:scheduled, {:ok, scheduled_at}} <- {:scheduled, parse_scheduled_at(Map.get(params, "scheduled_at"))},
         {:ok, event_id} <- Notifications.broadcast_to_all(title, message, category: category, scheduled_at: scheduled_at) do
      AuditLog.log("admin_action", to_int(admin_id), "notifications", "broadcast", %{"action" => "broadcast_all", "title" => title, "category" => category})

      conn |> put_status(202) |> json(%{success: true, data: %{event_id: event_id}, message: "Diffusion planifiée"})
    else
      {:message, false} ->
        conn |> put_status(400) |> json(%{success: false, message: "Message requis"})

      {:scheduled, {:error, _}} ->
        conn |> put_status(400) |> json(%{success: false, message: "scheduled_at invalide (ISO8601 UTC attendu)"})

      {:error, :invalid_category} ->
        conn |> put_status(400) |> json(%{success: false, message: "Catégorie invalide (transactional|marketing)"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{success: false, message: "Diffusion échouée : #{inspect(reason)}"})
    end
  end

  # ISO8601 optionnel → DateTime ou nil (envoi immédiat).
  defp parse_scheduled_at(nil), do: {:ok, nil}
  defp parse_scheduled_at(""), do: {:ok, nil}

  defp parse_scheduled_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, :invalid}
    end
  end

  defp parse_scheduled_at(_), do: {:error, :invalid}

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
