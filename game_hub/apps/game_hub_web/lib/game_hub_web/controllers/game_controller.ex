# ==================================
# WIWIGA - Controller Jeux
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.GameController
# Description: Endpoints liste jeux, rejoindre partie, état jeu

defmodule GameHubWeb.GameController do
  @moduledoc """
  Controller gestion jeux.
  
  ## Endpoints
    GET    /api/games                    - Liste jeux disponibles
    GET    /api/games/:game_id           - Détails jeu
    POST   /api/games/:game_id/join      - Rejoindre partie
    GET    /api/games/:game_id/state     - État partie
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Errors, Repo, Games.GameConfig}
  alias GameHub.Users.User
  import Ecto.Query
  
  @doc """
  GET /api/games
  
  Response: %{success: true, data: [%{id: "dice", name: "Jeu de Dés", ...}]}
  """
  def index(conn, _params) do
    # Récupérer jeux depuis DB
    game_configs = Repo.all(from g in GameConfig, where: g.is_active == true)
    
    games = Enum.map(game_configs, fn config ->
      %{
        id: config.game_type,
        name: config.name,
        description: config.description,
        min_bet: config.min_bet,
        max_bet: config.max_bet,
        commission_rate: Decimal.to_float(config.commission_rate),
        status: if(config.is_active, do: "active", else: "inactive"),
        players_online: get_players_online(config.game_type)
      }
    end)
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: games,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  @doc """
  GET /api/games/:game_id
  
  Response: %{success: true, data: %{id: "dice", name: "...", config: {...}}}
  """
  def show(conn, %{"game_id" => game_id}) do
    # Récupérer depuis DB
    game_config = Repo.get_by(GameConfig, game_type: game_id)
    
    case game_config do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
      
      config ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            id: config.game_type,
            name: config.name,
            description: config.description,
            min_bet: config.min_bet,
            max_bet: config.max_bet,
            commission_rate: Decimal.to_float(config.commission_rate),
            commission_mode: config.commission_mode,
            config: config.config || %{}
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end
  
  @doc """
  POST /api/games/:game_id/join
  
  Body: %{bet_amount: 500, prediction: %{predicted_sum: 10}}
  
  Response: %{success: true, data: %{game_id: "dice_123", status: "waiting"}}
  """
  def join(conn, %{"game_id" => game_id, "bet_amount" => bet_amount}) do
    user_id = get_current_user_id(conn)
    
    # Récupérer config jeu depuis DB
    game_config = Repo.get_by(GameConfig, game_type: game_id)
    
    cond do
      is_nil(game_config) ->
        conn
        |> put_status(404)
        |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
      
      bet_amount < game_config.min_bet ->
        conn
        |> put_status(400)
        |> json(Errors.error("Mise minimum: #{game_config.min_bet} FCFA", 400, "BET_TOO_LOW"))
      
      bet_amount > game_config.max_bet ->
        conn
        |> put_status(400)
        |> json(Errors.error("Mise maximum: #{game_config.max_bet} FCFA", 400, "BET_TOO_HIGH"))
      
      true ->
        # Vérifier solde utilisateur
        user = Repo.get(User, user_id)
        
        if is_nil(user) || user.balance < bet_amount do
          conn
          |> put_status(400)
          |> json(Errors.error("Solde insuffisant", 400, "INSUFFICIENT_FUNDS"))
        else
          # Rejoindre file d'attente matchmaking
          case GameHub.Matchmaking.join_queue(user_id, game_id, bet_amount) do
            {:ok, :waiting} ->
              conn
              |> put_status(202)
              |> json(%{
                success: true,
                data: %{
                  status: "waiting",
                  message: "En file d'attente..."
                },
                meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
              })
            
            {:ok, :matched, match_game_id} ->
              conn
              |> put_status(200)
              |> json(%{
                success: true,
                data: %{
                  status: "matched",
                  game_id: match_game_id,
                  message: "Partie trouvée !"
                },
                meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
              })
            
            {:error, reason} ->
              conn
              |> put_status(400)
              |> json(Errors.error("Erreur matchmaking: #{reason}", 400, "MATCHMAKING_ERROR"))
          end
        end
    end
  end
  
  def join(conn, %{"game_id" => _game_id}) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètre 'bet_amount' requis", 400, "VALIDATION_ERROR"))
  end
  
  @doc """
  GET /api/games/:game_id/state
  
  Response: %{success: true, data: %{status: "in_progress", players: [...], dice: [...]}}
  """
  def game_state(conn, %{"game_id" => game_id}) do
    # Récupérer état depuis Redis
    game_key = "game:#{game_id}"
    
    case Redix.command(GameHub.Redis, ["HGETALL", game_key]) do
      {:ok, []} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Partie non trouvée", 404, "GAME_NOT_FOUND"))
      
      {:ok, game_data} ->
        state = %{
          game_id: game_id,
          status: List.keyfind(game_data, "status", 0) |> elem(1),
          players: List.keyfind(game_data, "players", 0) |> elem(1) |> String.split(","),
          game_type: List.keyfind(game_data, "game_type", 0) |> elem(1)
        }
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: state,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, _} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur serveur", 500, "INTERNAL_ERROR"))
    end
  end
  
  # === Fonctions Privées ===
  
  defp get_current_user_id(conn) do
    # Utiliser AuthPlug
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
  
  defp get_players_online(game_type) do
    # Compter joueurs dans file d'attente Redis
    queue_key = "queue:#{game_type}"
    
    case Redix.command(GameHub.Redis, ["HLEN", queue_key]) do
      {:ok, count} -> count
      _ -> 0
    end
  end
end
