# ==================================
# WIWIGA - Friend Channel (WebSocket)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.FriendChannel
# Description: Channel WebSocket pour notifications amis

defmodule GameHubWeb.FriendChannel do
  @moduledoc """
  Channel WebSocket pour le système d'amis.

  ## Topics
    - `"friend:notif"` - Notifications d'un utilisateur

  ## Events entrants
    - `"subscribe"` - S'abonner aux notifications avec user_id

  ## Events sortants
    - `"friend_request"` - Nouvelle demande d'ami
    - `"friend_accepted"` - Demande acceptée
    - `"friend_online"` - Ami en ligne/hors ligne
    - `"game_invitation"` - Invitation à jouer
    - `"activity_update"` - Activité d'un ami
    - `"chat_message"` - Message de chat
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("friend:notif", %{"user_id" => user_id}, socket) do
    socket = assign(socket, :user_id, user_id)

    # S'abonner au topic utilisateur pour notifications
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}:friends")
    end

    {:ok, socket}
  end

  def join("friend:notif", _params, _socket) do
    {:error, %{reason: "user_id_required"}}
  end

  @impl true
  def handle_in("send_game_invite", %{"friend_id" => friend_id, "room_code" => room_code}, socket) do
    user_id = socket.assigns.user_id

    # Envoyer l'invitation via PubSub
    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "user:#{friend_id}:friends",
      %{
        event: "game_invitation",
        payload: %{
          from_user_id: user_id,
          room_code: room_code,
          invited_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }
    )

    {:reply, :ok, socket}
  end

  def handle_in("send_chat_message", %{"friend_id" => friend_id, "content" => content, "emoji_type" => emoji_type}, socket) do
    user_id = socket.assigns.user_id

    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "user:#{friend_id}:friends",
      %{
        event: "chat_message",
        payload: %{
          from_user_id: user_id,
          content: content,
          emoji_type: emoji_type,
          sent_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }
    )

    {:reply, :ok, socket}
  end

  defp connected?(socket) do
    socket.transport_pid != nil
  rescue
    _ -> false
  end
end
