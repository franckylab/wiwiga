# ==================================
# WIWIGA - Channel Matchmaking WebSocket
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.MatchmakingChannel
# Description: Matchmaking temps réel via WebSocket

defmodule GameHubWeb.MatchmakingChannel do
  @moduledoc """
  Phoenix Channel pour matchmaking.
  
  ## Events Client -> Serveur
    - "join_queue": Rejoindre file d'attente
    - "leave_queue": Quitter file d'attente
    - "queue_status": Statut file d'attente
  
  ## Events Serveur -> Client
    - "queue_joined": Confirmé entrée en file
    - "game_matched": Partie trouvée !
    - "queue_update": Update position en file
    - "error": Erreur
  """
  
  use Phoenix.Channel
  
  alias GameHub.Matchmaking
  
  @doc """
  Join matchmaking room.
  
  Topic: "matchmaking:dice"
  """
  @impl true
  def join("matchmaking:" <> game_type, _params, socket) do
    # Pour dev: permettre sans auth
    # En production, extraire user_id depuis JWT token
    user_id = get_user_id(socket) || "dev_user_#{System.unique_integer([:positive])}"
    
    socket = assign(socket, :user_id, user_id)
    socket = assign(socket, :game_type, game_type)
    
    {:ok, socket}
  end
  
  @doc """
  Handle join_queue event.
  
  Payload: %{bet_amount: 50000}
  """
  @impl true
  def handle_in("join_queue", %{"bet_amount" => bet_amount}, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    
    case Matchmaking.join_queue(user_id, game_type, bet_amount) do
      {:ok, :waiting} ->
        # Récupérer statut
        status = Matchmaking.get_queue_status(user_id, game_type)
        
        {:reply, {:ok, %{
          status: "waiting",
          position: status.position,
          total_players: status.total_players,
          message: "En file d'attente..."
        }}, socket}
      
      {:ok, :matched, game_id} ->
        # Match trouvé immédiatement !
        broadcast!(socket, "player_matched", %{
          user_id: user_id,
          game_id: game_id
        })
        
        {:reply, {:ok, %{
          status: "matched",
          game_id: game_id,
          message: "Partie trouvée !"
        }}, socket}
      
      {:error, :already_queued} ->
        {:reply, {:error, %{reason: "already_in_queue"}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
  
  @doc """
  Handle leave_queue event.
  """
  @impl true
  def handle_in("leave_queue", _params, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    
    Matchmaking.leave_queue(user_id, game_type)
    
    {:reply, {:ok, %{status: "left_queue"}}, socket}
  end
  
  @doc """
  Handle queue_status event.
  """
  @impl true
  def handle_in("queue_status", _params, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    
    status = Matchmaking.get_queue_status(user_id, game_type)
    
    {:reply, {:ok, status}, socket}
  end
  
  @doc """
  Handle disconnect.
  """
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    game_type = socket.assigns[:game_type]
    
    if user_id && game_type do
      # Retirer de la file automatiquement
      Matchmaking.leave_queue(user_id, game_type)
      IO.puts("[MATCHMAKING] User #{user_id} left queue #{game_type}")
    end
    
    :ok
  end
  
  # === Fonctions Privées ===
  
  defp get_user_id(socket) do
    # Extraire depuis Guardian token dans socket
    case socket.assigns[:current_user] do
      %{id: id} -> id
      _ ->
        # Pour dev, extraire depuis params
        case socket.assigns[:user_id] do
          id when is_binary(id) -> id
          _ -> nil
        end
    end
  end
end
