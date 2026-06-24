# ==================================
# WIWIGA - Migration Responsible Gaming Limits
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Repo.Migrations.CreateResponsibleGamingLimits do
  use Ecto.Migration

  def up do
    create table(:responsible_gaming_limits, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :daily_deposit_limit, :bigint
      add :daily_loss_limit, :bigint
      add :weekly_loss_limit, :bigint
      add :monthly_loss_limit, :bigint
      add :session_time_limit_minutes, :integer, default: 120
      add :reality_check_interval_minutes, :integer, default: 30
      add :self_exclusion_until, :utc_datetime
      add :self_exclusion_reason, :text
      add :cooling_off_until, :utc_datetime
      add :is_active, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:responsible_gaming_limits, [:user_id])
    create index(:responsible_gaming_limits, [:self_exclusion_until])
    create index(:responsible_gaming_limits, [:is_active])

    # Contraintes CHECK
    execute """
      ALTER TABLE responsible_gaming_limits
      ADD CONSTRAINT session_time_positive CHECK (session_time_limit_minutes > 0)
    """

    execute """
      ALTER TABLE responsible_gaming_limits
      ADD CONSTRAINT reality_check_positive CHECK (reality_check_interval_minutes > 0)
    """
  end

  def down do
    drop table(:responsible_gaming_limits)
  end
end
