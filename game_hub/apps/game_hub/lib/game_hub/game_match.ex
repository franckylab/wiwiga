# ==================================
# WIWIGA - Game Match (GenServer)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameMatch
# Description: Machine à états pour un match (partie complète avec sets)

defmodule GameHub.GameMatch do
  @moduledoc """
  GenServer gérant le cycle de vie d'un match de jeu.

  ## Concepts
  - **Match** : partie complète composée de N sets
  - **Set** : round individuel où chaque joueur lance les dés
  - **Manche** : tour de lancer d'un joueur dans un set

  ## State Machine
      :waiting_players → :ready → :set_in_progress → :set_ended → :match_ended
                                                   ↘ (set nul) → :voting_target → :set_in_progress

  ## Types de règles supportés
  - `normal` : High roll séquentiel, ordre tournant
  - `cible` : Vote pour cible, plus proche gagne
  """

  use GenServer
  require Logger

  alias GameHub.{GameRules, GameMode}

  @table :game_matches
  @cleanup_interval_ms 5 * 60 * 1000

  # === Client API ===

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Crée un nouveau match.

  ## Parameters
    - `config`: %{
        game_type: "dice",
        rule_type: "normal" | "cible",
        mode: :free | :staked (alias historique :betting → normalisé en :staked),
        sets_count: integer,
        dice_count: integer,
        bet_amount: integer (0 si Partie sans mise),
        max_players: integer,
        creator_id: string
      }

  ## Modes
    - `:free`   → Partie sans mise (gratuit)
    - `:staked` → Partie avec mise (alias "betting" accepté)

  ## Returns
    - `{:ok, match_state}`
  """
  def create_match(config) do
    GenServer.call(__MODULE__, {:create_match, config})
  end

  @doc """
  Ajoute un joueur au match.
  """
  def add_player(match_id, player_id, player_name \\ nil) do
    GenServer.call(__MODULE__, {:add_player, match_id, player_id, player_name})
  end

  @doc """
  Retire un joueur du match.
  """
  def remove_player(match_id, player_id) do
    GenServer.call(__MODULE__, {:remove_player, match_id, player_id})
  end

  @doc """
  Démarre le match (tous les joueurs prêts).
  """
  def start_match(match_id) do
    GenServer.call(__MODULE__, {:start_match, match_id})
  end

  @doc """
  Démarre le set en cours.
  """
  def start_set(match_id) do
    GenServer.call(__MODULE__, {:start_set, match_id})
  end

  @doc """
  Vote pour le nombre cible (Type Cible uniquement).
  """
  def vote_target(match_id, player_id, target_value) do
    GenServer.call(__MODULE__, {:vote_target, match_id, player_id, target_value})
  end

  @doc """
  Lance les dés pour un joueur.
  """
  def roll_dice(match_id, player_id) do
    GenServer.call(__MODULE__, {:roll_dice, match_id, player_id})
  end

  @doc """
  Récupère l'état d'un match.
  """
  def get_match(match_id) do
    GenServer.call(__MODULE__, {:get_match, match_id})
  end

  @doc """
  Liste les matchs actifs.
  """
  def list_active_matches do
    GenServer.call(__MODULE__, :list_active)
  end

  # === Server Callbacks ===

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:create_match, config}, _from, state) do
    match_id = generate_match_id(config.game_type)

    # Charger les règles
    rules = GameRules.get_rules_or_default(config.game_type, config.rule_type || "normal")
    rc = rules.config

    # Normaliser le mode (betting → staked)
    canonical_mode = GameMode.normalize(Map.get(config, :mode, :free))

    # Valeurs par défaut depuis les règles
    sets_count = Map.get(config, :sets_count, rc["default_sets"] || 1)
    dice_count = Map.get(config, :dice_count, rc["default_dice"] || 2)
    max_players = Map.get(config, :max_players, rc["max_players"] || 2)

    match = %{
      match_id: match_id,
      game_type: config.game_type,
      rule_type: config.rule_type || "normal",
      mode: canonical_mode,
      status: :waiting_players,
      sets_count: sets_count,
      sets_to_win: div(sets_count, 2) + 1,
      dice_count: dice_count,
      dice_faces: rc["dice_faces"] || 6,
      bet_amount: Map.get(config, :bet_amount, 0),
      max_players: max_players,
      creator_id: config.creator_id,
      players: [],
      current_set: 0,
      sets: [],
      set_scores: %{},
      current_set_state: nil,
      tie_rule: rc["tie_rule"] || "replay",
      turn_order: rc["turn_order"] || "rotating",
      target_vote_mode: rc["target_vote_mode"] || "average",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    :ets.insert(state.table, {match_id, match})
    Logger.info("Match #{match_id} created (#{config.game_type}/#{match.rule_type}, #{sets_count} sets)")

    {:reply, {:ok, match}, state}
  end

  @impl true
  def handle_call({:add_player, match_id, player_id, player_name}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        cond do
          match.status != :waiting_players ->
            {:reply, {:error, :match_already_started}, state}

          length(match.players) >= match.max_players ->
            {:reply, {:error, :match_full}, state}

          Enum.any?(match.players, fn p -> p.id == player_id end) ->
            {:reply, {:error, :already_joined}, state}

          true ->
            player = %{
              id: player_id,
              name: player_name || "Joueur_#{String.slice(to_string(player_id), 0..3)}",
              joined_at: DateTime.utc_now()
            }

            updated = %{match |
              players: match.players ++ [player],
              set_scores: Map.put(match.set_scores, player_id, 0),
              updated_at: DateTime.utc_now()
            }

            :ets.insert(state.table, {match_id, updated})
            Logger.info("Player #{player_id} joined match #{match_id}")

            {:reply, {:ok, updated}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_player, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        if match.status in [:waiting_players, :ready] do
          updated = %{match |
            players: Enum.reject(match.players, fn p -> p.id == player_id end),
            updated_at: DateTime.utc_now()
          }

          :ets.insert(state.table, {match_id, updated})
          {:reply, {:ok, updated}, state}
        else
          {:reply, {:error, :match_in_progress}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:start_match, match_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        cond do
          match.status != :waiting_players ->
            {:reply, {:error, :match_not_waiting}, state}

          length(match.players) < 2 ->
            {:reply, {:error, :not_enough_players}, state}

          true ->
            updated = %{match |
              status: :ready,
              updated_at: DateTime.utc_now()
            }

            :ets.insert(state.table, {match_id, updated})
            Logger.info("Match #{match_id} ready to start")

            {:reply, {:ok, updated}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:start_set, match_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        if match.status in [:ready, :set_ended] do
          set_number = match.current_set + 1

          # Déterminer l'ordre de tour pour ce set (tournant)
          turn_order = determine_turn_order(match, set_number)

          set_state = %{
            set_number: set_number,
            status: :in_progress,
            turn_order: turn_order,
            current_turn_index: 0,
            rolls: %{},
            target_value: nil,
            votes: %{},
            vote_phase: match.rule_type == "cible",
            started_at: DateTime.utc_now()
          }

          updated = %{match |
            status: :set_in_progress,
            current_set: set_number,
            current_set_state: set_state,
            updated_at: DateTime.utc_now()
          }

          :ets.insert(state.table, {match_id, updated})
          Logger.info("Match #{match_id}: Set #{set_number} started")

          {:reply, {:ok, updated}, state}
        else
          {:reply, {:error, :cannot_start_set}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:vote_target, match_id, player_id, target_value}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        set = match.current_set_state

        cond do
          is_nil(set) or set.status != :in_progress ->
            {:reply, {:error, :set_not_in_progress}, state}

          !set.vote_phase ->
            {:reply, {:error, :not_voting_phase}, state}

          Map.has_key?(set.votes, player_id) ->
            {:reply, {:error, :already_voted}, state}

          true ->
            # Valider la valeur du vote
            max_possible = match.dice_count * match.dice_faces
            if target_value < 1 or target_value > max_possible do
              {:reply, {:error, :invalid_target}, state}
            else
              updated_votes = Map.put(set.votes, player_id, target_value)
              updated_set = %{set | votes: updated_votes}

              # Si tous les joueurs ont voté → calculer la cible
              updated_set = if map_size(updated_votes) >= length(match.players) do
                target = calculate_target(updated_votes, match.target_vote_mode)
                %{updated_set | target_value: target, vote_phase: false}
              else
                updated_set
              end

              updated_match = %{match | current_set_state: updated_set, updated_at: DateTime.utc_now()}
              :ets.insert(state.table, {match_id, updated_match})

              {:reply, {:ok, updated_match}, state}
            end
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:roll_dice, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        set = match.current_set_state

        cond do
          is_nil(set) or set.status != :in_progress ->
            {:reply, {:error, :set_not_in_progress}, state}

          set.vote_phase ->
            {:reply, {:error, :voting_phase_active}, state}

          not is_current_turn(set, player_id) ->
            {:reply, {:error, :not_your_turn}, state}

          Map.has_key?(set.rolls, player_id) ->
            {:reply, {:error, :already_rolled}, state}

          true ->
            # Lancer les dés (crypto sécurisé)
            dice_results = Enum.map(1..match.dice_count, fn _ ->
              :crypto.strong_rand_bytes(1)
              |> :binary.decode_unsigned()
              |> rem(match.dice_faces)
              |> Kernel.+(1)
            end)

            roll = %{
              player_id: player_id,
              dice: dice_results,
              sum: Enum.sum(dice_results),
              rolled_at: DateTime.utc_now()
            }

            updated_rolls = Map.put(set.rolls, player_id, roll)
            next_turn_index = set.current_turn_index + 1

            updated_set = %{set |
              rolls: updated_rolls,
              current_turn_index: next_turn_index
            }

            # Si tous les joueurs ont lancé → évaluer le set
            {updated_set, set_result} = if map_size(updated_rolls) >= length(match.players) do
              result = evaluate_set(match, %{set | rolls: updated_rolls})
              {%{set | rolls: updated_rolls, status: :evaluated}, result}
            else
              {updated_set, :in_progress}
            end

            updated_match = %{match | current_set_state: updated_set, updated_at: DateTime.utc_now()}
            :ets.insert(state.table, {match_id, updated_match})

            {:reply, {:ok, %{match: updated_match, roll: roll, set_result: set_result}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_match, match_id}, _from, state) do
    {:reply, lookup_match(state.table, match_id), state}
  end

  @impl true
  def handle_call(:list_active, _from, state) do
    matches = :ets.tab2list(state.table)
    |> Enum.map(fn {_id, match} -> match end)
    |> Enum.filter(fn m -> m.status not in [:match_ended] end)

    {:reply, matches, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()
    five_min_ago = DateTime.add(now, -300, :second)

    :ets.tab2list(state.table)
    |> Enum.each(fn {match_id, match} ->
      if match.status == :match_ended or DateTime.compare(match.updated_at, five_min_ago) == :lt do
        :ets.delete(state.table, match_id)
      end
    end)

    schedule_cleanup()
    {:noreply, state}
  end

  # === Fonctions Privées ===

  defp lookup_match(table, match_id) do
    case :ets.lookup(table, match_id) do
      [{^match_id, match}] -> {:ok, match}
      [] -> {:error, :match_not_found}
    end
  end

  # Détermine l'ordre de tour pour un set.
  # Tournant : set 1 → [A, B], set 2 → [B, A], set 3 → [A, B], etc.
  defp determine_turn_order(match, set_number) do
    player_ids = Enum.map(match.players, fn p -> p.id end)

    case match.turn_order do
      "rotating" ->
        if rem(set_number, 2) == 1 do
          player_ids
        else
          Enum.reverse(player_ids)
        end

      "random" ->
        Enum.shuffle(player_ids)

      _ ->
        # creator_first
        creator_first = match.creator_id
        others = Enum.reject(player_ids, fn id -> id == creator_first end)
        [creator_first | others]
    end
  end

  defp is_current_turn(set, player_id) do
    turn_order = set.turn_order
    index = set.current_turn_index

    if index < length(turn_order) do
      Enum.at(turn_order, index) == player_id
    else
      false
    end
  end

  # Évalue le résultat d'un set selon le type de règle.
  defp evaluate_set(match, set) do
    case match.rule_type do
      "normal" -> evaluate_normal_set(match, set)
      "cible" -> evaluate_cible_set(match, set)
      _ -> evaluate_normal_set(match, set)
    end
  end

  # Type Normal : la somme la plus élevée gagne.
  # Égalité → set nul (replay selon tie_rule).
  defp evaluate_normal_set(_match, set) do
    rolls = set.rolls
    sums = Enum.map(rolls, fn {pid, roll} -> {pid, roll.sum} end)
    |> Enum.sort_by(fn {_pid, sum} -> -sum end)

    case sums do
      [{winner_id, highest}, {_loser_id, second}] when highest > second ->
        {:winner, winner_id}

      [{_pid1, same}, {_pid2, same}] ->
        :tie

      _ ->
        # Multi-joueurs : trouver le max unique
        max_sum = sums |> List.first() |> elem(1)
        winners = Enum.filter(sums, fn {_pid, s} -> s == max_sum end)

        case winners do
          [{winner_id, _}] -> {:winner, winner_id}
          _ -> :tie
        end
    end
  end

  # Type Cible : la distance la plus courte à la cible gagne.
  # Distances égales → set nul.
  defp evaluate_cible_set(_match, set) do
    target = set.target_value
    rolls = set.rolls

    distances = Enum.map(rolls, fn {pid, roll} ->
      {pid, abs(roll.sum - target)}
    end)
    |> Enum.sort_by(fn {_pid, dist} -> dist end)

    case distances do
      [{winner_id, closest}, {_loser_id, second}] when closest < second ->
        {:winner, winner_id}

      [{_pid1, same}, {_pid2, same}] ->
        :tie

      _ ->
        min_dist = distances |> List.first() |> elem(1)
        winners = Enum.filter(distances, fn {_pid, d} -> d == min_dist end)

        case winners do
          [{winner_id, _}] -> {:winner, winner_id}
          _ -> :tie
        end
    end
  end

  # Calcule la valeur cible depuis les votes.
  defp calculate_target(votes, mode) do
    values = Map.values(votes)

    case mode do
      "mode" ->
        # Mode statistique : valeur la plus fréquente
        values
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_val, count} -> -count end)
        |> List.first()
        |> elem(0)

      _ ->
        # Moyenne arrondie (défaut)
        sum = Enum.sum(values)
        count = length(values)
        if count > 0 do
          Float.round(sum / count) |> trunc()
        else
          7
        end
    end
  end

  defp generate_match_id(game_type) do
    "#{game_type}_match_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
