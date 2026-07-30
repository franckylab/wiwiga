# ==================================
# WIWIGA - Migration Friendships
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Table friendships - gestion des relations d'amis

defmodule GameHub.Repo.Migrations.CreateFriendships do
  use Ecto.Migration

  def up do
    create table(:friendships, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, :bigint, null: false
      add :friend_id, :bigint, null: false
      add :status, :string, null: false, default: "pending"
      # pending | accepted | blocked

      timestamps()
    end

    create unique_index(:friendships, [:user_id, :friend_id])
    create index(:friendships, [:friend_id, :status])
    create index(:friendships, [:user_id, :status])
  end

  def down do
    drop table(:friendships)
  end
end
