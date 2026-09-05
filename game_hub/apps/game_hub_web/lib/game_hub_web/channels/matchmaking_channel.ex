# ==================================
# WIWIGA - Channel Matchmaking WebSocket (V3)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.MatchmakingChannel
# Description: Matchmaking temps réel via WebSocket — partition rule_type

defmodule GameHubWeb.MatchmakingChannel do
  @moduledoc """
  Phoenix Channel pour matchmaking — V3.
  
  ## Events Client -> Serveur
    - "join_queue": Rejoindre file {bet_amount, rule_type}
    - "leave_queue": Quitter file
    - "queue_status": Statut file
  
  ## Events Serveur -> Client
    - "queue_joined": Confirmé
    - "game_matched": Partie trouvée
  """
  
  use Phoenix.Channel
  
  require Logger
  alias GameHub.Matchmaking
  
  @valid_rules ~w(normal cible)

  defp normalize_rule(rule) when is_binary(rule) do
    r = String.downcase(String.trim(rule))
    if r in @valid_rules, do: r, else: "normal"
  end
  defp normalize_rule(_), do: "normal"
  
  @impl true
  def join("matchmaking:" <> game_type, _params, socket) do
    user_id = get_user_id(socket) || "dev_user_#{System.unique_integer([:positive])}"
    socket = assign(socket, :user_id, user_id)
    socket = assign(socket, :game_type, game_type)
    try do
      Phoenix.PubSub.subscribe(GameHub.PubSub, "matchmaking:#{game_type}")
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}")
    rescue _ -> :ok end
    {:ok, socket}
  end

  @impl true
  def join("qm:lobby:" <> lobby_suffix, _params, socket) do
    # lobby_suffix = "dice:normal:500"
    parts = String.split(lobby_suffix, ":")
    game_type = Enum.at(parts, 0, "dice")
    rule_type = Enum.at(parts, 1, "normal")
    bet_str = Enum.at(parts, 2, "0")
    user_id = get_user_id(socket) || "dev_user_#{System.unique_integer([:positive])}"
    socket = socket
      |> assign(:user_id, user_id)
      |> assign(:game_type, game_type)
      |> assign(:rule_type, rule_type)
      |> assign(:bet_amount, bet_str)
    try do
      Phoenix.PubSub.subscribe(GameHub.PubSub, "qm:lobby:#{lobby_suffix}")
      Phoenix.PubSub.subscribe(GameHub.PubSub, "user:#{user_id}")
      Phoenix.PubSub.subscribe(GameHub.PubSub, "matchmaking:#{game_type}")
    rescue _ -> :ok end
    {:ok, socket}
  end
  
  @impl true
  def handle_in("join_queue", payload, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    bet_amount = payload["bet_amount"] || payload["betAmount"]
    rule_type = normalize_rule(payload["rule_type"] || payload["ruleType"] || "normal")

    bet_amount =
      cond do
        is_integer(bet_amount) -> bet_amount
        is_float(bet_amount) -> trunc(bet_amount)
        is_binary(bet_amount) -> String.to_integer(bet_amount)
        true -> nil
      end

    if is_nil(bet_amount) do
      {:reply, {:error, %{reason: "bet_amount_required"}}, socket}
    else
      case Matchmaking.join_queue(user_id, game_type, rule_type, bet_amount) do
        {:ok, :waiting} ->
          status = Matchmaking.get_queue_status(user_id, game_type, rule_type)
          {:reply, {:ok, %{
            status: "waiting",
            position: status.position,
            total_players: status.total_players,
            elapsed_seconds: status.elapsed_seconds,
            rule_type: rule_type,
            message: "En file d'attente..."
          }}, socket}
        
        {:ok, :matched, game_id} ->
          broadcast!(socket, "player_matched", %{
            user_id: user_id,
            game_id: game_id,
            rule_type: rule_type
          })
          {:reply, {:ok, %{
            status: "matched",
            game_id: game_id,
            rule_type: rule_type,
            message: "Partie trouvée !"
          }}, socket}
        
        {:error, :already_queued} ->
          {:reply, {:error, %{reason: "already_in_queue"}}, socket}
        
        {:error, reason} ->
          {:reply, {:error, %{reason: reason}}, socket}
      end
    end
  end
  
  @impl true
  def handle_in("leave_queue", payload, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    rule_type = normalize_rule(payload["rule_type"] || payload["ruleType"] || "normal")
    bet_amount = payload["bet_amount"] || payload["betAmount"]
    bet_amount = cond do is_integer(bet_amount) -> bet_amount; is_binary(bet_amount) -> String.to_integer(bet_amount); true -> nil end
    if bet_amount, do: Matchmaking.leave_quick_lobby(user_id, game_type, rule_type, bet_amount)
    Matchmaking.leave_queue(user_id, game_type, rule_type)
    Matchmaking.leave_queue(user_id, game_type)
    {:reply, {:ok, %{status: "left_queue"}}, socket}
  end
  
  @impl true
  def handle_in("queue_status", payload, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    rule_type = normalize_rule(payload["rule_type"] || payload["ruleType"] || "normal")
    bet_amount = payload["bet_amount"] || payload["betAmount"]
    bet_amount = cond do is_integer(bet_amount) -> bet_amount; is_binary(bet_amount) -> String.to_integer(bet_amount); true -> nil end
    status = Matchmaking.get_queue_status(user_id, game_type, rule_type)
    fallback = Matchmaking.check_fallback_status(user_id, game_type, rule_type)
    lobby = if bet_amount, do: Matchmaking.get_quick_lobby_state(game_type, rule_type, bet_amount, user_id), else: nil
    {:reply, {:ok, Map.merge(status, %{fallback: fallback, lobby: lobby})}, socket}
  end

  @impl true
  def handle_in("lobby_update", payload, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    rule_type = normalize_rule(payload["rule_type"] || payload["ruleType"] || "normal")
    bet_amount = payload["bet_amount"] || payload["betAmount"]
    bet_amount = cond do is_integer(bet_amount) -> bet_amount; is_binary(bet_amount) -> String.to_integer(bet_amount); true -> nil end
    if is_nil(bet_amount) do
      {:reply, {:error, %{reason: "bet_amount_required"}}, socket}
    else
      lobby = Matchmaking.get_quick_lobby_state(game_type, rule_type, bet_amount, user_id)
      {:reply, {:ok, lobby}, socket}
    end
  end

  @impl true
  def handle_in("toggle_ready", payload, socket) do
    user_id = socket.assigns.user_id
    game_type = socket.assigns.game_type
    rule_type = normalize_rule(payload["rule_type"] || payload["ruleType"] || "normal")
    bet_amount = payload["bet_amount"] || payload["betAmount"]
    bet_amount = cond do is_integer(bet_amount) -> bet_amount; is_binary(bet_amount) -> String.to_integer(bet_amount); true -> nil end
    if is_nil(bet_amount) do
      {:reply, {:error, %{reason: "bet_amount_required"}}, socket}
    else
      case Matchmaking.toggle_quick_ready(user_id, game_type, rule_type, bet_amount) do
        {:ok, :matched, game_id, _lobby} ->
          broadcast!(socket, "game_matched", %{game_id: game_id})
          {:reply, {:ok, %{status: "matched", game_id: game_id}}, socket}
        {:ok, lobby} ->
          broadcast!(socket, "lobby_update", lobby)
          {:reply, {:ok, lobby}, socket}
        {:error, reason} ->
          {:reply, {:error, %{reason: reason}}, socket}
      end
    end
  end
  
  # Forward PubSub lobby/match en temps réel vers le client
  @impl true
  def handle_info(%{event: "lobby_update", lobby: lobby}, socket) do
    push(socket, "lobby_update", lobby)
    {:noreply, socket}
  end

  def handle_info(%{event: "game_matched", game_id: game_id} = payload, socket) do
    push(socket, "game_matched", payload)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]
    game_type = socket.assigns[:game_type]
    if user_id && game_type do
      Matchmaking.leave_queue(user_id, game_type)
      Logger.info("[MATCHMAKING] User #{user_id} left queue #{game_type}")
    end
    :ok
  end
  
  defp get_user_id(socket) do
    case socket.assigns[:current_user] do
      %{id: id} -> to_string(id)
      _ ->
        case socket.assigns[:user_id] do
          id when is_binary(id) -> id
          _ -> nil
        end
    end
  end
end
