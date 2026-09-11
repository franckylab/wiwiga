# ==================================
# WIWIGA - Migration liste de suppression (consentement)
# ==================================
# STOP SMS, bounces/plaintes SES : ne jamais recontacter
# (sauf réinscription explicite). Lignes immuables (audit).

defmodule GameHub.Repo.Migrations.CreateNotificationSuppressions do
  use Ecto.Migration

  def up do
    create table(:notification_suppressions, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :channel, :string, null: false
      add :value, :string, null: false
      add :reason, :string, null: false
      add :source, :string, null: false
      add :expires_at, :utc_datetime
      timestamps(updated_at: false)
    end

    create unique_index(:notification_suppressions, [:channel, :value])
    create index(:notification_suppressions, [:channel])
    create index(:notification_suppressions, [:inserted_at])
  end

  def down do
    drop table(:notification_suppressions)
  end
end
