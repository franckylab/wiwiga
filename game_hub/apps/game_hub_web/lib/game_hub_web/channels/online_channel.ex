# ==================================
# WIWIGA - Channel Présence en ligne (temps réel)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Suivi présence global + par jeu via Phoenix.Presence

defmodule GameHubWeb.OnlineChannel do
  use Phoenix.Channel

  alias GameHub.Presence

  @impl true
  def join("online:lobby", _params, socket) do
    user_id = get_user_id(socket)
    if user_id do
      send(self(), {:after_join_global, user_id})
    end
    {:ok, assign(socket, :presence_topic, "online:lobby")}
  end

  def join("online:game:" <> game_type, _params, socket) do
    user_id = get_user_id(socket)
    if user_id do
      send(self(), {:after_join_game, user_id, game_type})
    end
    {:ok, assign(socket, :presence_topic, "online:game:#{game_type}") |> assign(:presence_game_type, game_type)}
  end

  @impl true
  def handle_info({:after_join_global, user_id}, socket) do
    {:ok, _} = Presence.track_user(user_id, %{online_at: System.system_time(:second)})
    # Phoenix Presence enverra automatiquement presence_state / presence_diff
    {:noreply, socket}
  end

  def handle_info({:after_join_game, user_id, game_type}, socket) do
    {:ok, _} = Presence.track_game(user_id, game_type, %{online_at: System.system_time(:second)})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # Presence auto-untrack à la terminaison du channel (process exit)
    _ = socket.assigns[:presence_topic]
    :ok
  end

  defp get_user_id(socket) do
    case socket.assigns[:current_user] do
      %{id: id} -> to_string(id)
      _ ->
        case socket.assigns[:user_id] do
          id when is_binary(id) ->
            if String.starts_with?(id, "guest_") do
              # Compter les guests aussi, mais on peut les distinguer via meta
              id
            else
              id
            end
          _ -> nil
        end
    end
  end
end
