# ==================================
# WIWIGA - Tests GameStats
# ==================================
defmodule GameHub.GameStatsTest do
  @moduledoc """
  Tests du contexte GameStats.

  Tests:
  - record_match_result : agrégats gagnant/perdant, streaks, événements activité
  - leaderboard : métriques × périodes, my_rank
  - my_stats : agrégat vide et rempli
  - recent_activity : flux public
  """

  use ExUnit.Case, async: false

  alias GameHub.Repo
  alias GameHub.GameStats
  alias GameHub.GameStats.{GameStat, ActivityEvent}
  alias GameHub.Users.User

  setup do
    Repo.delete_all(ActivityEvent)
    Repo.delete_all(GameStat)
    Repo.delete_all(GameHub.Wallet.WalletTransaction)
    Repo.delete_all(User)

    alice = Repo.insert!(%User{phone: "+237699100001", name: "Alice", balance: 100_000,
                               is_active: true, has_verified_kyc: true})
    bob = Repo.insert!(%User{phone: "+237699100002", name: "Bob", balance: 100_000,
                             is_active: true, has_verified_kyc: true})

    GameStats.invalidate_cache("dice")

    %{alice: alice, bob: bob}
  end

  defp record_win(winner, loser, bet, net) do
    GameStats.record_match_result(%{
      game_type: "dice",
      winner_id: winner.id,
      player_ids: [winner.id, loser.id],
      bets: %{winner.id => %{amount: bet}, loser.id => %{amount: bet}},
      net_winnings: net
    })
  end

  describe "record_match_result/1" do
    test "crée les agrégats gagnant et perdant", %{alice: alice, bob: bob} do
      assert :ok = record_win(alice, bob, 1000, 1900)

      winner_stat = Repo.get_by!(GameStat, user_id: alice.id, game_type: "dice")
      assert winner_stat.matches_played == 1
      assert winner_stat.wins == 1
      assert winner_stat.losses == 0
      assert winner_stat.total_wagered == 1000
      assert winner_stat.total_won_net == 1900
      assert winner_stat.biggest_win == 1900
      assert winner_stat.current_streak == 1
      assert winner_stat.best_streak == 1
      assert winner_stat.last_played_at != nil

      loser_stat = Repo.get_by!(GameStat, user_id: bob.id, game_type: "dice")
      assert loser_stat.matches_played == 1
      assert loser_stat.wins == 0
      assert loser_stat.losses == 1
      assert loser_stat.total_wagered == 1000
      assert loser_stat.current_streak == 0
    end

    test "cumule les agrégats et gère les streaks", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(alice, bob, 2000, 3800)
      record_win(bob, alice, 500, 950)

      alice_stat = Repo.get_by!(GameStat, user_id: alice.id, game_type: "dice")
      assert alice_stat.matches_played == 3
      assert alice_stat.wins == 2
      assert alice_stat.losses == 1
      assert alice_stat.total_wagered == 3500
      assert alice_stat.total_won_net == 5700
      assert alice_stat.biggest_win == 3800
      # Streak cassée par la défaite du 3e match
      assert alice_stat.current_streak == 0
      assert alice_stat.best_streak == 2

      bob_stat = Repo.get_by!(GameStat, user_id: bob.id, game_type: "dice")
      assert bob_stat.wins == 1
      assert bob_stat.losses == 2
      assert bob_stat.current_streak == 1
    end

    test "insère un événement d'activité pour la victoire", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)

      events = Repo.all(ActivityEvent)
      assert length(events) == 1
      [event] = events
      assert event.user_id == alice.id
      assert event.event_type == "win"
      assert event.amount == 1900
    end

    test "match nul : aucun événement, pas de victoire", %{alice: alice, bob: bob} do
      assert :ok = GameStats.record_match_result(%{
        game_type: "dice",
        winner_id: nil,
        player_ids: [alice.id, bob.id],
        bets: %{alice.id => %{amount: 1000}, bob.id => %{amount: 1000}},
        net_winnings: 0
      })

      assert Repo.all(ActivityEvent) == []
      alice_stat = Repo.get_by!(GameStat, user_id: alice.id, game_type: "dice")
      assert alice_stat.wins == 0
      assert alice_stat.losses == 1
      assert alice_stat.matches_played == 1
    end

    test "accepte les clés de bets en string", %{alice: alice, bob: bob} do
      assert :ok = GameStats.record_match_result(%{
        game_type: "dice",
        winner_id: alice.id,
        player_ids: [alice.id, bob.id],
        bets: %{"#{alice.id}" => %{"amount" => 700}, "#{bob.id}" => %{"amount" => 700}},
        net_winnings: 1330
      })

      alice_stat = Repo.get_by!(GameStat, user_id: alice.id, game_type: "dice")
      assert alice_stat.total_wagered == 700
    end
  end

  describe "leaderboard/5" do
    test "classement all-time par victoires avec my_rank", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(alice, bob, 1000, 1900)
      record_win(bob, alice, 1000, 1900)

      {:ok, result} = GameStats.leaderboard("dice", "wins", "all", 10, bob.id)

      assert [first, second] = result.entries
      assert first.user_id == alice.id
      assert first.name == "Alice"
      assert first.value == 2
      assert first.rank == 1
      assert second.user_id == bob.id
      assert second.rank == 2

      assert result.my_rank == 2
      assert result.my_value == 1
    end

    test "classement all-time par plus gros gain", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(bob, alice, 5000, 9500)

      {:ok, result} = GameStats.leaderboard("dice", "biggest_win", "all", 10, nil)

      assert [first | _] = result.entries
      assert first.user_id == bob.id
      assert first.value == 9500
      assert result.my_rank == nil
    end

    test "classement période jour depuis les événements", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(alice, bob, 1000, 2100)

      {:ok, result} = GameStats.leaderboard("dice", "total_won", "day", 10, alice.id)

      assert [entry] = result.entries
      assert entry.user_id == alice.id
      assert entry.value == 4000
      assert result.my_rank == 1
    end

    test "rejette métrique et période invalides" do
      assert {:error, :invalid_metric} = GameStats.leaderboard("dice", "hacks", "all", 10, nil)
      assert {:error, :invalid_period} = GameStats.leaderboard("dice", "wins", "year", 10, nil)
    end
  end

  describe "my_stats/2" do
    test "retourne un agrégat vide si jamais joué", %{alice: alice} do
      stats = GameStats.my_stats(alice.id, "dice")
      assert stats.matches_played == 0
      assert stats.win_rate == 0.0
    end

    test "retourne les stats avec win_rate", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(bob, alice, 1000, 1900)

      stats = GameStats.my_stats(alice.id, "dice")
      assert stats.matches_played == 2
      assert stats.wins == 1
      assert stats.win_rate == 50.0
    end
  end

  describe "recent_activity/2" do
    test "retourne les victoires récentes avec pseudo", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(bob, alice, 1000, 2500)

      activity = GameStats.recent_activity("dice", 10)
      assert length(activity) == 2
      assert Enum.all?(activity, fn e -> e.name in ["Alice", "Bob"] end)
      assert Enum.all?(activity, fn e -> e.event_type == "win" end)
    end

    test "respecte la limite", %{alice: alice, bob: bob} do
      Enum.each(1..5, fn _ -> record_win(alice, bob, 1000, 1900) end)

      assert length(GameStats.recent_activity("dice", 3)) == 3
    end
  end

  describe "global_stats/1" do
    test "agrège les stats du jour", %{alice: alice, bob: bob} do
      record_win(alice, bob, 1000, 1900)
      record_win(bob, alice, 1000, 2500)
      GameStats.invalidate_cache("dice")

      stats = GameStats.global_stats("dice")
      assert stats.matches_today == 2
      assert stats.total_distributed_today == 4400
      assert stats.biggest_win_today == 2500
      assert stats.total_players == 2
    end
  end
end
