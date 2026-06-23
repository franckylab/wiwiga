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

  # Transports
  @transport_options []

  def connect(_params, socket, _connect_info) do
    # TODO: Extraire et valider le token JWT
    # case Phoenix.Token.verify(socket, "user_socket", token, max_age: 86400) do
    #   {:ok, user_id} ->
    #     socket = assign(socket, :user_id, user_id)
    #     {:ok, socket}
    #   {:error, _reason} ->
    #     :error
    # end
    
    {:ok, socket}
  end

  def id(_socket), do: nil
end
