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

        cond do
          GameMode.staked?(room_params.mode) and room_params.bet_amount <= 0 ->
            conn
            |> put_status(400)
            |> json(Errors.error("Mise requise pour le mode Partie avec mise", 400, "VALIDATION_ERROR"))

          room_params.game_type not in ~w(dice) ->
            conn
            |> put_status(400)
            |> json(Errors.error("Type de jeu non supporté", 400, "INVALID_GAME_TYPE"))

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

  def join_by_code(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("Paramètre 'code' requis", 400, "VALIDATION_ERROR"))
  end

  # === Helpers ===

  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_int(_), do: nil

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
