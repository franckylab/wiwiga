import Config

# Configure la base de données pour les tests
config :game_hub, GameHub.Repo,
  username: "postgres",
  password: "postgres",
  database: "game_hub_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 4

# Configure Redis pour les tests (mock ou instance séparée)
config :game_hub, GameHub.Redis,
  host: "localhost",
  port: 6379

# Configure Guardian pour les tests
config :game_hub, GameHub.Guardian,
  issuer: "game_hub_test",
  secret_key: "test_secret_key_for_jwt_generation_32_chars_long"

# Configure Oban pour les tests (si utilisé)
config :game_hub, Oban,
  repo: GameHub.Repo,
  queues: false,
  plugins: false

# Configure logger pour les tests
config :logger, level: :warning

# ExUnit configuration
config :ex_unit,
  assert_receive_timeout: 1000,
  capture_log: true
