# ==================================
# WIWIGA - Migration lien deliveries ↔ jobs Oban
# ==================================

defmodule GameHub.Repo.Migrations.AddObanJobIdToDeliveries do
  use Ecto.Migration

  def up do
    alter table(:notification_deliveries) do
      add :oban_job_id, :bigint
    end

    create index(:notification_deliveries, [:oban_job_id])
  end

  def down do
    drop index(:notification_deliveries, [:oban_job_id])

    alter table(:notification_deliveries) do
      remove :oban_job_id
    end
  end
end
