# ============================================================
# Fichier: endpoint.ex
# Description: Configuration du endpoint Phoenix WIWIGA
# Auteur: WIWIGA Team
# Date: 2026-06-23
# ============================================================

defmodule GameHubWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :game_hub_web

  # Session
  @session_options [
    store: :cookie,
    key: "_wiwiga_key",
    signing_salt: "wiwiga_signing_salt",
    same_site: "Lax"
  ]

  # Socket WebSocket
  socket "/socket", GameHubWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Plug statiques (si nécessaire)
  # plug Plug.Static,
  #   at: "/",
  #   from: :game_hub_web,
  #   gzip: false,
  #   only: ~w(assets images uploads favicon.ico robots.txt)

  # Code reloading
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :game_hub
  end

  # Parsers
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # Router
  plug GameHubWeb.Router
end
