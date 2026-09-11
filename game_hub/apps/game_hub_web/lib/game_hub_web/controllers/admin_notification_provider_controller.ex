# ==================================
# WIWIGA - Controller Admin Providers Notifications
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminNotificationProviderController

defmodule GameHubWeb.AdminNotificationProviderController do
  @moduledoc """
  Controller admin CRUD providers multi-canaux.

  ## Endpoints
      GET  /api/admin/notification-providers
      POST /api/admin/notification-providers
      PUT  /api/admin/notification-providers/:id
      POST /api/admin/notification-providers/:id/test
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications
  alias GameHub.AuditLog

  @doc """
  GET /api/admin/notification-providers
  """
  def index(conn, params) do
    providers = Notifications.list_providers(params)

    conn |> put_status(200) |> json(%{success: true, data: providers})
  end

  @doc """
  POST /api/admin/notification-providers
  """
  def create(conn, params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.create_provider(params) do
      {:ok, provider} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_providers", to_string(provider.id), %{"action" => "create", "channel" => provider.channel, "name" => provider.name})

        conn |> put_status(201) |> json(%{success: true, data: provider, message: "Provider créé"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Validation échouée", errors: format_errors(changeset)})
    end
  end

  @doc """
  PUT /api/admin/notification-providers/:id
  """
  def update(conn, %{"id" => id} = params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.update_provider(String.to_integer(id), params) do
      {:ok, provider} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_providers", id, %{"action" => "update"})

        conn |> put_status(200) |> json(%{success: true, data: provider})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Validation échouée", errors: format_errors(changeset)})
    end
  end

  @doc """
  GET /api/admin/notification-providers/:id/config
  Config assainie (secrets masqués, jamais exposés).
  """
  def show_config(conn, %{"id" => id}) do
    case Notifications.get_provider_config(String.to_integer(id)) do
      {:ok, config} ->
        conn |> put_status(200) |> json(%{success: true, data: config})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})
    end
  end

  @doc """
  PUT /api/admin/notification-providers/:id/config
  Fusion partielle (secrets vides = conserver l'existant).
  Body: {config: {...}}
  """
  def update_config(conn, %{"id" => id} = params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    config_params = Map.get(params, "config", %{})

    case Notifications.update_provider_config(String.to_integer(id), config_params) do
      {:ok, config} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_providers", id, %{"action" => "update_config"})

        conn |> put_status(200) |> json(%{success: true, data: config, message: "Configuration enregistrée"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Validation échouée", errors: format_errors(changeset)})
    end
  end

  @doc """
  DELETE /api/admin/notification-providers/:id
  """
  def delete(conn, %{"id" => id}) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    {:ok, count} = Notifications.delete_provider(String.to_integer(id))
    AuditLog.log("admin_action", to_int(admin_id), "notification_providers", id, %{"action" => "delete"})

    if count > 0 do
      conn |> put_status(200) |> json(%{success: true, message: "Provider supprimé"})
    else
      conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})
    end
  end

  @doc """
  POST /api/admin/notification-providers/:id/health
  Vérifie la santé SANS envoyer de message (credentials, connectivité).
  """
  def check_health(conn, %{"id" => id}) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.check_provider_health(String.to_integer(id)) do
      {:ok, result} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_providers", id, %{"action" => "health_check"})

        conn |> put_status(200) |> json(%{success: true, data: result, message: "Vérification effectuée"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{success: false, message: "Vérification échouée : #{inspect(reason)}"})
    end
  end

  @doc """
  POST /api/admin/notification-providers/:id/test
  Body: {recipient}
  """
  def test_connection(conn, %{"id" => id} = params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    recipient = params |> Map.get("recipient", "") |> to_string()

    require Logger
    Logger.info("[AdminProviders] test id=#{id} par admin=#{admin_id} (destinataire #{String.length(recipient)} caractères)")

    case Notifications.test_provider(String.to_integer(id), params) do
      {:ok, result} ->
        Logger.info("[AdminProviders] test id=#{id} OK : #{inspect(Map.get(result, :status))}")
        AuditLog.log("admin_action", to_int(admin_id), "notification_providers", id, %{"action" => "test"})

        conn |> put_status(200) |> json(%{success: true, data: result, message: "Test effectué"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Provider non trouvé"})

      {:error, reason} ->
        Logger.warning("[AdminProviders] test id=#{id} échec : #{inspect(reason) |> String.slice(0, 300)}")
        conn |> put_status(422) |> json(%{success: false, message: "Test échoué : #{inspect(reason)}"})
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
