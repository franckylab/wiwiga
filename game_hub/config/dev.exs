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
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "localhost", port: 8000],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "dev_secret_key_base_123456789012345678901234567890",
  server: true,
  pubsub_server: GameHub.PubSub,
  render_errors: [
    formats: [json: GameHubWeb.ErrorView],
    layout: false
  ]

# Logger
config :logger, :console, format: "[$level] $message\n"

# Importer configuration Guardian
import_config "guardian.ex"
