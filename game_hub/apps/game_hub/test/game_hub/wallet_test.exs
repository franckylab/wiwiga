defmodule GameHub.WalletTest do
  @moduledoc """
  Tests unitaires pour le module Wallet.

  Tests critiques:
  - Transactions ACID
  - Verrouillage pessimiste
  - Idempotence
  - Gestion des erreurs (solde insuffisant, user not found)

  Conventions 2026 (single-ledger) :
  - `balance` = centimes monétaires (dépôt/retrait).
  - `token_balance` = jetons (mises/gains).
  - Seuils PlatformConfig : dépôt min 50 000, retrait min 200 000.
  """

  use ExUnit.Case, async: false
  use Oban.Testing, repo: GameHub.Repo

  alias GameHub.{Repo, Tokens, Wallet}
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction

  import Ecto.Query

  # Setup: créer un utilisateur de test avant chaque test
  setup do
    GameHub.TestHelpers.cleanup_test_data()

    # Créer utilisateur de test
    user = Repo.insert!(%User{
      phone: "+237699000001",
      name: "Test User",
      balance: 1_000_000,
      token_balance: 100_000,
      is_active: true,
      has_verified_kyc: true
    })

    {:ok, user: user}
  end

  describe "get_balance/1" do
    test "retourne le solde d'un utilisateur existant", %{user: user} do
      assert Wallet.get_balance(user.id) == {:ok, 1_000_000}
    end

    test "retourne une erreur pour un utilisateur inexistant" do
      assert Wallet.get_balance(999999) == {:error, :user_not_found}
    end
  end

  describe "deposit/3" do
    test "dépose des fonds avec succès", %{user: user} do
      idempotency_key = "deposit_test_#{System.unique_integer()}"

      assert {:ok, transaction} = Wallet.deposit(user.id, 50_000, idempotency_key)

      # Vérifier la transaction
      assert transaction.type == "deposit"
      assert transaction.amount == 50_000
      assert transaction.balance_before == 1_000_000
      assert transaction.balance_after == 1_050_000

      # Vérifier que le balance a été mis à jour
      assert Wallet.get_balance(user.id) == {:ok, 1_050_000}
    end

    test "rejette un montant invalide (négatif)", %{user: user} do
      assert Wallet.deposit(user.id, -100, "key1") == {:error, :invalid_amount}
      assert Wallet.deposit(user.id, 0, "key2") == {:error, :invalid_amount}
    end

    test "rejette sous le seuil de dépôt", %{user: user} do
      assert {:error, :deposit_limit_violation} =
               Wallet.deposit(user.id, 10_000, "key3_#{System.unique_integer()}")
    end

    test "respecte l'idempotence - même clé = même transaction", %{user: user} do
      idempotency_key = "unique_deposit_#{System.unique_integer()}"

      # Premier dépôt
      assert {:ok, tx1} = Wallet.deposit(user.id, 60_000, idempotency_key)

      # Second dépôt avec même clé (dans la même transaction car rollback)
      assert {:error, :idempotency_key_used} =
               Wallet.deposit(user.id, 60_000, idempotency_key)

      # Le balance ne doit avoir augmenté qu'une seule fois
      assert Wallet.get_balance(user.id) == {:ok, 1_060_000}
      assert tx1.amount == 60_000
    end

    test "crée une transaction avec idempotency_key unique", %{user: user} do
      key1 = "deposit_key_1_#{System.unique_integer()}"
      key2 = "deposit_key_2_#{System.unique_integer()}"

      {:ok, _} = Wallet.deposit(user.id, 60_000, key1)
      {:ok, _} = Wallet.deposit(user.id, 70_000, key2)

      # Deux transactions distinctes doivent exister
      count = Repo.aggregate(WalletTransaction, :count, :id)
      assert count == 2
    end
  end

  describe "withdraw/3" do
    test "retire des fonds avec succès", %{user: user} do
      idempotency_key = "withdraw_test_#{System.unique_integer()}"

      assert {:ok, transaction} = Wallet.withdraw(user.id, 200_000, idempotency_key)

      # Vérifier la transaction
      assert transaction.type == "withdrawal"
      assert transaction.amount == -200_000
      assert transaction.balance_before == 1_000_000
      assert transaction.balance_after == 800_000

      # Vérifier que le balance a été mis à jour
      assert Wallet.get_balance(user.id) == {:ok, 800_000}
    end

    test "rejette un montant invalide", %{user: user} do
      assert Wallet.withdraw(user.id, -100, "key1") == {:error, :invalid_amount}
      assert Wallet.withdraw(user.id, 0, "key2") == {:error, :invalid_amount}
    end

    test "rejette sous le seuil de retrait", %{user: user} do
      assert {:error, :withdrawal_limit_violation} =
               Wallet.withdraw(user.id, 30_000, "key3_#{System.unique_integer()}")
    end

    test "rejette si solde insuffisant", %{user: user} do
      # Tenter de retirer plus que le balance
      assert {:error, :insufficient_funds} =
               Wallet.withdraw(user.id, 5_000_000, "withdraw_fail_#{System.unique_integer()}")

      # Le balance ne doit pas avoir changé
      assert Wallet.get_balance(user.id) == {:ok, 1_000_000}
    end

    test "permet de retirer tout le balance", %{user: user} do
      idempotency_key = "withdraw_all_#{System.unique_integer()}"

      assert {:ok, transaction} = Wallet.withdraw(user.id, 1_000_000, idempotency_key)

      assert transaction.balance_after == 0
      assert Wallet.get_balance(user.id) == {:ok, 0}
    end
  end

  describe "place_bet/4" do
    test "place un pari avec succès (ledger jetons)", %{user: user} do
      idempotency_key = "bet_test_#{System.unique_integer()}"
      game_id = "dice_123"

      assert {:ok, transaction} = Wallet.place_bet(user.id, 50_000, game_id, idempotency_key)

      # Vérifier la transaction jetons (single-ledger)
      assert transaction.type == "bet"
      assert transaction.token_amount == -50_000
      assert transaction.balance_before == 100_000
      assert transaction.balance_after == 50_000

      # Vérifier que le solde jetons a été débité
      assert Tokens.get_token_balance(user.id) == {:ok, 50_000}
    end

    test "rejette si solde insuffisant pour le pari", %{user: user} do
      assert {:error, :insufficient_tokens} =
               Wallet.place_bet(user.id, 200_000, "dice_123", "bet_fail_#{System.unique_integer()}")

      assert Tokens.get_token_balance(user.id) == {:ok, 100_000}
    end
  end

  describe "credit_winnings/4" do
    test "crédite les gains avec succès (ledger jetons)", %{user: user} do
      idempotency_key = "winnings_test_#{System.unique_integer()}"
      game_id = "dice_456"

      assert {:ok, transaction} = Wallet.credit_winnings(user.id, 80_000, game_id, idempotency_key)

      # Vérifier la transaction jetons (single-ledger)
      assert transaction.type == "winnings"
      assert transaction.token_amount == 80_000
      assert transaction.balance_before == 100_000
      assert transaction.balance_after == 180_000

      # Vérifier que le solde jetons a été crédité
      assert Tokens.get_token_balance(user.id) == {:ok, 180_000}
    end

    test "rejette un montant de gains invalide", %{user: user} do
      assert Wallet.credit_winnings(user.id, -100, "game", "key1") == {:error, :invalid_amount}
      assert Wallet.credit_winnings(user.id, 0, "game", "key2") == {:error, :invalid_amount}
    end
  end

  describe "list_transactions/3" do
    test "retourne les transactions paginées", %{user: user} do
      # Créer plusieurs transactions
      Wallet.deposit(user.id, 60_000, "deposit_1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 70_000, "deposit_2_#{System.unique_integer()}")
      Wallet.withdraw(user.id, 200_000, "withdraw_1_#{System.unique_integer()}")

      # Récupérer page 1 (limit 2)
      {:ok, transactions, total} = Wallet.list_transactions(user.id, 1, 2)

      assert length(transactions) == 2
      assert total == 3

      # Vérifier l'ordre (plus récent d'abord)
      [tx1, tx2] = transactions
      assert tx1.inserted_at >= tx2.inserted_at
    end

    test "retourne page vide si au-delà du total", %{user: user} do
      Wallet.deposit(user.id, 60_000, "deposit_#{System.unique_integer()}")

      {:ok, transactions, total} = Wallet.list_transactions(user.id, 10, 20)

      assert length(transactions) == 0
      assert total == 1
    end

    test "retourne liste vide pour utilisateur sans transactions" do
      {:ok, transactions, total} = Wallet.list_transactions(999999, 1, 20)

      assert transactions == []
      assert total == 0
    end
  end

  describe "intégrité ACID" do
    test "rollback en cas d'erreur ne modifie pas le balance", %{user: user} do
      initial_balance = 1_000_000

      # Tenter un retrait avec solde insuffisant
      Wallet.withdraw(user.id, 5_000_000, "fail_#{System.unique_integer()}")

      # Le balance doit rester inchangé
      assert Wallet.get_balance(user.id) == {:ok, initial_balance}
    end

    test "transactions séquentielles maintiennent la cohérence", %{user: user} do
      # Série de transactions
      Wallet.deposit(user.id, 60_000, "seq_dep_1_#{System.unique_integer()}")
      Wallet.withdraw(user.id, 200_000, "seq_with_1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 70_000, "seq_dep_2_#{System.unique_integer()}")

      # Balance final devrait être: 1000000 + 60000 - 200000 + 70000 = 930000
      assert Wallet.get_balance(user.id) == {:ok, 930_000}

      # Toutes les transactions doivent exister
      {:ok, transactions, total} = Wallet.list_transactions(user.id, 1, 10)
      assert total == 3
      assert length(transactions) == 3
    end
  end
end
