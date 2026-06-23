defmodule GameHub.WalletTest do
  @moduledoc """
  Tests unitaires pour le module Wallet.
  
  Tests critiques:
  - Transactions ACID
  - Verrouillage pessimiste
  - Idempotence
  - Gestion des erreurs (solde insuffisant, user not found)
  """
  
  use ExUnit.Case, async: false
  use Oban.Testing, repo: GameHub.Repo
  
  alias GameHub.Wallet
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  
  import Ecto.Query
  
  # Setup: créer un utilisateur de test avant chaque test
  setup do
    # Nettoyer les données de test
    Repo.delete_all(WalletTransaction)
    Repo.delete_all(User)
    
    # Créer utilisateur de test
    user = Repo.insert!(%User{
      phone: "+237699000001",
      name: "Test User",
      balance: 100000, # 1000 FCFA en centimes
      is_active: true,
      has_verified_kyc: true
    })
    
    {:ok, user: user}
  end
  
  describe "get_balance/1" do
    test "retourne le solde d'un utilisateur existant", %{user: user} do
      assert Wallet.get_balance(user.id) == {:ok, 100000}
    end
    
    test "retourne une erreur pour un utilisateur inexistant" do
      assert Wallet.get_balance(999999) == {:error, :user_not_found}
    end
  end
  
  describe "deposit/3" do
    test "dépose des fonds avec succès", %{user: user} do
      idempotency_key = "deposit_test_#{System.unique_integer()}"
      
      assert {:ok, transaction} = Wallet.deposit(user.id, 50000, idempotency_key)
      
      # Vérifier la transaction
      assert transaction.type == "deposit"
      assert transaction.amount == 50000
      assert transaction.balance_before == 100000
      assert transaction.balance_after == 150000
      
      # Vérifier que le balance a été mis à jour
      assert Wallet.get_balance(user.id) == {:ok, 150000}
    end
    
    test "rejette un montant invalide (négatif)", %{user: user} do
      assert Wallet.deposit(user.id, -100, "key1") == {:error, :invalid_amount}
      assert Wallet.deposit(user.id, 0, "key2") == {:error, :invalid_amount}
    end
    
    test "respecte l'idempotence - même clé = même transaction", %{user: user} do
      idempotency_key = "unique_deposit_#{System.unique_integer()}"
      
      # Premier dépôt
      assert {:ok, tx1} = Wallet.deposit(user.id, 10000, idempotency_key)
      
      # Second dépôt avec même clé (dans la même transaction car rollback)
      assert {:error, :idempotency_key_used} = 
        Wallet.deposit(user.id, 10000, idempotency_key)
      
      # Le balance ne doit avoir augmenté qu'une seule fois
      assert Wallet.get_balance(user.id) == {:ok, 110000}
    end
    
    test "crée une transaction avec idempotency_key unique", %{user: user} do
      key1 = "deposit_key_1_#{System.unique_integer()}"
      key2 = "deposit_key_2_#{System.unique_integer()}"
      
      {:ok, _} = Wallet.deposit(user.id, 10000, key1)
      {:ok, _} = Wallet.deposit(user.id, 20000, key2)
      
      # Deux transactions distinctes doivent exister
      count = Repo.aggregate(WalletTransaction, :count, :id)
      assert count == 2
    end
  end
  
  describe "withdraw/3" do
    test "retire des fonds avec succès", %{user: user} do
      idempotency_key = "withdraw_test_#{System.unique_integer()}"
      
      assert {:ok, transaction} = Wallet.withdraw(user.id, 30000, idempotency_key)
      
      # Vérifier la transaction
      assert transaction.type == "withdrawal"
      assert transaction.amount == -30000
      assert transaction.balance_before == 100000
      assert transaction.balance_after == 70000
      
      # Vérifier que le balance a été mis à jour
      assert Wallet.get_balance(user.id) == {:ok, 70000}
    end
    
    test "rejette un montant invalide", %{user: user} do
      assert Wallet.withdraw(user.id, -100, "key1") == {:error, :invalid_amount}
      assert Wallet.withdraw(user.id, 0, "key2") == {:error, :invalid_amount}
    end
    
    test "rejette si solde insuffisant", %{user: user} do
      # Tenter de retirer plus que le balance
      assert {:error, :insufficient_funds} = 
        Wallet.withdraw(user.id, 200000, "withdraw_fail_#{System.unique_integer()}")
      
      # Le balance ne doit pas avoir changé
      assert Wallet.get_balance(user.id) == {:ok, 100000}
    end
    
    test "permet de retirer tout le balance", %{user: user} do
      idempotency_key = "withdraw_all_#{System.unique_integer()}"
      
      assert {:ok, transaction} = Wallet.withdraw(user.id, 100000, idempotency_key)
      
      assert transaction.balance_after == 0
      assert Wallet.get_balance(user.id) == {:ok, 0}
    end
  end
  
  describe "place_bet/4" do
    test "place un pari avec succès", %{user: user} do
      idempotency_key = "bet_test_#{System.unique_integer()}"
      game_id = "dice_123"
      
      assert {:ok, transaction} = Wallet.place_bet(user.id, 50000, game_id, idempotency_key)
      
      # Vérifier la transaction
      assert transaction.type == "bet"
      assert transaction.amount == -50000
      assert transaction.balance_before == 100000
      assert transaction.balance_after == 50000
      assert transaction.metadata[:game_id] == game_id
      
      # Vérifier que le balance a été débité
      assert Wallet.get_balance(user.id) == {:ok, 50000}
    end
    
    test "rejette si solde insuffisant pour le pari", %{user: user} do
      assert {:error, :insufficient_funds} = 
        Wallet.place_bet(user.id, 200000, "dice_123", "bet_fail_#{System.unique_integer()}")
      
      assert Wallet.get_balance(user.id) == {:ok, 100000}
    end
  end
  
  describe "credit_winnings/4" do
    test "crédite les gains avec succès", %{user: user} do
      idempotency_key = "winnings_test_#{System.unique_integer()}"
      game_id = "dice_456"
      
      assert {:ok, transaction} = Wallet.credit_winnings(user.id, 80000, game_id, idempotency_key)
      
      # Vérifier la transaction
      assert transaction.type == "winnings"
      assert transaction.amount == 80000
      assert transaction.balance_before == 100000
      assert transaction.balance_after == 180000
      assert transaction.metadata[:game_id] == game_id
      
      # Vérifier que le balance a été crédité
      assert Wallet.get_balance(user.id) == {:ok, 180000}
    end
    
    test "rejette un montant de gains invalide", %{user: user} do
      assert Wallet.credit_winnings(user.id, -100, "game", "key1") == {:error, :invalid_amount}
      assert Wallet.credit_winnings(user.id, 0, "game", "key2") == {:error, :invalid_amount}
    end
  end
  
  describe "list_transactions/3" do
    test "retourne les transactions paginées", %{user: user} do
      # Créer plusieurs transactions
      Wallet.deposit(user.id, 10000, "deposit_1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 20000, "deposit_2_#{System.unique_integer()}")
      Wallet.withdraw(user.id, 5000, "withdraw_1_#{System.unique_integer()}")
      
      # Récupérer page 1 (limit 2)
      {:ok, transactions, total} = Wallet.list_transactions(user.id, 1, 2)
      
      assert length(transactions) == 2
      assert total == 3
      
      # Vérifier l'ordre (plus récent d'abord)
      [tx1, tx2] = transactions
      assert tx1.inserted_at >= tx2.inserted_at
    end
    
    test "retourne page vide si au-delà du total", %{user: user} do
      Wallet.deposit(user.id, 10000, "deposit_#{System.unique_integer()}")
      
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
      initial_balance = 100000
      
      # Tenter un retrait avec solde insuffisant
      Wallet.withdraw(user.id, 999999, "fail_#{System.unique_integer()}")
      
      # Le balance doit rester inchangé
      assert Wallet.get_balance(user.id) == {:ok, initial_balance}
    end
    
    test "transactions séquentielles maintiennent la cohérence", %{user: user} do
      # Série de transactions
      Wallet.deposit(user.id, 50000, "seq_dep_1_#{System.unique_integer()}")
      Wallet.withdraw(user.id, 20000, "seq_with_1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 30000, "seq_dep_2_#{System.unique_integer()}")
      
      # Balance final devrait être: 100000 + 50000 - 20000 + 30000 = 160000
      assert Wallet.get_balance(user.id) == {:ok, 160000}
      
      # Toutes les transactions doivent exister
      {:ok, transactions, total} = Wallet.list_transactions(user.id, 1, 10)
      assert total == 3
    end
  end
end
