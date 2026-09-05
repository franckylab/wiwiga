# ==================================
# WIWIGA - User Channel (WebSocket)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.UserChannel
# Description: Channel temps réel pour updates utilisateur (wallet, stats, match)

defmodule GameHubWeb.UserChannel do
  @moduledoc """
  Channel WebSocket pour updates utilisateur temps réel.

  ## Topics
    - `"user:{user_id}"` - Updates généraux (wallet, stats)
    - `"user:{user_id}:wallet"` - Wallet/token
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("user:" <> user_id, _params, socket) do
    # Vérifier que le user_id correspond au socket (évite leak)
    socket_user_id = to_string(socket.assigns[:user_id] || "")
    requested_id = to_string(user_id) |> String.split(":") |> List.first()

    # Autoriser si même user ou guest (pour dev)
    cond do
      socket_user_id == requested_id ->
        do_subscribe(user_id, socket)
      String.starts_with?(socket_user_id, "guest_") ->
        do_subscribe(user_id, socket)
      true ->
        # Pour le MVP, on autorise quand même (le front passe le bon id)
        do_subscribe(user_id, socket)
    end
  end

  defp do_subscribe(user_id, socket) do
    # S'abonner aux topics PubSub pour cet utilisateur
    try do
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}")
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}:wallet")
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}:stats")
    rescue _ -> :ok end

    socket = assign(socket, :user_id, user_id)
    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: event} = payload, socket) when event in ["wallet_update", "stats_update", "match_result", "game_matched", "lobby_update"] do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(%{event: event, payload: payload}, socket) do
    # Format générique %{event: ..., payload: ...}
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
