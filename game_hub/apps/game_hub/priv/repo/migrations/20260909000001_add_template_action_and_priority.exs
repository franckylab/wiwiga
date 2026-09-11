# ==================================
# WIWIGA - Migration action deep-link + priorité templates
# ==================================
# - notification_templates: default_priority, action (route app)
# - notifications: action (copiée au dispatch, pilotée par template)

defmodule GameHub.Repo.Migrations.AddTemplateActionAndPriority do
  use Ecto.Migration

  def up do
    alter table(:notification_templates) do
      add :default_priority, :string, default: "normal", null: false
      add :action, :string
    end

    alter table(:notifications) do
      add :action, :string
    end

    create index(:notifications, [:user_id, :is_read, :inserted_at])

    # Backfill : deep-links des templates existants non personnalisés
    execute "UPDATE notification_templates SET action = '/transactions' WHERE action IS NULL AND key IN ('wallet_credit', 'wallet_debit')"
    execute "UPDATE notification_templates SET action = '/games' WHERE action IS NULL AND key = 'match_result'"
    execute "UPDATE notification_templates SET action = '/friends' WHERE action IS NULL AND key = 'friend_request'"
    execute "UPDATE notification_templates SET default_priority = 'urgent' WHERE key = 'otp_login'"
    execute "UPDATE notification_templates SET default_priority = 'high' WHERE key = 'security_alert'"
    execute "UPDATE notification_templates SET default_priority = 'low' WHERE key = 'promo_broadcast'"
  end

  def down do
    drop index(:notifications, [:user_id, :is_read, :inserted_at])

    alter table(:notifications) do
      remove :action
    end

    alter table(:notification_templates) do
      remove :action
      remove :default_priority
    end
  end
end
