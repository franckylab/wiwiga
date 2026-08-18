# ==================================
# WIWIGA - Migration Alert Thresholds
# ==================================
# Migration: 20260825000004_add_alert_thresholds.exs

defmodule GameHub.Repo.Migrations.AddAlertThresholds do
  use Ecto.Migration

  def up do
    create table(:alert_thresholds) do
      add :name, :string
      add :metric_key, :string, null: false
      add :threshold_value, :float, null: false
      add :comparison, :string, null: false, default: "gt"
      add :severity, :string, null: false, default: "warning"
      add :is_enabled, :boolean, default: true
      add :description, :text

      timestamps()
    end

    create unique_index(:alert_thresholds, [:metric_key])
    create index(:alert_thresholds, [:is_enabled])

    # Insérer les seuils par défaut
    execute """
    INSERT INTO alert_thresholds (name, metric_key, threshold_value, comparison, severity, is_enabled, inserted_at, updated_at) VALUES
    ('Auth échouées 1h', 'failed_auths_1h', 10, 'gt', 'warning', true, NOW(), NOW()),
    ('Latence DB critique', 'db_latency_ms', 500, 'gt', 'critical', true, NOW(), NOW()),
    ('Latence DB warning', 'db_latency_ms_warning', 100, 'gt', 'warning', true, NOW(), NOW()),
    ('Erreurs paiement 1h', 'payment_errors_1h', 5, 'gt', 'warning', true, NOW(), NOW()),
    ('Parties actives max', 'active_games', 500, 'gt', 'warning', true, NOW(), NOW())
    """
  end

  def down do
    drop table(:alert_thresholds)
  end
end
