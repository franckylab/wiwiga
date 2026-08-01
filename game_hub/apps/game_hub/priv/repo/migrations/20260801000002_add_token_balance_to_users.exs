# ==================================
# WIWIGA - Migration Add Token Balance
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo.Migrations.AddTokenBalanceToUsers
# Description: Ajout du solde en jetons virtuels aux utilisateurs

defmodule GameHub.Repo.Migrations.AddTokenBalanceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :token_balance, :bigint, default: 0, null: false
    end

    # Contrainte: solde jetons >= 0
    create constraint(:users, :token_balance_positive, check: "token_balance >= 0")
  end
end
