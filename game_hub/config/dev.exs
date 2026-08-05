# Configuration du développement
import Config

# Configure votre base de données
config :game_hub, GameHub.Repo,
  username: System.get_env("DATABASE_USER") || "wiwiga_user",
  password: System.get_env("DATABASE_PASSWORD") || "wiwiga_password",
  hostname: System.get_env("DATABASE_HOST") || "postgres",
  database: System.get_env("DATABASE_NAME") || "wiwiga_dev",
  pool_size: 10

# Configure Redis
config :game_hub, GameHub.Redis,
  url: System.get_env("REDIS_URL") || "redis://redis:6379"

# Configuration du endpoint Phoenix
config :game_hub_web, GameHubWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4001],
  url: [host: "localhost", port: 4001],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "dev_secret_key_base_123456789012345678901234567890",
  server: true,
  code_reloader: true,
  check_origin: false,
  pubsub_server: GameHub.PubSub,
  render_errors: [
    formats: [json: GameHubWeb.ErrorView],
    layout: false
  ],
  watchers: [
    # Recharge automatiquement le backend quand les fichiers Elixir changent
  ]

# Live reload pour le développement Docker
config :game_hub_web, GameHubWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpg|gif|svg)$",
      ~r"lib/game_hub/.*(ex|exs)$",
      ~r"lib/game_hub_web/.*(ex|exs|heex)$",
      ~r"apps/game_hub/.*(ex|exs)$",
      ~r"apps/game_hub_web/.*(ex|exs|heex)$"
    ]
  ]

# Logger
config :logger, :console, format: "[$level] $message\n"

# CORS: accepter toutes les origines en développement
config :game_hub_web, allow_all_origins: true

# Importer configuration Guardian
import_config "guardian.ex"
