# ==================================
# WIWIGA - Migration Player Progression & Platform Config
# ==================================
# Fichier: 20260825000010_add_player_progression_and_platform_config.exs
# Description: Tables pour niveaux joueur, récompenses, et configuration plateforme étendue

defmodule GameHub.Repo.Migrations.AddPlayerProgressionAndPlatformConfig do
  use Ecto.Migration

  def change do
    # ============================================================
    # Table: player_level_configs
    # Configuration des niveaux/tiers joueur (admin configurable)
    # ============================================================
    create table(:player_level_configs) do
      add :tier, :string, null: false, comment: "bronze, silver, gold, platinum, diamond, legend"
      add :name, :string, null: false
      add :min_xp, :integer, null: false, default: 0
      add :max_xp, :integer, comment: "nil = pas de limite supérieure"
      add :icon, :string, default: "shield"
      add :color, :string, default: "#CD7F32"
      add :benefits, :map, default: %{}, comment: "JSONB: cashback_rate, withdrawal_bonus, bet_discount, etc."
      add :display_order, :integer, default: 0
      add :is_active, :boolean, default: true
      timestamps()
    end

    create unique_index(:player_level_configs, [:tier])
    create index(:player_level_configs, [:display_order])

    # ============================================================
    # Table: platform_configs
    # Configuration centralisée de tous les aspects de la plateforme
    # ============================================================
    create table(:platform_configs) do
      add :category, :string, null: false, comment: "payment, security, registration, social, ranking, gaming, notification"
      add :key, :string, null: false
      add :value, :text
      add :value_type, :string, default: "string", comment: "string, integer, float, boolean, json"
      add :label, :string, comment: "Label affiché dans l'admin"
      add :description, :text, comment: "Description pour l'admin"
      add :default_value, :text, comment: "Valeur par défaut"
      add :validation_rules, :map, default: %{}, comment: "JSONB: min, max, pattern, options"
      add :is_editable, :boolean, default: true
      add :updated_by, :integer
      timestamps()
    end

    create unique_index(:platform_configs, [:category, :key])
    create index(:platform_configs, [:category])

    # ============================================================
    # Seed: Niveaux joueur par défaut
    # ============================================================
    now = NaiveDateTime.utc_now(:second)

    execute """
    INSERT INTO player_level_configs (tier, name, min_xp, max_xp, icon, color, benefits, display_order, is_active, inserted_at, updated_at) VALUES
      ('bronze', 'Bronze', 0, 499, 'shield', '#CD7F32', '{"cashback_rate": 0.0, "withdrawal_bonus": 0.0, "bet_discount": 0.0, "daily_bonus_multiplier": 1.0, "label": "Débutant"}', 1, true, '#{now}', '#{now}'),
      ('silver', 'Argent', 500, 1999, 'workspace_premium', '#C0C0C0', '{"cashback_rate": 0.02, "withdrawal_bonus": 0.0, "bet_discount": 0.01, "daily_bonus_multiplier": 1.1, "label": "Apprenti"}', 2, true, '#{now}', '#{now}'),
      ('gold', 'Or', 2000, 4999, 'emoji_events', '#FFD700', '{"cashback_rate": 0.03, "withdrawal_bonus": 0.01, "bet_discount": 0.02, "daily_bonus_multiplier": 1.2, "label": "Confirmé"}', 3, true, '#{now}', '#{now}'),
      ('platinum', 'Platine', 5000, 9999, 'star', '#E5E4E2', '{"cashback_rate": 0.05, "withdrawal_bonus": 0.02, "bet_discount": 0.03, "daily_bonus_multiplier": 1.5, "label": "Expert"}', 4, true, '#{now}', '#{now}'),
      ('diamond', 'Diamant', 10000, 24999, 'diamond', '#B9F2FF', '{"cashback_rate": 0.08, "withdrawal_bonus": 0.03, "bet_discount": 0.05, "daily_bonus_multiplier": 2.0, "label": "Maître"}', 5, true, '#{now}', '#{now}'),
      ('legend', 'Légende', 25000, NULL, 'military_tech', '#FF6B35', '{"cashback_rate": 0.10, "withdrawal_bonus": 0.05, "bet_discount": 0.08, "daily_bonus_multiplier": 3.0, "label": "Légende"}', 6, true, '#{now}', '#{now}')
    ON CONFLICT (tier) DO NOTHING
    """

    # ============================================================
    # Seed: Configuration plateforme par défaut
    # ============================================================
    execute """
    INSERT INTO platform_configs (category, key, value, value_type, label, description, default_value, validation_rules, is_editable, inserted_at, updated_at) VALUES
      ('payment', 'min_deposit', '500', 'integer', 'Dépôt minimum (FCFA)', 'Montant minimum pour un dépôt', '500', '{"min": 100, "max": 100000}', true, '#{now}', '#{now}'),
      ('payment', 'max_deposit', '5000000', 'integer', 'Dépôt maximum (FCFA)', 'Montant maximum pour un dépôt journalier', '5000000', '{"min": 10000, "max": 50000000}', true, '#{now}', '#{now}'),
      ('payment', 'min_withdrawal', '2000', 'integer', 'Retrait minimum (FCFA)', 'Montant minimum pour un retrait', '2000', '{"min": 500, "max": 100000}', true, '#{now}', '#{now}'),
      ('payment', 'max_withdrawal', '2000000', 'integer', 'Retrait maximum (FCFA)', 'Montant maximum pour un retrait journalier', '2000000', '{"min": 10000, "max": 50000000}', true, '#{now}', '#{now}'),
      ('payment', 'daily_withdrawal_limit', '5000000', 'integer', 'Limite journalière retraits (FCFA)', 'Total max des retraits par jour', '5000000', '{}', true, '#{now}', '#{now}'),
      ('payment', 'withdrawal_fee_percent', '0', 'float', 'Frais de retrait (%)', 'Pourcentage de frais sur les retraits', '0', '{"min": 0, "max": 10}', true, '#{now}', '#{now}'),
      ('payment', 'kyc_required_for_withdrawal', 'true', 'boolean', 'KYC requis pour retrait', 'Exiger KYC vérifié avant retrait', NULL, '{}', true, '#{now}', '#{now}'),
      ('payment', 'kyc_withdrawal_threshold', '500000', 'integer', 'Seuil KYC pour retrait (FCFA)', 'Montant au-delà duquel KYC obligatoire', '500000', '{}', true, '#{now}', '#{now}'),
      ('payment', 'auto_validate_small_withdrawals', 'true', 'boolean', 'Validation auto petits retraits', 'Validation automatique sous seuil', NULL, '{}', true, '#{now}', '#{now}'),
      ('payment', 'small_withdrawal_threshold', '50000', 'integer', 'Seuil petit retrait (FCFA)', 'Retraits sous ce seuil validés auto', '50000', '{}', true, '#{now}', '#{now}'),
      ('security', 'max_login_attempts', '5', 'integer', 'Tentatives login max', 'Nombre de tentatives avant verrouillage', '5', '{"min": 3, "max": 20}', true, '#{now}', '#{now}'),
      ('security', 'lockout_duration_minutes', '30', 'integer', 'Durée verrouillage (minutes)', 'Durée du verrouillage après échecs', '30', '{}', true, '#{now}', '#{now}'),
      ('security', 'session_timeout_minutes', '60', 'integer', 'Timeout session (minutes)', 'Inactivité avant déconnexion', '60', '{}', true, '#{now}', '#{now}'),
      ('security', 'require_2fa_admin', 'true', 'boolean', '2FA requis pour admin', 'Exiger 2FA pour les comptes admin', NULL, '{}', true, '#{now}', '#{now}'),
      ('security', 'require_otp_withdrawal', 'false', 'boolean', 'OTP requis pour retrait', 'Exiger OTP pour valider un retrait', NULL, '{}', true, '#{now}', '#{now}'),
      ('security', 'rate_limit_api_per_minute', '60', 'integer', 'Rate limit API/minute', 'Requêtes max par minute par IP', '60', '{}', true, '#{now}', '#{now}'),
      ('security', 'rate_limit_game_per_minute', '30', 'integer', 'Rate limit jeux/minute', 'Actions de jeu max par minute', '30', '{}', true, '#{now}', '#{now}'),
      ('security', 'ip_max_accounts', '3', 'integer', 'Comptes max par IP', 'Nombre max de comptes par adresse IP', '3', '{}', true, '#{now}', '#{now}'),
      ('registration', 'require_phone_verification', 'true', 'boolean', 'Vérification téléphone requise', 'Exiger vérification SMS à l''inscription', NULL, '{}', true, '#{now}', '#{now}'),
      ('registration', 'require_email_verification', 'false', 'boolean', 'Vérification email requise', 'Exiger vérification email à l''inscription', NULL, '{}', true, '#{now}', '#{now}'),
      ('registration', 'welcome_bonus_amount', '1000', 'integer', 'Bonus de bienvenue (FCFA)', 'Montant du bonus offert à l''inscription', '1000', '{"min": 0, "max": 50000}', true, '#{now}', '#{now}'),
      ('registration', 'welcome_bonus_wagering', '3', 'integer', 'Wagering bonus bienvenue', 'Nombre de mises avant retrait du bonus', '3', '{}', true, '#{now}', '#{now}'),
      ('registration', 'min_age_requirement', '18', 'integer', 'Âge minimum requis', 'Âge légal minimum pour s''inscrire', '18', '{}', true, '#{now}', '#{now}'),
      ('registration', 'allow_guest_play', 'false', 'boolean', 'Permettre jeu invité', 'Autoriser le jeu sans inscription', NULL, '{}', true, '#{now}', '#{now}'),
      ('registration', 'referral_bonus_amount', '500', 'integer', 'Bonus parrainage (FCFA)', 'Bonus pour chaque filleul inscrit', '500', '{}', true, '#{now}', '#{now}'),
      ('social', 'max_friends', '200', 'integer', 'Amis maximum', 'Nombre max d''amis par joueur', '200', '{}', true, '#{now}', '#{now}'),
      ('social', 'friend_request_cooldown_seconds', '10', 'integer', 'Cooldown demande d''ami (sec)', 'Temps minimum entre 2 demandes', '10', '{}', true, '#{now}', '#{now}'),
      ('social', 'max_daily_friend_requests', '30', 'integer', 'Demandes d''ami max/jour', 'Limite journalière de demandes', '30', '{}', true, '#{now}', '#{now}'),
      ('social', 'enable_friend_chat', 'true', 'boolean', 'Chat entre amis activé', 'Activer la messagerie entre amis', NULL, '{}', true, '#{now}', '#{now}'),
      ('social', 'max_message_length', '200', 'integer', 'Longueur max message', 'Nombre max de caractères par message', '200', '{}', true, '#{now}', '#{now}'),
      ('social', 'enable_friend_leaderboard', 'true', 'boolean', 'Classement entre amis', 'Activer le leaderboard entre amis', NULL, '{}', true, '#{now}', '#{now}'),
      ('ranking', 'leaderboard_reset_period', 'monthly', 'string', 'Période reset leaderboard', 'Fréquence de réinitialisation', NULL, '{"options": ["daily", "weekly", "monthly", "seasonal", "never"]}', true, '#{now}', '#{now}'),
      ('ranking', 'leaderboard_top_display', '100', 'integer', 'Top affiché leaderboard', 'Nombre de joueurs affichés', '100', '{}', true, '#{now}', '#{now}'),
      ('ranking', 'leaderboard_reward_top1', '100000', 'integer', 'Récompense 1er classement (FCFA)', 'Bonus pour le 1er du leaderboard', '100000', '{}', true, '#{now}', '#{now}'),
      ('ranking', 'leaderboard_reward_top2', '50000', 'integer', 'Récompense 2e classement (FCFA)', 'Bonus pour le 2e', '50000', '{}', true, '#{now}', '#{now}'),
      ('ranking', 'leaderboard_reward_top3', '25000', 'integer', 'Récompense 3e classement (FCFA)', 'Bonus pour le 3e', '25000', '{}', true, '#{now}', '#{now}'),
      ('ranking', 'ranking_metric', 'wins', 'string', 'Métrique de classement', 'Métrique utilisée pour le classement', NULL, '{"options": ["wins", "win_rate", "total_wagered", "xp_points", "net_profit"]}', true, '#{now}', '#{now}'),
      ('gaming', 'max_concurrent_games_per_user', '3', 'integer', 'Parties simultanées max/joueur', 'Nombre max de parties en cours par joueur', '3', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'match_timeout_seconds', '300', 'integer', 'Timeout partie (secondes)', 'Durée max d''une partie avant résolution auto', '300', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'turn_timeout_seconds', '60', 'integer', 'Timeout tour (secondes)', 'Temps max pour jouer un tour', '60', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'auto_resolve_enabled', 'true', 'boolean', 'Résolution automatique', 'Résoudre auto les parties bloquées', NULL, '{}', true, '#{now}', '#{now}'),
      ('gaming', 'global_commission_rate', '0.05', 'float', 'Taux commission global', 'Taux par défaut si non configuré par jeu', '0.05', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'min_bet_global', '100', 'integer', 'Mise minimum globale (FCFA)', 'Mise minimum toutes sauf config par jeu', '100', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'max_bet_global', '1000000', 'integer', 'Mise maximum globale (FCFA)', 'Mise maximum toutes sauf config par jeu', '1000000', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'daily_loss_limit_default', '500000', 'integer', 'Limite perte journalière défaut (FCFA)', 'Limite par défaut par joueur', '500000', '{}', true, '#{now}', '#{now}'),
      ('gaming', 'daily_deposit_limit_default', '1000000', 'integer', 'Limite dépôt journalière défaut (FCFA)', 'Limite par défaut par joueur', '1000000', '{}', true, '#{now}', '#{now}'),
      ('notification', 'enable_push_notifications', 'true', 'boolean', 'Push notifications activées', 'Activer les notifications push', NULL, '{}', true, '#{now}', '#{now}'),
      ('notification', 'enable_email_notifications', 'false', 'boolean', 'Email notifications activées', 'Activer les notifications email', NULL, '{}', true, '#{now}', '#{now}'),
      ('notification', 'alert_threshold_balance_low', '1000', 'integer', 'Seuil alerte solde bas (FCFA)', 'Notifier quand solde sous ce seuil', '1000', '{}', true, '#{now}', '#{now}'),
      ('notification', 'webhook_url', '', 'string', 'Webhook URL', 'URL pour webhooks externes (Slack, Discord, etc.)', NULL, '{}', true, '#{now}', '#{now}'),
      ('notification', 'slack_webhook_url', '', 'string', 'Slack Webhook URL', 'URL webhook Slack pour alertes admin', NULL, '{}', true, '#{now}', '#{now}')
    ON CONFLICT (category, key) DO NOTHING
    """
  end
end
