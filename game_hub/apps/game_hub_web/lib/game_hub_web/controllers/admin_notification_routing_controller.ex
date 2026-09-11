# ==================================
# WIWIGA - Controller Admin Routage Notifications
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminNotificationRoutingController

defmodule GameHubWeb.AdminNotificationRoutingController do
  @moduledoc """
  Controller admin du routage événements → canaux.

  ## Endpoints
      GET /api/admin/notification-routing
      PUT /api/admin/notification-routing/:key
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications
  alias GameHub.AuditLog

  @doc """
  GET /api/admin/notification-routing
  Liste tous les événements avec leur routage effectif.
  """
  def index(conn, _params) do
    conn |> put_status(200) |> json(%{success: true, data: Notifications.list_routing()})
  end

  @doc """
  PUT /api/admin/notification-routing/:key
  Body: {channels: [...], is_active: bool}
  """
  def upsert(conn, %{"key" => key} = params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.upsert_routing(key, params) do
      {:ok, rule} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_routing", key, %{
          "action" => "upsert",
          "channels" => rule.channels,
          "is_active" => rule.is_active
        })

        conn |> put_status(200) |> json(%{success: true, data: rule})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Règle invalide", errors: format_errors(changeset)})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{success: false, message: "Erreur : #{inspect(reason)}"})
    end
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
