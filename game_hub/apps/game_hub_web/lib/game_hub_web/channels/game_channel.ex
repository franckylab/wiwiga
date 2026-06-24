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
    - "place_bet": Placer un pari
    - "roll_dice": Lancer les dés
    - "leave_game": Quitter partie
  
  ## Events Serveur -> Client
    - "game_state": État jeu mis à jour
    - "bet_placed": Pari confirmé
    - "dice_rolled": Résultats dés
    - "game_ended": Partie terminée
    - "error": Erreur
  """
  
  use Phoenix.Channel
  
  alias GameHub.Wallet
  alias DiceGame.Engine
  
  @doc """
  Join game room.
  
  Topic: "game:dice_123"
  """
  @impl true
  def join("game:" <> game_id, _params, socket) do
    # Vérifier authentification
    user_id = get_user_id(socket)
    
    if user_id do
      # Ajouter joueur au socket
      socket = assign(socket, :user_id, user_id)
      socket = assign(socket, :game_id, game_id)
      
      # Notifier autres joueurs
      broadcast!(socket, "player_joined", %{
        user_id: user_id,
        message: "Nouveau joueur rejoint"
      })
      
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
  
  @doc """
  Handle place_bet event.
  
  Payload: %{amount: 500, prediction: %{predicted_sum: 10}}
  """
  @impl true
  def handle_in("place_bet", %{"amount" => amount, "prediction" => prediction}, socket) do
    user_id = socket.assigns.user_id
    game_id = socket.assigns.game_id
    idempotency_key = generate_idempotency_key()
    
    # Débiter portefeuille (ACID)
    case Wallet.place_bet(user_id, amount, game_id, idempotency_key) do
      {:ok, transaction} ->
        # Envoyer pari au moteur de jeu
        Engine.place_bet(game_id, user_id, amount, prediction)
        
        # Confirmer au client
        {:reply, {:ok, %{
          status: "bet_placed",
          transaction_id: transaction.id,
          new_balance: transaction.balance_after
        }}, socket}
        
        #Notifier autres joueurs
        broadcast!(socket, "bet_placed", %{
          user_id: user_id,
          amount: amount,
          prediction: prediction
        })
      
      {:error, :insufficient_funds} ->
        {:reply, {:error, %{reason: "insufficient_funds"}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
  
  @doc """
  Handle roll_dice event.
  
  Déclenche lancement des dés côté serveur.
  """
  @impl true
  def handle_in("roll_dice", _params, socket) do
    game_id = socket.assigns.game_id
    
    # Exécuter tour (génération crypto)
    case Engine.execute_turn(game_id) do
      {:ok, result} ->
        # Diffuser résultats à TOUS les joueurs
        broadcast!(socket, "dice_rolled", %{
          dice_results: result.dice_results,
          total_sum: result.total_sum,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
        
        {:noreply, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
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
  
  Règle 8: Appliquer politique de déconnexion
  """
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    game_id = socket.assigns[:game_id]
    
    if user_id && game_id do
      # Appliquer politique déconnexion (Règle 8)
      game_type = extract_game_type(game_id)
      GameHub.GameTimeout.handle_disconnect(user_id, game_id, game_type)
      
      IO.puts("[DISCONNECT] User #{user_id} disconnected from game #{game_id}")
    end
    
    :ok
  end
  
  # === Fonctions Privées ===
  
  defp extract_game_type(game_id) do
    # Extraire type de jeu depuis game_id (ex: "dice_123" -> "dice")
    game_id
    |> String.split("_")
    |> List.first()
    |> to_string()
  end
  
  # === Fonctions Privées ===
  
  defp get_user_id(socket) do
    # Extraire depuis Guardian token
    case socket.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
  end
  
  defp generate_idempotency_key do
    "#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end
end
