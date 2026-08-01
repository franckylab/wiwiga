# ==================================
# WIWIGA - Migration User Promo Tokens
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.CreateUserPromoTokens
# Description: Tracking des promos réclamées par utilisateur

defmodule GameHub.Repo.Migrations.CreateUserPromoTokens do
  use Ecto.Migration

  def change do
    create table(:user_promo_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :promo_token_id, references(:promo_tokens, on_delete: :delete_all), null: false

      # Jetons crédités au total
      add :tokens_credited, :integer, null: false

      # Jetons restants (si utilisation partielle avec conditions)
      add :tokens_remaining, :integer, null: false

      # Les conditions d'utilisation sont-elles remplies?
      add :conditions_met, :boolean, default: false, null: false

      # Date de réclamation
      add :redeemed_at, :utc_datetime, null: false

      # Date d'expiration
      add :expires_at, :utc_datetime

      timestamps()
    end

    # Index
    create index(:user_promo_tokens, [:user_id])
    create index(:user_promo_tokens, [:promo_token_id])

    # Un utilisateur ne peut réclamer une promo qu'une seule fois
    create unique_index(:user_promo_tokens, [:user_id, :promo_token_id])

    # Contraintes
    create constraint(:user_promo_tokens, :tokens_credited_positive, check: "tokens_credited > 0")
    create constraint(:user_promo_tokens, :tokens_remaining_non_negative, check: "tokens_remaining >= 0")
  end
end
