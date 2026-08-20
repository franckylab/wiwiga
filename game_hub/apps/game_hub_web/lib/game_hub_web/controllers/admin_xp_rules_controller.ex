# ==================================
# WIWIGA - Admin XP Rules Controller
# ==================================
# Module: GameHubWeb.AdminXPRulesController
# Description: API pour gérer les règles de gain XP par type de jeu

defmodule GameHubWeb.AdminXPRulesController do
  use GameHubWeb, :controller

  alias GameHub.Admin.XPRules

  @doc "Liste toutes les règles XP"
  def index(conn, _params) do
    rules = XPRules.list_xp_rules()
    json(conn, %{data: rules, total: length(rules)})
  end

  @doc "Récupère les règles XP pour un type de jeu"
  def show(conn, %{"game_type" => game_type}) do
    rules = XPRules.get_xp_rules(game_type)
    json(conn, %{data: rules})
  end

  @doc "Crée ou met à jour les règles XP pour un type de jeu"
  def upsert(conn, params) do
    game_type = params["game_type"] || ""
    admin_id = get_admin_id(conn)

    case XPRules.upsert_xp_rules(game_type, params, admin_id) do
      {:ok, rules} ->
        conn |> put_status(:created) |> json(%{data: rules, message: "Règles XP mises à jour"})
      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Erreur: #{inspect(reason)}"})
    end
  end

  @doc "Supprime les règles XP pour un type de jeu"
  def delete(conn, %{"game_type" => game_type}) do
    admin_id = get_admin_id(conn)

    case XPRules.delete_xp_rules(game_type, admin_id) do
      :ok ->
        json(conn, %{message: "Règles XP supprimées"})
      {:error, reason} ->
        conn |> put_status(:not_found) |> json(%{error: "Erreur: #{inspect(reason)}"})
    end
  end

  @doc "Calcule l'XP gagné pour un résultat"
  def calculate(conn, %{"game_type" => game_type, "result" => result, "win_streak" => win_streak}) do
    result_atom = case result do
      "win" -> :win
      "loss" -> :loss
      "draw" -> :draw
      _ -> :participation
    end

    xp = XPRules.calculate_xp(game_type, result_atom, win_streak || 0)
    json(conn, %{data: %{xp_earned: xp, game_type: game_type, result: result}})
  end

  def calculate(conn, %{"game_type" => game_type, "result" => result}) do
    result_atom = case result do
      "win" -> :win
      "loss" -> :loss
      "draw" -> :draw
      _ -> :participation
    end

    xp = XPRules.calculate_xp(game_type, result_atom, 0)
    json(conn, %{data: %{xp_earned: xp, game_type: game_type, result: result}})
  end

  # Helpers privés

  defp get_admin_id(conn) do
    case conn.assigns[:current_user] do
      %{id: id} when is_binary(id) -> id
      %{id: id} when is_integer(id) -> id
      _ -> 0
    end
  end
end
