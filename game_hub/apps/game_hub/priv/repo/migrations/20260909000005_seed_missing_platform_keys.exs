# ==================================
# WIWIGA - Migration seeds clés lues mais jamais seedées
# ==================================
# Plusieurs clés platform_configs sont lues avec fallback dur sans
# jamais avoir été seedées (invisibles/non éditables en admin).
# Insertion idempotente (ON CONFLICT DO NOTHING).

defmodule GameHub.Repo.Migrations.SeedMissingPlatformKeys do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO platform_configs (category, key, value, value_type, label, description, default_value, is_editable, inserted_at, updated_at) VALUES
      ('gaming', 'default_daily_loss_limit', '500000', 'integer', 'Perte nette / jour par défaut (jetons)', 'Repli quand l''utilisateur n''a pas de limite', '500000', true, NOW(), NOW()),
      ('gaming', 'default_session_time_minutes', '120', 'integer', 'Session par défaut (minutes)', 'Repli quand l''utilisateur n''a pas de limite', '120', true, NOW(), NOW()),
      ('gaming', 'reality_check_interval_minutes', '30', 'integer', 'Rappel réalité (minutes)', 'Repli quand l''utilisateur n''a pas de limite', '30', true, NOW(), NOW()),
      ('payment', 'daily_gift_limit', '10000', 'integer', 'Cadeaux / jour (jetons)', 'Plafond d''envoi de cadeaux par utilisateur et par jour', '10000', true, NOW(), NOW())
    ON CONFLICT (category, key) DO NOTHING
    """
  end

  def down, do: :ok
end
