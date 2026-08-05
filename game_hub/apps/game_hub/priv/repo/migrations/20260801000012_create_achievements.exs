# ==================================
# WIWIGA - Migration Achievements
# ==================================
# Tables achievements (définitions) + user_achievements (unlock)

defmodule GameHub.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    create table(:achievements) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text, null: false
      add :icon, :string, default: "star", null: false
      add :tier, :string, default: "bronze", null: false
      add :condition_type, :string, null: false
      add :condition_value, :integer, null: false
      add :xp_reward, :integer, default: 0, null: false

      timestamps()
    end

    create unique_index(:achievements, [:code])

    create table(:user_achievements) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :achievement_id, references(:achievements, on_delete: :delete_all), null: false
      add :unlocked_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:user_achievements, [:user_id, :achievement_id])
    create index(:user_achievements, [:user_id])
  end
end
