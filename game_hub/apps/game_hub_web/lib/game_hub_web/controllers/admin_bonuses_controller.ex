# ==================================
# WIWIGA - Admin Bonuses Controller
# ==================================
# Endpoints: List, Create, Update, Toggle, Stats

defmodule GameHubWeb.AdminBonusesController do
  use GameHubWeb, :controller

  alias GameHub.Admin.Bonuses

  def index(conn, params) do
    bonuses = Bonuses.list_bonuses(params)
    json(conn, %{bonuses: bonuses})
  end

  def create(conn, params) do
    admin_id = get_admin_id(conn)

    case Bonuses.create_bonus(params, admin_id) do
      {:ok, bonus} ->
        conn |> put_status(201) |> json(%{bonus: bonus})
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    admin_id = get_admin_id(conn)

    case Bonuses.update_bonus(String.to_integer(id), params, admin_id) do
      {:ok, bonus} ->
        json(conn, %{bonus: bonus})
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def toggle(conn, %{"id" => id} = params) do
    admin_id = get_admin_id(conn)
    active = Map.get(params, "is_active", true)

    case Bonuses.toggle_bonus(String.to_integer(id), active, admin_id) do
      {:ok, bonus} ->
        json(conn, %{bonus: bonus})
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def stats(conn, %{"id" => id}) do
    case Bonuses.get_bonus_stats(String.to_integer(id)) do
      {:ok, stats} ->
        json(conn, stats)
      {:error, reason} ->
        conn |> put_status(404) |> json(%{error: to_string(reason)})
    end
  end

  defp get_admin_id(conn) do
    case conn.assigns[:current_user] do
      %{id: id} when is_integer(id) -> id
      _ ->
        case conn.assigns[:current_user_id] do
          id when is_integer(id) -> id
          id when is_binary(id) ->
            case Integer.parse(id) do {n,_} -> n; :error -> 0 end
          _ ->
            case conn.assigns[:current_admin] do %{id: id} -> id; _ -> conn.private[:current_user_id] || 0 end
            |> then(fn v -> if is_binary(v) do case Integer.parse(v) do {n,_} -> n; :error -> 0 end else v end end)
        end
    end
  end
end
