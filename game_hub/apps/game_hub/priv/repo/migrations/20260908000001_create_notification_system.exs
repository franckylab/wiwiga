# ==================================
# WIWIGA - Migration Système Notifications Multi-Canal
# ==================================
# Tables: notification_providers, notification_templates,
#         notifications, notification_deliveries,
#         notification_preferences, device_tokens

defmodule GameHub.Repo.Migrations.CreateNotificationSystem do
  use Ecto.Migration

  def up do
    # === Providers multi-canaux (config centralisée persistante) ===
    create table(:notification_providers, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :channel, :string, null: false
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :is_active, :boolean, default: false, null: false
      add :is_default, :boolean, default: false, null: false
      add :priority, :integer, default: 100, null: false
      add :config, :map, default: %{}, null: false
      add :rate_limit_per_min, :integer, default: 60, null: false
      add :quota_monthly, :integer
      add :supports_delivery_webhook, :boolean, default: false, null: false
      add :last_health_check_at, :utc_datetime
      add :last_health_status, :string
      add :last_error, :text
      add :created_by, :integer
      timestamps()
    end

    create unique_index(:notification_providers, [:channel, :name])
    create index(:notification_providers, [:channel])
    create index(:notification_providers, [:is_active])

    # === Templates versionnés par canal + locale ===
    create table(:notification_templates, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :key, :string, null: false
      add :channel, :string, null: false
      add :locale, :string, default: "fr", null: false
      add :version, :integer, default: 1, null: false
      add :subject, :string
      add :body_tpl, :text, null: false
      add :required_variables, {:array, :string}, default: []
      add :category, :string, default: "transactional", null: false
      add :is_active, :boolean, default: true, null: false
      add :created_by, :integer
      timestamps()
    end

    create unique_index(:notification_templates, [:key, :channel, :locale, :version])
    create index(:notification_templates, [:key])
    create index(:notification_templates, [:channel])
    create index(:notification_templates, [:is_active])

    # === Notifications (intention + inbox joueur) ===
    create table(:notifications, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :event_type, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :template_key, :string, null: false
      add :template_version, :integer, default: 1
      add :title, :string, null: false
      add :body, :text, null: false
      add :variables, :map, default: %{}
      add :category, :string, default: "transactional", null: false
      add :priority, :string, default: "normal", null: false
      add :status, :string, default: "queued", null: false
      add :idempotency_key, :string, null: false
      add :scheduled_at, :utc_datetime
      add :read_at, :utc_datetime
      add :is_read, :boolean, default: false, null: false
      timestamps()
    end

    create unique_index(:notifications, [:idempotency_key])
    create index(:notifications, [:user_id, :inserted_at])
    create index(:notifications, [:user_id, :is_read])
    create index(:notifications, [:status])
    create index(:notifications, [:event_type])

    # === Tentatives de livraison par canal/provider ===
    create table(:notification_deliveries, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :notification_id, references(:notifications, on_delete: :delete_all), null: false
      add :channel, :string, null: false
      add :provider_id, references(:notification_providers, on_delete: :nilify_all)
      add :provider_name, :string
      add :attempt_number, :integer, default: 1, null: false
      add :status, :string, default: "queued", null: false
      add :provider_message_id, :string
      add :error_code, :string
      add :error_message, :text
      add :next_retry_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :delivered_at, :utc_datetime
      timestamps()
    end

    create index(:notification_deliveries, [:notification_id])
    create index(:notification_deliveries, [:status, :next_retry_at])
    create index(:notification_deliveries, [:channel])
    create index(:notification_deliveries, [:sent_at])

    # === Préférences matrice (user × catégorie × canal) ===
    create table(:notification_preferences, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :category, :string, null: false
      add :channel, :string, null: false
      add :enabled, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:notification_preferences, [:user_id, :category, :channel])
    create index(:notification_preferences, [:user_id])

    # === Tokens push (FCM/APNs/Web) ===
    create table(:device_tokens, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :platform, :string, null: false
      add :token, :string, null: false
      add :app_version, :string
      add :last_seen_at, :utc_datetime
      add :is_valid, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:device_tokens, [:token])
    create index(:device_tokens, [:user_id])
    create index(:device_tokens, [:is_valid])
  end

  def down do
    drop table(:device_tokens)
    drop table(:notification_preferences)
    drop table(:notification_deliveries)
    drop table(:notifications)
    drop table(:notification_templates)
    drop table(:notification_providers)
  end
end
