defmodule GameHub.Repo.Migrations.CreatePlatformConfigs do
  use Ecto.Migration

  def change do
    create table(:platform_configs) do
      add :category, :string, null: false
      add :key, :string, null: false
      add :value, :text
      add :value_type, :string, default: "string"
      add :label, :string
      add :description, :text
      add :default_value, :text
      add :validation_rules, :map, default: %{}
      add :is_editable, :boolean, default: true
      add :updated_by, :integer
      timestamps()
    end

    create unique_index(:platform_configs, [:category, :key])
    create index(:platform_configs, [:category])

    # ========================================
    # Données par défaut — 7 catégories
    # ========================================

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    configs = [
      # --- PAYMENT ---
      %{category: "payment", key: "min_deposit", value: "500", value_type: "integer",
        label: "Dépôt minimum (FCFA)", description: "Montant minimum de dépôt", default_value: "500"},
      %{category: "payment", key: "max_deposit", value: "5000000", value_type: "integer",
        label: "Dépôt maximum (FCFA)", description: "Montant maximum de dépôt", default_value: "5000000"},
      %{category: "payment", key: "min_withdrawal", value: "2000", value_type: "integer",
        label: "Retrait minimum (FCFA)", description: "Montant minimum de retrait", default_value: "2000"},
      %{category: "payment", key: "max_withdrawal", value: "2000000", value_type: "integer",
        label: "Retrait maximum journalier (FCFA)", description: "Montant max de retrait par jour", default_value: "2000000"},
      %{category: "payment", key: "withdrawal_fee_percent", value: "0", value_type: "float",
        label: "Frais de retrait (%)", description: "Pourcentage de frais sur chaque retrait", default_value: "0"},
      %{category: "payment", key: "kyc_required_for_withdrawal", value: "true", value_type: "boolean",
        label: "KYC requis pour retrait", description: "Exiger KYC complet avant retrait", default_value: "true"},
      %{category: "payment", key: "kyc_withdrawal_threshold", value: "500000", value_type: "integer",
        label: "Seuil KYC (FCFA)", description: "Montant à partir duquel le KYC est obligatoire", default_value: "500000"},

      # --- SECURITY ---
      %{category: "security", key: "rate_limit_api_per_minute", value: "60", value_type: "integer",
        label: "Rate limit API/min", description: "Nombre max de requêtes API par minute", default_value: "60"},
      %{category: "security", key: "rate_limit_game_per_minute", value: "30", value_type: "integer",
        label: "Rate limit jeu/min", description: "Nombre max de requêtes jeu par minute", default_value: "30"},
      %{category: "security", key: "max_login_attempts", value: "5", value_type: "integer",
        label: "Max tentatives login", description: "Nombre max de tentatives avant verrouillage", default_value: "5"},
      %{category: "security", key: "lockout_duration_minutes", value: "15", value_type: "integer",
        label: "Durée verrouillage (min)", description: "Durée du verrouillage après échecs", default_value: "15"},
      %{category: "security", key: "session_max_age_days", value: "30", value_type: "integer",
        label: "Durée session max (jours)", description: "Nombre de jours avant expiration session", default_value: "30"},

      # --- REGISTRATION ---
      %{category: "registration", key: "registration_enabled", value: "true", value_type: "boolean",
        label: "Inscription activée", description: "Autoriser les nouvelles inscriptions", default_value: "true"},
      %{category: "registration", key: "require_phone_verification", value: "true", value_type: "boolean",
        label: "Vérification phone requise", description: "Exiger vérification OTP du numéro", default_value: "true"},
      %{category: "registration", key: "minimum_age", value: "18", value_type: "integer",
        label: "Âge minimum", description: "Âge minimum pour s'inscrire", default_value: "18"},
      %{category: "registration", key: "welcome_bonus_amount", value: "1000", value_type: "integer",
        label: "Bonus de bienvenue (FCFA)", description: "Montant offert à l'inscription", default_value: "1000"},
      %{category: "registration", key: "welcome_bonus_wagering", value: "3", value_type: "integer",
        label: "Wagering bonus (x)", description: "Nombre de mises avant retrait du bonus", default_value: "3"},

      # --- SOCIAL ---
      %{category: "social", key: "max_friends", value: "200", value_type: "integer",
        label: "Nombre max d'amis", description: "Limite d'amis par utilisateur", default_value: "200"},
      %{category: "social", key: "chat_enabled", value: "true", value_type: "boolean",
        label: "Chat activé", description: "Activer le chat entre amis", default_value: "true"},
      %{category: "social", key: "activity_feed_enabled", value: "true", value_type: "boolean",
        label: "Feed d'activité activé", description: "Afficher le feed d'activité des amis", default_value: "true"},
      %{category: "social", key: "friend_request_cooldown", value: "60", value_type: "integer",
        label: "Cooldown demande d'ami (s)", description: "Temps minimum entre 2 demandes", default_value: "60"},

      # --- RANKING ---
      %{category: "ranking", key: "leaderboard_reward_top1", value: "100000", value_type: "integer",
        label: "Récompense #1 (FCFA)", description: "Récompense pour la 1ère place", default_value: "100000"},
      %{category: "ranking", key: "leaderboard_reward_top2", value: "50000", value_type: "integer",
        label: "Récompense #2 (FCFA)", description: "Récompense pour la 2ème place", default_value: "50000"},
      %{category: "ranking", key: "leaderboard_reward_top3", value: "25000", value_type: "integer",
        label: "Récompense #3 (FCFA)", description: "Récompense pour la 3ème place", default_value: "25000"},
      %{category: "ranking", key: "leaderboard_season_days", value: "30", value_type: "integer",
        label: "Durée saison (jours)", description: "Nombre de jours par saison de classement", default_value: "30"},

      # --- GAMING ---
      %{category: "gaming", key: "default_daily_loss_limit", value: "500000", value_type: "integer",
        label: "Perte quotidienne max (FCFA)", description: "Limite de perte quotidienne par défaut", default_value: "500000"},
      %{category: "gaming", key: "default_session_time_minutes", value: "120", value_type: "integer",
        label: "Durée session max (min)", description: "Durée max d'une session de jeu", default_value: "120"},
      %{category: "gaming", key: "max_bet_per_round", value: "1000000", value_type: "integer",
        label: "Mise max par round (FCFA)", description: "Mise maximum autorisée par round", default_value: "1000000"},
      %{category: "gaming", key: "reality_check_interval_minutes", value: "30", value_type: "integer",
        label: "Intervalle rappel réalité (min)", description: "Intervalle entre les rappels de réalité", default_value: "30"},
      %{category: "gaming", key: "fallback_timeout_seconds", value: "30", value_type: "integer",
        label: "Timeout matchmaking fallback (s)", description: "Délai avant activation du fallback matchmaking", default_value: "30"},
      %{category: "gaming", key: "fallback_tolerance_pct", value: "0.20", value_type: "float",
        label: "Tolérance fallback (%)", description: "Tolérance de mise pour le fallback matchmaking", default_value: "0.20"},

      # --- NOTIFICATION ---
      %{category: "notification", key: "push_enabled", value: "true", value_type: "boolean",
        label: "Push notifications activées", description: "Activer les notifications push", default_value: "true"},
      %{category: "notification", key: "email_enabled", value: "true", value_type: "boolean",
        label: "Email notifications activées", description: "Activer les notifications email", default_value: "true"},
      %{category: "notification", key: "webhook_enabled", value: "false", value_type: "boolean",
        label: "Webhooks activés", description: "Activer les webhooks pour intégrations", default_value: "false"},
      %{category: "notification", key: "alert_large_loss", value: "100000", value_type: "integer",
        label: "Alerte perte importante (FCFA)", description: "Seuil d'alerte pour perte importante", default_value: "100000"},
    ]

    Enum.each(configs, fn config ->
      execute """
        INSERT INTO platform_configs (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at)
        VALUES ('#{config.category}', '#{config.key}', '#{config.value}', '#{config.value_type}', '#{config.label}', '#{config.description}', '#{config.default_value}', true, '#{naive_datetime(now)}', '#{naive_datetime(now)}')
        ON CONFLICT (category, key) DO NOTHING
      """
    end)
  end

  defp naive_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
end
