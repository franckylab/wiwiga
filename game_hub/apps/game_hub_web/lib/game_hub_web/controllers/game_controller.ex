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
  
  alias GameHub.Errors
  
  @doc """
  GET /api/games
  
  Response: %{success: true, data: [%{id: "dice", name: "Jeu de Dés", ...}]}
  """
  def index(conn, _params) do
    games = [
      %{
        id: "dice",
        name: "Jeu de Dés",
        description: "Pariez sur la somme des dés",
        min_bet: 100,
        max_bet: 100000,
        commission_rate: 0.05,
        status: "active",
        players_online: 42
      }
    ]
    
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
    case get_game_config(game_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
      
      game_config ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: game_config,
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
    
    # Validation
    if bet_amount < 100 do
      conn
      |> put_status(400)
      |> json(Errors.error("Mise minimum: 100 FCFA", 400, "BET_TOO_LOW"))
    else
      # Créer ou rejoindre partie
      game_session = %{
        game_id: "#{game_id}_#{System.unique_integer([:positive])}",
        player_id: user_id,
        status: "waiting_for_players",
        bet_amount: bet_amount
      }
      
      conn
      |> put_status(201)
      |> json(%{
        success: true,
        data: game_session,
        meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
      })
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
    # Récupérer état depuis Registry/Redis
    state = %{
      game_id: game_id,
      status: "waiting_for_bets",
      players: [%{id: "player1", bet: 500}],
      time_remaining: 30
    }
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: state,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  # === Fonctions Privées ===
  
  defp get_game_config("dice") do
    %{
      id: "dice",
      name: "Jeu de Dés",
      description: "Pariez sur la somme des dés lancés",
      min_bet: 100,
      max_bet: 100_000,
      commission_rate: 0.05,
      dice_count: 3,
      dice_faces: 6,
      bet_types: ["exact_sum", "over_under", "specific_value"]
    }
  end
  
  defp get_game_config(_), do: nil
  
  defp get_current_user_id(conn) do
    "user_id_from_jwt"
  end
end
