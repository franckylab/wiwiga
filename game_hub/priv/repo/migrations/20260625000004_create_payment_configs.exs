defmodule GameHub.Repo.Migrations.CreatePaymentConfigs do
  use Ecto.Migration

  def change do
    create table(:payment_configs) do
      add :provider, :string, null: false  # "campay", "mtn_momo", "orange_money"
      add :enabled, :boolean, default: true
      
      # Paramètres de montant
      add :min_amount, :integer, default: 500
      add :max_amount, :integer, default: 1_000_000
      
      # Configuration API (chiffrée en production)
      add :api_key, :string
      add :api_secret, :string
      add :api_url, :string
      add :webhook_url, :string
      
      # Paramètres spécifiques (JSON)
      add :provider_settings, :map, default: %{}
      # Exemple pour Campay:
      # %{
      #   "timeout_ms" => 30000,
      #   "retry_attempts" => 3,
      #   "callback_url" => "https://wiwiga.cm/api/webhooks/campay"
      # }
      
      # Frais
      add :transaction_fee_percentage, :float, default: 0.0
      add :transaction_fee_fixed, :integer, default: 0
      
      add :updated_by, references(:users, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:payment_configs, [:provider], unique: true)
    create index(:payment_configs, [:enabled])
    create index(:payment_configs, [:updated_by])
    
    # Constraints
    create constraint(:payment_configs, :min_amount_positive, check: "min_amount > 0")
    create constraint(:payment_configs, :max_amount_positive, check: "max_amount > 0")
    create constraint(:payment_configs, :max_amount_gte_min, check: "max_amount >= min_amount")
    create constraint(:payment_configs, :fee_percentage_valid, check: "transaction_fee_percentage >= 0 AND transaction_fee_percentage <= 1")
  end
end
