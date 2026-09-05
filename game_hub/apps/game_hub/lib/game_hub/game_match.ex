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
  @turn_timeout_default 30_000 # 30s par tour (utilise GameTimeoutConfig si configuré)
  @grace_period_default 45 # secondes

  # === Client API ===

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Crée un nouveau match — migration brutale (betting supprimé).

  ## Parameters
    - `config`: %{
        game_type: "dice",
        rule_type: "normal" | "cible",
        mode: :free | :staked,
        sets_count: integer,
        dice_count: integer,
        bet_amount: integer (0 si Partie sans mise),
        max_players: integer,
        creator_id: string
      }

  ## Modes
    - `:free`   → Partie sans mise (gratuit)
    - `:staked` → Partie avec mise

  ## Returns
    - `{:ok, match_state}` | `{:error, :invalid_mode}`
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

  @doc """
  Récupère le match actif d'un joueur (non terminé).
  """
  def get_active_match_for_player(player_id) do
    GenServer.call(__MODULE__, {:get_active_for_player, to_string(player_id)})
  end

  @doc """
  Déclare forfait pour un joueur (timeout expiré). Retiré de la partie, ne peut plus jouer.
  Si un seul joueur reste, il est déclaré gagnant du match.
  """
  def forfeit_player(match_id, player_id) do
    GenServer.call(__MODULE__, {:forfeit_player, match_id, player_id})
  end

  @doc """
  Propose une revanche après fin de partie (opt-out lobby).
  Le proposant accepte implicitement. Idempotent : si une proposition est
  déjà active, retourne le lobby existant.
  """
  def propose_rematch(match_id, player_id) do
    GenServer.call(__MODULE__, {:propose_rematch, match_id, to_string(player_id)})
  end

  @doc """
  Répond à une revanche proposée (`accept` booléen).
  Le proposant qui refuse annule la proposition.
  """
  def respond_rematch(match_id, player_id, accept?) do
    GenServer.call(__MODULE__, {:respond_rematch, match_id, to_string(player_id), accept? == true})
  end

  @doc """
  Démarre la revanche (proposant uniquement) avec les joueurs ayant accepté
  (minimum 2). Les mises sont re-débitées en partie avec mise.
  """
  def start_rematch(match_id, player_id) do
    GenServer.call(__MODULE__, {:start_rematch, match_id, to_string(player_id)})
  end

  @doc """
  Annule une revanche proposée (proposant uniquement).
  """
  def cancel_rematch(match_id, player_id) do
    GenServer.call(__MODULE__, {:cancel_rematch, match_id, to_string(player_id)})
  end

  @doc """
  Signale qu'un joueur quitte l'interface de fin de partie.
  Idempotent et sans effet avant la fin du match. Un joueur parti est exclu
  des revanches (le nombre de participants s'ajuste).
  """
  def leave_match(match_id, player_id) do
    GenServer.call(__MODULE__, {:leave_match, match_id, to_string(player_id)})
  end

  @doc """
  Récupère le délai par tour en secondes (config admin ou défaut).
  """
  def turn_timeout_seconds(game_type \\ "dice") do
    get_turn_timeout(game_type)
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
    game_type = Map.get(config, :game_type, "dice") || "dice"
    rule_type = Map.get(config, :rule_type, "normal") || "normal"
    match_id = generate_match_id(game_type)

    # Charger les règles
    rules = GameRules.get_rules_or_default(game_type, rule_type)
    rc = rules.config

    # Migration brutale: seuls :free et :staked — betting supprimé
    raw_mode = Map.get(config, :mode, :free)
    canonical_mode = case GameMode.parse_strict(to_string(raw_mode)) do
      {:ok, m} -> m
      {:error, _} -> nil
    end

    if is_nil(canonical_mode) do
      {:reply, {:error, :invalid_mode}, state}
    else

    # Nombre de sets : source unique GameRules.resolve_sets_count/3.
    # - Salles : la valeur client (déjà résolue par GameRoom) est respectée.
    # - Partie rapide : sets_count absent → défaut fixe ou tirage serveur
    #   (mode aléatoire), identique pour tous les joueurs du lobby.
    # Le résultat est figé dans le match : cohérent création → fin.
    {:ok, sets_count, sets_mode} =
      GameRules.resolve_sets_count(game_type, rule_type, Map.get(config, :sets_count))

    dice_count = Map.get(config, :dice_count) || rc["default_dice"] || 2
    max_players = Map.get(config, :max_players) || rc["max_players"] || 2

    match = %{
      match_id: match_id,
      game_type: game_type,
      rule_type: rule_type,
      mode: canonical_mode,
      status: :waiting_players,
      sets_count: sets_count,
      sets_mode: sets_mode,
      sets_to_win: div(sets_count, 2) + 1,
      dice_count: dice_count,
      dice_faces: rc["dice_faces"] || 6,
      bet_amount: Map.get(config, :bet_amount, 0),
      max_players: max_players,
      creator_id: Map.get(config, :creator_id) |> to_string(),
      players: [],
      current_set: 0,
      sets: [],
      set_scores: %{},
      current_set_state: nil,
      eliminated_players: MapSet.new(),
      forfeited_players: [],
      # Revanche opt-out : proposition active + joueurs ayant quitté l'interface
      rematch: nil,
      left_players: MapSet.new(),
      turn_timeout_ms: get_turn_timeout_ms(game_type),
      turn_deadline: nil,
      tie_rule: rc["tie_rule"] || "replay",
      turn_order: rc["turn_order"] || "rotating",
      target_vote_mode: rc["target_vote_mode"] || "average",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    :ets.insert(state.table, {match_id, match})
    Logger.info("Match #{match_id} created (#{game_type}/#{rule_type}, #{sets_count} sets, mode #{sets_mode})")

    {:reply, {:ok, match}, state}
    end
  end

  @impl true
  def handle_call({:add_player, match_id, player_id, player_name}, _from, state) do
    pid_str = to_string(player_id)
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        cond do
          match.status != :waiting_players ->
            {:reply, {:error, :match_already_started}, state}

          length(match.players) >= match.max_players ->
            {:reply, {:error, :match_full}, state}

          Enum.any?(match.players, fn p -> to_string(p.id) == pid_str end) ->
            {:reply, {:error, :already_joined}, state}

          true ->
            player = %{
              id: pid_str,
              name: player_name || "Joueur_#{String.slice(pid_str, 0..3)}",
              joined_at: DateTime.utc_now()
            }

            updated = %{match |
              players: match.players ++ [player],
              set_scores: Map.put(match.set_scores, pid_str, 0),
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
        if match.status in [:ready, :set_ended, :set_in_progress] do
          # Si un set est déjà en cours et non évalué, refuser
          if match.status == :set_in_progress and not is_nil(match.current_set_state) and match.current_set_state.status == :in_progress do
            {:reply, {:error, :set_already_in_progress}, state}
          else
            set_number = match.current_set + 1

            # Déterminer l'ordre de tour pour ce set (tournant) — filtrer éliminés
            turn_order = determine_turn_order(match, set_number)
            # Filtrer joueurs éliminés
            turn_order = Enum.reject(turn_order, fn pid -> eliminated?(match, pid) end)

            if length(turn_order) < 2 do
              # Plus qu'un joueur actif → fin de match par forfait
              winner_id = List.first(turn_order)
              ended = Map.merge(match, %{status: :match_ended, winner_id: winner_id, updated_at: DateTime.utc_now()})
              :ets.insert(state.table, {match_id, ended})
              broadcast_match_forfeit(match_id, nil, winner_id)
              {:reply, {:ok, ended}, state}
            else
              set_state = %{
                set_number: set_number,
                status: :in_progress,
                turn_order: turn_order,
                current_turn_index: 0,
                rolls: %{},
                target_value: nil,
                votes: %{},
                vote_phase: match.rule_type == "cible",
                started_at: DateTime.utc_now(),
                turn_deadline: DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)
              }

              updated = %{match |
                status: :set_in_progress,
                current_set: set_number,
                current_set_state: set_state,
                turn_deadline: set_state.turn_deadline,
                updated_at: DateTime.utc_now()
              }

              :ets.insert(state.table, {match_id, updated})
              Logger.info("Match #{match_id}: Set #{set_number} started (order #{inspect(turn_order)})")
              schedule_turn_timeout(match_id, updated.current_set_state.turn_order |> List.first(), turn_timeout_ms(match))
              broadcast_set_started(match_id, updated)

              {:reply, {:ok, updated}, state}
            end
          end
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

          Map.has_key?(set.votes, to_string(player_id)) or Map.has_key?(set.votes, player_id) ->
            {:reply, {:error, :already_voted}, state}

          true ->
            # Valider la valeur du vote
            max_possible = match.dice_count * match.dice_faces
            if target_value < 1 or target_value > max_possible do
              {:reply, {:error, :invalid_target}, state}
            else
              pid_str = to_string(player_id)
              updated_votes = Map.put(set.votes, pid_str, target_value)
              updated_set = %{set | votes: updated_votes}

              # Si tous les joueurs actifs ont voté → calculer la cible (filtrer éliminés)
              active_count = length(match.players) - MapSet.size(match.eliminated_players || MapSet.new())
              {updated_set, vote_event} = if map_size(updated_votes) >= active_count do
                target = calculate_target(updated_votes, match.target_vote_mode)
                # Délai de vote terminé → relancer deadline de tour pour premier lanceur
                new_deadline = DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)
                updated_with_target = %{updated_set | target_value: target, vote_phase: false, turn_deadline: new_deadline}
                # Reprogrammer timeout pour premier joueur
                first_player = List.first(updated_with_target.turn_order)
                if first_player, do: schedule_turn_timeout(match_id, first_player, turn_timeout_ms(match))
                {updated_with_target, {:calculated, target}}
              else
                {updated_set, {:progress, map_size(updated_votes), active_count}}
              end

              updated_match = %{match | current_set_state: updated_set, updated_at: DateTime.utc_now()}
              :ets.insert(state.table, {match_id, updated_match})

              # Broadcasts temps réel synchrones pour TOUS les joueurs (y compris vote via REST) :
              # chaque vote est propagé immédiatement, pas seulement la cible finale.
              case vote_event do
                {:calculated, target} ->
                  broadcast_target_voted(match_id, pid_str, target_value, updated_match)
                  broadcast_target_calculated(match_id, target, %{updated_match | current_set_state: updated_set})
                {:progress, votes_count, total_needed} ->
                  broadcast_target_voted(match_id, pid_str, target_value, updated_match)
                  broadcast_vote_progress(match_id, votes_count, total_needed, updated_match)
              end

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

          eliminated?(match, player_id) ->
            {:reply, {:error, :player_eliminated}, state}

          set.vote_phase ->
            {:reply, {:error, :voting_phase_active}, state}

          not is_current_turn(set, player_id) ->
            {:reply, {:error, :not_your_turn}, state}

          Map.has_key?(set.rolls, player_id) ->
            {:reply, {:error, :already_rolled}, state}

          true ->
            # Normaliser l'id joueur en string (cohérence rolls/votes/scores).
            # Évite les mismatches int vs string qui cassent already_rolled
            # et la synchro des tours entre WS (string) et REST (int).
            pid_str = to_string(player_id)
            # Vérifier doublon en string-safe (support anciens matchs mixtes)
            already_rolled? =
              Map.has_key?(set.rolls, pid_str) or Map.has_key?(set.rolls, player_id) or
                Enum.any?(Map.keys(set.rolls), fn k -> to_string(k) == pid_str end)

            if already_rolled? do
              {:reply, {:error, :already_rolled}, state}
            else
            # Phase 1 : notifier TOUS les joueurs du début du lancer (animation synchro).
            # Émis AVANT la génération crypto pour que l'anim démarre partout en même temps.
            broadcast_dice_rolling(match_id, pid_str, match)
            # Lancer les dés (crypto sécurisé)
            dice_results = Enum.map(1..match.dice_count, fn _ ->
              :crypto.strong_rand_bytes(1)
              |> :binary.decode_unsigned()
              |> rem(match.dice_faces)
              |> Kernel.+(1)
            end)

            roll = %{
              player_id: pid_str,
              dice: dice_results,
              sum: Enum.sum(dice_results),
              rolled_at: DateTime.utc_now()
            }

            updated_rolls = Map.put(set.rolls, pid_str, roll)
            next_turn_index = set.current_turn_index + 1

            # Calculer next player (skip éliminés) et vérifier fin de set
            active_players_count = length(match.players) - MapSet.size(match.eliminated_players)
            is_last_roll = map_size(updated_rolls) >= active_players_count

            {updated_set, set_result, final_match} =
              if is_last_roll do
                result = evaluate_set(match, %{set | rolls: updated_rolls})
                Logger.info("Roll last: match=#{match.match_id} result=#{inspect(result)} rolls=#{inspect(updated_rolls)}")
                # Gérer le scoring du set
                {scores, sets_list, match_status} =
                  try do
                    apply_set_result(match, result, updated_rolls, set.set_number, set.target_value)
                  rescue
                    e -> Logger.error("apply_set_result failed: #{inspect(e)} result=#{inspect(result)} match_id=#{match.match_id} stack=#{Exception.format(:error, e, __STACKTRACE__)}"); reraise e, __STACKTRACE__
                  end
                evaluated_set = Map.merge(set, %{rolls: updated_rolls, status: :evaluated, result: result})
                interim = %{match |
                  current_set_state: evaluated_set,
                  set_scores: scores,
                  sets: sets_list,
                  status: match_status,
                  turn_deadline: nil,
                  updated_at: DateTime.utc_now()
                }
                # Si match terminé ou tie replay, gérer automatiquement prochain set
                # Gestion fin de match : majorité OU tous les sets joués (spec: plus de sets gagnés)
                final = if match_status == :match_ended do
                  interim
                else
                  cond do
                    result == :tie ->
                      # Tie : set nul, mais si c'était le dernier set prévu et pas de majorité, départager au max
                      if interim.current_set >= interim.sets_count do
                        winner = get_winner_by_max(scores)
                        if winner do
                          Map.merge(interim, %{status: :match_ended, winner_id: winner})
                        else
                          Map.merge(interim, %{status: :match_ended, winner_id: nil})
                        end
                      else
                        %{interim | status: :set_ended}
                      end
                    match?({:winner, _}, result) ->
                      if has_match_winner?(scores, interim.sets_to_win) do
                        winner = get_match_winner(scores, interim.sets_to_win)
                        Map.merge(interim, %{status: :match_ended, winner_id: winner})
                      else
                        if interim.current_set >= interim.sets_count do
                          # Tous les sets joués, gagnant au max
                          winner = get_winner_by_max(scores)
                          if winner do
                            Map.merge(interim, %{status: :match_ended, winner_id: winner})
                          else
                            Map.merge(interim, %{status: :match_ended, winner_id: nil})
                          end
                        else
                          %{interim | status: :set_ended}
                        end
                      end
                  end
                end
                {evaluated_set, result, final}
              else
                next_set = %{set |
                  rolls: updated_rolls,
                  current_turn_index: next_turn_index,
                  turn_deadline: DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)
                }
                interim = %{match | current_set_state: next_set, turn_deadline: next_set.turn_deadline, updated_at: DateTime.utc_now()}
                {next_set, :in_progress, interim}
              end

            :ets.insert(state.table, {match_id, final_match})
            broadcast_dice_rolled(match_id, roll, final_match)

            if is_last_roll do
              broadcast_set_result(match_id, final_match, set_result)
              if final_match.status == :match_ended do
                broadcast_match_result(match_id, final_match)
                # Persistance et stats (async, best effort)
                Task.start(fn -> persist_match_result(final_match) end)
              else
                # Auto-démarrage du set suivant après 4s si personne ne clique (synchro garantie pour tous)
                schedule_auto_next_set(match_id, 4000)
              end
            else
              # Schedule timeout pour le prochain joueur
              next_player = Enum.at(set.turn_order, next_turn_index)
              if next_player, do: schedule_turn_timeout(match_id, next_player, turn_timeout_ms(match))
              broadcast_turn_changed(match_id, final_match)
            end

            {:reply, {:ok, %{match: final_match, roll: roll, set_result: set_result}}, state}
            end
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:forfeit_player, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        if eliminated?(match, player_id) do
          {:reply, {:error, :already_eliminated}, state}
        else
          pid_str = to_string(player_id)
          current_eliminated = Map.get(match, :eliminated_players, MapSet.new()) || MapSet.new()
          eliminated = MapSet.put(current_eliminated, pid_str)
          cur_forfeited = Map.get(match, :forfeited_players, []) || []
          forfeited = [pid_str | cur_forfeited]
          # Avancer l'index si c'était son tour
          set = match.current_set_state
          updated_set =
            if set && set.status == :in_progress && is_current_turn(set, player_id) do
              %{set | current_turn_index: set.current_turn_index + 1, turn_deadline: DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)}
            else
              set
            end

          interim = %{match | eliminated_players: eliminated, forfeited_players: forfeited, current_set_state: updated_set, updated_at: DateTime.utc_now()}

          # Si un seul joueur reste actif → match terminé (comparaison string-safe)
          active = Enum.reject(match.players, fn p -> eliminated?(%{eliminated_players: eliminated}, p.id) end)
          final =
            if length(active) <= 1 do
              winner_id = if length(active) == 1, do: List.first(active).id |> to_string(), else: nil
              Map.merge(interim, %{status: :match_ended, winner_id: winner_id})
            else
              # si c'était le dernier à jouer dans le set, évaluer avec joueurs restants
              if updated_set && map_size(updated_set.rolls) + MapSet.size(eliminated) >= length(match.players) do
                # Évaluer set avec rolls existants (sans le forfeited)
                result = evaluate_set(interim, updated_set)
                {scores, sets_list, _} = apply_set_result(interim, result, updated_set.rolls, updated_set.set_number, updated_set.target_value)
                %{interim | set_scores: scores, sets: sets_list, current_set_state: %{updated_set | status: :evaluated, result: result}, status: :set_ended}
              else
                # Schedule next timeout + broadcast turn change (synchro UI)
                if updated_set do
                  next_player = Enum.at(updated_set.turn_order, updated_set.current_turn_index)
                  if next_player, do: schedule_turn_timeout(match_id, next_player, turn_timeout_ms(match))
                end
                # Broadcast turn change for sync (même si pas forfait, le tour avance)
                broadcast_turn_changed(match_id, interim)
                interim
              end
            end

          :ets.insert(state.table, {match_id, final})
          broadcast_player_forfeited(match_id, pid_str, final)
          if final.status == :match_ended do
            broadcast_match_result(match_id, final)
            Task.start(fn -> persist_match_result(final) end)
          end
          # Si set évalué après forfait, broadcaster aussi le résultat de set + auto next
          if final.status == :set_ended and final.current_set_state && final.current_set_state.status == :evaluated do
            broadcast_set_result(match_id, final, final.current_set_state.result)
            cond do
              has_match_winner?(final.set_scores, final.sets_to_win) ->
                winner = get_match_winner(final.set_scores, final.sets_to_win)
                ended = Map.merge(final, %{status: :match_ended, winner_id: winner})
                :ets.insert(state.table, {match_id, ended})
                broadcast_match_result(match_id, ended)
                Task.start(fn -> persist_match_result(ended) end)
              final.current_set >= final.sets_count ->
                winner = get_winner_by_max(final.set_scores)
                ended = Map.merge(final, %{status: :match_ended, winner_id: winner})
                :ets.insert(state.table, {match_id, ended})
                broadcast_match_result(match_id, ended)
                Task.start(fn -> persist_match_result(ended) end)
              true ->
                schedule_auto_next_set(match_id, 4000)
            end
          end

          {:reply, {:ok, final}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:propose_rematch, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        pid = to_string(player_id)
        cond do
          match.status != :match_ended ->
            {:reply, {:error, :match_not_ended}, state}

          not match_player?(match, pid) ->
            {:reply, {:error, :not_a_player}, state}

          left_player?(match, pid) ->
            {:reply, {:error, :player_left}, state}

          true ->
            case Map.get(match, :rematch) do
              %{started: false} = existing ->
                # Revanche simultanée : proposer = accepter. L'appelant
                # rejoint les acceptants au lieu de rester en attente.
                merged =
                  Map.merge(existing, %{
                    accepted: MapSet.put(existing.accepted, pid),
                    declined: MapSet.delete(existing.declined, pid),
                    notice: nil
                  })

                interim = Map.put(match, :rematch, merged) |> Map.put(:updated_at, DateTime.utc_now())
                :ets.insert(state.table, {match_id, interim})
                # Démarre seul si tout le monde a accepté (zéro tap de plus)
                {final, _started?} = maybe_auto_start(state.table, match_id, interim)

                {:reply, {:ok, rematch_lobby_view(final, Map.get(final, :rematch))}, state}

              _ ->
                lobby = %{
                  proposed_by: pid,
                  accepted: MapSet.new([pid]),
                  declined: MapSet.new(),
                  proposed_at: DateTime.utc_now(),
                  started: false,
                  new_match_id: nil,
                  notice: nil
                }

                updated = Map.put(match, :rematch, lobby) |> Map.put(:updated_at, DateTime.utc_now())
                :ets.insert(state.table, {match_id, updated})
                Logger.info("Match #{match_id}: revanche proposée par #{pid}")
                broadcast_rematch(match_id, "rematch_proposed", updated)

                {:reply, {:ok, rematch_lobby_view(updated, lobby)}, state}
            end
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:respond_rematch, match_id, player_id, accept?}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        pid = to_string(player_id)

        case Map.get(match, :rematch) do
          %{started: false} = lobby ->
            cond do
              not match_player?(match, pid) ->
                {:reply, {:error, :not_a_player}, state}

              left_player?(match, pid) ->
                {:reply, {:error, :player_left}, state}

              pid == lobby.proposed_by and not accept? ->
                # Le proposant qui refuse annule la proposition
                updated = Map.put(match, :rematch, nil) |> Map.put(:updated_at, DateTime.utc_now())
                :ets.insert(state.table, {match_id, updated})
                broadcast_rematch(match_id, "rematch_cancelled", updated)
                {:reply, {:ok, rematch_lobby_view(updated, nil)}, state}

              true ->
                accepted =
                  if accept?,
                    do: MapSet.put(lobby.accepted, pid),
                    else: MapSet.delete(lobby.accepted, pid)

                declined =
                  if accept?,
                    do: MapSet.delete(lobby.declined, pid),
                    else: MapSet.put(lobby.declined, pid)

                updated_lobby =
                  Map.merge(lobby, %{accepted: accepted, declined: declined, notice: nil})
                interim = Map.put(match, :rematch, updated_lobby) |> Map.put(:updated_at, DateTime.utc_now())
                :ets.insert(state.table, {match_id, interim})
                # Démarre seul si tout le monde a accepté (zéro tap de plus)
                {final, _started?} = maybe_auto_start(state.table, match_id, interim)

                {:reply, {:ok, rematch_lobby_view(final, Map.get(final, :rematch))}, state}
            end

          _ ->
            {:reply, {:error, :no_rematch_proposal}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:start_rematch, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        pid = to_string(player_id)

        case Map.get(match, :rematch) do
          %{started: false} = lobby when lobby.proposed_by == pid ->
            case do_start_rematch(state.table, match_id, match, lobby) do
              {:ok, new_match, excluded, updated} ->
                {:reply, {:ok, %{lobby: rematch_lobby_view(updated, Map.get(updated, :rematch)), new_match_id: new_match.match_id, match: sanitize_match(new_match), excluded: excluded}}, state}

              {:error, reason} ->
                {:reply, {:error, reason}, state}
            end

          %{started: false} ->
            {:reply, {:error, :not_proposer}, state}

          _ ->
            {:reply, {:error, :no_rematch_proposal}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cancel_rematch, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        pid = to_string(player_id)

        case Map.get(match, :rematch) do
          %{started: false} = lobby when lobby.proposed_by == pid ->
            updated = Map.put(match, :rematch, nil) |> Map.put(:updated_at, DateTime.utc_now())
            :ets.insert(state.table, {match_id, updated})
            broadcast_rematch(match_id, "rematch_cancelled", updated)
            {:reply, {:ok, rematch_lobby_view(updated, nil)}, state}

          %{started: false} ->
            {:reply, {:error, :not_proposer}, state}

          _ ->
            {:reply, {:error, :no_rematch_proposal}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:leave_match, match_id, player_id}, _from, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        pid = to_string(player_id)

        if match.status != :match_ended do
          {:reply, {:ok, %{left: false}}, state}
        else
          left = Map.get(match, :left_players, MapSet.new()) || MapSet.new()

          if MapSet.member?(left, pid) do
            {:reply, {:ok, %{left: true}}, state}
          else
            updated_left = MapSet.put(left, pid)
            interim = Map.put(match, :left_players, updated_left) |> Map.put(:updated_at, DateTime.utc_now())

            # Si une revanche est proposée : le partant est retiré des acceptants.
            # Si c'est le proposant, la proposition est annulée.
            final =
              case Map.get(interim, :rematch) do
                %{started: false} = lobby ->
                  if lobby.proposed_by == pid do
                    Map.put(interim, :rematch, nil)
                  else
                    updated_lobby =
                      Map.merge(lobby, %{
                        accepted: MapSet.delete(lobby.accepted, pid),
                        declined: MapSet.put(lobby.declined, pid),
                        notice: nil
                      })

                    Map.put(interim, :rematch, updated_lobby)
                  end

                _ ->
                  interim
              end

            :ets.insert(state.table, {match_id, final})

            case Map.get(match, :rematch) do
              %{started: false} = lobby when lobby.proposed_by == pid ->
                broadcast_rematch(match_id, "rematch_cancelled", final)

              %{started: false} ->
                broadcast_rematch(match_id, "rematch_updated", final)

              _ ->
                :ok
            end

            {:reply, {:ok, %{left: true}}, state}
          end
        end

      {:error, _} ->
        # Idempotent pour les chemins dispose : match déjà nettoyé
        {:reply, {:ok, %{left: false}}, state}
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
  def handle_call({:get_active_for_player, player_id}, _from, state) do
    pid_str = to_string(player_id)
    match = :ets.tab2list(state.table)
    |> Enum.map(fn {_id, m} -> m end)
    |> Enum.find(fn m ->
      m.status not in [:match_ended] and
        Enum.any?(m.players, fn p -> to_string(p.id) == pid_str end)
    end)

    case match do
      nil -> {:reply, {:error, :not_found}, state}
      m -> {:reply, {:ok, m}, state}
    end
  end

  @impl true
  def handle_info({:turn_timeout, match_id, player_id}, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        set = match.current_set_state
        cond do
          match.status != :set_in_progress or is_nil(set) or set.status != :in_progress ->
            {:noreply, state}

          eliminated?(match, player_id) ->
            {:noreply, state}

          Map.has_key?(set.rolls, player_id) ->
            {:noreply, state}

          not is_current_turn(set, player_id) ->
            {:noreply, state}

          true ->
            pid_str = to_string(player_id)
            Logger.warning("Turn timeout for player #{pid_str} in match #{match_id} — perd le set (délai expiré)")
            # Timeout = le joueur perd le set avec un lancer à 0, pas élimination du match
            synthetic_roll = %{
              player_id: pid_str,
              dice: List.duplicate(0, match.dice_count),
              sum: 0,
              rolled_at: DateTime.utc_now(),
              forfeited: true
            }
            updated_rolls = Map.put(set.rolls, pid_str, synthetic_roll)
            next_turn_index = set.current_turn_index + 1
            active_count = length(match.players) - MapSet.size(match.eliminated_players || MapSet.new())
            is_last = map_size(updated_rolls) >= active_count
            {updated_set, set_result, interim} =
              if is_last do
                # Dernier joueur du set a expiré → évaluer le set (le forfeited a 0, perdra)
                tmp_set = %{set | rolls: updated_rolls}
                result = evaluate_set(match, tmp_set)
                {scores, sets_list, _} = apply_set_result(match, result, updated_rolls, set.set_number, set.target_value)
                evaluated_set = Map.merge(set, %{rolls: updated_rolls, status: :evaluated, result: result})
                interim0 = %{match |
                  current_set_state: evaluated_set,
                  set_scores: scores,
                  sets: sets_list,
                  updated_at: DateTime.utc_now()
                }
                # Déterminer si match terminé (majorité ou tous sets joués)
                final0 = cond do
                  has_match_winner?(scores, interim0.sets_to_win) ->
                    winner = get_match_winner(scores, interim0.sets_to_win)
                    Map.merge(interim0, %{status: :match_ended, winner_id: winner})
                  interim0.current_set >= interim0.sets_count ->
                    winner = get_winner_by_max(scores)
                    Map.merge(interim0, %{status: :match_ended, winner_id: winner})
                  true ->
                    %{interim0 | status: :set_ended}
                end
                {evaluated_set, result, final0}
              else
                next_set = %{set |
                  rolls: updated_rolls,
                  current_turn_index: next_turn_index,
                  turn_deadline: DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)
                }
                interim0 = %{match | current_set_state: next_set, turn_deadline: next_set.turn_deadline, updated_at: DateTime.utc_now()}
                {next_set, :in_progress, interim0}
              end
            :ets.insert(state.table, {match_id, interim})
            # Notifier forfait du tour (perd le set, pas le match)
            broadcast_player_forfeited(match_id, pid_str, interim)
            if is_last do
              broadcast_set_result(match_id, interim, set_result)
              if interim.status == :match_ended do
                broadcast_match_result(match_id, interim)
                Task.start(fn -> persist_match_result(interim) end)
              else
                schedule_auto_next_set(match_id, 4000)
              end
            else
              next_player = Enum.at(updated_set.turn_order, updated_set.current_turn_index)
              if next_player, do: schedule_turn_timeout(match_id, next_player, turn_timeout_ms(match))
              broadcast_turn_changed(match_id, interim)
            end
            {:noreply, state}
        end
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:auto_next_set, match_id}, state) do
    case lookup_match(state.table, match_id) do
      {:ok, match} ->
        if match.status == :set_ended do
          # Vérifier fin de match : majorité OU tous les sets joués
          cond do
            has_match_winner?(match.set_scores, match.sets_to_win) ->
              winner = get_match_winner(match.set_scores, match.sets_to_win)
              ended = Map.merge(match, %{status: :match_ended, winner_id: winner, updated_at: DateTime.utc_now()})
              :ets.insert(state.table, {match_id, ended})
              broadcast_match_result(match_id, ended)
              Task.start(fn -> persist_match_result(ended) end)
              {:noreply, state}
            match.current_set >= match.sets_count ->
              winner = get_winner_by_max(match.set_scores)
              ended = Map.merge(match, %{status: :match_ended, winner_id: winner, updated_at: DateTime.utc_now()})
              :ets.insert(state.table, {match_id, ended})
              broadcast_match_result(match_id, ended)
              Task.start(fn -> persist_match_result(ended) end)
              {:noreply, state}
            true ->
              # Lancer set suivant automatiquement (synchro pour tous les joueurs)
              case do_start_set_internal(state.table, match) do
                {:ok, updated} ->
                  :ets.insert(state.table, {match_id, updated})
                  broadcast_set_started(match_id, updated)
                  # Programmer timeout pour premier joueur du nouveau set
                  first_player = updated.current_set_state.turn_order |> List.first()
                  if first_player, do: schedule_turn_timeout(match_id, first_player, turn_timeout_ms(updated))
                  {:noreply, state}
                _ ->
                  {:noreply, state}
              end
          end
        else
          {:noreply, state}
        end
      _ ->
        {:noreply, state}
    end
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
    player_ids = Enum.map(match.players, fn p -> to_string(p.id) end)

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
        creator_first = to_string(match.creator_id)
        others = Enum.reject(player_ids, fn id -> to_string(id) == creator_first end)
        [creator_first | others]
    end
  end

  defp is_current_turn(set, player_id) do
    turn_order = set.turn_order
    index = set.current_turn_index

    if index < length(turn_order) do
      to_string(Enum.at(turn_order, index)) == to_string(player_id)
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

  defp eliminated?(match, player_id) do
    pid_str = to_string(player_id)
    case Map.get(match, :eliminated_players) do
      nil -> false
      %MapSet{} = set ->
        # Support ancien stockage mixte (int/string) via double vérification
        MapSet.member?(set, pid_str) or MapSet.member?(set, player_id) or
          Enum.any?(set, fn e -> to_string(e) == pid_str end)
      _ -> false
    end
  end

  defp turn_timeout_ms(match) do
    Map.get(match, :turn_timeout_ms, @turn_timeout_default) || @turn_timeout_default
  end

  # === Revanche (opt-out lobby) ===

  defp match_player?(match, player_id) do
    pid = to_string(player_id)
    Enum.any?(Map.get(match, :players, []), fn p -> to_string(p.id) == pid end)
  end

  defp left_player?(match, player_id) do
    pid = to_string(player_id)
    case Map.get(match, :left_players) do
      %MapSet{} = set -> MapSet.member?(set, pid)
      _ -> false
    end
  end

  # Acceptants effectifs triés : acceptés − partis − refus − non-joueurs.
  defp rematch_accepters(match, lobby) do
    left = Map.get(match, :left_players, MapSet.new()) || MapSet.new()

    lobby.accepted
    |> MapSet.to_list()
    |> Enum.reject(fn id -> MapSet.member?(left, id) end)
    |> Enum.reject(fn id -> MapSet.member?(lobby.declined, id) end)
    |> Enum.filter(fn id -> match_player?(match, id) end)
    |> Enum.sort()
  end

  # Invités effectifs triés : joueurs n'ayant pas quitté l'interface.
  defp rematch_invited(match) do
    left = Map.get(match, :left_players, MapSet.new()) || MapSet.new()

    match.players
    |> Enum.map(fn p -> to_string(p.id) end)
    |> Enum.reject(fn id -> MapSet.member?(left, id) end)
    |> Enum.sort()
  end

  # Démarrage effectif (débits + création). Retourne le nouveau match.
  defp do_start_rematch(table, match_id, match, lobby) do
    accepters = rematch_accepters(match, lobby)

    if length(accepters) < 2 do
      {:error, :not_enough_players}
    else
      names = Map.new(match.players, fn p -> {to_string(p.id), Map.get(p, :name, "Joueur")} end)
      bet = Map.get(match, :bet_amount, 0) || 0

      # Partie avec mise : re-débit des acceptants (exclusion si fonds insuffisants)
      {funded, excluded} =
        if bet > 0 do
          {f, e} =
            Enum.reduce(accepters, {[], []}, fn id, {ok, ko} ->
              case debit_rematch_bet(id, bet, match_id) do
                :ok -> {[id | ok], ko}
                {:error, _} -> {ok, [id | ko]}
              end
            end)

          # Reduce prépend : restaurer l'ordre déterministe (trié)
          {Enum.reverse(f), Enum.reverse(e)}
        else
          {accepters, []}
        end

      if length(funded) < 2 do
        # Rembourse les débits effectués (meilleur effort)
        Enum.each(funded, fn id -> refund_rematch_bet(id, bet, match_id) end)
        {:error, :not_enough_players}
      else
        config = %{
          game_type: match.game_type,
          rule_type: match.rule_type,
          mode: match.mode,
          sets_count: match.sets_count,
          dice_count: match.dice_count,
          bet_amount: bet,
          max_players: length(funded),
          creator_id: lobby.proposed_by
        }

        case create_rematch_match(table, config, funded, names) do
          {:ok, new_match} ->
            started_lobby =
              Map.merge(lobby, %{started: true, new_match_id: new_match.match_id, notice: nil})
            updated = Map.put(match, :rematch, started_lobby) |> Map.put(:updated_at, DateTime.utc_now())
            :ets.insert(table, {match_id, updated})
            Logger.info("Match #{match_id}: revanche démarrée → #{new_match.match_id} (#{length(funded)} joueurs)")
            broadcast_rematch_ready(match_id, updated, new_match, excluded)
            {:ok, new_match, excluded, updated}

          {:error, reason} ->
            Enum.each(funded, fn id -> refund_rematch_bet(id, bet, match_id) end)
            {:error, reason}
        end
      end
    end
  end

  # Démarrage automatique quand TOUS les invités ont accepté (ex : deux
  # joueurs appuient simultanément sur Revanche). Zéro tap supplémentaire.
  # Retourne {match_à_jour, a_démarré?}.
  defp maybe_auto_start(table, match_id, match) do
    case Map.get(match, :rematch) do
      %{started: false} = lobby ->
        invited = rematch_invited(match)
        accepters = rematch_accepters(match, lobby)

        if length(invited) >= 2 and length(accepters) >= length(invited) do
          case do_start_rematch(table, match_id, match, lobby) do
            {:ok, _new_match, _excluded, updated} ->
              {updated, true}

            {:error, _reason} ->
              # Ex : jetons insuffisants → on garde le lobby, avec notice
              # persistante (effacée à la prochaine réponse/proposition).
              noticed = Map.put(lobby, :notice, "Démarrage auto impossible : jetons insuffisants")
              failed = Map.put(match, :rematch, noticed) |> Map.put(:updated_at, DateTime.utc_now())
              :ets.insert(table, {match_id, failed})
              broadcast_rematch(match_id, "rematch_updated", failed)
              {failed, false}
          end
        else
          broadcast_rematch(match_id, "rematch_updated", match)
          {match, false}
        end

      _ ->
        {match, false}
    end
  end

  # Vue lobby sérialisable : invités = joueurs n'ayant pas quitté l'interface.
  defp rematch_lobby_view(_match, nil), do: %{status: "none"}

  defp rematch_lobby_view(_match, %{started: true} = lobby) do
    %{
      status: "started",
      proposed_by: lobby.proposed_by,
      accepted: lobby.accepted |> MapSet.to_list() |> Enum.map(&to_string/1),
      new_match_id: lobby.new_match_id
    }
  end

  defp rematch_lobby_view(match, lobby) do
    %{
      status: "proposed",
      proposed_by: lobby.proposed_by,
      accepted: lobby.accepted |> MapSet.to_list() |> Enum.map(&to_string/1),
      declined: lobby.declined |> MapSet.to_list() |> Enum.map(&to_string/1),
      invited: rematch_invited(match),
      left: (Map.get(match, :left_players, MapSet.new()) || MapSet.new()) |> MapSet.to_list() |> Enum.map(&to_string/1),
      accepted_count: rematch_accepters(match, lobby) |> length(),
      proposed_at: lobby.proposed_at |> DateTime.to_iso8601(),
      notice: Map.get(lobby, :notice)
    }
  end

  defp debit_rematch_bet(player_id, bet_amount, match_id) do
    case Integer.parse(to_string(player_id)) do
      {int_id, _} ->
        # Jeu responsable : une revanche est une nouvelle mise (mêmes
        # limites qu'une partie rapide). Le joueur bloqué est exclu du
        # financement comme pour fonds insuffisants (remboursé ensuite).
        with :ok <- GameHub.ResponsibleGaming.check_before_bet(int_id, bet_amount),
             {:ok, _} <- GameHub.Wallet.place_bet(int_id, bet_amount, match_id, "rematch_debit_#{match_id}_#{player_id}") do
          :ok
        else
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :invalid_player}
    end
  rescue
    _ -> {:error, :debit_failed}
  end

  defp refund_rematch_bet(player_id, bet_amount, match_id) do
    case Integer.parse(to_string(player_id)) do
      {int_id, _} ->
        GameHub.Wallet.credit_winnings(int_id, bet_amount, match_id, "rematch_refund_#{match_id}_#{player_id}")
        :ok

      :error ->
        :ok
    end
  rescue
    _ -> :ok
  end

  # Crée le match de revanche en interne (même GenServer → pas d'interblocage,
  # logique dupliquée de do_start_set_internal/start sans GenServer.call).
  defp create_rematch_match(table, config, player_ids, names) do
    game_type = Map.get(config, :game_type, "dice") || "dice"
    rule_type = Map.get(config, :rule_type, "normal") || "normal"
    match_id = generate_match_id(game_type)
    rules = GameRules.get_rules_or_default(game_type, rule_type)
    rc = rules.config
    sets_count = Map.get(config, :sets_count) || rc["default_sets"] || 1
    max_players = Map.get(config, :max_players) || length(player_ids)

    base = %{
      match_id: match_id,
      game_type: game_type,
      rule_type: rule_type,
      mode: Map.get(config, :mode, :free),
      status: :waiting_players,
      sets_count: sets_count,
      sets_to_win: div(sets_count, 2) + 1,
      dice_count: Map.get(config, :dice_count) || rc["default_dice"] || 2,
      dice_faces: rc["dice_faces"] || 6,
      bet_amount: Map.get(config, :bet_amount, 0),
      max_players: max_players,
      creator_id: Map.get(config, :creator_id) |> to_string(),
      players: [],
      current_set: 0,
      sets: [],
      set_scores: %{},
      current_set_state: nil,
      eliminated_players: MapSet.new(),
      forfeited_players: [],
      rematch: nil,
      left_players: MapSet.new(),
      turn_timeout_ms: get_turn_timeout_ms(game_type),
      turn_deadline: nil,
      tie_rule: rc["tie_rule"] || "replay",
      turn_order: rc["turn_order"] || "rotating",
      target_vote_mode: rc["target_vote_mode"] || "average",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # Ajout direct des joueurs (sans vérification waiting/full : match neuf fermé)
    with_players =
      Enum.reduce(player_ids, base, fn pid, acc ->
        id = to_string(pid)

        player = %{id: id, name: Map.get(names, id, "Joueur_#{String.slice(id, 0..3)}"), joined_at: DateTime.utc_now()}

        %{acc | players: acc.players ++ [player], set_scores: Map.put(acc.set_scores, id, 0)}
      end)

    ready = %{with_players | status: :ready, updated_at: DateTime.utc_now()}

    case do_start_set_internal(table, ready) do
      {:ok, started} ->
        :ets.insert(table, {match_id, started})
        Logger.info("Match #{match_id} created (revanche, #{length(player_ids)} joueurs)")
        first = started.current_set_state.turn_order |> List.first()
        if first, do: schedule_turn_timeout(match_id, first, turn_timeout_ms(started))
        broadcast_set_started(match_id, started)
        {:ok, started}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Gains nets du vainqueur (brut − commission), nil si non applicable.
  defp payout_summary(match) do
    bet = Map.get(match, :bet_amount, 0) || 0
    winner = Map.get(match, :winner_id)

    if match.status == :match_ended and bet > 0 and not is_nil(winner) do
      n = length(Map.get(match, :players, []))
      gross = bet * n

      rate =
        try do
          rules = GameRules.get_rules_or_default(match.game_type, match.rule_type || "normal")
          (rules.config["commission_rate"] || 0.05) |> to_string() |> Decimal.new() |> Decimal.to_float()
        rescue
          _ -> 0.05
        end

      commission = trunc(gross * rate)

      %{gross: gross, commission: commission, net: gross - commission, winner_id: to_string(winner)}
    else
      nil
    end
  rescue
    _ -> nil
  end

  # Détail des sets sérialisable (scores + dés par joueur depuis les lancers).
  defp sanitize_set(set) when is_map(set) do
    rolls = Map.get(set, :rolls, %{}) || %{}

    {sums, dice} =
      Enum.reduce(rolls, {%{}, %{}}, fn {pid, roll}, {sums, dice} ->
        key = to_string(pid)

        {sum, faces} =
          case roll do
            %{sum: s, dice: d} when is_integer(s) and is_list(d) -> {s, d}
            %{"sum" => s, "dice" => d} when is_integer(s) and is_list(d) -> {s, d}
            %{sum: s} when is_integer(s) -> {s, []}
            %{dice: d} when is_list(d) -> {Enum.sum(d), d}
            %{"dice" => d} when is_list(d) -> {Enum.sum(d), d}
            _ -> {0, []}
          end

        {Map.put(sums, key, sum), Map.put(dice, key, faces)}
      end)

    {winner_id, result} =
      case Map.get(set, :winner_id) do
        nil ->
          case Map.get(set, :result) do
            {:winner, id} -> {to_string(id), "winner"}
            :tie -> {nil, "tie"}
            _ -> {nil, "tie"}
          end

        id ->
          {to_string(id), "winner"}
      end

    %{
      set_number: Map.get(set, :set_number),
      winner_id: winner_id,
      result: result,
      sums: sums,
      dice: dice,
      target_value: Map.get(set, :target_value)
    }
  end

  defp generate_match_id(game_type) do
    "#{game_type}_match_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp schedule_turn_timeout(match_id, player_id, timeout_ms) do
    Process.send_after(self(), {:turn_timeout, match_id, player_id}, timeout_ms)
  end

  defp schedule_auto_next_set(match_id, delay_ms) do
    Process.send_after(self(), {:auto_next_set, match_id}, delay_ms)
  end

  # Logique interne pour démarrer un set (réutilisable par handle_call et auto_next_set)
  defp do_start_set_internal(_table, match) do
    # Vérifier qu'on peut démarrer
    if match.status not in [:ready, :set_ended] do
      {:error, :cannot_start_set}
    else
      if match.status == :set_in_progress and not is_nil(match.current_set_state) and match.current_set_state.status == :in_progress do
        {:error, :set_already_in_progress}
      else
        set_number = match.current_set + 1
        turn_order = determine_turn_order(match, set_number)
        turn_order = Enum.reject(turn_order, fn pid -> eliminated?(match, pid) end)
        if length(turn_order) < 2 do
          winner_id = List.first(turn_order)
          ended = Map.merge(match, %{status: :match_ended, winner_id: winner_id, updated_at: DateTime.utc_now()})
          {:ok, ended}
        else
          set_state = %{
            set_number: set_number,
            status: :in_progress,
            turn_order: turn_order,
            current_turn_index: 0,
            rolls: %{},
            target_value: nil,
            votes: %{},
            vote_phase: match.rule_type == "cible",
            started_at: DateTime.utc_now(),
            turn_deadline: DateTime.add(DateTime.utc_now(), div(turn_timeout_ms(match), 1000), :second)
          }
          updated = %{match |
            status: :set_in_progress,
            current_set: set_number,
            current_set_state: set_state,
            turn_deadline: set_state.turn_deadline,
            updated_at: DateTime.utc_now()
          }
          {:ok, updated}
        end
      end
    end
  end

  defp get_turn_timeout_ms(game_type) do
    # Essaie GameTimeoutConfig (grace_period) sinon fallback 30s
    try do
      case GameHub.Repo.get_by(GameHub.Games.GameTimeoutConfig, game_type: game_type, is_active: true) do
        %{grace_period_seconds: secs} when is_integer(secs) and secs > 0 -> secs * 1000
        _ -> @turn_timeout_default
      end
    rescue
      _ -> @turn_timeout_default
    end
  end

  defp get_turn_timeout(game_type), do: div(get_turn_timeout_ms(game_type), 1000)

  # Applique le résultat du set aux scores globaux
  defp apply_set_result(match, result, rolls, set_number, target_value) do
    scores = match.set_scores
    sets = match.sets

    case result do
      {:winner, winner_id} ->
        new_scores = Map.update(scores, winner_id, 1, &(&1 + 1))
        new_sets = sets ++ [%{set_number: set_number, winner_id: winner_id, rolls: rolls, target_value: target_value, result: :winner}]
        {new_scores, new_sets, :set_ended}

      :tie ->
        new_sets = sets ++ [%{set_number: set_number, winner_id: nil, rolls: rolls, target_value: target_value, result: :tie}]
        {scores, new_sets, :set_ended}
    end
  end

  defp has_match_winner?(scores, sets_to_win) do
    Enum.any?(scores, fn {_pid, wins} -> wins >= sets_to_win end)
  end

  defp get_match_winner(scores, sets_to_win) do
    scores
    |> Enum.find(fn {_pid, wins} -> wins >= sets_to_win end)
    |> case do
      {pid, _} -> pid
      nil -> nil
    end
  end

  defp get_winner_by_max(scores) do
    case scores |> Enum.sort_by(fn {_pid, wins} -> -wins end) do
      [] -> nil
      [{winner_id, max} | rest] ->
        # Vérifier qu'il n'y a pas d'égalité au max (match nul)
        if Enum.any?(rest, fn {_pid, w} -> w == max end), do: nil, else: winner_id
      _ -> nil
    end
  end

  defp persist_match_result(match) do
    try do
      player_ids = Enum.map(match.players, fn p -> p.id end)
      winner_id = Map.get(match, :winner_id)
      # Normaliser winner_id en int si possible
      winner_int = case winner_id do
        nil -> nil
        v when is_integer(v) -> v
        v when is_binary(v) -> case Integer.parse(v) do {i,_} -> i; :error -> nil end
        _ -> nil
      end
      bets = Map.new(player_ids, fn pid -> {pid, match.bet_amount || 0} end)
      # Calcul commission si staked
      net_winnings = if winner_int && match.bet_amount > 0 do
        total_pot = match.bet_amount * length(player_ids)
        # Commission depuis GameRules (défaut 5%)
        commission_rate = try do
          rules = GameHub.GameRules.get_rules_or_default(match.game_type, match.rule_type || "normal")
          (rules.config["commission_rate"] || 0.05) |> to_string() |> Decimal.new() |> Decimal.to_float()
        rescue _ -> 0.05 end
        commission = trunc(total_pot * commission_rate)
        total_pot - commission
      else
        0
      end
      GameHub.GameStats.record_match_result(%{
        game_type: match.game_type || "dice",
        winner_id: winner_int,
        player_ids: player_ids,
        bets: bets,
        net_winnings: net_winnings
      })
      # Audit dice results pour 10 ans (chaque set)
      Enum.each(match.sets, fn set ->
        if set.rolls do
          Enum.each(set.rolls, fn {_pid, roll} ->
            try do
              %GameHub.DiceGame.DiceGameResult{}
              |> GameHub.DiceGame.DiceGameResult.create_changeset(%{
                game_id: match.match_id,
                dice_results: roll.dice,
                total_sum: roll.sum,
                dice_count: match.dice_count,
                dice_type: 6,
                player_ids: player_ids |> Enum.map(fn id -> case Integer.parse(to_string(id)) do {i,_} -> i; :error -> 0 end end),
                winner_id: winner_int,
                bets: bets,
                payouts: %{},
                commission_amount: 0
              })
              |> GameHub.Repo.insert()
            rescue _ -> :ok end
          end)
        end
      end)
    rescue e -> require Logger; Logger.error("persist_match_result failed: #{inspect(e)}") end
    :ok
  end

  # === Broadcasts ===
  # Source unique temps réel : chaque mutation émet un event PubSub avec `seq`
  # monotone pour ordonner côté client et ignorer les doublons/stales.
  defp next_seq, do: System.unique_integer([:positive, :monotonic])

  defp broadcast_set_started(match_id, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "set_started", match_id: match_id, seq: next_seq(), set: match.current_set_state, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_dice_rolled(match_id, roll, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "dice_rolled", match_id: match_id, seq: next_seq(), roll: sanitize_roll(roll), match: sanitize_match(match)})
  rescue _ -> :ok
  end

  # Phase 1 du lancer : notifie TOUS les joueurs que `roller_id` lance les dés.
  # Les clients démarrent la même animation ensemble, puis révèlent le final
  # à la réception de `dice_rolled` (reveal synchronisé après durée min).
  defp broadcast_dice_rolling(match_id, roller_id, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "dice_rolling", match_id: match_id, seq: next_seq(), roller_id: to_string(roller_id), dice_count: Map.get(match, :dice_count, 2), match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_turn_changed(match_id, match) do
    set = match.current_set_state
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{
      event: "turn_changed",
      match_id: match_id,
      seq: next_seq(),
      current_player_id: Enum.at(set.turn_order, set.current_turn_index),
      current_turn_index: set.current_turn_index,
      turn_order: set.turn_order,
      turn_deadline: set.turn_deadline,
      match: sanitize_match(match)
    })
  rescue _ -> :ok
  end

  defp broadcast_set_result(match_id, match, result) do
    encoded = case result do {:winner, id} -> %{winner_id: id, result: "winner"}; :tie -> %{result: "tie"}; other -> %{result: inspect(other)} end
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "set_result", match_id: match_id, seq: next_seq(), result: encoded, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_match_result(match_id, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "match_result", match_id: match_id, seq: next_seq(), winner_id: match[:winner_id], match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_player_forfeited(match_id, player_id, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "player_forfeited", match_id: match_id, seq: next_seq(), player_id: player_id, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_match_forfeit(match_id, _player_id, winner_id) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "match_forfeit", match_id: match_id, seq: next_seq(), winner_id: winner_id})
  rescue _ -> :ok
  end

  defp broadcast_target_calculated(match_id, target, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "target_calculated", match_id: match_id, seq: next_seq(), target_value: target, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_target_voted(match_id, player_id, target_value, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "target_voted", match_id: match_id, seq: next_seq(), player_id: to_string(player_id), target_value: target_value, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_vote_progress(match_id, votes_count, total_needed, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "vote_progress", match_id: match_id, seq: next_seq(), votes_count: votes_count, total_needed: total_needed, match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_rematch(match_id, event, match) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: event, match_id: match_id, seq: next_seq(), lobby: rematch_lobby_view(match, Map.get(match, :rematch)), match: sanitize_match(match)})
  rescue _ -> :ok
  end

  defp broadcast_rematch_ready(match_id, match, new_match, excluded) do
    Phoenix.PubSub.broadcast(GameHub.PubSub, "game:#{match_id}", %{event: "rematch_ready", match_id: match_id, seq: next_seq(), lobby: rematch_lobby_view(match, Map.get(match, :rematch)), new_match_id: new_match.match_id, match: sanitize_match(new_match), excluded: Enum.map(excluded, &to_string/1)})
  rescue _ -> :ok
  end

  defp sanitize_match(match) do
    css = Map.get(match, :current_set_state)
    sanitized_css = case css do
      nil -> nil
      m when is_map(m) ->
        # Convertir tuple result en map JSON
        base = Map.update(m, :result, nil, fn
          {:winner, id} -> %{winner_id: id, result: "winner"}
          :tie -> %{result: "tie"}
          other -> other
        end)
        |> Map.update(:result, nil, fn v -> v end)
        |> (fn mm ->
          case Map.get(mm, :result) do
            {:winner, id} -> Map.put(mm, :result, %{winner_id: id, result: "winner"})
            :tie -> Map.put(mm, :result, %{result: "tie"})
            _ -> mm
          end
        end).()
        # Sanitizer les rolls (rolled_at DateTime → ISO8601) pour JSON déterministe
        with_rolls = try do
          case Map.get(base, :rolls) do
            rolls when is_map(rolls) ->
              Map.put(base, :rolls, Map.new(rolls, fn {k, v} -> {to_string(k), sanitize_roll(v)} end))
            _ -> base
          end
        rescue _ -> base end
        # Ajouter remaining calculé côté serveur pour éviter dérive horloge client
        remaining = case Map.get(base, :turn_deadline) do
          %DateTime{} = dl ->
            try do
              max(0, DateTime.diff(dl, DateTime.utc_now(), :second))
            rescue _ -> nil end
          _ -> nil
        end
        Map.put(with_rolls, :turn_remaining_seconds, remaining)
      other -> other
    end
    {last_roller_id, last_roll} = latest_roll(match)
    sets = try do
      match.sets |> Enum.map(&sanitize_set/1)
    rescue
      _ -> []
    end
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
      sets: sets,
      payout: payout_summary(match),
      rematch: rematch_lobby_view(match, Map.get(match, :rematch)),
      left_players: (Map.get(match, :left_players, MapSet.new()) || MapSet.new()) |> MapSet.to_list() |> Enum.map(&to_string/1),
      current_set_state: sanitized_css,
      eliminated_players: MapSet.to_list(match.eliminated_players || MapSet.new()),
      winner_id: Map.get(match, :winner_id),
      turn_timeout_ms: turn_timeout_ms(match),
      last_roller_id: last_roller_id,
      last_roll: last_roll,
      players: Enum.map(Map.get(match, :players, []), fn p -> %{id: to_string(p.id), name: Map.get(p, :name, "Joueur")} end)
    }
  rescue
    _ -> %{match_id: match.match_id, status: to_string(match.status)}
  end

  # Roll sérialisable JSON : rolled_at → ISO8601, player_id → string.
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
    sanitize_roll(%{player_id: pid, dice: List.wrap(dice), sum: sum, rolled_at: Map.get(other, :rolled_at) || Map.get(other, "rolled_at")})
  rescue _ -> %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}
  end
  defp sanitize_roll(_), do: %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}

  # Dernier lancer du set courant (le plus récent par rolled_at).
  # Évite que le client devine via l'ordre d'itération de la map (non déterministe).
  defp latest_roll(match) do
    rolls = match |> Map.get(:current_set_state, %{}) |> then(fn
      nil -> %{}
      css when is_map(css) -> Map.get(css, :rolls, %{}) || %{}
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
end
