# ==================================
# WIWIGA - Module Matchmaking Redis (v2)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Matchmaking
# Description: Matchmaking atomique avec Redis + fallback approximatif

defmodule GameHub.Matchmaking do
  @moduledoc """
  Matchmaking temps réel avec Redis.

  ## Flow Amélioré (2 phases)
  1. **Phase 1** : recherche mise exacte (immédiat)
  2. **Phase 2** : après 30s timeout → proposer mises approximatives (±10-20%)
     - Le joueur confirme ou refuse la mise alternative
     - Si confirme → matché avec la nouvelle mise

  ## Sécurité
  - SETNX évite conditions de course
  - TTL auto-nettoyage files abandonnées
  """

  alias GameHub.Redis

  @fallback_timeout_seconds 30
  @fallback_tolerance_pct 0.20  # ±20%

  @doc """
  Rejoint file d'attente matchmaking.

  ## Returns
    - `{:ok, :waiting}`: En file d'attente
    - `{:ok, :matched, game_id}`: Partie trouvée
    - `{:error, :already_queued}`: Déjà en file
  """
  @spec join_queue(String.t(), atom() | String.t(), integer()) :: {:ok, atom()} | {:ok, atom(), String.t()} | {:error, atom()}
  def join_queue(user_id, game_type, bet_amount) do
    queue_key = "queue:#{game_type}"
    user_key = "queue:#{game_type}:#{user_id}"

    # SETNX atomique
    case Redix.command(Redis, ["SETNX", user_key, "waiting"]) do
      {:ok, 1} ->
        # Stocker avec mise et timestamp
        Redix.command(Redis, ["EXPIRE", user_key, 300])
        Redix.command(Redis, ["HSET", queue_key, user_id, "#{bet_amount}"])

        # Stocker le timestamp d'entrée
        Redix.command(Redis, ["HSET", "queue:#{game_type}:timestamps", user_id, "#{System.system_time(:second)}"])

        # Vérifier si match possible immédiatement
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
  @spec leave_queue(String.t(), atom() | String.t()) :: :ok | {:error, atom()}
  def leave_queue(user_id, game_type) do
    queue_key = "queue:#{game_type}"
    user_key = "queue:#{game_type}:#{user_id}"

    Redix.command(Redis, ["HDEL", queue_key, user_id])
    Redix.command(Redis, ["HDEL", "queue:#{game_type}:timestamps", user_id])
    Redix.command(Redis, ["DEL", user_key])

    :ok
  end

  @doc """
  Confirme la mise alternative proposée (Phase 2).
  """
  @spec confirm_alternative_bet(String.t(), atom() | String.t(), integer()) :: {:ok, :matched, String.t()} | {:error, atom()}
  def confirm_alternative_bet(user_id, game_type, new_bet_amount) do
    queue_key = "queue:#{game_type}"
    user_key = "queue:#{game_type}:#{user_id}"

    # Mettre à jour la mise dans la file
    Redix.command(Redis, ["HSET", queue_key, user_id, "#{new_bet_amount}"])

    # Tenter un match avec la nouvelle mise
    case check_match(queue_key, game_type, user_id, new_bet_amount) do
      {:ok, :matched, game_id} -> {:ok, :matched, game_id}
      {:ok, :waiting} -> {:error, :no_match_found}
      error -> error
    end
  end

  @doc """
  Vérifie le statut de fallback pour un joueur.
  Appelé périodiquement pour vérifier si le timeout est atteint.
  """
  @spec check_fallback_status(String.t(), atom() | String.t()) :: :exact_search | {:fallback_proposal, integer()}
  def check_fallback_status(user_id, game_type) do
    timestamps_key = "queue:#{game_type}:timestamps"
    queue_key = "queue:#{game_type}"

    case Redix.command(Redis, ["HGET", timestamps_key, user_id]) do
      {:ok, nil} ->
        :exact_search

      {:ok, timestamp_str} ->
        entry_time = String.to_integer(timestamp_str)
        elapsed = System.system_time(:second) - entry_time

        if elapsed >= @fallback_timeout_seconds do
          # Récupérer la mise du joueur
          case Redix.command(Redis, ["HGET", queue_key, user_id]) do
            {:ok, bet_str} ->
              original_bet = String.to_integer(bet_str)
              proposed_bet = find_best_alternative_bet(queue_key, original_bet, user_id)

              case proposed_bet do
                nil -> :exact_search
                alt_bet -> {:fallback_proposal, alt_bet}
              end

            _ ->
              :exact_search
          end
        else
          :exact_search
        end

      _ ->
        :exact_search
    end
  end

  # === Fonctions Privées ===

  defp check_match(queue_key, game_type, user_id, bet_amount) do
    {:ok, player_count} = Redix.command(Redis, ["HLEN", queue_key])

    if player_count >= 2 do
      {:ok, players} = Redix.command(Redis, ["HGETALL", queue_key])

      # Phase 1: mise exacte
      matching_players = find_exact_matching_players(players, bet_amount, user_id)

      if length(matching_players) >= 1 do
        # Match trouvé !
        all_players = [user_id | matching_players] |> Enum.take(2)
        game_id = create_game(game_type, all_players, bet_amount)
        cleanup_queue(queue_key, game_type, all_players)
        notify_players_matched(all_players, game_id)
        {:ok, :matched, game_id}
      else
        {:ok, :waiting}
      end
    else
      {:ok, :waiting}
    end
  end

  defp find_exact_matching_players(players, target_bet, requesting_user_id) do
    target_str = Integer.to_string(target_bet)

    players
    |> Enum.chunk_every(2)
    |> Enum.filter(fn [uid, bet] ->
      uid != requesting_user_id and bet == target_str
    end)
    |> Enum.map(fn [uid, _] -> uid end)
  end

  defp find_best_alternative_bet(queue_key, original_bet, user_id) do
    {:ok, players} = Redix.command(Redis, ["HGETALL", queue_key])

    min_bet = round(original_bet * (1 - @fallback_tolerance_pct))
    max_bet = round(original_bet * (1 + @fallback_tolerance_pct))

    # Trouver les mises alternatives disponibles
    alternatives =
      players
      |> Enum.chunk_every(2)
      |> Enum.filter(fn [uid, _bet] -> uid != user_id end)
      |> Enum.map(fn [uid, bet_str] ->
        bet = String.to_integer(bet_str)
        {uid, bet}
      end)
      |> Enum.filter(fn {_uid, bet} ->
        bet >= min_bet and bet <= max_bet and bet != original_bet
      end)
      |> Enum.sort_by(fn {_uid, bet} -> abs(bet - original_bet) end)

    case alternatives do
      [{_uid, alt_bet} | _] -> alt_bet
      [] -> nil
    end
  end

  defp create_game(game_type, players, bet_amount) do
    game_id = "#{game_type}_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"

    game_key = "game:#{game_id}"
    Redix.command(Redis, ["HSET", game_key, "status", "waiting_for_bets"])
    Redix.command(Redis, ["HSET", game_key, "players", players |> Enum.join(",")])
    Redix.command(Redis, ["HSET", game_key, "bet_amount", "#{bet_amount}"])
    Redix.command(Redis, ["HSET", game_key, "game_type", "#{game_type}"])
    Redix.command(Redis, ["EXPIRE", game_key, 3600])

    game_id
  end

  defp cleanup_queue(queue_key, game_type, matched_players) do
    Enum.each(matched_players, fn user_id ->
      Redix.command(Redis, ["HDEL", queue_key, user_id])
      Redix.command(Redis, ["HDEL", "queue:#{game_type}:timestamps", user_id])
      Redix.command(Redis, ["DEL", "queue:#{game_type}:#{user_id}"])
    end)
  end

  defp notify_players_matched(players, game_id) do
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
  @spec get_queue_status(String.t(), atom() | String.t()) :: %{position: integer(), total_players: integer(), elapsed_seconds: integer()}
  def get_queue_status(user_id, game_type) do
    queue_key = "queue:#{game_type}"

    {:ok, total_players} = Redix.command(Redis, ["HLEN", queue_key])

    {:ok, all_players} = Redix.command(Redis, ["HKEYS", queue_key])
    position = Enum.find_index(all_players, fn p -> p == user_id end)

    # Temps écoulé depuis l'entrée
    elapsed = case Redix.command(Redis, ["HGET", "queue:#{game_type}:timestamps", user_id]) do
      {:ok, timestamp_str} when is_binary(timestamp_str) ->
        System.system_time(:second) - String.to_integer(timestamp_str)
      _ -> 0
    end

    %{
      position: (position || 0) + 1,
      total_players: total_players,
      elapsed_seconds: elapsed
    }
  end

  @doc """
  Cleanup files expirées.
  """
  def cleanup_expired_queues do
    :ok
  end
end
