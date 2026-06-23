# ==================================
# WIWIGA - Migration Users
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260623000001_create_users.exs

defmodule GameHub.Repo.Migrations.CreateUsers do
  use Ecto.Migration
  
  def up do
    create table(:users, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :phone, :string, null: false
      add :name, :string
      add :balance, :bigint, default: 0, null: false
      add :is_active, :boolean, default: true, null: false
      add :has_verified_kyc, :boolean, default: false, null: false
      add :self_excluded, :boolean, default: false, null: false
      add :daily_deposit_limit, :bigint, default: 1_000_000
      add :daily_loss_limit, :bigint, default: 500_000
      
      timestamps()
    end
    
    # Index unique sur phone
    create unique_index(:users, [:phone])
    
    # Index pour requêtes actives
    create index(:users, [:is_active])
    
    # Vérification balance >= 0
    execute """
      ALTER TABLE users 
      ADD CONSTRAINT check_balance_positive 
      CHECK (balance >= 0)
    """
  end
  
  def down do
    drop table(:users)
  end
end
