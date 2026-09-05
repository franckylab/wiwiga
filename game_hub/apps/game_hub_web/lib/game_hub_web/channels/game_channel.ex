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
      
      # Notifier différé pour éviter broadcast avant join complet
      send(self(), {:after_join, user_id})

      # Si c'est un match GameMatch, pousser l'état actuel pour synchro
      if String.contains?(game_id, "match") do
        case GameHub.GameMatch.get_match(game_id) do
          {:ok, match} -> 
            send(self(), {:push_match_state, match})
          _ -> :ok
        end
      end
      
      {:ok, socket}
    else
      # Dev mode: accepter sans auth
      dev_id = "dev_#{System.unique_integer([:positive])}"
      socket = assign(socket, :user_id, dev_id)
      socket = assign(socket, :game_id, game_id)
      
      send(self(), {:after_join, dev_id})

      if String.contains?(game_id, "match") do
        case GameHub.GameMatch.get_match(game_id) do
          {:ok, match} -> send(self(), {:push_match_state, match})
          _ -> :ok
        end
      end
      
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
        {:ok, %{roll: roll}} ->
          # Source unique de vérité : GameMatch diffuse déjà via PubSub
          # (dice_rolled / turn_changed / set_result / match_result).
          # Ici on ne fait que répondre au lanceur pour feedback immédiat,
          # sans broadcast redondant (évite doubles events et races UI).
          {:reply, {:ok, %{status: "rolled", roll: %{player_id: to_string(roll.player_id), dice: roll.dice, sum: roll.sum}}}, socket}

        {:error, :not_your_turn} ->
          {:reply, {:error, %{reason: "not_your_turn"}}, socket}

        {:error, :player_eliminated} ->
          {:reply, {:error, %{reason: "player_eliminated"}}, socket}

        {:error, :already_rolled} ->
          {:reply, {:error, %{reason: "already_rolled"}}, socket}

        {:error, :set_not_in_progress} ->
          {:reply, {:error, %{reason: "set_not_in_progress"}}, socket}

        {:error, :voting_phase_active} ->
          {:reply, {:error, %{reason: "voting_phase_active"}}, socket}

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
      {:ok, _match} ->
        # Source unique : GameMatch diffuse via PubSub (target_voted /
        # vote_progress / target_calculated). Pas de broadcast redondant ici.
        {:reply, {:ok, %{status: "voted", target: target_value}}, socket}

      {:error, :already_voted} ->
        {:reply, {:error, %{reason: "already_voted"}}, socket}

      {:error, :not_voting_phase} ->
        {:reply, {:error, %{reason: "not_voting_phase"}}, socket}

      {:error, :invalid_target} ->
        {:reply, {:error, %{reason: "invalid_target"}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("vote_target", _params, socket) do
    {:reply, {:error, %{reason: "missing_target_value"}}, socket}
  end

  @impl true
  def handle_in("start_set", _params, socket) do
    game_id = socket.assigns.game_id

    case GameHub.GameMatch.start_set(game_id) do
      {:ok, match} ->
        # Source unique : GameMatch diffuse set_started via PubSub.
        {:reply, {:ok, %{status: "set_started", match: sanitize_match(match)}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # === Revanche opt-out (fin de partie) — le GenServer diffuse via PubSub,
  # ici on ne fait que répondre à l'appelant (pas de broadcast redondant). ===

  @impl true
  def handle_in("propose_rematch", _params, socket) do
    case GameHub.GameMatch.propose_rematch(socket.assigns.game_id, to_string(socket.assigns.user_id)) do
      {:ok, lobby} ->
        {:reply, {:ok, %{status: "proposed", lobby: lobby}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("respond_rematch", params, socket) do
    accept? = Map.get(params, "accept", Map.get(params, "accepted", true))

    case GameHub.GameMatch.respond_rematch(socket.assigns.game_id, to_string(socket.assigns.user_id), accept?) do
      {:ok, lobby} ->
        {:reply, {:ok, %{status: "responded", lobby: lobby}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("start_rematch", _params, socket) do
    case GameHub.GameMatch.start_rematch(socket.assigns.game_id, to_string(socket.assigns.user_id)) do
      # Match déjà sanitisé par GameMatch : ne pas re-sanitiser (idempotence).
      {:ok, %{new_match_id: new_id, match: match, excluded: excluded}} ->
        {:reply, {:ok, %{status: "started", new_match_id: new_id, match: match, excluded: excluded}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("cancel_rematch", _params, socket) do
    case GameHub.GameMatch.cancel_rematch(socket.assigns.game_id, to_string(socket.assigns.user_id)) do
      {:ok, lobby} ->
        {:reply, {:ok, %{status: "cancelled", lobby: lobby}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("leave_match", _params, socket) do
    # Idempotent : quitter l'interface de fin de partie (exclu des revanches)
    GameHub.GameMatch.leave_match(socket.assigns.game_id, to_string(socket.assigns.user_id))
    {:reply, {:ok, %{status: "left"}}, socket}
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

  @impl true
  def handle_info({:after_join, user_id}, socket) do
    broadcast!(socket, "player_joined", %{
      user_id: user_id,
      player_name: "Joueur_#{String.slice(to_string(user_id), 0..5)}"
    })
    {:noreply, socket}
  end

  @impl true
  def handle_info({:push_match_state, match}, socket) do
    push(socket, "match_state", %{match: sanitize_match(match)})
    {:noreply, socket}
  end

  # Forward GameMatch PubSub events to channel clients
  # Source unique temps réel : tout vient du GenServer via PubSub.
  @impl true
  def handle_info(%{event: event} = payload, socket) when event in ["dice_rolling", "dice_rolled", "turn_changed", "set_result", "match_result", "player_forfeited", "match_forfeit", "set_started", "target_calculated", "target_voted", "vote_progress", "match_state", "rematch_proposed", "rematch_updated", "rematch_ready", "rematch_cancelled"] do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp sanitize_match(match) do
    css = Map.get(match, :current_set_state)
    sanitized_css = case css do
      nil -> nil
      m when is_map(m) ->
        base = case Map.get(m, :result) do
          {:winner, id} -> Map.put(m, :result, %{winner_id: to_string(id), result: "winner"})
          :tie -> Map.put(m, :result, %{result: "tie"})
          _ -> m
        end
        # Rolls sanitize (clés string, rolled_at ISO) — déterministe pour tous
        base =
          try do
            Map.update(base, :rolls, %{}, fn rolls when is_map(rolls) ->
              Map.new(rolls, fn {k, v} -> {to_string(k), sanitize_roll(v)} end)
            end)
          rescue
            _ -> base
          end
        remaining = case Map.get(base, :turn_deadline) do
          %DateTime{} = dl -> try do max(0, DateTime.diff(dl, DateTime.utc_now(), :second)) rescue _ -> nil end
          _ -> nil
        end
        Map.put(base, :turn_remaining_seconds, remaining)
      other -> other
    end
    timeout_ms = try do GameHub.GameMatch.turn_timeout_seconds(Map.get(match, :game_type, "dice")) * 1000 rescue _ -> 30000 end
    {last_roller_id, last_roll} = latest_roll(match)
    %{
      match_id: match.match_id,
      status: to_string(match.status),
      current_set: match.current_set,
      sets_count: match.sets_count,
      sets_mode: Map.get(match, :sets_mode, "fixed"),
      sets_to_win: Map.get(match, :sets_to_win, div(match.sets_count, 2) + 1),
      dice_count: Map.get(match, :dice_count, 2),
      bet_amount: Map.get(match, :bet_amount, 0),
      rule_type: Map.get(match, :rule_type, "normal"),
      game_type: Map.get(match, :game_type, "dice"),
      max_players: Map.get(match, :max_players, 2),
      set_scores: match.set_scores,
      current_set_state: sanitized_css,
      eliminated_players: match.eliminated_players |> MapSet.to_list(),
      winner_id: Map.get(match, :winner_id) |> to_string_if_present(),
      turn_timeout_ms: timeout_ms,
      last_roller_id: last_roller_id,
      last_roll: last_roll,
      players: Enum.map(Map.get(match, :players, []), fn p -> %{id: to_string(p.id), name: Map.get(p, :name, "Joueur")} end)
    }
  rescue
    _ -> %{match_id: match.match_id, status: to_string(match.status)}
  end

  defp sanitize_roll(%{dice: dice, sum: sum} = roll) do
    %{
      player_id: roll |> Map.get(:player_id) |> to_string(),
      dice: dice,
      sum: sum,
      forfeited: Map.get(roll, :forfeited, false),
      rolled_at: case Map.get(roll, :rolled_at) do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        v when is_binary(v) -> v
        _ -> nil
      end
    }
  end
  defp sanitize_roll(other) when is_map(other) do
    pid = Map.get(other, :player_id) || Map.get(other, "player_id")
    dice = Map.get(other, :dice) || Map.get(other, "dice") || []
    sum = Map.get(other, :sum) || Map.get(other, "sum") || Enum.sum(List.wrap(dice))
    %{player_id: to_string(pid), dice: List.wrap(dice), sum: sum,
      forfeited: Map.get(other, :forfeited) || Map.get(other, "forfeited") || false,
      rolled_at: case Map.get(other, :rolled_at) || Map.get(other, "rolled_at") do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        v when is_binary(v) -> v
        _ -> nil
      end}
  rescue _ -> %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}
  end
  defp sanitize_roll(_), do: %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}

  defp latest_roll(match) do
    rolls = match |> Map.get(:current_set_state, %{}) |> then(fn
      nil -> %{}
      css when is_map(css) -> Map.get(css, :rolls, %{}) || Map.get(css, "rolls", %{}) || %{}
      _ -> %{}
    end)
    if map_size(rolls) == 0 do
      {nil, nil}
    else
      {pid, roll} = Enum.max_by(rolls, fn {_pid, r} ->
        case r do
          %{rolled_at: %DateTime{} = dt} -> DateTime.to_unix(dt, :microsecond)
          %{"rolled_at" => v} when is_binary(v) -> v
          %{rolled_at: v} when is_binary(v) -> v
          _ -> ""
        end
      end)
      {to_string(pid), sanitize_roll(roll)}
    end
  rescue _ -> {nil, nil}
  end

  defp to_string_if_present(nil), do: nil
  defp to_string_if_present(v), do: to_string(v)
  
  @doc """
  Handle disconnect.
  Applique politique de déconnexion (grace period).
  """
  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    game_id = socket.assigns[:game_id]

    if user_id && game_id do
      # Fin de partie : quitter l'interface = exclu des revanches (best effort).
      # leave_match est sans effet avant la fin du match (connexions instables).
      if String.contains?(to_string(game_id), "match") do
        try do
          GameHub.GameMatch.leave_match(to_string(game_id), to_string(user_id))
        rescue
          _ -> :ok
        end
      end

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
    # Le socket assigne :user_id dans UserSocket.connect/3.
    # Ancien code lisait :current_user (jamais assigné) → guest aléatoire
    # → not_your_turn permanent via WS. On lit :user_id en priorité.
    case socket.assigns[:user_id] do
      nil ->
        case socket.assigns[:current_user] do
          %{id: id} -> id
          _ -> nil
        end
      id -> id
    end
  end
end
