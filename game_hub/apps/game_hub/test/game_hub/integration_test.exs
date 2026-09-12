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
    
    # Nettoyer Redis (files classiques + lobbies rapides utilisés ici ;
    # patterns explicites car le Redis est partagé avec le dev)
    for pattern <- ["queue:test_*", "queue:dice:*", "qm:lobby:dice:*", "qm:lobby:test_*"] do
      Redix.command(Redis, ["KEYS", pattern])
      |> elem(1)
      |> Enum.each(fn key -> Redix.command(Redis, ["DEL", key]) end)
    end
    
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
    # Modèle single-ledger : `balance` (centimes, dépôts/retraits) et
    # `token_balance` (jetons, mises/gains) évoluent séparément.
    test "scénario utilisateur complet", %{dice_config: _config} do
      # ==================================
      # ÉTAPE 1: Authentification
      # ==================================
      phone = "+237699100001"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, jwt_token, _refresh_token, user} = Auth.verify_otp(phone, otp)

      assert user.phone == phone
      assert user.balance == 0
      assert jwt_token != nil

      initial_user_id = user.id

      # ==================================
      # ÉTAPE 2: Dépôt via webhook (≥ min 50 000)
      # ==================================
      idempotency_key = "deposit_flow_#{System.unique_integer()}"

      {:ok, deposit_tx} = Wallet.deposit(
        initial_user_id,
        500_000, # 5000 FCFA
        idempotency_key
      )

      assert deposit_tx.type == "deposit"
      assert deposit_tx.amount == 500_000

      # Dépôt crédite le wallet ET les jetons (double écriture d'entrée)
      {:ok, balance} = Wallet.get_balance(initial_user_id)
      assert balance == 500_000
      assert GameHub.Tokens.get_token_balance(initial_user_id) == {:ok, 5000}

      # ==================================
      # ÉTAPE 3: Rejoindre partie
      # ==================================
      # Créer un second joueur financé pour le match
      user2 = GameHub.TestHelpers.create_test_user(phone: "+237699100002", name: "Player 2")
      {:ok, _} = Wallet.deposit(user2.id, 500_000, "deposit_flow2_#{System.unique_integer()}")

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

      # Les mises débitent les JETONS (wallet inchangé)
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

      # Wallet inchangé, jetons débités
      {:ok, balance1_after_bet} = Wallet.get_balance(initial_user_id)
      assert balance1_after_bet == 500_000
      assert GameHub.Tokens.get_token_balance(initial_user_id) == {:ok, 0}

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
      assert win_tx.token_amount == winnings
      assert GameHub.Tokens.get_token_balance(initial_user_id) == {:ok, winnings}

      # ==================================
      # ÉTAPE 5: Retrait (≥ min 200 000)
      # ==================================
      withdraw_amount = 200_000
      withdraw_key = "withdraw_#{initial_user_id}_#{System.unique_integer()}"

      {:ok, withdraw_tx} = Wallet.withdraw(
        initial_user_id,
        withdraw_amount,
        withdraw_key
      )

      assert withdraw_tx.type == "withdrawal"
      assert withdraw_tx.amount == -withdraw_amount

      {:ok, balance_after_withdraw} = Wallet.get_balance(initial_user_id)
      assert balance_after_withdraw == 500_000 - withdraw_amount

      # ==================================
      # VÉRIFICATIONS FINALES
      # ==================================
      transactions = Repo.all(
        from t in WalletTransaction,
        where: t.user_id == ^initial_user_id,
        order_by: [asc: t.inserted_at]
      )

      assert length(transactions) >= 2 # deposit, withdraw (mises/gains en ledger jetons)

      types = Enum.map(transactions, & &1.type)
      assert "deposit" in types
      assert "withdrawal" in types

      IO.puts("\n✅ FLOW COMPLET RÉUSSI")
      IO.puts("Balance finale: #{balance_after_withdraw} centimes")
      IO.puts("Profit: #{balance_after_withdraw - 500_000} centimes")
    end
  end
  
  describe "Multi-utilisateurs concurrence" do
    test "10 utilisateurs déposent simultanément" do
      users = Enum.map(1..10, fn i ->
        user = Repo.insert!(%User{
          phone: "+237699200#{:io_lib.format("~4..0B", [i]) |> to_string()}",
          username: "multi#{i}_#{System.unique_integer([:positive])}",
          name: "User #{i}",
          balance: 0,
          is_active: true
        })
        user
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
          username: "match#{i}_#{System.unique_integer([:positive])}",
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
        username: "idem_#{System.unique_integer([:positive])}",
        name: "Idempotence User",
        balance: 0,
        is_active: true
      })

      idempotency_key = "webhook_idempotence_#{System.unique_integer()}"
      amount = 50000
      
      # Simuler 5 webhooks identiques
      results = Enum.map(1..5, fn _ ->
        Wallet.deposit(user.id, amount, idempotency_key)
      end)
      
      # Premier succès, autres échouent (idempotence)
      successes = Enum.filter(results, fn r -> match?({:ok, _}, r) end)
      idempotency_errors = Enum.filter(results, fn r -> r == {:error, :idempotency_key_used} end)
      
      assert length(successes) == 1
      assert length(idempotency_errors) == 4
      
      # Balance ne doit être crédité qu'une fois
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 50000
      
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
    # Modèle single-ledger : les paris débitent les jetons
    # (`:insufficient_tokens`), pas le solde monétaire.
    test "pari rejeté si solde insuffisant, puis accepté après dépôt" do
      user = Repo.insert!(%User{
        phone: "+237699500001",
        username: "errrec_#{System.unique_integer([:positive])}",
        name: "Error Recovery User",
        balance: 1000, # Pas assez de jetons pour parier 5000
        is_active: true
      })

      # Tenter de parier (échoue : 0 jeton)
      result1 = Wallet.place_bet(
        user.id,
        5000,
        "dice_test",
        "bet_fail_#{System.unique_integer()}"
      )

      assert result1 == {:error, :insufficient_tokens}

      # Balance inchangée
      {:ok, balance1} = Wallet.get_balance(user.id)
      assert balance1 == 1000

      # Dépôt pour avoir assez (≥ min 50 000, 1 FCFA = 1 jeton :
      # 1 000 000 centimes → 10 000 jetons)
      Wallet.deposit(user.id, 1_000_000, "deposit_#{System.unique_integer()}")

      # Nouvelle tentative (réussit)
      result2 = Wallet.place_bet(
        user.id,
        5000,
        "dice_test",
        "bet_success_#{System.unique_integer()}"
      )

      assert {:ok, _} = result2

      # Wallet débité du dépôt seul, jetons débités de la mise
      {:ok, balance2} = Wallet.get_balance(user.id)
      assert balance2 == 1000 + 1_000_000
      assert GameHub.Tokens.get_token_balance(user.id) == {:ok, 10_000 - 5000}
    end

    test "retrait rejeté puis accepté après gains" do
      user = Repo.insert!(%User{
        phone: "+237699600001",
        username: "wdr_#{System.unique_integer([:positive])}",
        name: "Withdraw Test User",
        balance: 2000,
        is_active: true
      })

      # Tenter retrait dans les limites mais au-delà du solde
      result1 = Wallet.withdraw(
        user.id,
        200_000,
        "withdraw_fail_#{System.unique_integer()}"
      )

      assert result1 == {:error, :insufficient_funds}

      # Financer le wallet par dépôt
      Wallet.deposit(user.id, 500_000, "deposit_wdr_#{System.unique_integer()}")

      # Nouvelle tentative (réussit)
      result2 = Wallet.withdraw(
        user.id,
        200_000,
        "withdraw_success_#{System.unique_integer()}"
      )

      assert {:ok, _} = result2

      # Balance correcte
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 2000 + 500_000 - 200_000
    end
  end
  
  describe "Intégrité données sur erreurs" do
    test "rollback complet en cas d'erreur transaction" do
      user = Repo.insert!(%User{
        phone: "+237699700001",
        username: "rollback_#{System.unique_integer([:positive])}",
        name: "Rollback User",
        balance: 50000,
        is_active: true
      })

      _initial_balance = user.balance

      # Série d'opérations dans les limites (dépôt min 50 000)
      Wallet.deposit(user.id, 50000, "ok1_#{System.unique_integer()}")
      Wallet.deposit(user.id, 60000, "ok2_#{System.unique_integer()}")

      # Ceci échouera (solde insuffisant, dans les limites de retrait)
      Wallet.withdraw(user.id, 500000, "fail_#{System.unique_integer()}")

      # Balance devrait être: 50000 + 50000 + 60000 = 160000
      {:ok, final_balance} = Wallet.get_balance(user.id)
      assert final_balance == 160000
      
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
    test "25 dépôts rapides" do
      user = Repo.insert!(%User{
        phone: "+237699800001",
        username: "perf_#{System.unique_integer([:positive])}",
        name: "Performance User",
        balance: 0,
        is_active: true
      })

      start_time = System.monotonic_time(:millisecond)

      # 25 dépôts au minimum plateforme (50 000)
      Enum.each(1..25, fn i ->
        key = "perf_deposit_#{i}_#{System.unique_integer()}"
        Wallet.deposit(user.id, 50_000, key)
      end)

      elapsed = System.monotonic_time(:millisecond) - start_time

      # Vérifier balance
      {:ok, balance} = Wallet.get_balance(user.id)
      assert balance == 25 * 50_000

      IO.puts("\n⚡ 25 transactions en #{elapsed}ms")
      IO.puts("Moyenne: #{elapsed / 25}ms par transaction")

      # Devrait être raisonnablement rapide (< 10s)
      assert elapsed < 10000
    end
  end
end
