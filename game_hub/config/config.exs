import Config

# Configuration générale
config :game_hub,
  ecto_repos: [GameHub.Repo]

config :game_hub_web,
  generators: [timestamp_data_type: :utc_datetime]

# Notifications multi-canal : files d'attente (1 par canal, isolation des pannes)
# Concurrences basses : somme < pool DB (10)
# Cron santé providers (sans envoi) toutes les 6h (UTC)
config :game_hub, Oban,
  repo: GameHub.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 */6 * * *", GameHub.Notifications.Workers.HealthCheckSchedulerWorker}
     ]}
  ],
  queues: [notifications_sms: 5, notifications_push: 5, notifications_email: 10]

# Swoosh : pas d'adapter global, chaque provider email porte sa config
# (SMTP/SendGrid/SES choisis depuis la DB). API client désactivé.
config :swoosh, api_client: false

# Configuration par environnement
import_config "#{config_env()}.exs"
