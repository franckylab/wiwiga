# ==================================
# WIWIGA - Room Channel (WebSocket)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.RoomChannel
# Description: Channel WebSocket pour salles de jeu en temps réel

defmodule GameHubWeb.RoomChannel do
  @moduledoc """
  Channel WebSocket pour les salles de jeu.

  ## Topics
    - `"room:{room_id}"` - Salle spécifique

  ## Events entrants
    - `"join_room"` - Rejoindre la salle
    - `"leave_room"` - Quitter la salle
    - `"start_match"` - Démarrer le match (créateur)
    - `"player_ready"` - Joueur prêt

  ## Events sortants
    - `"room_updated"` - État salle mis à jour
    - `"player_joined"` - Nouveau joueur
    - `"player_left"` - Joueur parti
    - `"match_starting"` - Match en cours de démarrage
    - `"match_started"` - Match démarré
    - `"set_started"` - Set démarré
    - `"dice_rolled"` - Dés lancés
    - `"set_result"` - Résultat du set
    - `"match_result"` - Résultat du match
  """

  use Phoenix.Channel
  require Logger

  alias GameHub.{GameRoom, GameMatch}

  def join("room:" <> room_id, _params, socket) do
    case GameRoom.get_room(room_id) do
      {:ok, _room} ->
        socket = assign(socket, :room_id, room_id)
        send(self(), :after_join)
        {:ok, socket}

      {:error, _} ->
        {:error, %{reason: "room_not_found"}}
    end
  end

  def handle_info(:after_join, socket) do
    room_id = socket.assigns.room_id

    case GameRoom.get_room(room_id) do
      {:ok, room} ->
        push(socket, "room_updated", %{room: format_room(room)})
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("join_room", %{"player_name" => player_name}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:user_id] || generate_temp_id()

    case GameRoom.join_room(room_id, user_id, player_name) do
      {:ok, room} ->
        broadcast!(socket, "player_joined", %{
          player: %{id: user_id, name: player_name},
          room: format_room(room)
        })
        {:reply, {:ok, %{room: format_room(room)}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("leave_room", _params, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:user_id] || generate_temp_id()

    case GameRoom.leave_room(room_id, user_id) do
      {:ok, :room_cancelled} ->
        broadcast!(socket, "room_cancelled", %{reason: "creator_left"})
        {:noreply, socket}

      {:ok, room} ->
        broadcast!(socket, "player_left", %{
          player_id: user_id,
          room: format_room(room)
        })
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_in("start_match", _params, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:user_id] || generate_temp_id()

    case GameRoom.start_match(room_id, user_id) do
      {:ok, %{room: room, match: match}} ->
        broadcast!(socket, "match_started", %{
          match_id: match.match_id,
          room: format_room(room)
        })
        {:reply, {:ok, %{match_id: match.match_id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  def handle_in("player_ready", _params, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:user_id] || generate_temp_id()
    broadcast!(socket, "player_ready", %{player_id: user_id})
    {:noreply, socket}
  end

  # === Privé ===

  defp format_room(room) do
    %{
      room_id: room.room_id,
      room_code: room.room_code,
      creator_id: room.creator_id,
      game_type: room.game_type,
      rule_type: room.rule_type,
      mode: to_string(room.mode),
      status: to_string(room.status),
      bet_amount: room.bet_amount,
      sets_count: room.sets_count,
      dice_count: room.dice_count,
      max_players: room.max_players,
      players_count: length(room.players),
      players: Enum.map(room.players, fn p -> %{id: p.id, name: p.name} end),
      match_id: room.match_id
    }
  end

  defp generate_temp_id do
    "temp_#{System.unique_integer([:positive])}"
  end
end
