# ==================================
# WIWIGA - Controller Admin Settings
# ==================================
# Module: GameHubWeb.AdminSettingsController
# Description: Endpoints settings système

defmodule GameHubWeb.AdminSettingsController do
  @moduledoc """
  Controller pour les paramètres système.
  
  ## Endpoints
    GET /api/admin/settings          - Tous les settings groupés par catégorie
    PUT /api/admin/settings/:key     - Update un setting
    GET /api/admin/settings/category/:category - Settings par catégorie
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.SystemSettings

  @doc """
  GET /api/admin/settings
  Tous les settings groupés par catégorie.
  """
  def index(conn, _params) do
    settings = SystemSettings.get_all_settings()

    conn
    |> put_status(200)
    |> json(%{success: true, data: settings})
  end

  @doc """
  GET /api/admin/settings/category/:category
  Settings par catégorie.
  """
  def by_category(conn, %{"category" => category}) do
    settings = SystemSettings.get_category(category)

    conn
    |> put_status(200)
    |> json(%{success: true, data: settings, category: category})
  end

  @doc """
  PUT /api/admin/settings/:key
  Met à jour un setting.
  """
  def update(conn, %{"key" => key} = params) do
    admin_id = conn.assigns[:current_user_id]
    value = params["value"]

    if is_nil(value) do
      conn
      |> put_status(400)
      |> json(%{success: false, error: %{code: "VALIDATION_ERROR", message: "Valeur requise"}})
    else
      case SystemSettings.update(key, to_string(value), admin_id) do
        {:ok, setting} ->
          conn
          |> put_status(200)
          |> json(%{success: true, data: setting})

        {:error, :not_found} ->
          conn
          |> put_status(404)
          |> json(%{success: false, error: %{code: "NOT_FOUND", message: "Setting '#{key}' non trouvé"}})
      end
    end
  end
end
