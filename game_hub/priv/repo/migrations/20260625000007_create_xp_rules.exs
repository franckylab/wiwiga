defmodule GameHub.Repo.Migrations.CreateXPRules do
  use Ecto.Migration

  def change do
    create table(:xp_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_type, :string, null: false
      add :win_xp, :integer, default: 50
      add :loss_xp, :integer, default: 10
      add :draw_xp, :integer, default: 25
      add :participation_xp, :integer, default: 5
      add :streak_bonus, :integer, default: 5
      add :max_streak_bonus, :integer, default: 50
      add :xp_multiplier, :float, default: 1.0
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:xp_rules, [:game_type])
    create index(:xp_rules, [:is_active])

    # Seed: règles XP par défaut pour les 3 types de jeux
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute """
    INSERT INTO xp_rules (id, game_type, win_xp, loss_xp, draw_xp, participation_xp, streak_bonus, max_streak_bonus, xp_multiplier, is_active, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'dice', 50, 10, 25, 5, 5, 50, 1.0, true, '#{now}', '#{now}'),
      (gen_random_uuid(), 'ludo', 30, 5, 15, 5, 3, 30, 1.0, true, '#{now}', '#{now}'),
      (gen_random_uuid(), 'cards', 40, 10, 20, 5, 5, 50, 1.0, true, '#{now}', '#{now}')
    """
  end
end
