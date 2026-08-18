# ==================================
# WIWIGA - Admin GameConfig Controller
# ==================================
# Endpoints: List, Update, Create game configurations

defmodule GameHubWeb.AdminGameConfigController do
  use GameHubWeb, :controller

  alias GameHub.Admin.GameConfig

  def index(conn, _params) do
    configs = GameConfig.list_configs()
    json(conn, %{configs: configs})
  end

  def update(conn, %{"game_type" => game_type} = params) do
    admin_id = get_admin_id(conn)

    case GameConfig.upsert_config(Map.put(params, "game_type", game_type), admin_id) do
      {:ok, config} ->
        json(conn, %{config: config})
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def create(conn, params) do
    admin_id = get_admin_id(conn)

    case GameConfig.upsert_config(params, admin_id) do
      {:ok, config} ->
        conn |> put_status(201) |> json(%{config: config})
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  defp get_admin_id(conn) do
    case conn.assigns[:current_admin] do
      %{id: id} -> id
      _ -> 0
    end
  end
end
