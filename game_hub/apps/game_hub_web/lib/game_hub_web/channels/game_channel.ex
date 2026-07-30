# ==================================
# WIWIGA - Channel Jeu WebSocket
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.GameChannel
# Description: Communication temps réel pour parties de jeu

defmodule GameHubWeb.GameChannel do
  @moduledoc """
  Phoenix Channel pour jeux en temps réel.
  
  ## Events Client -> Serveur
    - "place_bet": Placer un pari (prédiction somme)
    - "execute_turn": Lancer les dés (auto quand 2 paris)
    - "leave_game": Quitter partie
  
  ## Events Serveur -> Client
    - "player_joined": Nouveau joueur
    - "bet_placed": Pari confirmé
    - "turn_executed": Dés lancés
    - "game_result": Résultat final
    - "error": Erreur
  """
  
  use Phoenix.Channel
  
  alias GameHub.GameStateManager
  alias DiceGame.Engine
  
  @doc """
  Join game room.
  
  Topic: "game:dice_123"
  """
  @impl true
  def join("game:" <> game_id, _params, socket) do
    user_id = get_user_id(socket)
    
    if user_id do
      socket = assign(socket, :user_id, user_id)
      socket = assign(socket, :game_id, game_id)
      
      # Notifier les autres joueurs
      broadcast!(socket, "player_joined", %{
        user_id: user_id,
        player_name: "Joueur_#{String.slice(to_string(user_id), 0..3)}"
      })
      
      {:ok, socket}
    else
      # Dev mode: accepter sans auth
      dev_id = "dev_#{System.unique_integer([:positive])}"
      socket = assign(socket, :user_id, dev_id)
      socket = assign(socket, :game_id, game_id)
      
      broadcast!(socket, "player_joined", %{
        user_id: dev_id,
        player_name: "Joueur_#{String.slice(dev_id, 0..5)}"
      })
      
      {:ok, socket}
    end
  end
  
  @doc """
  Handle place_bet event.
  
  Payload: %{"bet_amount" => 500, "predicted_sum" => 7}
  
  Le wallet est débité par DiceGame.Engine.place_bet (pas ici).
  """
  @impl true
  def handle_in("place_bet", %{"bet_amount" => bet_amount, "predicted_sum" => predicted_sum}, socket) do
    user_id = socket.assigns.user_id
    game_id = socket.assigns.game_id
    
    # Delegate to Engine which handles wallet debit + state update
    case Engine.place_bet(game_id, user_id, bet_amount, %{predicted_sum: predicted_sum}) do
      {:ok, result} ->
        # Confirmer au joueur
        reply = %{
          status: "bet_placed",
          player_id: user_id,
          amount: bet_amount,
          predicted_sum: predicted_sum,
          game_status: to_string(result.game_status)
        }
        
        # Notifier tous les joueurs du channel
        broadcast!(socket, "bet_placed", reply)
        
        {:reply, {:ok, reply}, socket}
      
      {:error, :insufficient_funds} ->
        {:reply, {:error, %{reason: "insufficient_funds"}}, socket}
      
      {:error, :invalid_prediction} ->
        {:reply, {:error, %{reason: "invalid_prediction"}}, socket}
      
      {:error, :bet_already_placed} ->
        {:reply, {:error, %{reason: "bet_already_placed"}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end
  
  @doc """
  Handle execute_turn event.
  
  Lance les dés quand les 2 paris sont placés.
  """
  @impl true
  def handle_in("execute_turn", _params, socket) do
    game_id = socket.assigns.game_id
    
    case Engine.execute_turn(game_id) do
      {:ok, result} ->
        broadcast!(socket, "turn_executed", %{
          dice_results: result.dice_results,
          total_sum: result.total_sum,
          executed_at: DateTime.to_iso8601(result.executed_at)
        })
        
        # Auto end game après le roll
        case Engine.end_game(game_id) do
          {:ok, end_result} ->
            broadcast!(socket, "game_result", %{
              winner: end_result.winner,
              loser: end_result.loser,
              result: to_string(end_result.result),
              dice_results: end_result.dice_results,
              total_sum: end_result.total_sum,
              total_pot: end_result.total_pot,
              commission: end_result.commission,
              net_winnings: end_result.net_winnings,
              payout_status: to_string(end_result.payout_status)
            })
          
          {:error, reason} ->
            broadcast!(socket, "error", %{reason: to_string(reason)})
        end
        
        {:noreply, socket}
      
      {:error, :not_ready_to_roll} ->
        {:reply, {:error, %{reason: "not_all_bets_placed"}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end
  
  @doc """
  Handle leave_game event.
  """
  @impl true
  def handle_in("leave_game", _params, socket) do
    user_id = socket.assigns.user_id
    
    broadcast!(socket, "player_left", %{
      user_id: user_id,
      message: "Joueur a quitté"
    })
    
    {:noreply, socket}
  end
  
  @doc """
  Handle disconnect.
  Applique politique de déconnexion (grace period).
  """
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    game_id = socket.assigns[:game_id]
    
    if user_id && game_id do
      game_type = extract_game_type(game_id)
      
      # Appliquer politique déconnexion si le jeu existe
      case GameHub.GameStateManager.get_game_state(game_id) do
        {:ok, state} when state.status not in [:ended] ->
          GameHub.GameTimeout.handle_disconnect(user_id, game_id, game_type)
        _ ->
          :ok
      end
      
      IO.puts("[DISCONNECT] User #{user_id} left game #{game_id}")
    end
    
    :ok
  end
  
  # === Fonctions Privées ===
  
  defp extract_game_type(game_id) do
    game_id
    |> String.split("_")
    |> List.first()
    |> to_string()
  end
  
  defp get_user_id(socket) do
    case socket.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
