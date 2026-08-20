defmodule GameHub.Repo.Migrations.CreateAdminNotifications do
  use Ecto.Migration

  def change do
    create table(:admin_notifications) do
      add :type, :string, default: "info", null: false
      add :title, :string
      add :message, :string
      add :target_type, :string, default: "admin"
      add :target_id, :integer
      add :is_read, :boolean, default: false
      add :read_at, :utc_datetime
      add :created_by, :integer

      timestamps()
    end

    create index(:admin_notifications, [:type])
    create index(:admin_notifications, [:is_read])
    create index(:admin_notifications, [:inserted_at])
  end
end
