defmodule GameHub.TokensTest do
  @moduledoc """
  Tests unitaires pour le module Tokens — refonte 2026-08-31
  Seuls achat, cadeau ami, promos et jeu restent. Transfert/échange supprimés.
  """

  use ExUnit.Case, async: false

  alias GameHub.Tokens
  alias GameHub.Tokens.{TokenConfig, TokenTransaction}
  alias GameHub.Friends.Friendship
  alias GameHub.Repo
  alias GameHub.Users.User

  import Ecto.Query

  setup do
    Repo.delete_all(TokenTransaction)
    Repo.delete_all(Friendship)
    # Delete users last (FK constraints)
    Repo.delete_all(User)

    uniq = System.unique_integer([:positive])

    user = Repo.insert!(%User{
      phone: "+237699#{String.pad_leading(to_string(rem(uniq, 900000) + 100000), 6, "0")}",
      username: "tester_#{uniq}_a",
      name: "Token Test User",
      balance: 100_000,
      token_balance: 5000,
      is_active: true,
      has_verified_kyc: true
    })

    user2 = Repo.insert!(%User{
      phone: "+237699#{String.pad_leading(to_string(rem(uniq + 1, 900000) + 100000), 6, "0")}",
      username: "tester_#{uniq}_b",
      name: "Token Test User 2",
      balance: 50_000,
      token_balance: 2000,
      is_active: true,
      has_verified_kyc: true
    })

    {:ok, user: user, user2: user2}
  end

  defp make_friends(a, b) do
    Repo.insert!(%Friendship{user_id: a.id, friend_id: b.id, status: "accepted"})
  end

  describe "get_token_balance/1" do
    test "retourne le solde en jetons", %{user: user} do
      assert Tokens.get_token_balance(user.id) == {:ok, 5000}
    end

    test "erreur si utilisateur inexistant" do
      assert Tokens.get_token_balance(999999) == {:error, :user_not_found}
    end
  end

  describe "get_token_summary/1" do
    test "retourne résumé sans transfert/échange", %{user: user} do
      {:ok, summary} = Tokens.get_token_summary(user.id)

      assert summary.token_balance == 5000
      assert summary.exchange_rate == 1.0
      assert summary.monetary_value_centimes > 0
      assert summary.gift_enabled == true
      refute Map.has_key?(summary, :transfer_enabled)
      refute Map.has_key?(summary, :min_exchange)
    end
  end

  describe "purchase_tokens/3" do
    test "achat réussi avec crédits jetons", %{user: user} do
      key = "purchase_test_#{System.unique_integer()}"

      {:ok, tx} = Tokens.purchase_tokens(user.id, 10000, key)

      assert tx.type == "purchase"
      assert tx.token_amount > 0
      assert tx.monetary_value == 10000
      assert tx.exchange_rate == 1.0

      {:ok, new_balance} = Tokens.get_token_balance(user.id)
      assert new_balance == 5000 + tx.token_amount
    end

    test "idempotence - même clé ne double pas", %{user: user} do
      key = "purchase_idem_#{System.unique_integer()}"

      {:ok, tx1} = Tokens.purchase_tokens(user.id, 5000, key)
      {:error, :idempotency_key_used} = Tokens.purchase_tokens(user.id, 5000, key)

      {:ok, balance} = Tokens.get_token_balance(user.id)
      assert balance == 5000 + tx1.token_amount
    end

    test "montant invalide" do
      assert Tokens.purchase_tokens(1, 0, "key") == {:error, :invalid_amount}
      assert Tokens.purchase_tokens(1, -100, "key") == {:error, :invalid_amount}
    end
  end

  describe "deduct_for_bet/4" do
    test "débit jetons pour mise réussi", %{user: user} do
      key = "bet_test_#{System.unique_integer()}"

      {:ok, tx} = Tokens.deduct_for_bet(user.id, 100, "dice_game_1", key)

      assert tx.type == "bet"
      assert tx.token_amount == -100
      assert tx.game_id == "dice_game_1"

      {:ok, balance} = Tokens.get_token_balance(user.id)
      assert balance == 5000 - 100
    end

    test "erreur si mise en dessous minimum jeu", %{user: user} do
      key = "bet_min_#{System.unique_integer()}"
      {:error, :below_min_bet} = Tokens.deduct_for_bet(user.id, 5, "dice_game_1", key)
    end

    test "erreur si solde insuffisant", %{user: user} do
      key = "bet_insuf_#{System.unique_integer()}"
      {:error, :insufficient_tokens} = Tokens.deduct_for_bet(user.id, 999999, "dice_game_1", key)
    end
  end

  describe "credit_winnings/4" do
    test "crédit gains réussi", %{user: user} do
      key = "win_test_#{System.unique_integer()}"

      {:ok, tx} = Tokens.credit_winnings(user.id, 500, "dice_game_1", key)

      assert tx.type == "winnings"
      assert tx.token_amount == 500

      {:ok, balance} = Tokens.get_token_balance(user.id)
      assert balance == 5000 + 500
    end
  end

  describe "send_gift/5 — amis uniquement" do
    test "envoi cadeau réussi entre amis", %{user: user, user2: user2} do
      make_friends(user, user2)
      key = "gift_test_#{System.unique_integer()}"

      {:ok, result} = Tokens.send_gift(user.id, user2.id, 100, key, "Joyeux anniversaire!")

      assert result.amount == 100

      {:ok, txs, _} = Tokens.get_token_transactions(user.id, 1, 10)
      gift_sent = Enum.find(txs, &(&1.type == "gift_sent"))
      assert gift_sent != nil
      assert gift_sent.token_amount == -100

      {:ok, txs2, _} = Tokens.get_token_transactions(user2.id, 1, 10)
      gift_received = Enum.find(txs2, &(&1.type == "gift_received"))
      assert gift_received != nil
      assert gift_received.token_amount == 100
    end

    test "échec si pas amis", %{user: user, user2: user2} do
      key = "gift_not_friends_#{System.unique_integer()}"
      assert {:error, :not_friends} = Tokens.send_gift(user.id, user2.id, 50, key, "hey")
    end

    test "échec si destinataire inexistant", %{user: user} do
      key = "gift_norecv_#{System.unique_integer()}"
      assert {:error, :recipient_not_found} = Tokens.send_gift(user.id, 999_999, 50, key, "")
    end

    test "échec si solde insuffisant (amis)", %{user: user, user2: user2} do
      make_friends(user, user2)
      key = "gift_insuf_#{System.unique_integer()}"
      # 6000 > solde 5000 mais < daily_limit 10000 → :insufficient_tokens
      assert {:error, :insufficient_tokens} = Tokens.send_gift(user.id, user2.id, 6_000, key, "")
    end
  end

  describe "get_token_transactions/3" do
    test "historique paginé", %{user: user} do
      Tokens.purchase_tokens(user.id, 5000, "hist_purchase_#{System.unique_integer()}")
      Tokens.deduct_for_bet(user.id, 50, "dice_game_1", "hist_bet_#{System.unique_integer()}")
      Tokens.credit_winnings(user.id, 200, "dice_game_1", "hist_win_#{System.unique_integer()}")

      {:ok, txs, total} = Tokens.get_token_transactions(user.id, 1, 10)

      assert length(txs) >= 3
      assert total >= 3
    end
  end

  describe "conversions" do
    test "tokens_to_monetary correct (taux 1.0)" do
      config = TokenConfig.get_config()
      # 100 jetons avec taux 1.0 = 100 FCFA = 10000 centimes
      assert TokenConfig.tokens_to_monetary(100, config) == 10_000
    end

    test "monetary_to_tokens correct (taux 1.0)" do
      config = TokenConfig.get_config()
      # 10000 centimes = 100 FCFA × 1.0 = 100 jetons
      assert TokenConfig.monetary_to_tokens(10_000, config) == 100
    end

    test "get_min_bet_tokens par jeu" do
      config = TokenConfig.get_config()
      assert TokenConfig.get_min_bet_tokens("dice", config) == config.min_bet_tokens_dice
      assert TokenConfig.get_min_bet_tokens("unknown", config) == 10
    end
  end
end
