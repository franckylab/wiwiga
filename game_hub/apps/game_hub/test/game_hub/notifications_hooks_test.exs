defmodule GameHub.NotificationsHooksTest do
  @moduledoc """
  Tests des hooks notifications sur les événements métier :
  cadeaux, promos, retraits, amis, auth, 2FA, jeu responsable,
  bans, succès, nouvel appareil.

  Tous best-effort : l'échec d'une notification n'échoue jamais l'action.
  Non couvert ici (lourd, GenServer) : settle_match_payout — le crédit
  vainqueur (wallet_credit) est déjà testé via TokensTest.
  """

  use ExUnit.Case, async: false

  alias GameHub.{Auth, Friends, Notifications, Repo, Tokens, Wallet}
  alias GameHub.Admin.{Security, TwoFactor}
  alias GameHub.Friends.Friendship
  alias GameHub.ResponsibleGaming
  alias GameHub.Tokens.PromoToken
  alias GameHub.Users.{Achievement, AchievementManager, User, UserStat}
  alias GameHub.Notifications.Notification

  import Ecto.Query

  setup do
    GameHub.TestHelpers.cleanup_test_data()
    GameHub.Notifications.ProviderCache.invalidate_all()

    uniq = System.unique_integer([:positive])

    make_user = fn suffix ->
      Repo.insert!(%User{
        phone: "+237690#{String.pad_leading(to_string(rem(uniq + suffix, 900000) + 100000), 6, "0")}",
        username: "hook_#{uniq}_#{suffix}",
        name: "Hook Test",
        balance: 100_000,
        token_balance: 5000,
        is_active: true,
        has_verified_kyc: true
      })
    end

    {:ok, user_a: make_user.(1), user_b: make_user.(2), uniq: uniq}
  end

  defp inbox_titles(user_id) do
    Repo.all(from n in Notification, where: n.user_id == ^user_id, select: {n.title, n.body})
  end

  defp assert_inbox_contains(user_id, expected_title, expected_fragment) do
    found =
      Enum.any?(inbox_titles(user_id), fn {title, body} ->
        title == expected_title and String.contains?(body, expected_fragment)
      end)

    assert found, "inbox de #{user_id} ne contient pas #{inspect(expected_title)} / #{inspect(expected_fragment)}"
  end

  describe "cadeaux et promos" do
    test "cadeau notifie expéditeur et destinataire", %{user_a: a, user_b: b, uniq: uniq} do
      Repo.insert!(Friendship.create_changeset(%Friendship{}, %{user_id: a.id, friend_id: b.id, status: "accepted"}))

      assert {:ok, _} = Tokens.send_gift(a.id, b.id, 100, "gift-hook-#{uniq}", "merci")

      assert_inbox_contains(a.id, "Jetons débités", "cadeau")
      assert_inbox_contains(b.id, "Jetons reçus", "cadeau")
    end

    test "promo notifie le crédit", %{user_a: a, uniq: uniq} do
      {:ok, promo} =
        PromoToken.create_promo(%{
          name: "Promo Hook",
          token_amount: 250,
          valid_from: DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second),
          is_active: true
        })

      assert {:ok, _} = Tokens.credit_promo(a.id, promo.id, "promo-hook-#{uniq}")
      assert_inbox_contains(a.id, "Jetons reçus", "Promo Hook")
    end

    test "retrait monétaire notifie sans unité mensongère", %{user_a: a, uniq: uniq} do
      # Seuil min retrait : 200 000 (PlatformConfig payment.min_withdrawal)
      {:ok, _} = a |> User.changeset(%{balance: 1_000_000}) |> Repo.update()
      assert {:ok, _} = Wallet.withdraw(a.id, 200_000, "wd-hook-#{uniq}")
      assert_inbox_contains(a.id, "Retrait effectué", "Mobile Money")
    end
  end

  describe "amis" do
    test "acceptation notifie le demandeur", %{user_a: a, user_b: b} do
      {:ok, friendship} = Friends.send_friend_request(a.id, b.id)
      assert {:ok, _} = Friends.accept_friend_request(b.id, friendship.id)
      assert_inbox_contains(a.id, "Ami ajouté", b.username)
    end
  end

  describe "auth et sécurité" do
    test "mot de passe modifié → alerte", %{user_a: a} do
      assert {:ok, _} = Auth.set_password(a.id, "nouveau-mot-de-passe-123")
      assert_inbox_contains(a.id, "Alerte sécurité", "Mot de passe")
    end

    test "2FA désactivée → alerte", %{user_a: a} do
      {:ok, _} =
        a
        |> User.changeset(%{totp_secret: "c2VjcmV0", totp_enabled: true})
        |> Repo.update()

      assert {:ok, _} = TwoFactor.disable_2fa(a.id)
      assert_inbox_contains(a.id, "Alerte sécurité", "deux étapes")
    end

    test "nouvel appareil → alerte, premier login silencieux", %{uniq: uniq} do
      phone = "+237691#{String.pad_leading(to_string(rem(uniq, 900000) + 100000), 6, "0")}"

      {:ok, otp_a} = Auth.send_otp(phone, device_id: "hook-dev-a-#{uniq}")
      assert {:ok, _access, _refresh, user} = Auth.verify_otp(phone, otp_a, device_id: "hook-dev-a-#{uniq}")
      assert {:ok, _items, 0} = Notifications.list_for_user(user.id, %{})

      {:ok, otp_b} = Auth.send_otp(phone, device_id: "hook-dev-b-#{uniq}")
      assert {:ok, _access2, _refresh2, _user2} = Auth.verify_otp(phone, otp_b, device_id: "hook-dev-b-#{uniq}")
      assert_inbox_contains(user.id, "Alerte sécurité", "nouvel appareil")
    end
  end

  describe "jeu responsable et modération" do
    test "limites, exclusion, levée et pause notifient", %{user_a: a} do
      assert {:ok, _} = ResponsibleGaming.set_limits(a.id, %{"daily_deposit_limit" => 5000})
      assert_inbox_contains(a.id, "Alerte sécurité", "limites")

      assert {:ok, _} = ResponsibleGaming.self_exclude(a.id, 30, "pause volontaire de test")
      assert_inbox_contains(a.id, "Alerte sécurité", "30 jour")

      assert {:ok, _} = ResponsibleGaming.lift_exclusion(a.id)
      assert_inbox_contains(a.id, "Alerte sécurité", "levée")

      assert {:ok, _} = ResponsibleGaming.start_cooling_off(a.id, 2)
      assert_inbox_contains(a.id, "Alerte sécurité", "Pause")
    end

    test "ban et unban notifient l'utilisateur", %{user_a: a, user_b: b} do
      assert {:ok, _} = Security.ban_user(a.id, b.id, "spam de test", true, nil)
      assert_inbox_contains(a.id, "Alerte sécurité", "suspendu")

      assert :ok = Security.unban_user(a.id, b.id, "erreur de test")
      assert_inbox_contains(a.id, "Alerte sécurité", "réactivé")
    end
  end

  describe "succès" do
    test "déblocage notifie nom + xp", %{user_a: a, uniq: uniq} do
      Repo.insert!(%UserStat{user_id: a.id, wins: 1, games_played: 1})

      # Code unique par run (base partagée entre runs)
      Repo.delete_all(from ua in GameHub.Users.UserAchievement, where: ua.user_id == ^a.id)

      Repo.insert!(%Achievement{
        code: "hook_win_#{uniq}",
        name: "Première Victoire Hook",
        description: "test",
        condition_type: "wins",
        condition_value: 1,
        tier: "bronze",
        xp_reward: 100
      })

      assert {:ok, count} = AchievementManager.check_and_unlock(a.id)
      assert count >= 1
      assert_inbox_contains(a.id, "Succès débloqué", "Première Victoire Hook")
    end
  end
end
