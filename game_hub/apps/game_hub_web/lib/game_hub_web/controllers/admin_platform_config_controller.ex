# ==================================
# WIWIGA - Controller Admin Platform Config
# ==================================
# Module: GameHubWeb.AdminPlatformConfigController
# Description: Endpoints API pour configuration plateforme centralisée

defmodule GameHubWeb.AdminPlatformConfigController do
  use GameHubWeb, :controller

  alias GameHub.Admin.PlatformConfig

  @doc """
  GET /api/admin/platform-config
  Liste toutes les configurations groupées par catégorie.
  """
  def index(conn, _params) do
    grouped = PlatformConfig.get_all_grouped()
    json(conn, %{data: grouped, categories: PlatformConfig.valid_categories()})
  end

  @doc """
  GET /api/admin/platform-config/:category
  Récupère les configurations d'une catégorie.
  """
  def show(conn, %{"category" => category}) do
    if category in PlatformConfig.valid_categories() do
      configs = PlatformConfig.get_category(category)
      json(conn, %{data: configs, category: category})
    else
      conn |> put_status(:bad_request) |> json(%{error: "Catégorie invalide", valid: PlatformConfig.valid_categories()})
    end
  end

  @doc """
  PUT /api/admin/platform-config/:category/:key
  Met à jour une valeur de configuration.
  """
  def update(conn, %{"category" => category, "key" => key, "value" => value}) do
    admin_id = conn.assigns[:current_admin_id] || 0

    case PlatformConfig.update(category, key, value, admin_id) do
      {:ok, config} ->
        json(conn, %{data: config, message: "Configuration mise à jour"})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Configuration non trouvée"})
      {:error, :invalid_category} ->
        conn |> put_status(:bad_request) |> json(%{error: "Catégorie invalide"})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  PUT /api/admin/platform-config/:category/batch
  Met à jour plusieurs configurations d'une catégorie.
  """
  def batch_update(conn, %{"category" => category, "updates" => updates}) when is_list(updates) do
    admin_id = conn.assigns[:current_admin_id] || 0

    parsed_updates = Enum.map(updates, fn %{"key" => key, "value" => value} ->
      %{key: key, value: value}
    end)

    case PlatformConfig.update_batch(category, parsed_updates, admin_id) do
      {:ok, count} ->
        json(conn, %{message: "#{count} configurations mises à jour", updated: count})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  GET /api/admin/platform-config/health
  Vérifie la santé de la configuration (toutes catégories).
  """
  def health(conn, _params) do
    grouped = PlatformConfig.get_all_grouped()
    categories = PlatformConfig.valid_categories()

    health_data = Enum.map(categories, fn cat ->
      configs = Map.get(grouped, cat, [])
      %{
        category: cat,
        total: length(configs),
        configured: Enum.count(configs, fn c -> c.value != nil and c.value != "" end),
        editable: Enum.count(configs, fn c -> c.is_editable end)
      }
    end)

    json(conn, %{data: health_data})
  end
end
