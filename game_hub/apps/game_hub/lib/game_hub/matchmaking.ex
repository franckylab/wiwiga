# ==================================
# WIWIGA - Module Matchmaking Redis (v3)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Matchmaking
# Description: Matchmaking atomique avec Redis + partition rule_type + hybrid Room
# V3: Suppression autoMatch séparé, partie rapide unifiée sur (game_type, rule_type, bet)

defmodule GameHub.Matchmaking do
  @moduledoc """
  Matchmaking temps réel avec Redis — V3 unifiée.

  ## Partition
  - Clé queue: `queue:{game_type}:{rule_type}` (ex: queue:dice:normal)
  - Compatibilité: recherche exacte sur (rule_type, bet_amount).
  - Fallback élargissement ±% après timeout (PlatformConfig).

  ## Flow
  1. Scan salles en attente compatibles (GameRoom) — hybrid (optionnel, fait par controller)
  2. Phase exacte immédiate dans la partition
  3. Phase fallback: mise alternative ±tolérance après timeout
  """

  require Logger

  alias GameHub.Redis
  alias GameHub.Admin.PlatformConfig

  @default_fallback_timeout 30
  @default_fallback_tolerance 0.20
  @queue_ttl 300
  @game_ttl 3600

  defp fallback_timeout_seconds do
    PlatformConfig.get_int("gaming", "fallback_timeout_seconds", @default_fallback_timeout)
  end

  defp fallback_tolerance_pct do
    PlatformConfig.get_float("gaming", "fallback_tolerance_pct", @default_fallback_tolerance)
  end

  # Normalise rule_type côté serveur
  defp normalize_rule(rule) when is_binary(rule) do
    case String.downcase(String.trim(rule)) do
      "cible" -> "cible"
      _ -> "normal"
    end
  end
  defp normalize_rule(_), do: "normal"

  defp queue_key(game_type, rule_type), do: "queue:#{game_type}:#{normalize_rule(rule_type)}"
  defp timestamps_key(game_type, rule_type), do: "queue:#{game_type}:#{normalize_rule(rule_type)}:timestamps"
  defp user_key(game_type, rule_type, user_id), do: "queue:#{game_type}:#{normalize_rule(rule_type)}:#{user_id}"

  # Pour compat ascendante (ancien clients sans rule_type) on tente normal puis cible si besoin
  defp legacy_queue_keys(game_type) do
    ["queue:#{game_type}:normal", "queue:#{game_type}:cible", "queue:#{game_type}"]
  end

  @doc """
  Rejoint file d'attente matchmaking — V3.

  ## Params
    - `rule_type`: "normal" | "cible"

  ## Returns
    - `{:ok, :waiting}`
    - `{:ok, :matched, game_id}`
    - `{:error, :already_queued}`
  """
  @spec join_queue(String.t(), atom() | String.t(), String.t(), integer()) ::
          {:ok, atom()} | {:ok, atom(), String.t()} | {:error, atom()}
  def join_queue(user_id, game_type, rule_type, bet_amount)
      when is_integer(bet_amount) and is_binary(rule_type) do
    do_join_queue(user_id, game_type, rule_type, bet_amount)
  end

  # Compat 3-arity legacy (tests)
  def join_queue(user_id, game_type, bet_amount) when is_integer(bet_amount) do
    do_join_queue(user_id, game_type, "normal", bet_amount)
  end

  defp do_join_queue(user_id, game_type, rule_type, bet_amount) do
    rule = normalize_rule(rule_type)
    qk = queue_key(game_type, rule)
    uk = user_key(game_type, rule, user_id)
    tk = timestamps_key(game_type, rule)

    # Vérifier déjà en file dans la partition cible
    case Redix.command(Redis, ["SETNX", uk, "waiting"]) do
      {:ok, 1} ->
        Redix.command(Redis, ["EXPIRE", uk, @queue_ttl])
        Redix.command(Redis, ["HSET", qk, user_id, "#{bet_amount}"])
        Redix.command(Redis, ["HSET", tk, user_id, "#{System.system_time(:second)}"])
        # Compat: nettoyer ancienne queue générique si existe (migration directe)
        Enum.each(legacy_queue_keys(game_type), fn lk ->
          if lk != qk, do: Redix.command(Redis, ["HDEL", lk, user_id])
        end)
        check_match(qk, tk, game_type, rule, user_id, bet_amount)

      {:ok, 0} ->
        {:error, :already_queued}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Quitte file d'attente — nettoie toutes partitions + ancienne générique.
  """
  @spec leave_queue(String.t(), atom() | String.t(), String.t() | nil) :: :ok
  def leave_queue(user_id, game_type, rule_type \\ nil)
  def leave_queue(user_id, game_type, rule_type) do
    keys =
      if rule_type do
        [queue_key(game_type, rule_type)]
      else
        legacy_queue_keys(game_type) ++ [queue_key(game_type, "normal"), queue_key(game_type, "cible")]
      end

    Enum.each(keys, fn qk ->
      Redix.command(Redis, ["HDEL", qk, user_id])
      # timestamps associé
      tk = qk <> ":timestamps"
      # cas partitionné timestamps est queue:game:rule:timestamps
      Redix.command(Redis, ["HDEL", tk, user_id])
      # cas generic legacy timestamps
      Redix.command(Redis, ["HDEL", "queue:#{game_type}:timestamps", user_id])
    end)

    # Supprime tous les locks user_key
    Enum.each(["normal", "cible"], fn r ->
      Redix.command(Redis, ["DEL", user_key(game_type, r, user_id)])
    end)
    Redix.command(Redis, ["DEL", "queue:#{game_type}:#{user_id}"])

    :ok
  end

  # Compat 2-arity


  @doc """
  Confirme la mise alternative proposée (Phase 2).
  """
  @spec confirm_alternative_bet(String.t(), atom() | String.t(), String.t(), integer()) ::
          {:ok, :matched, String.t()} | {:error, atom()}
  def confirm_alternative_bet(user_id, game_type, rule_type \\ "normal", new_bet_amount)
  def confirm_alternative_bet(user_id, game_type, rule_type, new_bet_amount) when is_binary(rule_type) do
    rule = normalize_rule(rule_type)
    qk = queue_key(game_type, rule)
    tk = timestamps_key(game_type, rule)
    Redix.command(Redis, ["HSET", qk, user_id, "#{new_bet_amount}"])
    case check_match(qk, tk, game_type, rule, user_id, new_bet_amount) do
      {:ok, :matched, game_id} -> {:ok, :matched, game_id}
      {:ok, :waiting} -> {:error, :no_match_found}
      error -> error
    end
  end

  @doc """
  Vérifie le statut de fallback pour un joueur.
  """
  @spec check_fallback_status(String.t(), atom() | String.t(), String.t()) ::
          :exact_search | {:fallback_proposal, integer()}
  def check_fallback_status(user_id, game_type, rule_type \\ "normal")
  def check_fallback_status(user_id, game_type, rule_type) when is_binary(rule_type) do
    rule = normalize_rule(rule_type)
    tk = timestamps_key(game_type, rule)
    qk = queue_key(game_type, rule)

    case Redix.command(Redis, ["HGET", tk, user_id]) do
      {:ok, nil} -> :exact_search
      {:ok, timestamp_str} when is_binary(timestamp_str) ->
        entry_time = String.to_integer(timestamp_str)
        elapsed = System.system_time(:second) - entry_time
        if elapsed >= fallback_timeout_seconds() do
          case Redix.command(Redis, ["HGET", qk, user_id]) do
            {:ok, bet_str} when is_binary(bet_str) ->
              original_bet = String.to_integer(bet_str)
              proposed_bet = find_best_alternative_bet(qk, original_bet, user_id)
              case proposed_bet do
                nil -> :exact_search
                alt_bet -> {:fallback_proposal, alt_bet}
              end
            _ -> :exact_search
          end
        else
          :exact_search
        end
      _ -> :exact_search
    end
  end

  # === Privé ===

  defp check_match(queue_key, _timestamps_key, game_type, rule_type, user_id, bet_amount) do
    {:ok, player_count} = Redix.command(Redis, ["HLEN", queue_key])

    if player_count >= 2 do
      {:ok, players} = Redix.command(Redis, ["HGETALL", queue_key])
      matching_players = find_exact_matching_players(players, bet_amount, user_id)

      if length(matching_players) >= 1 do
        all_players = [user_id | matching_players] |> Enum.take(2)
        game_id = create_game(game_type, rule_type, all_players, bet_amount)
        cleanup_queue(queue_key, game_type, rule_type, all_players)
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
    |> Enum.filter(fn [uid, bet] -> uid != requesting_user_id and bet == target_str end)
    |> Enum.map(fn [uid, _] -> uid end)
  end

  defp find_best_alternative_bet(queue_key, original_bet, user_id) do
    {:ok, players} = Redix.command(Redis, ["HGETALL", queue_key])
    min_bet = round(original_bet * (1 - fallback_tolerance_pct()))
    max_bet = round(original_bet * (1 + fallback_tolerance_pct()))

    alternatives =
      players
      |> Enum.chunk_every(2)
      |> Enum.filter(fn [uid, _bet] -> uid != user_id end)
      |> Enum.map(fn [_uid, bet_str] -> String.to_integer(bet_str) end)
      |> Enum.filter(fn bet -> bet >= min_bet and bet <= max_bet and bet != original_bet end)
      |> Enum.sort_by(fn bet -> abs(bet - original_bet) end)

    case alternatives do
      [alt_bet | _] -> alt_bet
      [] -> nil
    end
  end

  defp create_game(game_type, rule_type, players, bet_amount) do
    game_id = "#{game_type}_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
    game_key = "game:#{game_id}"
    Redix.command(Redis, ["HSET", game_key, "status", "waiting_for_bets"])
    Redix.command(Redis, ["HSET", game_key, "players", Enum.join(players, ",")])
    Redix.command(Redis, ["HSET", game_key, "bet_amount", "#{bet_amount}"])
    Redix.command(Redis, ["HSET", game_key, "game_type", "#{game_type}"])
    Redix.command(Redis, ["HSET", game_key, "rule_type", "#{normalize_rule(rule_type)}"])
    Redix.command(Redis, ["EXPIRE", game_key, @game_ttl])
    game_id
  end

  defp cleanup_queue(queue_key, game_type, rule_type, matched_players) do
    ts_key = timestamps_key(game_type, rule_type)
    Enum.each(matched_players, fn user_id ->
      Redix.command(Redis, ["HDEL", queue_key, user_id])
      Redix.command(Redis, ["HDEL", ts_key, user_id])
      Redix.command(Redis, ["DEL", user_key(game_type, rule_type, user_id)])
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
  @spec get_queue_status(String.t(), atom() | String.t(), String.t()) :: %{
          position: integer(),
          total_players: integer(),
          elapsed_seconds: integer(),
          rule_type: String.t()
        }
  def get_queue_status(user_id, game_type, rule_type \\ "normal")
  def get_queue_status(user_id, game_type, rule_type) when is_binary(rule_type) do
    rule = normalize_rule(rule_type)
    qk = queue_key(game_type, rule)
    tk = timestamps_key(game_type, rule)

    {:ok, total_players} = Redix.command(Redis, ["HLEN", qk])
    {:ok, all_players} = Redix.command(Redis, ["HKEYS", qk])
    position = Enum.find_index(all_players, fn p -> p == user_id end)

    elapsed =
      case Redix.command(Redis, ["HGET", tk, user_id]) do
        {:ok, ts} when is_binary(ts) -> System.system_time(:second) - String.to_integer(ts)
        _ -> 0
      end

    %{
      position: (position || 0) + 1,
      total_players: total_players,
      elapsed_seconds: elapsed,
      rule_type: rule
    }
  end



  # ============================================================
  # QUICK MATCH LOBBY SYNCHRONISÉ (V3.1) — Partie rapide multi-joueurs
  # ============================================================
  # Clé par (game, rule, bet) : un lobby éphémère qui accumule les joueurs
  # jusqu'à max_players, avec vote unanime pour démarrage anticipé.

  defp qm_lobby_key(game_type, rule_type, bet_amount),
    do: "qm:lobby:#{game_type}:#{normalize_rule(rule_type)}:#{bet_amount}"

  defp qm_meta_key(game_type, rule_type, bet_amount),
    do: "#{qm_lobby_key(game_type, rule_type, bet_amount)}:meta"

  defp qm_players_key(game_type, rule_type, bet_amount),
    do: "#{qm_lobby_key(game_type, rule_type, bet_amount)}:players"

  defp qm_ready_key(game_type, rule_type, bet_amount),
    do: "#{qm_lobby_key(game_type, rule_type, bet_amount)}:ready"

  defp get_lobby_limits(game_type, rule_type) do
    try do
      rules = GameHub.GameRules.get_rules_or_default(game_type, rule_type)
      rc = rules.config
      max = rc["max_players"] || 5
      min = rc["min_players"] || 2
      {min, max}
    rescue
      _ -> {2, 5}
    end
  end

  defp fetch_user_display(user_id) do
    # Essaie de récupérer nom réel depuis DB, fallback anonyme
    try do
      id_int = case Integer.parse(to_string(user_id)) do
        {int, ""} -> int
        _ -> nil
      end
      if id_int do
        case GameHub.Repo.get(GameHub.Users.User, id_int) do
          %{username: name} when is_binary(name) and name != "" -> name
          %{phone: phone} when is_binary(phone) -> "Joueur #{String.slice(phone, -4..-1)}"
          _ -> "Joueur #{String.slice(to_string(user_id), 0..3)}"
        end
      else
        "Joueur #{String.slice(to_string(user_id), 0..3)}"
      end
    rescue
      _ -> "Joueur #{String.slice(to_string(user_id), 0..3)}"
    end
  end

  @doc """
  Rejoint ou crée le lobby quick match (mise+rule) — synchronisé.
  Returns {:ok, :waiting, lobby_state} | {:ok, :matched, game_id, lobby_state} | {:error, reason}
  """
  def join_quick_lobby(user_id, game_type, rule_type, bet_amount) do
    rule = normalize_rule(rule_type)
    meta_key = qm_meta_key(game_type, rule, bet_amount)
    players_key = qm_players_key(game_type, rule, bet_amount)
    ready_key = qm_ready_key(game_type, rule, bet_amount)
    {min_players, max_players} = get_lobby_limits(game_type, rule)

    # Créer meta si absent
    case Redix.command(Redis, ["EXISTS", meta_key]) do
      {:ok, 0} ->
        Redix.command(Redis, ["HMSET", meta_key,
          "game_type", game_type,
          "rule_type", rule,
          "bet_amount", "#{bet_amount}",
          "max_players", "#{max_players}",
          "min_players", "#{min_players}",
          "created_at", "#{System.system_time(:second)}",
          "status", "waiting"])
        Redix.command(Redis, ["EXPIRE", meta_key, 300])
        Redix.command(Redis, ["EXPIRE", players_key, 300])
        Redix.command(Redis, ["EXPIRE", ready_key, 300])
      _ -> :ok
    end

    # Vérifier déjà dedans
    case Redix.command(Redis, ["HEXISTS", players_key, user_id]) do
      {:ok, 1} ->
        # Déjà dans lobby — retourner état
        {:ok, :waiting, get_quick_lobby_state(game_type, rule, bet_amount, user_id)}
      _ ->
        # Vérifier capacité
        {:ok, count} = Redix.command(Redis, ["HLEN", players_key])
        if count >= max_players do
          {:error, :lobby_full}
        else
          name = fetch_user_display(user_id)
          player_json = Jason.encode!(%{id: to_string(user_id), name: name, joined_at: System.system_time(:second)})
          Redix.command(Redis, ["HSET", players_key, user_id, player_json])
          Redix.command(Redis, ["HSET", ready_key, user_id, "0"])
          # Refresh TTL
          Redix.command(Redis, ["EXPIRE", meta_key, 300])
          Redix.command(Redis, ["EXPIRE", players_key, 300])
          Redix.command(Redis, ["EXPIRE", ready_key, 300])
          # Stocker aussi dans l'ancien système pour compat get_queue_status
          Redix.command(Redis, ["HSET", queue_key(game_type, rule), user_id, "#{bet_amount}"])
          Redix.command(Redis, ["HSET", timestamps_key(game_type, rule), user_id, "#{System.system_time(:second)}"])

          lobby = get_quick_lobby_state(game_type, rule, bet_amount, user_id)
          broadcast_quick_lobby(lobby)

          # Auto-start si complet
          if lobby.players_count >= max_players do
            case create_quick_game(game_type, rule, bet_amount, lobby.players) do
              {:ok, game_id, sets_info} ->
                cleanup_quick_lobby(game_type, rule, bet_amount, lobby.players)
                broadcast_quick_matched(game_type, rule, bet_amount, lobby.players, game_id, sets_info)
                {:ok, :matched, game_id, lobby}
              _ ->
                {:ok, :waiting, lobby}
            end
          else
            {:ok, :waiting, lobby}
          end
        end
    end
  end

  @doc """
  Quitte le lobby quick match.
  """
  def leave_quick_lobby(user_id, game_type, rule_type, bet_amount) do
    rule = normalize_rule(rule_type)
    players_key = qm_players_key(game_type, rule, bet_amount)
    ready_key = qm_ready_key(game_type, rule, bet_amount)
    meta_key = qm_meta_key(game_type, rule, bet_amount)

    Redix.command(Redis, ["HDEL", players_key, user_id])
    Redix.command(Redis, ["HDEL", ready_key, user_id])
    Redix.command(Redis, ["HDEL", queue_key(game_type, rule), user_id])
    Redix.command(Redis, ["HDEL", timestamps_key(game_type, rule), user_id])
    Redix.command(Redis, ["DEL", user_key(game_type, rule, user_id)])

    # Si lobby vide → cleanup meta
    case Redix.command(Redis, ["HLEN", players_key]) do
      {:ok, 0} ->
        Redix.command(Redis, ["DEL", meta_key])
        Redix.command(Redis, ["DEL", players_key])
        Redix.command(Redis, ["DEL", ready_key])
      _ ->
        lobby = get_quick_lobby_state(game_type, rule, bet_amount, nil)
        broadcast_quick_lobby(lobby)
    end

    # Aussi quitter l'ancien queue générique
    leave_queue(user_id, game_type, rule)
    :ok
  end

  @doc """
  Toggle ready pour démarrage anticipé. Retourne {:ok, lobby} | {:ok, :matched, game_id}
  """
  def toggle_quick_ready(user_id, game_type, rule_type, bet_amount) do
    rule = normalize_rule(rule_type)
    players_key = qm_players_key(game_type, rule, bet_amount)
    ready_key = qm_ready_key(game_type, rule, bet_amount)

    # Vérifier membre
    case Redix.command(Redis, ["HEXISTS", players_key, user_id]) do
      {:ok, 0} -> {:error, :not_in_lobby}
      _ ->
        {:ok, cur} = Redix.command(Redis, ["HGET", ready_key, user_id])
        new_val = if cur == "1", do: "0", else: "1"
        Redix.command(Redis, ["HSET", ready_key, user_id, new_val])

        lobby = get_quick_lobby_state(game_type, rule, bet_amount, user_id)
        broadcast_quick_lobby(lobby)

        # Si tous prêts et >= min_players → créer partie
        {min_players, _max} = get_lobby_limits(game_type, rule)
        if lobby.players_count >= min_players and lobby.ready_count == lobby.players_count and lobby.players_count >= 2 do
          case create_quick_game(game_type, rule, bet_amount, lobby.players) do
            {:ok, game_id, sets_info} ->
              cleanup_quick_lobby(game_type, rule, bet_amount, lobby.players)
              broadcast_quick_matched(game_type, rule, bet_amount, lobby.players, game_id, sets_info)
              {:ok, :matched, game_id, get_quick_lobby_state(game_type, rule, bet_amount, nil)}
            _ ->
              {:ok, lobby}
          end
        else
          {:ok, lobby}
        end
    end
  end

  @doc """
  Récupère l'état synchronisé du lobby.
  """
  def get_quick_lobby_state(game_type, rule_type, bet_amount, current_user_id \\ nil) do
    rule = normalize_rule(rule_type)
    meta_key = qm_meta_key(game_type, rule, bet_amount)
    players_key = qm_players_key(game_type, rule, bet_amount)
    ready_key = qm_ready_key(game_type, rule, bet_amount)

    {:ok, meta} = Redix.command(Redis, ["HGETALL", meta_key])
    # Si meta vide mais dernier match existe (course après consensus), retourner état matched
    if meta == [] do
      case fetch_last_matched(game_type, rule, bet_amount) do
        nil ->
          # Lobby inéxistant et pas de match récent → état vide
          {min_players, max_players} = get_lobby_limits(game_type, rule)
          %{
            game_type: game_type,
            rule_type: rule,
            bet_amount: bet_amount,
            max_players: max_players,
            min_players: min_players,
            players: [],
            players_count: 0,
            empty_slots: max_players,
            ready_count: 0,
            can_start: false,
            is_full: false,
            elapsed_seconds: 0,
            status: "empty",
            game_id: nil,
            sets: lobby_sets(game_type, rule)
          }
        game_id ->
          {min_players, max_players} = get_lobby_limits(game_type, rule)
          %{
            game_type: game_type,
            rule_type: rule,
            bet_amount: bet_amount,
            max_players: max_players,
            min_players: min_players,
            players: [],
            players_count: 0,
            empty_slots: max_players,
            ready_count: 0,
            can_start: false,
            is_full: false,
            elapsed_seconds: 0,
            status: "matched",
            game_id: game_id,
            sets: lobby_sets(game_type, rule)
          }
      end
    else
    meta_map = meta |> Enum.chunk_every(2) |> Enum.into(%{}, fn [k, v] -> {k, v} end)

    max_players = (meta_map["max_players"] || "5") |> String.to_integer()
    min_players = (meta_map["min_players"] || "2") |> String.to_integer()
    created_at = case meta_map["created_at"] do nil -> System.system_time(:second); v -> String.to_integer(v) end
    elapsed = System.system_time(:second) - created_at

    {:ok, players_raw} = Redix.command(Redis, ["HGETALL", players_key])
    {:ok, ready_raw} = Redix.command(Redis, ["HGETALL", ready_key])
    ready_map = ready_raw |> Enum.chunk_every(2) |> Enum.into(%{}, fn [k, v] -> {k, v == "1"} end)

    players =
      players_raw
      |> Enum.chunk_every(2)
      |> Enum.map(fn [uid, json] ->
        info = case Jason.decode(json) do {:ok, m} -> m; _ -> %{"id" => uid, "name" => "Joueur"} end
        ready = Map.get(ready_map, uid, false)
        Map.merge(info, %{"ready" => ready, "is_self" => to_string(uid) == to_string(current_user_id)})
      end)
      |> Enum.sort_by(fn p -> p["joined_at"] || 0 end)

    # Slots vides restants
    players_count = length(players)
    empty_slots = max(0, max_players - players_count)
    ready_count = Enum.count(players, fn p -> p["ready"] end)
    can_start = players_count >= min_players and ready_count == players_count and players_count >= 2
    is_full = players_count >= max_players

    lobby = %{
      game_type: game_type,
      rule_type: rule,
      bet_amount: bet_amount,
      max_players: max_players,
      min_players: min_players,
      players: players,
      players_count: players_count,
      empty_slots: empty_slots,
      ready_count: ready_count,
      can_start: can_start,
      is_full: is_full,
      elapsed_seconds: max(0, elapsed),
      status: cond do
        is_full -> "full"
        can_start -> "ready_to_start"
        true -> "waiting"
      end,
      game_id: nil,
      sets: lobby_sets(game_type, rule)
    }

    # Si lobby vient d'être matché (last_matched existe), propager game_id
    case fetch_last_matched(game_type, rule, bet_amount) do
      nil -> lobby
      game_id -> Map.put(lobby, :game_id, game_id) |> Map.put(:status, "matched")
    end
    end
  end

  defp create_quick_game(game_type, rule_type, bet_amount, players) do
    # Préfère créer un GameMatch multi-sets (vrai moteur) pour partie rapide,
    # fallback Redis simple si GameMatch indisponible.
    try do
      rules = GameHub.GameRules.get_rules_or_default(game_type, rule_type)
      rc = rules.config
      # Nombre de sets : tirage serveur UNIQUE (nil → défaut fixe ou tirage
      # aléatoire), identique pour tous les joueurs du lobby. Figé dans le
      # match : cohérent de la création jusqu'à la fin de la partie.
      {:ok, sets_count, sets_mode} =
        GameHub.GameRules.resolve_sets_count(game_type, normalize_rule(rule_type), nil)

      dice_count = rc["default_dice"] || 2
      creator = (List.first(players) || %{"id" => "unknown"})["id"]
      config = %{
        game_type: game_type,
        rule_type: normalize_rule(rule_type),
        mode: :staked,
        sets_count: sets_count,
        dice_count: dice_count,
        bet_amount: bet_amount,
        max_players: length(players),
        creator_id: creator
      }

      case GameHub.GameMatch.create_match(config) do
        {:ok, match} ->
          Enum.reduce_while(players, {:ok, match}, fn p, {:ok, acc} ->
            case GameHub.GameMatch.add_player(acc.match_id, p["id"], p["name"] || "Joueur") do
              {:ok, updated} -> {:cont, {:ok, updated}}
              {:error, :already_joined} -> {:cont, {:ok, acc}}
              err -> {:halt, err}
            end
          end)
          |> case do
            {:ok, final_match} ->
              # Démarrer le match (ready -> set_in_progress)
              case GameHub.GameMatch.start_match(final_match.match_id) do
                {:ok, _} -> GameHub.GameMatch.start_set(final_match.match_id)
                _ -> :ok
              end
              game_id = final_match.match_id
              Logger.info("Quick match #{game_id} created (#{game_type}/#{rule_type}, #{sets_count} sets, mode #{sets_mode}, #{length(players)} joueurs)")
              # Compat Redis pour game_state fallback
              Redix.command(Redis, ["HSET", "game:#{game_id}", "status", "in_progress"])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "players", Enum.map(players, fn p -> p["id"] end) |> Enum.join(",")])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "bet_amount", "#{bet_amount}"])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "game_type", game_type])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "rule_type", normalize_rule(rule_type)])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "sets_count", "#{sets_count}"])
              Redix.command(Redis, ["HSET", "game:#{game_id}", "sets_mode", sets_mode])
              Redix.command(Redis, ["EXPIRE", "game:#{game_id}", 3600])
              Redix.command(Redis, ["SET", "qm:last_matched:#{game_type}:#{normalize_rule(rule_type)}:#{bet_amount}", game_id, "EX", 60])
              {:ok, game_id, %{sets_count: sets_count, sets_mode: sets_mode}}
            err -> err
          end

        err -> err
      end
    rescue
      _ ->
        # Fallback Redis simple
        player_ids = Enum.map(players, fn p -> p["id"] end)
        game_id = create_game(game_type, rule_type, player_ids, bet_amount)
        Redix.command(Redis, ["SET", "qm:last_matched:#{game_type}:#{normalize_rule(rule_type)}:#{bet_amount}", game_id, "EX", 60])
        {:ok, game_id, %{sets_count: nil, sets_mode: "fixed"}}
    end
  end

  defp cleanup_quick_lobby(game_type, rule_type, bet_amount, players) do
    meta_key = qm_meta_key(game_type, rule_type, bet_amount)
    players_key = qm_players_key(game_type, rule_type, bet_amount)
    ready_key = qm_ready_key(game_type, rule_type, bet_amount)
    rule = normalize_rule(rule_type)

    Enum.each(players, fn p ->
      uid = p["id"]
      Redix.command(Redis, ["HDEL", queue_key(game_type, rule), uid])
      Redix.command(Redis, ["HDEL", timestamps_key(game_type, rule), uid])
      Redix.command(Redis, ["DEL", user_key(game_type, rule, uid)])
    end)

    Redix.command(Redis, ["DEL", meta_key])
    Redix.command(Redis, ["DEL", players_key])
    Redix.command(Redis, ["DEL", ready_key])
  end

  defp fetch_last_matched(game_type, rule_type, bet_amount) do
    case Redix.command(Redis, ["GET", "qm:last_matched:#{game_type}:#{normalize_rule(rule_type)}:#{bet_amount}"]) do
      {:ok, nil} -> nil
      {:ok, game_id} when is_binary(game_id) -> game_id
      _ -> nil
    end
  end

  defp broadcast_quick_lobby(lobby) do
    topic = "qm:lobby:#{lobby.game_type}:#{lobby.rule_type}:#{lobby.bet_amount}"
    Phoenix.PubSub.broadcast(GameHub.PubSub, topic, %{event: "lobby_update", lobby: lobby})
    # Aussi broadcast individuel pour fallback polling
    Enum.each(lobby.players, fn p ->
      Phoenix.PubSub.broadcast(GameHub.PubSub, "user:#{p["id"]}", %{event: "lobby_update", lobby: lobby})
      Phoenix.PubSub.broadcast(GameHub.PubSub, "matchmaking:#{lobby.game_type}", %{event: "lobby_update", lobby: lobby})
    end)
  rescue
    _ -> :ok
  end

  defp broadcast_quick_matched(game_type, rule_type, bet_amount, players, game_id, sets_info \\ %{sets_count: nil, sets_mode: "fixed"}) do
    rule = normalize_rule(rule_type)
    # Limites dynamiques (pas de valeurs codées en dur) + aperçu sets,
    # pour un lobby "matched" cohérent avec la configuration serveur.
    {min_players, max_players} = get_lobby_limits(game_type, rule)

    Enum.each(players, fn p ->
      Phoenix.PubSub.broadcast(GameHub.PubSub, "user:#{p["id"]}", %{event: "game_matched", game_id: game_id, bet_amount: bet_amount, rule_type: rule, sets_count: sets_info[:sets_count], sets_mode: sets_info[:sets_mode]})
      Phoenix.PubSub.broadcast(GameHub.PubSub, "matchmaking:#{game_type}", %{event: "game_matched", game_id: game_id, lobby_players: players, sets_count: sets_info[:sets_count], sets_mode: sets_info[:sets_mode]})
    end)
    broadcast_quick_lobby(%{game_type: game_type, rule_type: rule, bet_amount: bet_amount, players: players, players_count: length(players), max_players: max_players, min_players: min_players, ready_count: length(players), can_start: true, is_full: true, elapsed_seconds: 0, status: "matched", empty_slots: 0, sets: lobby_sets(game_type, rule)})
  rescue
    _ -> :ok
  end

  # Aperçu sets du lobby (jamais de crash : fallback statique).
  defp lobby_sets(game_type, rule_type) do
    GameHub.GameRules.sets_preview(game_type, rule_type)
  rescue
    _ -> %{mode: "fixed", fixed: 3, random_min: 1, random_max: 5, min_sets: 1, max_sets: 11, default_sets: 3}
  end

  @doc """
  Trouve le lobby quick match actif d'un joueur (scan Redis).
  Retourne {:ok, lobby_state} ou {:error, :not_found}
  """
  def find_active_quick_lobby_for_player(user_id) do
    uid = to_string(user_id)
    case Redix.command(Redis, ["KEYS", "qm:lobby:*:*:players"]) do
      {:ok, keys} when is_list(keys) ->
        Enum.find_value(keys, fn key ->
          # key = qm:lobby:{game}:{rule}:{bet}:players
          case String.split(key, ":") do
            ["qm", "lobby", game_type, rule_type, bet_str, "players"] ->
              case Integer.parse(bet_str) do
                {bet, ""} ->
                  case Redix.command(Redis, ["HEXISTS", key, uid]) do
                    {:ok, 1} ->
                      lobby = get_quick_lobby_state(game_type, rule_type, bet, uid)
                      if lobby.players_count > 0, do: {:ok, lobby}, else: nil
                    _ -> nil
                  end
                _ -> nil
              end
            _ -> nil
          end
        end) || {:error, :not_found}
      _ -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @doc """
  Cleanup files expirées.
  """
  def cleanup_expired_queues do
    :ok
  end
end
