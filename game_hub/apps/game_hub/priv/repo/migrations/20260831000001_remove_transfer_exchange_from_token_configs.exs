# ==================================
# WIWIGA - Suppression transfert & échange
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Date: 2026-08-31
# Description: Retire définitivement les colonnes liées au transfert libre
#              et à l'échange wiga→monnaie. Seuls achat, cadeau ami et promos restent.
#              Opération brutale et irréversible comme demandé.

defmodule GameHub.Repo.Migrations.RemoveTransferExchangeFromTokenConfigs do
  use Ecto.Migration

  def up do
    # Supprimer contraintes si elles existent
    drop_if_exists constraint(:token_configs, :min_exchange_positive)
    drop_if_exists constraint(:token_configs, :max_exchange_positive)
    drop_if_exists constraint(:token_configs, :max_exchange_gte_min)
    drop_if_exists constraint(:token_configs, :exchange_fee_valid)

    alter table(:token_configs) do
      remove_if_exists :min_exchange_tokens, :integer
      remove_if_exists :max_exchange_tokens, :integer
      remove_if_exists :transfer_enabled, :boolean
      remove_if_exists :exchange_fee_percentage, :float
      remove_if_exists :exchange_fee_fixed, :integer
    end
  end

  def down do
    alter table(:token_configs) do
      add :min_exchange_tokens, :integer, default: 100, null: false
      add :max_exchange_tokens, :integer, default: 100_000, null: false
      add :transfer_enabled, :boolean, default: true, null: false
      add :exchange_fee_percentage, :float, default: 0.0
      add :exchange_fee_fixed, :integer, default: 0
    end

    create constraint(:token_configs, :min_exchange_positive, check: "min_exchange_tokens > 0")
    create constraint(:token_configs, :max_exchange_positive, check: "max_exchange_tokens > 0")
    create constraint(:token_configs, :max_exchange_gte_min, check: "max_exchange_tokens >= min_exchange_tokens")
    create constraint(:token_configs, :exchange_fee_valid, check: "exchange_fee_percentage >= 0 AND exchange_fee_percentage <= 1")
  end
end
