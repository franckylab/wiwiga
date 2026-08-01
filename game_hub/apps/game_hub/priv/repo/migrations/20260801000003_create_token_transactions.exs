# ==================================
# WIWIGA - Migration Token Transactions
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.CreateTokenTransactions
# Description: Table des transactions de jetons virtuels

defmodule GameHub.Repo.Migrations.CreateTokenTransactions do
  use Ecto.Migration

  def change do
    create table(:token_transactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # Type de transaction
      # purchase: achat jetons (monnaie → jetons)
      # exchange: échange jetons (jetons → monnaie)
      # bet: mise de jeu (débit jetons)
      # winnings: gains (crédit jetons)
      # transfer_out: transfert sortant
      # transfer_in: transfert entrant
      # gift_sent: cadeau envoyé
      # gift_received: cadeau reçu
      # promo_credit: crédit promotionnel
      # promo_debit: débit promotionnel
      # commission: commission plateforme
      add :type, :string, null: false

      # Montant en jetons (positif = crédit, négatif = débit)
      add :token_amount, :integer, null: false

      # Soldes avant/après
      add :balance_before, :integer, null: false
      add :balance_after, :integer, null: false

      # Valeur monétaire associée (en centimes, nullable)
      add :monetary_value, :integer

      # Taux de conversion appliqué (si applicable)
      add :exchange_rate, :float

      # Contrepartie (pour transferts/cadeaux)
      add :counterparty_id, references(:users, on_delete: :nilify_all)

      # Référence promo (si applicable)
      add :promo_id, :integer

      # Clé idempotence
      add :idempotency_key, :string, null: false

      # Métadonnées (JSON flexible)
      add :metadata, :map, default: %{}

      # Référence jeu
      add :game_id, :string

      # Statut
      add :status, :string, default: "completed", null: false

      timestamps()
    end

    # Index
    create index(:token_transactions, [:user_id])
    create index(:token_transactions, [:user_id, :type])
    create index(:token_transactions, [:user_id, :inserted_at])
    create unique_index(:token_transactions, [:idempotency_key])
    create index(:token_transactions, [:counterparty_id])
    create index(:token_transactions, [:type])
  end
end
