# ==================================
# WIWIGA - Migration Friend Messages
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Table friend_messages - chat entre amis

defmodule GameHub.Repo.Migrations.CreateFriendMessages do
  use Ecto.Migration

  def up do
    create table(:friend_messages, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :sender_id, :bigint, null: false
      add :receiver_id, :bigint, null: false
      add :content, :text
      add :emoji_type, :string
      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:friend_messages, [:sender_id, :receiver_id])
    create index(:friend_messages, [:receiver_id, :read_at])
    create index(:friend_messages, [:inserted_at])
  end

  def down do
    drop table(:friend_messages)
  end
end
