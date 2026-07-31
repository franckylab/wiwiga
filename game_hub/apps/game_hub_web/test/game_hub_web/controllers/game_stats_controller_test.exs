# ==================================
# WIWIGA - Tests GameStatsController
# ==================================
defmodule GameHubWeb.GameStatsControllerTest do
  @moduledoc """
  Tests des endpoints stats/leaderboard/activity/rules/tips.

  Tests:
  - Contrats JSON (success/data/meta)
  - 404 jeu inconnu
  - Validation metric/period
  """

  use ExUnit.Case, async: false
  use Plug.Test

  alias GameHubWeb.GameStatsController
  alias GameHub.Repo
  alias GameHub.GameStats
  alias GameHub.GameStats.{GameStat, ActivityEvent}
  alias GameHub.Users.User
  alias GameHub.Games.GameConfig

  setup do
    Repo.delete_all(ActivityEvent)
    Repo.delete_all(GameStat)
    Repo.delete_all(GameConfig)
    Repo.delete_all(GameHub.Wallet.WalletTransaction)
    Repo.delete_all(User)

    user = Repo.insert!(%User{
      phone: "+237699000300",
      name: "Stats Test User",
      balance: 200_000,
      is_active: true,
      has_verified_kyc: true
    })

    opponent = Repo.insert!(%User{
      phone: "+237699000301",
      name: "Opponent",
      balance: 200_000,
      is_active: true,
      has_verified_kyc: true
    })

    Repo.insert!(%GameConfig{
      game_type: "dice",
      name: "Jeu de Dés",
      description: "Pariez sur la somme des dés",
      min_bet: 100,
      max_bet: 100_000,
      commission_rate: Decimal.new("0.05"),
      commission_mode: "percentage",
      is_active: true,
      coming_soon: false,
      display_order: 1,
      tips: %{"items" => [%{"title" => "Astuce", "body" => "Commencez petit"}]},
      config: %{}
    })

    GameStats.record_match_result(%{
      game_type: "dice",
      winner_id: user.id,
      player_ids: [user.id, opponent.id],
      bets: %{user.id => %{amount: 1000}, opponent.id => %{amount: 1000}},
      net_winnings: 1900
    })

    GameStats.invalidate_cache("dice")

    %{user: user, opponent: opponent}
  end

  defp authed_conn(method, path, user) do
    conn(method, path) |> put_private(:current_user_id, user.id)
  end

  describe "stats/2" do
    test "retourne les stats globales" do
      conn = conn(:get, "/api/games/dice/stats")
      conn = GameStatsController.stats(conn, %{"game_type" => "dice"})

      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      assert response["success"] == true
      data = response["data"]
      assert data["matches_today"] == 1
      assert data["total_distributed_today"] == 1900
      assert data["biggest_win_today"] == 1900
      assert Map.has_key?(data, "players_online")
      assert Map.has_key?(response["meta"], "timestamp")
    end

    test "404 pour jeu inconnu" do
      conn = conn(:get, "/api/games/poker/stats")
      conn = GameStatsController.stats(conn, %{"game_type" => "poker"})

      assert conn.status == 404
      assert Jason.decode!(conn.resp_body)["error"]["code"] == "GAME_NOT_FOUND"
    end
  end

  describe "leaderboard/2" do
    test "retourne le classement avec my_rank", %{user: user} do
      conn = authed_conn(:get, "/api/games/dice/leaderboard", user)
      conn = GameStatsController.leaderboard(conn, %{
        "game_type" => "dice", "metric" => "wins", "period" => "all"
      })

      assert conn.status == 200
      data = Jason.decode!(conn.resp_body)["data"]
      assert data["metric"] == "wins"
      assert data["period"] == "all"
      assert [entry] = data["entries"]
      assert entry["name"] == "Stats Test User"
      assert entry["value"] == 1
      assert entry["rank"] == 1
      assert data["my_rank"] == 1
    end

    test "400 pour métrique invalide", %{user: user} do
      conn = authed_conn(:get, "/api/games/dice/leaderboard", user)
      conn = GameStatsController.leaderboard(conn, %{
        "game_type" => "dice", "metric" => "cheats"
      })

      assert conn.status == 400
    end

    test "400 pour période invalide", %{user: user} do
      conn = authed_conn(:get, "/api/games/dice/leaderboard", user)
      conn = GameStatsController.leaderboard(conn, %{
        "game_type" => "dice", "period" => "decade"
      })

      assert conn.status == 400
    end
  end

  describe "my_stats/2" do
    test "retourne les stats personnelles", %{user: user} do
      conn = authed_conn(:get, "/api/games/dice/my-stats", user)
      conn = GameStatsController.my_stats(conn, %{"game_type" => "dice"})

      assert conn.status == 200
      data = Jason.decode!(conn.resp_body)["data"]
      assert data["matches_played"] == 1
      assert data["wins"] == 1
      assert data["win_rate"] == 100.0
    end
  end

  describe "activity/2" do
    test "retourne le flux d'activité" do
      conn = conn(:get, "/api/games/dice/activity")
      conn = GameStatsController.activity(conn, %{"game_type" => "dice"})

      assert conn.status == 200
      data = Jason.decode!(conn.resp_body)["data"]
      assert [event] = data
      assert event["name"] == "Stats Test User"
      assert event["amount"] == 1900
      assert event["event_type"] == "win"
    end
  end

  describe "rules/2" do
    test "retourne les règles du jeu (liste depuis DB)" do
      conn = conn(:get, "/api/games/dice/rules")
      conn = GameStatsController.rules(conn, %{"game_type" => "dice"})

      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      assert response["success"] == true
      assert is_list(response["data"])
    end
  end

  describe "tips/2" do
    test "retourne les astuces depuis game_configs.tips" do
      conn = conn(:get, "/api/games/dice/tips")
      conn = GameStatsController.tips(conn, %{"game_type" => "dice"})

      assert conn.status == 200
      data = Jason.decode!(conn.resp_body)["data"]
      assert [tip] = data
      assert tip["title"] == "Astuce"
    end

    test "liste vide si pas d'astuces" do
      Repo.insert!(%GameConfig{
        game_type: "ludo",
        name: "Ludo",
        min_bet: 100,
        max_bet: 100_000,
        commission_rate: Decimal.new("0.05"),
        commission_mode: "percentage",
        is_active: true,
        coming_soon: true
      })

      conn = conn(:get, "/api/games/ludo/tips")
      conn = GameStatsController.tips(conn, %{"game_type" => "ludo"})

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["data"] == []
    end
  end
end
