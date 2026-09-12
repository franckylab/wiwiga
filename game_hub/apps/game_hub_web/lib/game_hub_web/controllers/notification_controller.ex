# ==================================
# WIWIGA - Controller Notifications Joueur (inbox)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.NotificationController

defmodule GameHubWeb.NotificationController do
  @moduledoc """
  Controller inbox joueur.

  ## Endpoints
      GET  /api/notifications              - Liste inbox paginée
      GET  /api/notifications/unread-count - Compteur non-lues
      PUT  /api/notifications/:id/read     - Marquer comme lue
      PUT  /api/notifications/read-all     - Tout marquer lu
      GET  /api/notifications/preferences  - Préférences
      PUT  /api/notifications/preferences  - MAJ préférence
      POST /api/notifications/device-token - Enregistrer token push
      DELETE /api/notifications/device-token - Supprimer token push
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications

  defp current_user_id(conn) do
    conn |> GameHubWeb.AuthPlug.get_current_user_id() |> to_string() |> String.to_integer()
  end

  @doc """
  GET /api/notifications
  """
  def index(conn, params) do
    user_id = current_user_id(conn)

    case Notifications.list_for_user(user_id, params) do
      {:ok, items, total} ->
        page = params |> Map.get("page", "1") |> parse_int(1)
        limit = params |> Map.get("limit", "20") |> parse_int(20)

        conn
        |> put_status(200)
        |> json(%{success: true, data: %{notifications: items, total: total, page: page, limit: limit}})
    end
  end

  @doc """
  GET /api/notifications/unread-count
  """
  def unread_count(conn, _params) do
    count = conn |> current_user_id() |> Notifications.unread_count()

    conn
    |> put_status(200)
    |> json(%{success: true, data: %{unread_count: count}})
  end

  @doc """
  PUT /api/notifications/:id/read
  """
  def mark_read(conn, %{"id" => id}) do
    user_id = current_user_id(conn)

    case Notifications.mark_read(user_id, String.to_integer(id)) do
      {:ok, notification} ->
        conn |> put_status(200) |> json(%{success: true, data: notification})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Notification non trouvée"})
    end
  end

  @doc """
  PUT /api/notifications/read-all
  """
  def mark_all_read(conn, _params) do
    {:ok, count} = conn |> current_user_id() |> Notifications.mark_all_read()

    conn
    |> put_status(200)
    |> json(%{success: true, data: %{marked: count}, message: "Inbox marquée comme lue"})
  end

  @doc """
  DELETE /api/notifications/:id
  Supprime une notification de l'inbox (propriété vérifiée).
  """
  def delete(conn, %{"id" => id}) do
    user_id = current_user_id(conn)
    {:ok, count} = Notifications.delete_notification(user_id, String.to_integer(id))

    if count > 0 do
      conn |> put_status(200) |> json(%{success: true, message: "Notification supprimée"})
    else
      conn |> put_status(404) |> json(%{success: false, message: "Notification non trouvée"})
    end
  end

  @doc """
  GET /api/notifications/preferences
  """
  def list_preferences(conn, _params) do
    prefs = conn |> current_user_id() |> Notifications.list_preferences()

    conn |> put_status(200) |> json(%{success: true, data: prefs})
  end

  @doc """
  PUT /api/notifications/preferences
  Body: {category, channel, enabled}
  """
  def upsert_preference(conn, params) do
    user_id = current_user_id(conn)
    category = Map.get(params, "category", "")
    channel = Map.get(params, "channel", "")
    enabled = Map.get(params, "enabled", true)

    case Notifications.upsert_preference(user_id, category, channel, enabled) do
      {:ok, pref} ->
        conn |> put_status(200) |> json(%{success: true, data: pref})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Préférence invalide", errors: format_errors(changeset)})
    end
  end

  @doc """
  POST /api/notifications/device-token
  Body: {platform, token, app_version}
  """
  def register_token(conn, params) do
    user_id = current_user_id(conn)
    # Pas de défaut : une platform absente doit répondre 422 (fail-fast)
    # plutôt qu'enregistrer un "android" mensonger.
    platform = Map.get(params, "platform")
    token = Map.get(params, "token", "")
    app_version = Map.get(params, "app_version")

    case Notifications.register_device_token(user_id, platform, token, app_version) do
      {:ok, device} ->
        conn |> put_status(201) |> json(%{success: true, data: device})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Token invalide", errors: format_errors(changeset)})
    end
  end

  @doc """
  DELETE /api/notifications/device-token
  Body: {token}
  """
  def unregister_token(conn, params) do
    token = Map.get(params, "token", "")
    {:ok, _} = Notifications.unregister_device_token(token)

    conn |> put_status(200) |> json(%{success: true, message: "Token supprimé"})
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
