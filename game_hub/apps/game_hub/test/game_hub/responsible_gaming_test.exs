# ==================================
# WIWIGA - Tests Responsible Gaming
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Couvre : portes check_before_bet/check_playable/check_deposit, perte
# nette (mises − gains), fuseau Douala, hausses différées 24h,
# auto-exclusion + sync users, cooling-off, sessions.

defmodule GameHub.ResponsibleGamingTest do
  use ExUnit.Case, async: false

  alias GameHub.Repo
  alias GameHub.ResponsibleGaming
  alias GameHub.ResponsibleGaming.ResponsibleGamingLimit
  alias GameHub.Users.User
  alias GameHub.Tokens.TokenTransaction

  import Ecto.Query

  setup do
    Repo.delete_all(TokenTransaction)
    Repo.delete_all(ResponsibleGamingLimit)
    Repo.delete_all(User)

    user =
      Repo.insert!(%User{
        phone: "+237699000001",
        name: "Test RG",
        balance: 100_000,
        token_balance: 1_000_000,
        is_active: true,
        has_verified_kyc: true
      })

    ResponsibleGaming.init_session_tracker()
    {:ok, user: user}
  end

  defp bet_tx(user_id, amount, type \\ "bet") do
    Repo.insert!(%TokenTransaction{
      user_id: user_id,
      type: type,
      token_amount: amount,
      balance_before: 0,
      balance_after: 0,
      idempotency_key: "rg_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
    })
  end

  defp set_raw_limits(user_id, attrs) do
    %ResponsibleGamingLimit{user_id: user_id}
    |> ResponsibleGamingLimit.changeset(attrs)
    |> Repo.insert!()
  end

  describe "check_before_bet/2 — portes de base" do
    test "autorise sans limites (défauts plateforme)", %{user: user} do
      assert :ok = ResponsibleGaming.check_before_bet(user.id, 100)
    end

    test "bloque la mise max par coup perso", %{user: user} do
      set_raw_limits(user.id, %{max_bet_amount: 500})
      assert {:error, :max_bet_exceeded} = ResponsibleGaming.check_before_bet(user.id, 501)
      assert :ok = ResponsibleGaming.check_before_bet(user.id, 500)
    end

    test "bloque le total misé du jour (wager)", %{user: user} do
      set_raw_limits(user.id, %{daily_wager_limit: 1000})
      bet_tx(user.id, -900)
      assert {:error, :daily_wager_reached} = ResponsibleGaming.check_before_bet(user.id, 200)
      assert :ok = ResponsibleGaming.check_before_bet(user.id, 100)
    end

    test "perte nette = mises − gains (un gagnant n'est pas bloqué)", %{user: user} do
      set_raw_limits(user.id, %{daily_loss_limit: 1000})
      bet_tx(user.id, -5000)
      bet_tx(user.id, 4800, "winnings")
      # Perte nette 200 < 1000 → autorisé malgré 5000 misés
      assert :ok = ResponsibleGaming.check_before_bet(user.id, 100)
      bet_tx(user.id, -900)
      # Perte nette 1100 >= 1000 → bloqué
      assert {:error, :daily_limit_reached} = ResponsibleGaming.check_before_bet(user.id, 100)
    end

    test "bloque le nombre de parties du jour", %{user: user} do
      set_raw_limits(user.id, %{daily_matches_limit: 2})
      bet_tx(user.id, -100)
      bet_tx(user.id, -100)
      assert {:error, :daily_matches_reached} = ResponsibleGaming.check_before_bet(user.id, 100)
    end

    test "bloque les pertes hebdo/mensuelles", %{user: user} do
      set_raw_limits(user.id, %{weekly_loss_limit: 500, monthly_loss_limit: 5000})
      bet_tx(user.id, -600)
      assert {:error, :weekly_limit_reached} = ResponsibleGaming.check_before_bet(user.id, 100)
    end
  end

  describe "exclusion, pause, session" do
    test "auto-exclusion bloque tout + sync users", %{user: user} do
      assert {:ok, _} = ResponsibleGaming.self_exclude(user.id, 7, "Besoin de pause")
      assert {:error, :self_excluded} = ResponsibleGaming.check_before_bet(user.id, 100)
      assert {:error, :self_excluded} = ResponsibleGaming.check_playable(user.id)
      assert {:error, :self_excluded} = ResponsibleGaming.check_deposit(user.id, 100)
      assert Repo.get(User, user.id).self_excluded == true
    end

    test "levée d'exclusion débloque les deux sources", %{user: user} do
      {:ok, _} = ResponsibleGaming.self_exclude(user.id, 7, "Besoin de pause")
      assert {:ok, _} = ResponsibleGaming.lift_exclusion(user.id)
      assert :ok = ResponsibleGaming.check_playable(user.id)
      assert Repo.get(User, user.id).self_excluded == false
    end

    test "self_exclude valide durée et motif", %{user: user} do
      assert {:error, :invalid_duration} = ResponsibleGaming.self_exclude(user.id, -1, "Pause")
      assert {:error, :invalid_reason} = ResponsibleGaming.self_exclude(user.id, 7, "x")
    end

    test "cooling-off bloque jeu et dépôt", %{user: user} do
      assert {:ok, _} = ResponsibleGaming.start_cooling_off(user.id, 1)
      assert {:error, :cooling_off} = ResponsibleGaming.check_before_bet(user.id, 100)
      assert {:error, :cooling_off} = ResponsibleGaming.check_playable(user.id)
      assert {:error, :cooling_off} = ResponsibleGaming.check_deposit(user.id, 100)
      assert {:error, :invalid_duration} = ResponsibleGaming.start_cooling_off(user.id, 99)
    end

    test "session expirée sans partie active s'auto-réinitialise", %{user: user} do
      ResponsibleGaming.start_session(user.id)
      # Pas de salle ni match actif → pas de dépassement même avec limite 0 min
      # (limite min 1 via changeset ; on force une session ancienne)
      :ets.insert(:rg_session_tracker, {user.id, System.monotonic_time(:second) - 10_000})
      # Limite haute : pas d'erreur, session conservée
      assert :ok = ResponsibleGaming.check_playable(user.id)
    end
  end

  describe "hausses différées 24h" do
    test "baisse immédiate, hausse en attente", %{user: user} do
      assert {:ok, limits} = ResponsibleGaming.set_limits(user.id, %{daily_loss_limit: 10_000})
      assert limits.daily_loss_limit == 10_000
      assert limits.pending_config == %{}

      assert {:ok, limits2} = ResponsibleGaming.set_limits(user.id, %{daily_loss_limit: 50_000})
      # Valeur effective inchangée, hausse en attente
      assert limits2.daily_loss_limit == 10_000
      assert limits2.pending_config["daily_loss_limit"] == 50_000
      assert not is_nil(limits2.pending_effective_at)
      # Le contrôle utilise toujours l'ancienne valeur
      assert ResponsibleGaming.effective_daily_loss(limits2) == 10_000
    end
  end

  describe "dépôts" do
    test "limite de dépôt quotidienne", %{user: user} do
      set_raw_limits(user.id, %{daily_deposit_limit: 1000})
      bet_tx(user.id, 900, "purchase")
      assert {:error, :daily_deposit_reached} = ResponsibleGaming.check_deposit(user.id, 200)
      assert :ok = ResponsibleGaming.check_deposit(user.id, 100)
    end
  end

  describe "périodes Douala" do
    test "douala_day_range dure 24h et décale d'1h (UTC+1)" do
      {start_utc, end_utc} = ResponsibleGaming.douala_day_range(~D[2026-09-06])
      assert DateTime.diff(end_utc, start_utc, :second) == 86_400
      assert start_utc.hour == 23
      assert DateTime.compare(start_utc, DateTime.new!(~D[2026-09-05], ~T[23:00:00])) == :eq
    end
  end

  describe "changeset cohérence" do
    test "rejette weekly < daily", %{user: user} do
      changeset =
        ResponsibleGamingLimit.changeset(%ResponsibleGamingLimit{user_id: user.id}, %{
          daily_loss_limit: 5000,
          weekly_loss_limit: 1000
        })

      refute changeset.valid?
    end

    test "accepte une hiérarchie cohérente", %{user: user} do
      changeset =
        ResponsibleGamingLimit.changeset(%ResponsibleGamingLimit{user_id: user.id}, %{
          daily_loss_limit: 1000,
          weekly_loss_limit: 5000,
          monthly_loss_limit: 20_000,
          daily_wager_limit: 5000,
          max_bet_amount: 500,
          daily_matches_limit: 10
        })

      assert changeset.valid?
    end
  end
end
