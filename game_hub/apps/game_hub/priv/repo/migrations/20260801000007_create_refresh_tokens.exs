# ==================================
# WIWIGA - Migration Refresh Tokens
# ==================================
# Migration: 20260801000007_create_refresh_tokens.exs
# Description: Table des refresh tokens pour JWT rotation

defmodule GameHub.Repo.Migrations.CreateRefreshTokens do
  use Ecto.Migration

  def change do
    create table(:refresh_tokens, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :device_id, :string
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :replaced_by_id, :bigint
      add :ip_address, :string
      add :user_agent, :string
      
      timestamps()
    end
    
    # Index unique sur le hash du token
    create unique_index(:refresh_tokens, [:token_hash])
    
    # Index pour recherche par utilisateur
    create index(:refresh_tokens, [:user_id])
    
    # Index pour recherche par device
    create index(:refresh_tokens, [:device_id])
    
    # Index pour nettoyage des tokens expirés
    create index(:refresh_tokens, [:expires_at])
    
    # Index pour tokens actifs non révoqués
    create index(:refresh_tokens, [:user_id, :revoked_at],
      where: "revoked_at IS NULL"
    )
  end
end
