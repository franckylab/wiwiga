import Config

# Configuration JWT Guardian
config :game_hub, GameHub.Guardian,
  issuer: "wiwiga",
  secret_key: "wiwiga_dev_secret_key_for_jwt_tokens_minimum_32_characters_long"
