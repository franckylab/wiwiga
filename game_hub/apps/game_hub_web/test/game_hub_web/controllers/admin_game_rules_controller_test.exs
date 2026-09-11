defmodule GameHubWeb.AdminGameRulesControllerTest do
  @moduledoc """
  Tests de l'extension admin game-rules : dés, joueurs, mises,
  commission règle, égalité + cohérence min<=max.
  """

  use ExUnit.Case, async: false
  use Plug.Test

  alias GameHub.Games.GameRule
  alias GameHub.Repo
  alias GameHubWeb.AdminGameRulesController
  import Ecto.Query

  setup do
    Repo.delete_all(GameRule)
    GameHub.GameRules.invalidate_all_cache()

    Repo.insert!(%GameRule{
      game_type: "dice",
      rule_type: "normal",
      name: "Dés normal",
      config: %{
        "min_sets" => 1, "max_sets" => 7, "default_sets" => 3,
        "min_dice" => 1, "max_dice" => 6, "default_dice" => 2,
        "min_bet" => 100, "max_bet" => 50_000,
        "min_players" => 2, "max_players" => 5,
        "commission_rate" => 0.05
      },
      is_active: true
    })

    :ok
  end

  defp put_update(params) do
    AdminGameRulesController.update(
      conn(:put, "/api/admin/game-rules/dice/normal"),
      Map.merge(%{"game_type" => "dice", "rule_type" => "normal"}, params)
    )
  end

  defp config_of(conn) do
    conn.resp_body |> Jason.decode!() |> get_in(["data", "config"])
  end

  describe "PUT /api/admin/game-rules/:game_type/:rule_type (étendu)" do
    test "dés + joueurs valides" do
      conn = put_update(%{"min_dice" => 1, "max_dice" => 3, "min_players" => 2, "max_players" => 4})
      assert conn.status == 200
      config = config_of(conn)
      assert config["max_dice"] == 3
      assert config["max_players"] == 4
    end

    test "mises règle + commission décimale" do
      conn = put_update(%{"min_bet" => 50, "max_bet" => 100_000, "commission_rate" => 0.07})
      assert conn.status == 200
      config = config_of(conn)
      assert config["min_bet"] == 50
      assert_in_delta config["commission_rate"], 0.07, 0.0001
    end

    test "égalité + rejet incohérences" do
      assert put_update(%{"tie_rule" => "replay"}).status == 200
      assert put_update(%{"tie_rule" => "nimporte"}).status == 400
      assert put_update(%{"commission_rate" => 1.5}).status == 400
      assert put_update(%{"min_dice" => 5, "max_dice" => 2}).status == 400
      assert put_update(%{"min_bet" => 999_999, "max_bet" => 10}).status == 400
      assert put_update(%{"cle_inconnue_xyz" => 1}).status == 400
    end

    test "turn_timeout null = retour héritage (inchangé)" do
      conn = put_update(%{"turn_timeout_seconds" => nil})
      assert conn.status == 200
    end
  end
end
