# ==================================
# WIWIGA - Migration Wallet Transactions
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260623000002_create_wallet_transactions.exs

defmodule GameHub.Repo.Migrations.CreateWalletTransactions do
  use Ecto.Migration
  
  def up do
    create table(:wallet_transactions, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :type, :string, null: false
      add :amount, :bigint, null: false
      add :balance_before, :bigint, null: false
      add :balance_after, :bigint, null: false
      add :idempotency_key, :string, null: false
      add :metadata, :map
      add :game_id, :string
      add :payment_provider, :string
      add :provider_transaction_id, :string
      
      timestamps()
    end
    
    # Index foreign key
    create index(:wallet_transactions, [:user_id])
    
    # Index unique idempotence
    create unique_index(:wallet_transactions, [:idempotency_key])
    
    # Index pour recherche par type
    create index(:wallet_transactions, [:type])
    
    # Index composite pour historique utilisateur
    create index(:wallet_transactions, [:user_id, :inserted_at])
    
    # Index pour provider transactions
    create index(:wallet_transactions, [:payment_provider, :provider_transaction_id])
  end
  
  def down do
    drop table(:wallet_transactions)
  end
end
