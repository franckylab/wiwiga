# ==================================
# WIWIGA - Migration Responsible Gaming v2
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Limites manquantes + canonisation des clés PlatformConfig.
#   - responsible_gaming_limits : daily_wager_limit (total misé/jour),
#     max_bet_amount (mise max par coup), daily_matches_limit (participations
#     payantes/jour), pending_config + pending_effective_at (hausses différées
#     24h, baisse immédiate — standard jeu responsable).
#   - platform_configs : crée les clés canoniques lues par le code
#     (default_daily_deposit_limit, default_daily_wager_limit,
#     default_daily_matches_limit) et supprime les doublons historiques
#     (daily_loss_limit_default, daily_deposit_limit_default,
#     max_bet_global, min_bet_global) jamais lus par le code.

defmodule GameHub.Repo.Migrations.ResponsibleGamingLimitsV2 do
  use Ecto.Migration

  def up do
    alter table(:responsible_gaming_limits) do
      add :daily_wager_limit, :bigint
      add :max_bet_amount, :bigint
      add :daily_matches_limit, :integer
      add :pending_config, :map, default: %{}
      add :pending_effective_at, :utc_datetime
    end

    execute """
      ALTER TABLE responsible_gaming_limits
      ADD CONSTRAINT daily_wager_positive CHECK (daily_wager_limit IS NULL OR daily_wager_limit > 0)
    """

    execute """
      ALTER TABLE responsible_gaming_limits
      ADD CONSTRAINT max_bet_positive CHECK (max_bet_amount IS NULL OR max_bet_amount > 0)
    """

    execute """
      ALTER TABLE responsible_gaming_limits
      ADD CONSTRAINT daily_matches_positive CHECK (daily_matches_limit IS NULL OR daily_matches_limit > 0)
    """

    # Clés canoniques lues par ResponsibleGaming (jamais de doublons) —
    # valeurs reprises des doublons historiques quand présents.
    execute """
      INSERT INTO platform_configs
        (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at)
      SELECT 'gaming', 'default_daily_deposit_limit',
        COALESCE((SELECT value FROM platform_configs WHERE category = 'gaming' AND key = 'daily_deposit_limit_default'), '1000000'),
        'integer', 'Dépôt quotidien max (défaut)', 'Limite de dépôt quotidienne par défaut (jetons)',
        '1000000', true, NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE category = 'gaming' AND key = 'default_daily_deposit_limit')
    """

    execute """
      INSERT INTO platform_configs
        (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at)
      SELECT 'gaming', 'default_daily_wager_limit', '25000',
        'integer', 'Mises quotidiennes max (défaut)', 'Total misé par jour par défaut (jetons)',
        '25000', true, NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE category = 'gaming' AND key = 'default_daily_wager_limit')
    """

    execute """
      INSERT INTO platform_configs
        (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at)
      SELECT 'gaming', 'default_daily_matches_limit', '20',
        'integer', 'Parties quotidiennes max (défaut)', 'Participations payantes par jour par défaut',
        '20', true, NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE category = 'gaming' AND key = 'default_daily_matches_limit')
    """

    # Supprime les doublons historiques (aucun code ne les lit).
    execute """
      DELETE FROM platform_configs
      WHERE category = 'gaming'
        AND key IN ('daily_loss_limit_default', 'daily_deposit_limit_default', 'max_bet_global', 'min_bet_global')
    """

    # Resynchronise le drapeau `users.self_excluded` avec les exclusions
    # actives de `responsible_gaming_limits` (double source unifiée).
    execute """
      UPDATE users
      SET self_excluded = true
      WHERE id IN (
        SELECT user_id FROM responsible_gaming_limits
        WHERE self_exclusion_until IS NOT NULL
          AND self_exclusion_until > NOW()
      )
    """
  end

  def down do
    execute """
      ALTER TABLE responsible_gaming_limits
      DROP CONSTRAINT IF EXISTS daily_wager_positive
    """

    execute """
      ALTER TABLE responsible_gaming_limits
      DROP CONSTRAINT IF EXISTS max_bet_positive
    """

    execute """
      ALTER TABLE responsible_gaming_limits
      DROP CONSTRAINT IF EXISTS daily_matches_positive
    """

    alter table(:responsible_gaming_limits) do
      remove :daily_wager_limit
      remove :max_bet_amount
      remove :daily_matches_limit
      remove :pending_config
      remove :pending_effective_at
    end

    execute """
      DELETE FROM platform_configs
      WHERE category = 'gaming'
        AND key IN ('default_daily_deposit_limit', 'default_daily_wager_limit', 'default_daily_matches_limit')
    """

    execute """
      INSERT INTO platform_configs
        (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at)
      SELECT 'gaming', key, value, 'integer', key, key, value, true, NOW(), NOW()
      FROM (VALUES
        ('daily_loss_limit_default', '5000'),
        ('daily_deposit_limit_default', '10000'),
        ('max_bet_global', '10000'),
        ('min_bet_global', '1')
      ) AS legacy(key, value)
      WHERE NOT EXISTS (
        SELECT 1 FROM platform_configs WHERE category = 'gaming' AND key = legacy.key
      )
    """
  end
end
