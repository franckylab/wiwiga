# ==================================
# WIWIGA - Migration routage événements → canaux
# ==================================
# Chaque événement notifiable est activable/désactivable et
# routé vers N canaux depuis l'admin (plus rien en dur).

defmodule GameHub.Repo.Migrations.CreateNotificationRouting do
  use Ecto.Migration

  def up do
    create table(:notification_routing_rules, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :event_key, :string, null: false
      add :channels, {:array, :string}, default: ["in_app"], null: false
      add :is_active, :boolean, default: true, null: false
      add :created_by, :integer
      timestamps()
    end

    create unique_index(:notification_routing_rules, [:event_key])
  end

  def down do
    drop table(:notification_routing_rules)
  end
end
