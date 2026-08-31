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
  
  require Logger
  alias DiceGame.Engine
  
  @doc """
  Join game room.
  
  Topic: "game:dice_123"
  """
  @impl true
  def join("game:" <> game_id, _params, socket) do
    # S'abonner aux broadcasts PubSub du match (GameMatch)
    try do
      Phoenix.PubSub.subscribe(GameHub.PubSub, "game:#{game_id}")
    rescue
      _ -> :ok
    end

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
  
  # Handle execute_turn event.
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
  
  # === GameMatch (multi-sets) — roll & vote ===

  @impl true
  def handle_in("dice_rolled", _params, socket) do
    user_id = socket.assigns.user_id
    game_id = socket.assigns.game_id

    # Détecter si c'est un match GameMatch (id contient "match")
    if String.contains?(game_id, "match") do
      case GameHub.GameMatch.roll_dice(game_id, to_string(user_id)) do
        {:ok, %{roll: roll, match: match}} ->
          broadcast!(socket, "dice_rolled", %{
            roll: %{player_id: roll.player_id, dice: roll.dice, sum: roll.sum},
            match: sanitize_match(match)
          })
          # Si le set est terminé, broadcaster set_result / match_result déjà géré par GameMatch PubSub,
          # mais on push aussi ici pour le channel direct
          if match.status == :set_ended or match.status == :match_ended do
            # Le match a déjà broadcast via PubSub, on forward aussi
            :ok
          end
          {:reply, {:ok, %{status: "rolled", roll: roll}}, socket}

        {:error, :not_your_turn} ->
          {:reply, {:error, %{reason: "not_your_turn"}}, socket}

        {:error, :player_eliminated} ->
          {:reply, {:error, %{reason: "player_eliminated"}}, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: to_string(reason)}}, socket}
      end
    else
      # Fallback legacy Engine
      case Engine.execute_turn(game_id) do
        {:ok, result} ->
          broadcast!(socket, "turn_executed", %{
            dice_results: result.dice_results,
            total_sum: result.total_sum
          })
          {:reply, {:ok, result}, socket}
        {:error, reason} ->
          {:reply, {:error, %{reason: to_string(reason)}}, socket}
      end
    end
  end

  @impl true
  def handle_in("vote_target", %{"target_value" => target_value}, socket) do
    user_id = socket.assigns.user_id
    game_id = socket.assigns.game_id

    case GameHub.GameMatch.vote_target(game_id, to_string(user_id), target_value) do
      {:ok, match} ->
        broadcast!(socket, "target_voted", %{
          player_id: user_id,
          target_value: target_value,
          match: sanitize_match(match)
        })
        # Si tous ont voté, la cible est calculée → notifier
        set = match.current_set_state
        if set && !set.vote_phase && set.target_value do
          broadcast!(socket, "target_calculated", %{
            target_value: set.target_value,
            match: sanitize_match(match)
          })
        end
        {:reply, {:ok, %{status: "voted", target: target_value}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("vote_target", _params, socket) do
    {:reply, {:error, %{reason: "missing_target_value"}}, socket}
  end

  # Handle leave_game event.
  @impl true
  def handle_in("leave_game", _params, socket) do
    user_id = socket.assigns.user_id
    
    broadcast!(socket, "player_left", %{
      user_id: user_id,
      message: "Joueur a quitté"
    })
    
    {:noreply, socket}
  end

  # Forward GameMatch PubSub events to channel clients
  @impl true
  def handle_info(%{event: event} = payload, socket) when event in ["dice_rolled", "set_result", "match_result", "player_forfeited", "match_forfeit", "set_started", "target_calculated"] do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp sanitize_match(match) do
    %{
      match_id: match.match_id,
      status: to_string(match.status),
      current_set: match.current_set,
      sets_count: match.sets_count,
      set_scores: match.set_scores,
      current_set_state: match.current_set_state,
      eliminated_players: match.eliminated_players |> MapSet.to_list(),
      winner_id: Map.get(match, :winner_id)
    }
  rescue
    _ -> %{match_id: match.match_id, status: to_string(match.status)}
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
      
      Logger.info("[DISCONNECT] User #{user_id} left game #{game_id}")
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
