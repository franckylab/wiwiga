# ==================================
# WIWIGA - Migration Advanced Settings
# ==================================
# Migration: 20260825000009_add_advanced_settings.exs
# Ajout des settings gaming, bonus, paiement, plateforme avances

defmodule GameHub.Repo.Migrations.AddAdvancedSettings do
  use Ecto.Migration

  def up do
    # Inserer les settings avances par defaut
    execute """
    INSERT INTO system_settings (key, value, category, description, inserted_at, updated_at) VALUES
    -- Gaming
    ('commission_rate_global', '0.05', 'gaming', 'Taux de commission global par defaut', NOW(), NOW()),
    ('default_min_bet', '100', 'gaming', 'Mise minimum par defaut (FCFA)', NOW(), NOW()),
    ('default_max_bet', '100000', 'gaming', 'Mise maximum par defaut (FCFA)', NOW(), NOW()),
    ('max_concurrent_games', '100', 'gaming', 'Nombre max de parties simultanees', NOW(), NOW()),
    ('match_timeout_seconds', '300', 'gaming', 'Timeout d''une partie (secondes)', NOW(), NOW()),
    ('auto_resolve_enabled', 'true', 'gaming', 'Resolution automatique des parties timeout', NOW(), NOW()),
    -- Bonus
    ('max_bonus_percentage', '100', 'bonus', 'Pourcentage max du bonus par rapport au depot', NOW(), NOW()),
    ('wagering_requirement_default', '5', 'bonus', 'Wagering requirement par defaut (x)', NOW(), NOW()),
    ('bonus_cooldown_days', '7', 'bonus', 'Delai minimum entre deux bonus (jours)', NOW(), NOW()),
    ('max_active_bonuses_per_user', '3', 'bonus', 'Nombre max de bonus actifs par joueur', NOW(), NOW()),
    -- Paiement
    ('min_deposit', '100', 'payment', 'Depot minimum (FCFA)', NOW(), NOW()),
    ('max_deposit', '500000', 'payment', 'Depot maximum (FCFA)', NOW(), NOW()),
    ('min_withdrawal', '500', 'payment', 'Retrait minimum (FCFA)', NOW(), NOW()),
    ('max_withdrawal', '1000000', 'payment', 'Retrait maximum (FCFA)', NOW(), NOW()),
    ('daily_withdrawal_limit', '2000000', 'payment', 'Limite retrait journalier (FCFA)', NOW(), NOW()),
    ('withdrawal_fee_percentage', '0.0', 'payment', 'Frais de retrait (%)', NOW(), NOW()),
    ('auto_withdrawal_threshold', '100000', 'payment', 'Seuil retrait automatique (FCFA)', NOW(), NOW()),
    -- Notification avancee
    ('webhook_url', '', 'notification', 'URL webhook pour evenements', NOW(), NOW()),
    ('slack_webhook', '', 'notification', 'Slack webhook URL', NOW(), NOW()),
    ('email_alert_threshold', '5', 'notification', 'Seuil d''alertes email par heure', NOW(), NOW()),
    ('telegram_bot_token', '', 'notification', 'Token bot Telegram', NOW(), NOW()),
    ('telegram_chat_id', '', 'notification', 'Chat ID Telegram pour alertes', NOW(), NOW())
    """
  end

  def down do
    # Supprimer les settings avances
    execute """
    DELETE FROM system_settings WHERE category IN ('gaming', 'bonus', 'payment')
    OR key IN ('webhook_url', 'slack_webhook', 'email_alert_threshold', 'telegram_bot_token', 'telegram_chat_id')
    """
  end
end
