# ============================================================
# Fichier: user_socket.ex
# Description: WebSocket Socket principal pour WIWIGA
# Auteur: WIWIGA Team
# Date: 2026-06-23
# ============================================================

defmodule GameHubWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "game:*", GameHubWeb.GameChannel
  channel "matchmaking:*", GameHubWeb.MatchmakingChannel
  channel "room:*", GameHubWeb.RoomChannel
  channel "friend:*", GameHubWeb.FriendChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case GameHub.Guardian.resource_from_token(token) do
      {:ok, user, _claims} ->
        socket = assign(socket, :user_id, user.id)
        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, socket, _connect_info) do
    # Dev/Guest fallback : permet connexion sans token pour salles d'attente et match local
    dev_id = "guest_#{System.unique_integer([:positive])}"
    {:ok, assign(socket, :user_id, dev_id)}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
