# ==================================
# WIWIGA - Room Controller
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.RoomController
# Description: Endpoints REST pour gestion des salles de jeu

defmodule GameHubWeb.RoomController do
  @moduledoc """
  Controller REST pour les salles de jeu (Rooms).

  ## Endpoints
    POST   /api/rooms              - Créer une salle
    GET    /api/rooms/:room_id     - Détails salle
    POST   /api/rooms/:room_id/join   - Rejoindre salle
    POST   /api/rooms/:room_id/leave  - Quitter salle
    POST   /api/rooms/:room_id/start  - Démarrer match (créateur)
    POST   /api/rooms/:room_id/cancel - Annuler salle
    GET    /api/rooms/waiting      - Liste salles en attente
    POST   /api/rooms/join-by-code - Rejoindre par code
  """

  use GameHubWeb, :controller

  alias GameHub.{GameRoom, GameMode, Errors}

  @doc """
  POST /api/rooms
  Crée une nouvelle salle de jeu.
  """
  def create(conn, params) do
    user_id = get_current_user_id(conn)

    raw_mode = Map.get(params, "mode", "free")

    # Migration brutale: betting supprimé — parse strict sans fallback
    case GameMode.parse_strict(to_string(raw_mode)) do
      {:error, :invalid_mode} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Mode invalide: attendu free (Partie sans mise) ou staked (Partie avec mise) — betting supprimé", 400, "INVALID_MODE"))

      {:ok, canonical_mode} ->
        room_params = %{
          creator_id: user_id,
          creator_name: Map.get(params, "creator_name", "Joueur"),
          game_type: Map.get(params, "game_type", "dice"),
          rule_type: Map.get(params, "rule_type", "normal"),
          mode: canonical_mode,
          bet_amount: parse_int(Map.get(params, "bet_amount", 0)),
          sets_count: parse_int(Map.get(params, "sets_count")),
          dice_count: parse_int(Map.get(params, "dice_count")),
          max_players: parse_int(Map.get(params, "max_players"))
        }

        rg_gate = rg_gate_for_room(user_id, room_params)

        cond do
          GameMode.staked?(room_params.mode) and room_params.bet_amount <= 0 ->
            conn
            |> put_status(400)
            |> json(Errors.error("Mise requise pour le mode Partie avec mise", 400, "VALIDATION_ERROR"))

          # Jeu responsable : un joueur exclu/en pause/limite ne crée pas de
          # salle (avec mise : contrôle complet, sinon jouabilité).
          match?({:error, _}, rg_gate) ->
            {:error, reason} = rg_gate
            {message, details} = GameHub.ResponsibleGaming.block_message(reason, user_id, room_params.bet_amount || 0)
            conn
            |> put_status(403)
            |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))

          room_params.game_type not in ~w(dice) ->
            conn
            |> put_status(400)
            |> json(Errors.error("Type de jeu non supporté", 400, "INVALID_GAME_TYPE"))

          not valid_room_sets?(room_params) ->
            preview = GameHub.GameRules.sets_preview(room_params.game_type, room_params.rule_type)

            conn
            |> put_status(400)
            |> json(Errors.error("Nombre de sets invalide : attendu entre #{preview.min_sets} et #{preview.max_sets}", 400, "SETS_OUT_OF_RANGE"))

          true ->
            case GameRoom.create_room(room_params) do
              {:ok, room} ->
                conn
                |> put_status(201)
                |> json(%{
                  success: true,
                  data: format_room(room),
                  meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                })

              {:error, :invalid_mode} ->
                conn
                |> put_status(400)
                |> json(Errors.error("Mode invalide: betting supprimé — utiliser staked", 400, "INVALID_MODE"))

              {:error, :already_has_waiting_room, existing} ->
                conn
                |> put_status(200)
                |> json(%{
                  success: true,
                  data: format_room(existing),
                  meta: %{redirect: true, reason: "already_has_waiting_room", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()},
                  error: "Vous avez déjà une salle en attente — redirection vers la salle existante"
                })

              {:error, :already_in_active_match, existing} ->
                conn
                |> put_status(200)
                |> json(%{
                  success: true,
                  data: format_room(existing),
                  meta: %{redirect: true, reason: "already_in_active_match", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()},
                  error: "Vous êtes déjà en partie — redirection vers la salle en cours"
                })

              {:error, reason} ->
                conn
                |> put_status(400)
                |> json(Errors.error("Création échouée: #{inspect(reason)}", 400, "ROOM_CREATE_ERROR"))
            end
        end
    end
  end

  @doc """
  GET /api/rooms/:room_id
  Détails d'une salle.
  """
  def show(conn, %{"room_id" => room_id}) do
    case GameRoom.get_room(room_id) do
      {:ok, room} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: format_room(room),
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

      {:error, :room_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))
    end
  end

  @doc """
  POST /api/rooms/:room_id/join
  Rejoindre une salle.
  """
  def join(conn, %{"room_id" => room_id} = params) do
    user_id = get_current_user_id(conn)
    player_name = Map.get(params, "player_name")

    # Jeu responsable avant d'occuper un slot (exclu/en pause/limite).
    with {:ok, room} <- GameRoom.get_room(room_id),
         :ok <- rg_gate_for_room(user_id, %{mode: room.mode, bet_amount: room.bet_amount}) do
      do_join_room(conn, room_id, user_id, player_name)
    else
      {:error, :room_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))

      {:error, reason} when is_atom(reason) ->
        {message, details} = GameHub.ResponsibleGaming.block_message(reason, user_id, 0)
        conn |> put_status(403) |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))
    end
  end

  defp do_join_room(conn, room_id, user_id, player_name) do
    case GameRoom.join_room(room_id, user_id, player_name) do
      {:ok, room} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: format_room(room),
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

      {:error, :room_full} ->
        conn |> put_status(409) |> json(Errors.error("Salle pleine", 409, "ROOM_FULL"))

      {:error, :room_not_waiting} ->
        conn |> put_status(409) |> json(Errors.error("Salle non disponible", 409, "ROOM_NOT_WAITING"))

      {:error, :already_in_room} ->
        conn |> put_status(409) |> json(Errors.error("Déjà dans la salle", 409, "ALREADY_IN_ROOM"))

      {:error, :already_in_active_match, existing} ->
        conn
        |> put_status(409)
        |> json(%{
          success: false,
          data: format_room(existing),
          error: "Vous êtes déjà dans une autre salle active",
          code: "ALREADY_IN_ACTIVE_MATCH"
        })

      {:error, :room_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))
    end
  end

  @doc """
  POST /api/rooms/:room_id/leave
  Quitter une salle.
  """
  def leave(conn, %{"room_id" => room_id}) do
    user_id = get_current_user_id(conn)

    case GameRoom.leave_room(room_id, user_id) do
      {:ok, :room_cancelled} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "cancelled", message: "Salle annulée (créateur parti)"}})

      {:ok, _room} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "left", message: "Salle quittée"}})

      {:error, :room_in_progress} ->
        conn |> put_status(409) |> json(Errors.error("Partie en cours", 409, "ROOM_IN_PROGRESS"))

      {:error, _} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))
    end
  end

  @doc """
  POST /api/rooms/:room_id/start
  Démarrer le match (créateur uniquement, Partie avec mise / Sans mise).
  """
  def start(conn, %{"room_id" => room_id}) do
    user_id = get_current_user_id(conn)

    # Jeu responsable : tous les joueurs doivent pouvoir jouer (salle avec
    # mise : contrôle complet avec la mise, sinon jouabilité).
    with {:ok, room} <- GameRoom.get_room(room_id),
         :ok <- rg_gate_for_room_players(room) do
      do_start_match(conn, room_id, user_id)
    else
      {:error, :room_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))

      {:error, {:rg_blocked, reason, blocked_id}} ->
        {message, details} = GameHub.ResponsibleGaming.block_message(reason, blocked_id, 0)
        conn |> put_status(403) |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))
    end
  end

  defp do_start_match(conn, room_id, user_id) do
    case GameRoom.start_match(room_id, user_id) do
      {:ok, %{room: room, match: match}} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            room: format_room(room),
            match_id: match.match_id,
            status: "match_started"
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

      {:error, :not_creator} ->
        conn |> put_status(403) |> json(Errors.error("Seul le créateur peut démarrer", 403, "NOT_CREATOR"))

      {:error, :not_enough_players} ->
        conn |> put_status(400) |> json(Errors.error("Pas assez de joueurs (min 2)", 400, "NOT_ENOUGH_PLAYERS"))

      {:error, :room_not_waiting} ->
        conn |> put_status(409) |> json(Errors.error("Salle non disponible", 409, "ROOM_NOT_WAITING"))

      {:error, {:match_creation_failed, reason}} ->
        conn |> put_status(500) |> json(Errors.error("Création match échouée: #{inspect(reason)}", 500, "MATCH_CREATE_ERROR"))

      {:error, _} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))
    end
  end

  @doc """
  POST /api/rooms/:room_id/cancel
  Annuler une salle.
  """
  def cancel(conn, %{"room_id" => room_id}) do
    user_id = get_current_user_id(conn)

    case GameRoom.cancel_room(room_id, user_id) do
      {:ok, :room_cancelled} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "cancelled"}})

      {:error, :cannot_cancel} ->
        conn |> put_status(403) |> json(Errors.error("Impossible d'annuler", 403, "CANNOT_CANCEL"))

      {:error, _} ->
        conn |> put_status(404) |> json(Errors.error("Salle non trouvée", 404, "ROOM_NOT_FOUND"))
    end
  end

  @doc """
  GET /api/rooms/waiting
  Liste des salles en attente.
  """
  def waiting(conn, params) do
    game_type = Map.get(params, "game_type")

    # Migration brutale: mode betting rejeté
    mode_result =
      if Map.has_key?(params, "mode") do
        case GameMode.parse_strict(to_string(params["mode"])) do
          {:ok, m} -> {:ok, m}
          {:error, _} -> {:error, :invalid_mode}
        end
      else
        {:ok, nil}
      end

    case mode_result do
      {:error, :invalid_mode} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Mode invalide: betting supprimé — utiliser free | staked", 400, "INVALID_MODE"))

      {:ok, mode} ->
        rooms = GameRoom.list_waiting_rooms(game_type, mode)

        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: Enum.map(rooms, &format_room/1),
          meta: %{
            total: length(rooms),
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        })
    end
  end

  @doc """
  POST /api/rooms/join-by-code
  Rejoindre une salle par code.
  """
  def join_by_code(conn, %{"code" => code} = params) do
    user_id = get_current_user_id(conn)
    player_name = Map.get(params, "player_name")

    # Jeu responsable avant d'occuper un slot (salle résolue par code).
    with {:ok, room} <- GameRoom.get_room_by_code(code),
         :ok <- rg_gate_for_room(user_id, %{mode: room.mode, bet_amount: room.bet_amount}) do
      do_join_by_code(conn, code, user_id, player_name)
    else
      {:error, :room_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Code invalide", 404, "ROOM_NOT_FOUND"))

      {:error, reason} when is_atom(reason) ->
        {message, details} = GameHub.ResponsibleGaming.block_message(reason, user_id, 0)
        conn |> put_status(403) |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))
    end
  end

  def join_by_code(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("Paramètre 'code' requis", 400, "VALIDATION_ERROR"))
  end

  defp do_join_by_code(conn, code, user_id, player_name) do
    case GameRoom.join_by_code(code, user_id, player_name) do
      {:ok, room} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: format_room(room),
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

      {:error, :room_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Code invalide", 404, "ROOM_NOT_FOUND"))

      {:error, :room_full} ->
        conn |> put_status(409) |> json(Errors.error("Salle pleine", 409, "ROOM_FULL"))

      {:error, :room_not_waiting} ->
        conn |> put_status(409) |> json(Errors.error("Salle non disponible", 409, "ROOM_NOT_WAITING"))

      {:error, :already_in_room} ->
        conn |> put_status(409) |> json(Errors.error("Déjà dans la salle", 409, "ALREADY_IN_ROOM"))
    end
  end

  # === Helpers ===

  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end

  # Porte jeu responsable pour une salle : avec mise → contrôle complet
  # (montant de la salle), sans mise → jouabilité (exclusion/pause/session).
  defp rg_gate_for_room(user_id, %{mode: mode, bet_amount: bet}) do
    if staked_mode?(mode) and is_integer(bet) and bet > 0 do
      GameHub.ResponsibleGaming.check_before_bet(user_id, bet)
    else
      GameHub.ResponsibleGaming.check_playable(user_id)
    end
  end

  # Tous les joueurs d'une salle au démarrage (premier bloqué remonte).
  defp rg_gate_for_room_players(room) do
    Enum.reduce_while(room.players, :ok, fn player, :ok ->
      case rg_gate_for_room(player.id, %{mode: room.mode, bet_amount: room.bet_amount}) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:rg_blocked, reason, player.id}}}
      end
    end)
  end

  defp staked_mode?(:staked), do: true
  defp staked_mode?("staked"), do: true
  defp staked_mode?(_), do: false

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_int(_), do: nil

  # Validation backend obligatoire (règle 23) : en mode fixe, un
  # sets_count client hors [min_sets, max_sets] est rejeté (400).
  # En mode aléatoire, la valeur client est ignorée (tirage serveur).
  defp valid_room_sets?(%{sets_count: nil}), do: true

  defp valid_room_sets?(%{game_type: game_type, rule_type: rule_type, sets_count: sets}) do
    preview = GameHub.GameRules.sets_preview(game_type, rule_type)

    cond do
      preview.mode == "random" -> true
      not is_integer(sets) -> true
      true -> sets >= preview.min_sets and sets <= preview.max_sets
    end
  end

  defp format_room(room) do
    canonical_mode = GameMode.normalize(room.mode)
    %{
      room_id: room.room_id,
      room_code: room.room_code,
      creator_id: room.creator_id,
      game_type: room.game_type,
      rule_type: room.rule_type,
      mode: GameMode.to_string(canonical_mode),
      mode_label: GameMode.display_label(canonical_mode),
      mode_short: GameMode.short_label(canonical_mode),
      status: to_string(room.status),
      bet_amount: room.bet_amount,
      sets_count: room.sets_count,
      sets_mode: Map.get(room, :sets_mode, "fixed"),
      dice_count: room.dice_count,
      max_players: room.max_players,
      players_count: length(room.players),
      players: Enum.map(room.players, fn p ->
        %{id: p.id, name: p.name, joined_at: p.joined_at}
      end),
      match_id: room.match_id,
      created_at: room.created_at
    }
  end
end
