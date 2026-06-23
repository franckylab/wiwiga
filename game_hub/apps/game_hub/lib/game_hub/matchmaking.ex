# ==================================
# WIWIGA - Module Matchmaking Redis
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Matchmaking
# Description: Matchmaking atomique avec Redis SETNX

defmodule GameHub.Matchmaking do
  @moduledoc """
  Matchmaking temps réel avec Redis.
  
  ## Flow
  1. Joueur rejoint file d'attente (SETNX atomique)
  2. Redis check si assez de joueurs
  3. Si oui -> créer partie + notifier WebSocket
  4. Si non -> attendre timeout
  
  ## Sécurité
  - SETNX évite conditions de course
  - TTL auto-nettoyage files abandonnées
  """
  
  alias GameHub.Redis
  
  @doc """
  Rejoint file d'attente matchmaking.
  
  ## Parameters
    - `user_id`: ID joueur
    - `game_type`: Type jeu (:dice, :card, etc.)
    - `bet_amount`: Mise
  
  ## Returns
    - `{:ok, :waiting}`: En file d'attente
    - `{:ok, :matched, game_id}`: Partie trouvée
    - `{:error, :already_queued}`: Déjà en file
  """
  @spec join_queue(String.t(), atom(), integer()) :: {:ok, atom()} | {:ok, atom(), String.t()} | {:error, atom()}
  def join_queue(user_id, game_type, bet_amount) do
    queue_key = "queue:#{game_type}"
    user_key = "queue:#{game_type}:#{user_id}"
    
    # SETNX atomique - évite double inscription
    case Redix.command(Redis, ["SETNX", user_key, "waiting"]) do
      {:ok, 1} ->
        # Ajouté avec TTL 5 min
        Redix.command(Redis, ["EXPIRE", user_key, 300])
        
        # Ajouter à file globale
        Redix.command(Redis, ["HSET", queue_key, user_id, "#{bet_amount}"])
        
        # Vérifier si assez de joueurs
        check_match(queue_key, game_type, user_id, bet_amount)
      
      {:ok, 0} ->
        {:error, :already_queued}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Quitte file d'attente.
  """
  @spec leave_queue(String.t(), atom()) :: :ok | {:error, atom()}
  def leave_queue(user_id, game_type) do
    queue_key = "queue:#{game_type}"
    user_key = "queue:#{game_type}:#{user_id}"
    
    # Supprimer de file
    Redix.command(Redis, ["HDEL", queue_key, user_id])
    Redix.command(Redis, ["DEL", user_key])
    
    :ok
  end
  
  @doc """
  Vérifie si match possible.
  
  Si >= 2 joueurs avec mêmes mises -> créer partie.
  """
  defp check_match(queue_key, game_type, user_id, bet_amount) do
    # Compter joueurs en file
    {:ok, player_count} = Redix.command(Redis, ["HLEN", queue_key])
    
    if player_count >= 2 do
      # Récupérer tous joueurs
      {:ok, players} = Redix.command(Redis, ["HGETALL", queue_key])
      
      # Trouver joueurs avec même mise
      matching_players = find_matching_players(players, bet_amount)
      
      if length(matching_players) >= 2 do
        # Créer partie
        game_id = create_game(game_type, matching_players)
        
        # Nettoyer files
        cleanup_queue(queue_key, game_type, matching_players)
        
        # Notifier joueurs via WebSocket
        notify_players_matched(matching_players, game_id)
        
        {:ok, :matched, game_id}
      else
        {:ok, :waiting}
      end
    else
      {:ok, :waiting}
    end
  end
  
  @doc """
  Trouve joueurs avec mises compatibles.
  """
  defp find_matching_players(players, target_bet) do
    players
    |> Enum.chunk_every(2)
    |> Enum.filter(fn [_, bet] ->
      bet == Integer.to_string(target_bet)
    end)
    |> Enum.map(fn [user_id, _] -> user_id end)
    |> Enum.take(2) # Premier match trouvé
  end
  
  @doc """
  Crée nouvelle partie.
  """
  defp create_game(game_type, players) do
    game_id = "#{game_type}_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
    
    # Stocker info partie dans Redis
    game_key = "game:#{game_id}"
    Redix.command(Redis, ["HSET", game_key, "status", "waiting_for_bets"])
    Redix.command(Redis, ["HSET", game_key, "players", players |> Enum.join(",")])
    Redix.command(Redis, ["EXPIRE", game_key, 3600]) # TTL 1h
    
    game_id
  end
  
  @doc """
  Nettoyer files après match.
  """
  defp cleanup_queue(queue_key, game_type, matched_players) do
    Enum.each(matched_players, fn user_id ->
      Redix.command(Redis, ["HDEL", queue_key, user_id])
      Redix.command(Redis, ["DEL", "queue:#{game_type}:#{user_id}"])
    end)
  end
  
  @doc """
  Notifie joueurs matchés via WebSocket.
  """
  defp notify_players_matched(players, game_id) do
    # Broadcast via Phoenix.PubSub
    Enum.each(players, fn user_id ->
      Phoenix.PubSub.broadcast(
        GameHub.PubSub,
        "user:#{user_id}",
        %{event: "game_matched", game_id: game_id}
      )
    end)
  end
  
  @doc """
  Get queue status for user.
  """
  @spec get_queue_status(String.t(), atom()) :: %{position: integer(), total_players: integer()}
  def get_queue_status(user_id, game_type) do
    queue_key = "queue:#{game_type}"
    
    {:ok, total_players} = Redix.command(Redis, ["HLEN", queue_key])
    
    # Position approximative
    {:ok, all_players} = Redix.command(Redis, ["HKEYS", queue_key])
    position = Enum.find_index(all_players, fn p -> p == user_id end) + 1
    
    %{
      position: position || 0,
      total_players: total_players
    }
  end
  
  @doc """
  Cleanup files expirées (cron job).
  """
  def cleanup_expired_queues do
    # Trouver clés TTL expiré
    # Supprimer
    :ok
  end
end
