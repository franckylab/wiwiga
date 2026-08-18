# ==================================
# WIWIGA - Migration System Settings
# ==================================
# Migration: 20260825000006_add_system_settings.exs

defmodule GameHub.Repo.Migrations.AddSystemSettings do
  use Ecto.Migration

  def up do
    create table(:system_settings) do
      add :key, :string, null: false
      add :value, :text
      add :category, :string, null: false, default: "general"
      add :description, :text
      add :updated_by, :integer

      timestamps()
    end

    create unique_index(:system_settings, [:key])
    create index(:system_settings, [:category])

    # Insérer les settings par défaut
    execute """
    INSERT INTO system_settings (key, value, category, description, inserted_at, updated_at) VALUES
    -- Général
    ('platform_name', 'WIWIGA', 'general', 'Nom de la plateforme', NOW(), NOW()),
    ('platform_timezone', 'Africa/Douala', 'general', 'Fuseau horaire', NOW(), NOW()),
    ('default_language', 'fr', 'general', 'Langue par défaut', NOW(), NOW()),
    ('maintenance_mode', 'false', 'general', 'Mode maintenance activé', NOW(), NOW()),
    ('maintenance_message', 'Maintenance en cours. Retour imminent.', 'general', 'Message maintenance', NOW(), NOW()),
    ('support_email', 'support@wiwiga.com', 'general', 'Email support', NOW(), NOW()),
    -- Email
    ('smtp_host', '', 'email', 'Serveur SMTP', NOW(), NOW()),
    ('smtp_port', '587', 'email', 'Port SMTP', NOW(), NOW()),
    ('smtp_from_address', 'noreply@wiwiga.com', 'email', 'Adresse expéditeur', NOW(), NOW()),
    ('smtp_from_name', 'WIWIGA', 'email', 'Nom expéditeur', NOW(), NOW()),
    ('smtp_use_tls', 'true', 'email', 'Utiliser TLS', NOW(), NOW()),
    -- Stockage
    ('max_upload_size_mb', '10', 'storage', 'Taille max upload (MB)', NOW(), NOW()),
    ('image_quality', '85', 'storage', 'Qualité compression images (%)', NOW(), NOW()),
    ('allowed_image_types', 'jpg,jpeg,png,webp', 'storage', 'Types images autorisés', NOW(), NOW()),
    -- Notifications
    ('email_notifications', 'true', 'notification', 'Notifications email activées', NOW(), NOW()),
    ('push_notifications', 'true', 'notification', 'Notifications push activées', NOW(), NOW()),
    ('admin_alert_email', 'true', 'notification', 'Email alertes admin', NOW(), NOW()),
    ('deposit_notification', 'true', 'notification', 'Notification lors des dépôts', NOW(), NOW()),
    -- Sécurité
    ('max_login_attempts', '5', 'security', 'Tentatives login max avant lock', NOW(), NOW()),
    ('lockout_duration_minutes', '30', 'security', 'Durée verrouillage (minutes)', NOW(), NOW()),
    ('session_timeout_minutes', '60', 'security', 'Timeout session admin (minutes)', NOW(), NOW()),
    ('require_2fa_admin', 'true', 'security', '2FA obligatoire pour admins', NOW(), NOW()),
    ('ip_whitelist_enabled', 'false', 'security', 'IP whitelist activée', NOW(), NOW())
    """
  end

  def down do
    drop table(:system_settings)
  end
end
