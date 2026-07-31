# Configuration des tests
import Config

# Configure la base de données de test (isolée du dev)
config :game_hub, GameHub.Repo,
  username: System.get_env("DATABASE_USER") || "wiwiga_user",
  password: System.get_env("DATABASE_PASSWORD") || "wiwiga_password",
  hostname: System.get_env("DATABASE_HOST") || "postgres",
  database: System.get_env("DATABASE_TEST_NAME") || "wiwiga_test",
  pool_size: 10

# Configure Redis
config :game_hub, GameHub.Redis,
  url: System.get_env("REDIS_URL") || "redis://redis:6379"

# Configuration du endpoint Phoenix (serveur désactivé en test)
config :game_hub_web, GameHubWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4002],
  url: [host: "localhost", port: 4002],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "test_secret_key_base_123456789012345678901234567890",
  server: false,
  pubsub_server: GameHub.PubSub,
  render_errors: [
    formats: [json: GameHubWeb.ErrorView],
    layout: false
  ]

# Logger silencieux en test
config :logger, level: :warning

# Importer configuration Guardian
import_config "guardian.ex"
