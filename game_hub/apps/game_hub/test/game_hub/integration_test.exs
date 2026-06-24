defmodule GameHub.IntegrationTest do
  @moduledoc """
  Tests d'intégration pour les flows complets.
  
  Scénarios:
  1. Auth → Deposit → Join Game → Play → Win → Withdraw
  2. Multi-utilisateurs concurrence
  3. Webhook idempotence
  4. Flow erreur (solde insuffisant, etc.)
  """
  
  use ExUnit.Case, async: false
  
  alias GameHub.{Auth, Wallet, Repo, Matchmaking, Redis}
  alias GameHub.Users.User
  alias GameHub.Games.GameConfig
  alias GameHub.Wallet.WalletTransaction
  
  import Ecto.Query
  
  setup do
    # Nettoyer
    Repo.delete_all(WalletTransaction)
    Repo.delete_all(User)
    Repo.delete_all(GameConfig)
    
    # Nettoyer Redis
    Redix.command(Redis, ["KEYS", "queue:test_*"])
    |> elem(1)
    |> Enum.each(fn key -> Redix.command(Redis, ["DEL", key]) end)
    
    # Créer config jeu
    dice_config = Repo.insert!(%GameConfig{
      game_type: "dice",
      name: "Jeu de Dés",
      description: "Test dice game",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0.05"),
      commission_mode: "percentage",
      is_active: true,
      config: %{}
    })
    
    %{dice_config: dice_config}
  end
  
  describe "Flow complet: Auth → Deposit → Play → Win" do
    test "scénario utilisateur complet", %{dice_config: config} do
      # ==================================
      # ÉTAPE 1: Authentification
      # ==================================
      phone = "+237699100001"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, jwt_token, user} = Auth.verify_otp(phone, otp)
      
      assert user.phone == phone
      assert user.balance == 0
      assert jwt_token != nil
      
      initial_user_id = user.id
      
      # ==================================
      # ÉTAPE 2: Dépôt via webhook
      # ==================================
      idempotency_key = "deposit_flow_#{System.unique_integer()}"
      
      {:ok, deposit_tx} = Wallet.deposit(
        initial_user_id,
        100000, # 1000 FCFA
        idempotency_key
      )
      
      assert deposit_tx.type == "deposit"
      assert deposit_tx.amount == 100000
      
      # Vérifier balance
      {:ok, balance} = Wallet.get_balance(initial_user_id)
      assert balance == 100000
      
      # ==================================
      # ÉTAPE 3: Rejoindre partie
      # ==================================
      # Créer un second joueur pour le match
      user2 = Repo.insert!(%User{
        phone: "+237699100002",
        name: "Player 2",
        balance: 150000,
        is_active: true
      })
      
      # Les deux joueurs rejoignent
      bet_amount = 5000
      
      # Player 1
      {:ok, :waiting} = Matchmaking.join_queue(
        to_string(initial_user_id),
        "dice",
        bet_amount
      )
      
      # Player 2 (déclenche match)
      {:ok, :matched, game_id} = Matchmaking.join_queue(
        to_string(user2.id),
        "dice",
        bet_amount
      )
      
      assert String.starts_with?(game_id, "dice_")
      
      # Vérifier que les balances ont été débités (via place_bet)
      bet_key1 = "bet_#{game_id}_#{initial_user_id}_#{System.unique_integer()}"
      bet_key2 = "bet_#{game_id}_#{user2.id}_#{System.unique_integer()}"
      
      {:ok, _bet1} = Wallet.place_bet(
        initial_user_id,
        bet_amount,
        game_id,
        bet_key1
      )
      
      {:ok, _bet2} = Wallet.place_bet(
        user2.id,
        bet_amount,
        game_id,
        bet_key2
      )
      
      # Vérifier balances après paris
      {:ok, balance1_after_bet} = Wallet.get_balance(initial_user_id)
      {:ok, balance2_after_bet} = Wallet.get_balance(user2.id)
      
      assert balance1_after_bet == 100000 - bet_amount
      assert balance2_after_bet == 150000 - bet_amount
      
      # ==================================
      # ÉTAPE 4: Simuler victoire Player 1
      # ==================================
      # Player 1 gagne (pot total - commission)
      pot = bet_amount * 2 # 10000
      commission = floor(pot * 0.05) # 500
      winnings = pot - commission # 9500
      
      win_key = "winnings_#{game_id}_#{initial_user_id}_#{System.unique_integer()}"
      
      {:ok, win_tx} = Wallet.credit_winnings(
        initial_user_id,
        winnings,
        game_id,
        win_key
      )
      
      assert win_tx.type == "winnings"
      assert win_tx.amount == winnings
      
      # ==================================
      # ÉTAPE 5: Vérifier balance finale
      # ==================================
      {:ok, final_balance} = Wallet.get_balance(initial_user_id)
      
      # Balance = initial - bet + winnings
      expected = 100000 - bet_amount + winnings
      assert final_balance == expected
      
      # Player 1 a gagné de l'argent
      assert final_balance > 100000
      
      # ==================================
      # ÉTAPE 6: Retrait
      # ==================================
      withdraw_amount = 50000
      withdraw_key = "withdraw_#{initial_user_id}_#{System.unique_integer()}"
      
      {:ok, withdraw_tx} = Wallet.withdraw(
        initial_user_id,
        withdraw_amount,
        withdraw_key
      )
      
      assert withdraw_tx.type == "withdrawal"
      assert withdraw_tx.amount == -withdraw_amount
      
      {:ok, balance_after_withdraw} = Wallet.get_balance(initial_user_id)
      assert balance_after_withdraw == final_balance - withdraw_amount
      
      # ==================================
      # VÉRIFICATIONS FINALES
      # ==================================
      # Toutes les transactions existent
      transactions = Repo.all(
        from t in WalletTransaction,
        where: t.user_id == ^initial_user_id,
        order_by: [asc: t.inserted_at]
      )
      
      assert length(transactions) >= 4 # deposit, bet, winnings, withdraw
      
      types = Enum.map(transactions, & &1.type)
      assert "deposit" in types
      assert "bet" in types
      assert "winnings" in types
      assert "withdrawal" in types
      
      IO.puts("\n✅ FLOW COMPLET RÉUSSI")
      IO.puts("Balance finale: #{balance_after_withdraw} centimes")
      IO.puts("Profit: #{balance_after_withdraw - 100000} centimes")
    end
  end
  
  describe "Multi-utilisateurs concurrence" do
    test "10 utilisateurs déposent simultanément" do
      users = Enum.map(1..10, fn i ->
        Repo.insert!(%User{
          phone: "+237699200#{:io_lib.format("~4..0B", [i]) |> to_string()}",
          name: "User #{i}",
          balance: 0,
          is_active: true
        })
      end)
      
      # Tous déposent en "parallèle" (séquentiel dans test)
      Enum.each(users, fn user ->
        key = "concurrent_deposit_#{user.id}_#{System.unique_integer()}"
        {:ok, _} = Wallet.deposit(user.id, 50000, key)
      end)
      
      # Vérifier que tous ont reçu leur dépôt
      Enum.each(users, fn user ->
        {:ok, balance} = Wallet.get_balance(user.id)
        assert balance == 50000
      end)
      
      # Vérifier transactions
      total_deposits = Repo.aggregate(
        from(t in WalletTransaction, where: t.type == "deposit"),
        :count,
        :id
      )
      
      assert total_deposits == 10
    end
    
    test "5 matchs simultanés" do
      # Créer 10 utilisateurs
      users = Enum.map(1..10, fn i ->
        user = Repo.insert!(%User{
          phone: "+237699300#{:io_lib.format("~4..0B", [i]) |> to_string()}",
          name: "Match User #{i}",
          balance: 100000,
          is_active: true
        })
        user
      end)
      
      # Créer 5 matchs (2 joueurs par match)
      matches = Enum.chunk_every(users, 2)
      |> Enum.map(fn [u1, u2] ->
        bet = 5000
        
        Matchmaking.join_queue(to_string(u1.id), "test_match", bet)
        {:ok, :matched, game_id} = Matchmaking.join_queue(to_string(u2.id), "test_match", bet)
        
        {game_id, u1, u2}
      end)
      
      # Vérifier que 5 matchs ont été créés
      assert length(matches) == 5
      
      # Tous les game_id sont uniques
      game_ids = Enum.map(matches, fn {game_id, _, _} -> game_id end)
      assert Enum.uniq(game_ids) |> length() == 5
    end
  end
  
  describe "Webhook idempotence flow" do
    test "même webhook 5 fois = 1 seul crédit" do
      user = Repo.insert!(%User{
        phone: "+237699400001",
        name: "Idempotence User",
        balance: 0,
        is_active: true
      })
      
      idempotency_key = "webhook_idempotence_#{System.unique_integer()}"
      amount = 25000
      
      # Simuler 5 webhooks identiques
      results = Enum.map(1..5, fn _ ->
        Wallet.deposit(user.id, amount, idempotency_key)
      end)
      
      # Premier succès, autres échouent (idempotence)
      successes = Enum.filter(results, fn r -> r == {:ok, _} end)
      idempotency_errors = Enum.filter(results, fn r -> r == {:error, :idempotency_key_used} end)
      
      assert length(successes) == 1
      assert length(idempotency_errors) == 4
      
      # Balance ne doit être crédité qu'une fois
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 25000
      
      # Une seule transaction
      count = Repo.aggregate(
        from(t in WalletTransaction, where: t.idempotency_key == ^idempotency_key),
        :count,
        :id
      )
      
      assert count == 1
    end
  end
  
  describe "Flow erreur et recovery" do
    test "pari rejeté si solde insuffisant, puis accepté après dépôt" do
      user = Repo.insert!(%User{
        phone: "+237699500001",
        name: "Error Recovery User",
        balance: 1000, # Pas assez pour parier 5000
        is_active: true
      })
      
      # Tenter de parier (échoue)
      result1 = Wallet.place_bet(
        user.id,
        5000,
        "dice_test",
        "bet_fail_#{System.unique_integer()}"
      )
      
      assert result1 == {:error, :insufficient_funds}
      
      # Balance inchangée
      {:ok, balance1} = Wallet.get_balance(user.id)
      assert balance1 == 1000
      
      # Dépôt pour avoir assez
      Wallet.deposit(user.id, 10000, "deposit_#{System.unique_integer()}")
      
      # Nouvelle tentative (réussit)
      result2 = Wallet.place_bet(
        user.id,
        5000,
        "dice_test",
        "bet_success_#{System.unique_integer()}"
      )
      
      assert {:ok, _} = result2
      
      # Balance débitée
      {:ok, balance2} = Wallet.get_balance(user.id)
      assert balance2 == 1000 + 10000 - 5000
    end
    
    test "retrait rejeté puis accepté après gains" do
      user = Repo.insert!(%User{
        phone: "+237699600001",
        name: "Withdraw Test User",
        balance: 2000,
        is_active: true
      })
      
      # Tenter retrait trop important
      result1 = Wallet.withdraw(
        user.id,
        10000,
        "withdraw_fail_#{System.unique_integer()}"
      )
      
      assert result1 == {:error, :insufficient_funds}
      
      # Créditer gains
      Wallet.credit_winnings(
        user.id,
        15000,
        "game_test",
        "winnings_#{System.unique_integer()}"
      )
      
      # Nouvelle tentative (réussit)
      result2 = Wallet.withdraw(
        user.id,
        10000,
        "withdraw_success_#{System.unique_integer()}"
      )
      
      assert {:ok, _} = result2
      
      # Balance correcte
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 2000 + 15000 - 10000
    end
  end
  
  describe "Intégrité données sur erreurs" do
    test "rollback complet en cas d'erreur transaction" do
      user = Repo.insert!(%User{
        phone: "+237699700001",
        name: "Rollback User",
        balance: 50000,
        is_active: true
      })
      
      initial_balance = user.balance
      
      # Série d'opérations dont une échoue
      Wallet.deposit(user.id, 10000, "ok1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 20000, "ok2_#{System.unique_integer()}")
      
      # Ceci échouera (solde insuffisant)
      Wallet.withdraw(user.id, 999999, "fail_#{System.unique_integer()}")
      
      # Balance devrait être: 50000 + 10000 + 20000 = 80000
      {:ok, final_balance} = Wallet.get_balance(user.id)
      assert final_balance == 80000
      
      # Transactions OK doivent exister
      count = Repo.aggregate(
        from(t in WalletTransaction, where: t.user_id == ^user.id and t.type == "deposit"),
        :count,
        :id
      )
      
      assert count == 2
    end
  end
  
  describe "Performance et timeouts" do
    test "100 transactions rapides" do
      user = Repo.insert!(%User{
        phone: "+237699800001",
        name: "Performance User",
        balance: 0,
        is_active: true
      })
      
      start_time = System.monotonic_time(:millisecond)
      
      # 100 dépôts
      Enum.each(1..100, fn i ->
        key = "perf_deposit_#{i}_#{System.unique_integer()}"
        Wallet.deposit(user.id, 100, key)
      end)
      
      elapsed = System.monotonic_time(:millisecond) - start_time
      
      # Vérifier balance
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 100 * 100 # 10000
      
      IO.puts("\n⚡ 100 transactions en #{elapsed}ms")
      IO.puts("Moyenne: #{elapsed / 100}ms par transaction")
      
      # Devrait être raisonnablement rapide (< 10s pour 100 transactions)
      assert elapsed < 10000
    end
  end
end
