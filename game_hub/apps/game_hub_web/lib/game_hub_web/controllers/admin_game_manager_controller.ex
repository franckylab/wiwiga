# ==================================
# WIWIGA - Controller Admin Game Manager
# ==================================
# Module: GameHubWeb.AdminGameManagerController
# Description: Supervision des parties en cours

defmodule GameHubWeb.AdminGameManagerController do
  @moduledoc """
  Controller pour la supervision des parties.
  
  ## Endpoints
    GET /api/admin/games/active          - Parties en cours
    GET /api/admin/games/active/:id      - Détail partie active
    POST /api/admin/games/:id/force-close - Forcer clôture
    GET /api/admin/games/stats/summary   - Résumé stats jeux
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Metrics

  @doc """
  GET /api/admin/games/active
  Liste les parties/sessions actives via Redis.
  """
  def active_games(conn, params) do
    # Récupérer les clés de jeu depuis Redis
    active_games = get_active_games_from_redis()

    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> min(100)
    total = length(active_games)
    paginated = Enum.slice(active_games, (page - 1) * limit, limit)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        games: paginated,
        total: total,
        page: page,
        limit: limit
      }
    })
  end

  @doc """
  GET /api/admin/games/active/:id
  Détail d'une partie active.
  """
  def active_game_detail(conn, %{"id" => game_id}) do
    game_key = "game:#{game_id}"

    case Redix.command(GameHub.Redis, ["HGETALL", game_key]) do
      {:ok, []} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Partie non trouvée"})

      {:ok, fields} ->
        game_data = parse_redis_hash(fields)

        conn
        |> put_status(200)
        |> json(%{success: true, data: game_data})

      _ ->
        conn
        |> put_status(500)
        |> json(%{success: false, message: "Erreur de lecture Redis"})
    end
  rescue
    _ ->
      conn
      |> put_status(503)
      |> json(%{success: false, message: "Redis indisponible"})
  end

  @doc """
  POST /api/admin/games/:id/force-close
  Forcer la clôture d'une partie.
  """
  def force_close(conn, %{"id" => game_id}) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    game_key = "game:#{game_id}"

    # Vérifier que la partie existe
    case Redix.command(GameHub.Redis, ["EXISTS", game_key]) do
      {:ok, 0} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Partie non trouvée"})

      {:ok, 1} ->
        # Mettre le statut à force_closed
        Redix.command(GameHub.Redis, ["HSET", game_key, "status", "force_closed"])
        Redix.command(GameHub.Redis, ["HSET", game_key, "closed_by_admin", admin_id])
        Redix.command(GameHub.Redis, ["HSET", game_key, "closed_at", DateTime.utc_now() |> DateTime.to_iso8601()])

        # Broadcast l'événement
        try do
          GameHubWeb.Endpoint.broadcast!("game:#{game_id}", "game_force_closed", %{
            closed_by: admin_id,
            reason: "Fermé par administrateur"
          })
        rescue
          _ -> :ok
        end

        # Audit log
        GameHub.AuditLog.log("admin_action", admin_id, "games", game_id, %{
          "action" => "force_close"
        })

        conn
        |> put_status(200)
        |> json(%{success: true, message: "Partie fermée avec succès"})

      _ ->
        conn
        |> put_status(503)
        |> json(%{success: false, message: "Redis indisponible"})
    end
  rescue
    _ ->
      conn
      |> put_status(503)
      |> json(%{success: false, message: "Redis indisponible"})
  end

  @doc """
  GET /api/admin/games/stats/summary
  Résumé des statistiques de jeux.
  """
  def stats_summary(conn, params) do
    period = Map.get(params, "period", "24h")
    metrics = Metrics.get_game_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  # ========================================
  # Helpers
  # ========================================

  defp get_active_games_from_redis do
    case Redix.command(GameHub.Redis, ["KEYS", "game:*"]) do
      {:ok, keys} ->
        keys
        |> Enum.filter(fn key -> not String.contains?(key, ":match:") end)
        |> Enum.map(fn key ->
          game_id = String.replace(key, "game:", "")
          case Redix.command(GameHub.Redis, ["HGETALL", key]) do
            {:ok, fields} ->
              data = parse_redis_hash(fields)
              Map.put(data, "game_id", game_id)
            _ ->
              %{"game_id" => game_id, "status" => "unknown"}
          end
        end)
        |> Enum.filter(fn game ->
          game["status"] in ["waiting", "in_progress", "active"]
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp parse_redis_hash([]), do: %{}
  defp parse_redis_hash(fields) when is_list(fields) do
    fields
    |> Enum.chunk_every(2)
    |> Map.new(fn [k, v] -> {to_string(k), to_string(v)} end)
  end
  defp parse_redis_hash(_), do: %{}
end
