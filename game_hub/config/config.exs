import Config

# Configuration générale
config :game_hub,
  ecto_repos: [GameHub.Repo]

config :game_hub_web,
  generators: [timestamp_data_type: :utc_datetime]

# Configuration par environnement
import_config "#{config_env()}.exs"
