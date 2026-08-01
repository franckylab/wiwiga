# ==================================
# WIWIGA - Migration Promo Tokens
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.CreatePromoTokens
# Description: Offres de jetons promotionnels

defmodule GameHub.Repo.Migrations.CreatePromoTokens do
  use Ecto.Migration

  def change do
    create table(:promo_tokens) do
      # Nom de l'offre
      add :name, :string, null: false

      # Description
      add :description, :text

      # Nombre de jetons offerts
      add :token_amount, :integer, null: false

      # Conditions d'utilisation (JSON)
      # Exemples:
      # %{
      #   "min_games" => 5,          # nombre minimum de parties à jouer
      #   "game_type" => "dice",     # restriction type de jeu
      #   "expiry_days" => 30,       # jours avant expiration
      #   "min_bet" => 100,          # mise minimum requise
      #   "wagering_multiplier" => 3 # multiplicateur de mise requis
      # }
      add :conditions, :map, default: %{}

      # Activation
      add :is_active, :boolean, default: true, null: false

      # Limites de réclamations
      add :max_redemptions, :integer
      add :current_redemptions, :integer, default: 0, null: false

      # Période de validité
      add :valid_from, :utc_datetime, null: false
      add :valid_until, :utc_datetime

      # Créateur
      add :created_by, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    # Index
    create index(:promo_tokens, [:is_active])
    create index(:promo_tokens, [:valid_from, :valid_until])
    create index(:promo_tokens, [:created_by])

    # Contraintes
    create constraint(:promo_tokens, :token_amount_positive, check: "token_amount > 0")
    create constraint(:promo_tokens, :current_redemptions_non_negative, check: "current_redemptions >= 0")
  end
end
