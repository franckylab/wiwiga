defmodule GameHub.Repo.Migrations.CreateAppFeatureConfigs do
  use Ecto.Migration

  def change do
    create table(:app_feature_configs, primary_key: false) do
      add :id, :bigint, primary_key: true
      
      # Mode maintenance et inscriptions
      add :maintenance_mode, :boolean, default: false
      add :maintenance_message, :text, default: "WIWIGA est en maintenance. Veuillez réessayer plus tard."
      add :registration_enabled, :boolean, default: true
      
      # Paramètres de dépôt
      add :min_deposit_amount, :integer, default: 500
      add :max_deposit_amount, :integer, default: 1_000_000
      
      # Paramètres de retrait
      add :min_withdrawal_amount, :integer, default: 1_000
      add :max_withdrawal_amount, :integer, default: 5_000_000
      
      # KYC
      add :kyc_required_threshold, :integer, default: 100_000
      
      # Limites utilisateur
      add :max_games_per_user, :integer, default: 10
      
      # Timeouts
      add :websocket_timeout_ms, :integer, default: 30_000
      add :session_timeout_ms, :integer, default: 1_800_000  # 30 minutes
      add :reality_check_interval_ms, :integer, default: 1_800_000  # 30 minutes
      
      # Auto-exclusion (heures)
      add :self_exclusion_options, {:array, :integer}, default: [24, 168, 720]  # 1j, 7j, 30j
      
      # Contact et URLs
      add :support_email, :string, default: "support@wiwiga.cm"
      add :support_phone, :string, default: "+237 600 000 000"
      add :terms_url, :string, default: "https://wiwiga.cm/terms"
      add :privacy_url, :string, default: "https://wiwiga.cm/privacy"
      
      add :updated_by, references(:users, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:app_feature_configs, [:updated_by])
    
    # Singleton
    execute """
      CREATE UNIQUE INDEX app_feature_configs_singleton_idx ON app_feature_configs ((1))
    """
  end
end
