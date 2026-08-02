# ==================================
# WIWIGA - Migration Auth Fields
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260801000008_add_auth_fields_to_users.exs
# Description: Ajout des champs d'authentification multi-méthodes
#              et système de rôles RBAC

defmodule GameHub.Repo.Migrations.AddAuthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Auth multi-méthodes
      add :email, :string
      add :username, :string, null: false, default: ""
      add :password_hash, :string

      # Système de rôles RBAC
      add :role, :string, null: false, default: "user"

      # Avatars
      add :avatar_type, :string, null: false, default: "default"
      add :avatar_url, :string

      # Tracking connexion
      add :last_login_at, :utc_datetime
      add :login_count, :integer, default: 0, null: false
    end

    # Index unique sur email (nullable)
    create unique_index(:users, [:email], where: "email IS NOT NULL")

    # Index unique sur username (après avoir assigné des usernames uniques)
    # On utilise execute pour gérer le before/after
    execute(
      # Forward: assigner des usernames uniques aux utilisateurs existants
      """
      UPDATE users SET username = 'player_' || id::text
      WHERE username = '' OR username IS NULL
      """,
      # Rollback: remettre username vide
      """
      UPDATE users SET username = ''
      WHERE username LIKE 'player_%'
      """
    )

    create unique_index(:users, [:username])

    # Index sur role pour filtrage admin
    create index(:users, [:role])
  end
end
