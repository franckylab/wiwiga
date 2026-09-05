# ==================================
# WIWIGA - Module GameRoom (GenServer)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameRoom
# Description: Gestion des salles de jeu (Free + Betting)

defmodule GameHub.GameRoom do
  @moduledoc """
  GenServer gérant les salles de jeu en attente — migration brutale 2026-08-30.

  ## Concepts
  - **Partie sans mise (gratuit)** (`:free`) : créée par un joueur, partageable par code ou invitation ami, sans enjeu en jetons.
  - **Partie avec mise** (`:staked`) : créée avec mise fixe, démarrage manuel si 2 joueurs, enjeu en jetons. `betting` supprimé.

  ## State Machine Room
      :waiting → :starting → :in_progress → :ended
                        ↘ :cancelled (timeout ou départ créateur)
  """

  use GenServer
  require Logger

  alias GameHub.{GameMatch, GameRules, GameMode}
  alias GameHub.ResponsibleGaming

  @table :game_rooms
  @cleanup_interval_ms 60_000
  @room_ttl_seconds 1800  # 30 min max par room

  # === Client API ===

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Crée une nouvelle salle de jeu — migration brutale (betting supprimé).

  ## Parameters
    - `params`: %{
        creator_id: string,
        creator_name: string,
        game_type: "dice",
        rule_type: "normal" | "cible",
        mode: :free | :staked,
        bet_amount: integer (0 si Partie sans mise),
        sets_count: integer,
        dice_count: integer,
        max_players: integer
      }

  ## Modes
    - `:free`   → Partie sans mise (gratuit)
    - `:staked` → Partie avec mise

  ## Returns
    - `{:ok, room}` | `{:error, :invalid_mode}` si mode hors free/staked
    - `{:error, :already_has_waiting_room, existing_room}` si un salon en attente existe déjà
    - `{:error, :already_in_active_match, existing_room}` si déjà en partie en cours
  """
  def create_room(params) do
    GenServer.call(__MODULE__, {:create_room, params})
  end

  @doc """
  Récupère la salle en attente du joueur (si une seule autorisée).
  """
  def get_waiting_room_for_player(player_id) do
    GenServer.call(__MODULE__, {:get_waiting_for_player, player_id})
  end

  @doc """
  Récupère la salle active (waiting ou in_progress) du joueur.
  """
  def get_active_room_for_player(player_id) do
    GenServer.call(__MODULE__, {:get_active_for_player, player_id})
  end

  @doc """
  Rejoint une salle par ID.
  """
  def join_room(room_id, player_id, player_name \\ nil) do
    GenServer.call(__MODULE__, {:join_room, room_id, player_id, player_name})
  end

  @doc """
  Rejoint une salle par code (ex: "WIWIGA-7X3K").
  """
  def join_by_code(code, player_id, player_name \\ nil) do
    GenServer.call(__MODULE__, {:join_by_code, code, player_id, player_name})
  end

  @doc """
  Quitte une salle.
  """
  def leave_room(room_id, player_id) do
    GenServer.call(__MODULE__, {:leave_room, room_id, player_id})
  end

  @doc """
  Démarre le match dans la salle (créateur uniquement, mode Partie avec mise).
  """
  def start_match(room_id, player_id) do
    GenServer.call(__MODULE__, {:start_match, room_id, player_id})
  end

  @doc """
  Récupère l'état d'une salle.
  """
  def get_room(room_id) do
    GenServer.call(__MODULE__, {:get_room, room_id})
  end

  @doc """
  Recherche une salle par code.
  """
  def get_room_by_code(code) do
    GenServer.call(__MODULE__, {:get_room_by_code, code})
  end

  @doc """
  Liste les salles en attente (pour matchmaking/lobby).
  """
  def list_waiting_rooms(game_type \\ nil, mode \\ nil) do
    GenServer.call(__MODULE__, {:list_waiting, game_type, mode})
  end

  @doc """
  Supprime une salle (créateur ou admin).
  """
  def cancel_room(room_id, player_id) do
    GenServer.call(__MODULE__, {:cancel_room, room_id, player_id})
  end

  # === Server Callbacks ===

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:create_room, params}, _from, state) do
    creator_id = Map.get(params, :creator_id)

    # Vérifier qu'un joueur n'a qu'un seul salon en attente / actif
    case find_active_room_for_player(state.table, creator_id) do
      {:ok, existing} when existing.status == :waiting ->
        {:reply, {:error, :already_has_waiting_room, existing}, state}

      {:ok, existing} when existing.status in [:in_progress, :starting] ->
        {:reply, {:error, :already_in_active_match, existing}, state}

      _ ->
        room_id = generate_room_id()
        room_code = generate_room_code()

        # Charger les règles pour valider la config (robuste aux clés manquantes)
        rule_type = Map.get(params, :rule_type, "normal") || "normal"
        game_type = Map.get(params, :game_type, "dice") || "dice"
        rules = GameRules.get_rules_or_default(game_type, rule_type)
        rc = rules.config

        # Migration brutale 2026-08-30: seuls :free (Partie sans mise) et :staked (Partie avec mise) valides — "betting" supprimé
        raw_mode = Map.get(params, :mode, :free)
        canonical_mode = case GameMode.parse_strict(to_string(raw_mode)) do
          {:ok, m} -> m
          {:error, _} -> nil
        end

        if is_nil(canonical_mode) do
          {:reply, {:error, :invalid_mode}, state}
        else

        # Nombre de sets : source unique GameRules.resolve_sets_count/3.
        # - Mode fixe : valeur client (bornée) ou défaut.
        # - Mode aléatoire : tirage serveur unique, valeur client ignorée
        #   (équité : le créateur ne choisit pas). Figé dans la salle.
        {:ok, sets_count, sets_mode} =
          GameHub.GameRules.resolve_sets_count(game_type, rule_type, Map.get(params, :sets_count))

        dice_count = Map.get(params, :dice_count) || rc["default_dice"] || 2
        max_players = Map.get(params, :max_players) || rc["max_players"] || 2
        bet_amount = if canonical_mode == :staked, do: (Map.get(params, :bet_amount) || 0), else: 0

        creator_name = Map.get(params, :creator_name, "Créateur") || "Créateur"

        room = %{
          room_id: room_id,
          room_code: room_code,
          creator_id: creator_id,
          game_type: game_type,
          rule_type: rule_type,
          mode: canonical_mode,
          status: :waiting,
          bet_amount: bet_amount,
          sets_count: sets_count,
          sets_mode: sets_mode,
          dice_count: dice_count,
          max_players: max_players,
          players: [
            %{
              id: creator_id,
              name: creator_name,
              joined_at: DateTime.utc_now()
            }
          ],
          match_id: nil,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          expires_at: DateTime.add(DateTime.utc_now(), @room_ttl_seconds)
        }

        :ets.insert(state.table, {room_id, room})
        # Index par code pour recherche rapide
        :ets.insert(state.table, {{:code, room_code}, room_id})

        Logger.info("Room #{room_id} created by #{creator_id} (code: #{room_code}, mode: #{room.mode})")

        {:reply, {:ok, room}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_waiting_for_player, player_id}, _from, state) do
    {:reply, find_waiting_room_for_player(state.table, player_id), state}
  end

  @impl true
  def handle_call({:get_active_for_player, player_id}, _from, state) do
    {:reply, find_active_room_for_player(state.table, player_id), state}
  end

  @impl true
  def handle_call({:join_room, room_id, player_id, player_name}, _from, state) do
    # Empêche un joueur déjà dans un salon actif de rejoindre un autre salon
    case find_active_room_for_player(state.table, player_id) do
      {:ok, existing} when existing.room_id != room_id and existing.status in [:waiting, :in_progress, :starting] ->
        {:reply, {:error, :already_in_active_match, existing}, state}

      _ ->
        case lookup_room(state.table, room_id) do
          {:ok, room} ->
            cond do
              room.status != :waiting ->
                {:reply, {:error, :room_not_waiting}, state}

              length(room.players) >= room.max_players ->
                {:reply, {:error, :room_full}, state}

              Enum.any?(room.players, fn p -> p.id == player_id end) ->
                {:reply, {:error, :already_in_room}, state}

              true ->
                player = %{
                  id: player_id,
                  name: player_name || "Joueur_#{String.slice(to_string(player_id), 0..3)}",
                  joined_at: DateTime.utc_now()
                }

                updated = %{room |
                  players: room.players ++ [player],
                  updated_at: DateTime.utc_now()
                }

                :ets.insert(state.table, {room_id, updated})
                Logger.info("Player #{player_id} joined room #{room_id}")

                # Tracker session de jeu pour Responsible Gaming
                try do
                  if is_integer(player_id), do: ResponsibleGaming.start_session(player_id)
                rescue
                  _ -> :ok
                end

                # Notifier via PubSub
                broadcast_room_update(room_id, updated)

                # Auto-start si la room est pleine — tous les joueurs présents → démarrage immédiat
                if length(updated.players) >= updated.max_players do
                  case do_auto_start_match(state.table, updated) do
                    {:ok, auto_room} ->
                      {:reply, {:ok, auto_room}, state}
                    {:error, _reason} ->
                      {:reply, {:ok, updated}, state}
                  end
                else
                  {:reply, {:ok, updated}, state}
                end
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:join_by_code, code, player_id, player_name}, _from, state) do
    normalized_code = String.upcase(String.trim(code))

    case :ets.lookup(state.table, {:code, normalized_code}) do
      [{_, room_id}] ->
        # Délègue à join_room
        handle_call({:join_room, room_id, player_id, player_name}, nil, state)

      [] ->
        {:reply, {:error, :room_not_found}, state}
    end
  end

  @impl true
  def handle_call({:leave_room, room_id, player_id}, _from, state) do
    case lookup_room(state.table, room_id) do
      {:ok, room} ->
        if room.status in [:waiting] do
          updated_players = Enum.reject(room.players, fn p -> p.id == player_id end)

          # Fin session Responsible Gaming
          try do
            if is_integer(player_id), do: ResponsibleGaming.end_session(player_id)
          rescue
            _ -> :ok
          end

          # Si le créateur part → annuler la room
          if player_id == room.creator_id do
            :ets.delete(state.table, room_id)
            :ets.delete(state.table, {:code, room.room_code})
            Logger.info("Room #{room_id} cancelled (creator left)")
            broadcast_room_update(room_id, %{room | status: :cancelled, players: updated_players})
            {:reply, {:ok, :room_cancelled}, state}
          else
            updated = %{room |
              players: updated_players,
              updated_at: DateTime.utc_now()
            }

            :ets.insert(state.table, {room_id, updated})
            broadcast_room_update(room_id, updated)
            {:reply, {:ok, updated}, state}
          end
        else
          {:reply, {:error, :room_in_progress}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:start_match, room_id, player_id}, _from, state) do
    case lookup_room(state.table, room_id) do
      {:ok, room} ->
        cond do
          room.creator_id != player_id ->
            {:reply, {:error, :not_creator}, state}

          room.status != :waiting ->
            {:reply, {:error, :room_not_waiting}, state}

          length(room.players) < 2 ->
            {:reply, {:error, :not_enough_players}, state}

          true ->
            # Créer le match via GameMatch
            match_config = %{
              game_type: room.game_type,
              rule_type: room.rule_type,
              mode: room.mode,
              sets_count: room.sets_count,
              dice_count: room.dice_count,
              bet_amount: room.bet_amount,
              max_players: room.max_players,
              creator_id: room.creator_id
            }

            case GameMatch.create_match(match_config) do
              {:ok, match} ->
                # Ajouter tous les joueurs au match
                Enum.reduce(room.players, match, fn player, acc ->
                  {:ok, updated_match} = GameMatch.add_player(acc.match_id, player.id, player.name)
                  updated_match
                end)

                # Passage par états : waiting -> ready -> set_in_progress (synchrone)
                case GameMatch.start_match(match.match_id) do
                  {:ok, _} -> :ok
                  _ -> :ok
                end

                case GameMatch.start_set(match.match_id) do
                  {:ok, _} -> :ok
                  {:error, reason} -> Logger.warning("start_set failed for manual start #{match.match_id}: #{inspect(reason)}")
                end

                # Mettre à jour la room
                updated = %{room |
                  status: :in_progress,
                  match_id: match.match_id,
                  updated_at: DateTime.utc_now()
                }

                :ets.insert(state.table, {room_id, updated})
                Logger.info("Room #{room_id}: match #{match.match_id} started (manual, #{length(room.players)} joueurs)")

                broadcast_room_update(room_id, updated)
                broadcast_match_started(room_id, match.match_id)

                {:reply, {:ok, %{room: updated, match: match}}, state}

              {:error, reason} ->
                {:reply, {:error, {:match_creation_failed, reason}}, state}
            end
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_room, room_id}, _from, state) do
    {:reply, lookup_room(state.table, room_id), state}
  end

  @impl true
  def handle_call({:get_room_by_code, code}, _from, state) do
    normalized = String.upcase(String.trim(code))

    case :ets.lookup(state.table, {:code, normalized}) do
      [{_, room_id}] ->
        {:reply, lookup_room(state.table, room_id), state}

      [] ->
        {:reply, {:error, :room_not_found}, state}
    end
  end

  @impl true
  def handle_call({:list_waiting, game_type, mode}, _from, state) do
    # Migration brutale: seuls free/staked valides — betting rejeté (retour liste vide si filtre invalide)
    canonical_filter =
      case mode do
        nil -> nil
        _ ->
          case GameMode.parse_strict(to_string(mode)) do
            {:ok, m} -> m
            {:error, _} -> :invalid
          end
      end

    # Si filtre invalide (dont betting), retourner liste vide (le controller renvoie déjà 400, mais sécurité GenServer)
    if canonical_filter == :invalid do
      {:reply, [], state}
    else

    rooms = :ets.tab2list(state.table)
    |> Enum.filter(fn
      {{:code, _}, _} -> false
      {_, room} -> room.status == :waiting
    end)
    |> Enum.map(fn {_id, room} -> room end)
    |> then(fn rooms ->
      if game_type do
        Enum.filter(rooms, fn r -> r.game_type == game_type end)
      else
        rooms
      end
    end)
    |> then(fn rooms ->
      if canonical_filter do
        Enum.filter(rooms, fn r ->
          case GameMode.parse_strict(to_string(r.mode)) do
            {:ok, m} -> m == canonical_filter
            _ -> false
          end
        end)
      else
        rooms
      end
    end)
    |> Enum.sort_by(fn r -> r.created_at end, {:desc, DateTime})

    {:reply, rooms, state}
    end
  end

  @impl true
  def handle_call({:cancel_room, room_id, player_id}, _from, state) do
    case lookup_room(state.table, room_id) do
      {:ok, room} ->
        if room.creator_id == player_id and room.status == :waiting do
          :ets.delete(state.table, room_id)
          :ets.delete(state.table, {:code, room.room_code})
          broadcast_room_update(room_id, %{room | status: :cancelled})
          {:reply, {:ok, :room_cancelled}, state}
        else
          {:reply, {:error, :cannot_cancel}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()

    :ets.tab2list(state.table)
    |> Enum.each(fn
      {{:code, _}, _} -> :ok
      {room_id, room} ->
        if DateTime.compare(room.expires_at, now) == :lt do
          :ets.delete(state.table, room_id)
          :ets.delete(state.table, {:code, room.room_code})
        end
    end)

    schedule_cleanup()
    {:noreply, state}
  end

  # === Fonctions Privées ===

  defp lookup_room(table, room_id) do
    case :ets.lookup(table, room_id) do
      [{^room_id, room}] -> {:ok, room}
      [] -> {:error, :room_not_found}
    end
  end

  # Trouve une salle en attente pour un joueur (une seule autorisée)
  defp find_waiting_room_for_player(table, player_id) do
    :ets.tab2list(table)
    |> Enum.find_value(fn
      {{:code, _}, _} -> nil
      {_id, room} when room.status == :waiting ->
        if Enum.any?(room.players, fn p -> p.id == player_id end), do: {:ok, room}, else: nil
      _ -> nil
    end) || {:error, :not_found}
  end

  defp find_active_room_for_player(table, player_id) do
    :ets.tab2list(table)
    |> Enum.find_value(fn
      {{:code, _}, _} -> nil
      {_id, room} when room.status in [:waiting, :starting, :in_progress] ->
        if Enum.any?(room.players, fn p -> p.id == player_id end), do: {:ok, room}, else: nil
      _ -> nil
    end) || {:error, :not_found}
  end

  # Auto-start interne (sans vérification créateur) — utilisé quand full
  defp do_auto_start_match(table, room) do
    if room.status != :waiting or length(room.players) < 2 do
      {:error, :not_enough_players}
    else
      match_config = %{
        game_type: room.game_type,
        rule_type: room.rule_type,
        mode: room.mode,
        sets_count: room.sets_count,
        dice_count: room.dice_count,
        bet_amount: room.bet_amount,
        max_players: room.max_players,
        creator_id: room.creator_id
      }

      case GameMatch.create_match(match_config) do
        {:ok, match} ->
          Enum.reduce(room.players, match, fn player, acc ->
            {:ok, updated_match} = GameMatch.add_player(acc.match_id, player.id, player.name)
            updated_match
          end)
          # Démarre le match (ready)
          case GameMatch.start_match(match.match_id) do
            {:ok, _} -> :ok
            _ -> :ok
          end
          # Démarre le premier set
          case GameMatch.start_set(match.match_id) do
            {:ok, _} -> :ok
            _ -> :ok
          end

          updated = %{room |
            status: :in_progress,
            match_id: match.match_id,
            updated_at: DateTime.utc_now()
          }

          :ets.insert(table, {room.room_id, updated})
          Logger.info("Room #{room.room_id}: auto-started match #{match.match_id} (full #{length(room.players)}/#{room.max_players})")
          broadcast_room_update(room.room_id, updated)
          # Broadcast match_started explicite pour le salon
          broadcast_match_started(room.room_id, match.match_id)
          {:ok, updated}

        {:error, reason} ->
          Logger.error("Auto-start failed for room #{room.room_id}: #{inspect(reason)}")
          {:error, {:match_creation_failed, reason}}
      end
    end
  end

  defp broadcast_match_started(room_id, match_id) do
    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "room:#{room_id}",
      %{event: "match_started", room_id: room_id, match_id: match_id}
    )
  rescue
    _ -> :ok
  end

  defp generate_room_id do
    "room_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end

  @doc """
  Génère un code de salle unique (format: WIWIGA-XXXX).
  """
  def generate_room_code do
    chars = ~w(A B C D E F G H J K L M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9)
    code = for _ <- 1..4, into: "", do: Enum.random(chars)
    "WIWIGA-#{code}"
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp broadcast_room_update(room_id, room) do
    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "room:#{room_id}",
      %{event: "room_updated", room: sanitize_room_for_broadcast(room)}
    )
  rescue
    _ -> :ok
  end

  defp sanitize_room_for_broadcast(room) do
    canonical = GameMode.normalize(room.mode)
    %{
      room_id: room.room_id,
      room_code: room.room_code,
      creator_id: room.creator_id,
      game_type: room.game_type,
      rule_type: room.rule_type,
      mode: GameMode.to_string(canonical),
      mode_label: GameMode.display_label(canonical),
      mode_short: GameMode.short_label(canonical),
      status: room.status,
      bet_amount: room.bet_amount,
      sets_count: room.sets_count,
      sets_mode: Map.get(room, :sets_mode, "fixed"),
      dice_count: room.dice_count,
      max_players: room.max_players,
      players_count: length(room.players),
      players: Enum.map(room.players, fn p -> %{id: p.id, name: p.name} end),
      match_id: room.match_id
    }
  end
end
