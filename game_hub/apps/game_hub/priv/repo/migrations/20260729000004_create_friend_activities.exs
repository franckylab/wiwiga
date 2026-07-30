# ==================================
# WIWIGA - Migration Friend Activities
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Table friend_activities - feed d'activité des amis

defmodule GameHub.Repo.Migrations.CreateFriendActivities do
  use Ecto.Migration

  def up do
    create table(:friend_activities, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, :bigint, null: false
      add :action, :string, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:friend_activities, [:user_id, :inserted_at])
    create index(:friend_activities, [:action])
  end

  def down do
    drop table(:friend_activities)
  end
end
