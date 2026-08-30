# ==================================
# WIWIGA - Migration XP Rules
# ==================================
# Table: xp_rules - regles XP par type de jeu (manquante, cause 500 /api/admin/xp-rules)
# Fix: 500 Internal Server Error sur GET /api/admin/xp-rules

defmodule GameHub.Repo.Migrations.CreateXpRules do
  use Ecto.Migration

  def up do
    create table(:xp_rules) do
      add :game_type, :string, null: false
      add :win_xp, :integer, null: false, default: 50
      add :loss_xp, :integer, null: false, default: 10
      add :draw_xp, :integer, null: false, default: 25
      add :participation_xp, :integer, null: false, default: 5
      add :streak_bonus, :integer, null: false, default: 5
      add :max_streak_bonus, :integer, null: false, default: 50
      add :xp_multiplier, :float, null: false, default: 1.0
      add :is_active, :boolean, null: false, default: true
      timestamps()
    end

    create unique_index(:xp_rules, [:game_type])

    # Seed defaults (idempotent)
    now = NaiveDateTime.utc_now(:second)
    execute """
    INSERT INTO xp_rules (game_type, win_xp, loss_xp, draw_xp, participation_xp, streak_bonus, max_streak_bonus, xp_multiplier, is_active, inserted_at, updated_at)
    VALUES
      ('dice', 50, 10, 25, 5, 5, 50, 1.0, true, '#{now}', '#{now}'),
      ('ludo', 30, 5, 15, 5, 5, 50, 1.0, true, '#{now}', '#{now}'),
      ('cards', 40, 10, 20, 5, 5, 50, 1.0, true, '#{now}', '#{now}')
    ON CONFLICT (game_type) DO NOTHING
    """
  end

  def down do
    drop table(:xp_rules)
  end
end
