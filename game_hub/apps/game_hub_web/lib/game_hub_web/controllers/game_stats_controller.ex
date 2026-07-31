# ==================================
# WIWIGA - Controller Statistiques Jeux
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.GameStatsController
# Description: Endpoints stats globales, leaderboard, activité, règles, astuces

defmodule GameHubWeb.GameStatsController do
  @moduledoc """
  Controller statistiques et contenus d'un jeu.

  ## Endpoints
    GET /api/games/:game_type/stats        - Stats globales du jeu
    GET /api/games/:game_type/leaderboard  - Classement (metric × period)
    GET /api/games/:game_type/my-stats     - Stats personnelles (auth)
    GET /api/games/:game_type/activity     - Flux d'activité récent
    GET /api/games/:game_type/rules        - Règles du jeu (Normal/Cible)
    GET /api/games/:game_type/tips         - Astuces du jeu
  """

  use GameHubWeb, :controller

  alias GameHub.{Errors, Repo, GameStats, GameRules, Games.GameConfig}

  @doc """
  GET /api/games/:game_type/stats

  Response: %{success: true, data: %{players_online: 3, matches_today: 12, ...}}
  """
  def stats(conn, %{"game_type" => game_type}) do
    with {:ok, _config} <- fetch_game(game_type) do
      conn
      |> put_status(200)
      |> json(ok(GameStats.global_stats(game_type)))
    else
      {:error, :not_found} -> game_not_found(conn)
    end
  end

  @doc """
  GET /api/games/:game_type/leaderboard?metric=wins&period=all&limit=20

  Response: %{success: true, data: %{entries: [...], my_rank: 4, my_value: 12}}
  """
  def leaderboard(conn, %{"game_type" => game_type} = params) do
    metric = Map.get(params, "metric", "wins")
    period = Map.get(params, "period", "all")
    limit = params |> Map.get("limit", "20") |> parse_limit()
    user_id = get_current_user_id(conn)

    with {:ok, _config} <- fetch_game(game_type),
         {:ok, result} <- GameStats.leaderboard(game_type, metric, period, limit, user_id) do
      conn
      |> put_status(200)
      |> json(ok(%{
        metric: metric,
        period: period,
        entries: result.entries,
        my_rank: result.my_rank,
        my_value: result.my_value
      }))
    else
      {:error, :not_found} ->
        game_not_found(conn)

      {:error, :invalid_metric} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Métrique invalide (wins, total_won, biggest_win)", 400, "VALIDATION_ERROR"))

      {:error, :invalid_period} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Période invalide (day, week, month, all)", 400, "VALIDATION_ERROR"))
    end
  end

  @doc """
  GET /api/games/:game_type/my-stats

  Response: %{success: true, data: %{matches_played: 10, wins: 6, win_rate: 60.0, ...}}
  """
  def my_stats(conn, %{"game_type" => game_type}) do
    user_id = get_current_user_id(conn)

    with {:ok, _config} <- fetch_game(game_type) do
      conn
      |> put_status(200)
      |> json(ok(GameStats.my_stats(user_id, game_type)))
    else
      {:error, :not_found} -> game_not_found(conn)
    end
  end

  @doc """
  GET /api/games/:game_type/activity?limit=20

  Response: %{success: true, data: [%{name: "...", amount: 4500, inserted_at: "..."}]}
  """
  def activity(conn, %{"game_type" => game_type} = params) do
    limit = params |> Map.get("limit", "20") |> parse_limit()

    with {:ok, _config} <- fetch_game(game_type) do
      conn
      |> put_status(200)
      |> json(ok(GameStats.recent_activity(game_type, limit)))
    else
      {:error, :not_found} -> game_not_found(conn)
    end
  end

  @doc """
  GET /api/games/:game_type/rules

  Response: %{success: true, data: [%{rule_type: "normal", name: "...", config: {...}}]}
  """
  def rules(conn, %{"game_type" => game_type}) do
    with {:ok, _config} <- fetch_game(game_type) do
      rules =
        game_type
        |> GameRules.list_rules()
        |> Enum.map(fn rule ->
          %{
            rule_type: rule.rule_type,
            name: rule.name,
            description: rule.description,
            config: rule.config || %{}
          }
        end)

      conn
      |> put_status(200)
      |> json(ok(rules))
    else
      {:error, :not_found} -> game_not_found(conn)
    end
  end

  @doc """
  GET /api/games/:game_type/tips

  Response: %{success: true, data: [%{title: "...", body: "..."}]}
  """
  def tips(conn, %{"game_type" => game_type}) do
    with {:ok, config} <- fetch_game(game_type) do
      tips =
        case config.tips do
          %{"items" => items} when is_list(items) -> items
          _ -> []
        end

      conn
      |> put_status(200)
      |> json(ok(tips))
    else
      {:error, :not_found} -> game_not_found(conn)
    end
  end

  # === Fonctions Privées ===

  defp fetch_game(game_type) do
    case Repo.get_by(GameConfig, game_type: game_type) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  defp game_not_found(conn) do
    conn
    |> put_status(404)
    |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
  end

  defp ok(data) do
    %{
      success: true,
      data: data,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    }
  end

  defp parse_limit(value) when is_integer(value), do: min(max(value, 1), 100)

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> min(max(int, 1), 100)
      :error -> 20
    end
  end

  defp parse_limit(_), do: 20

  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
end
