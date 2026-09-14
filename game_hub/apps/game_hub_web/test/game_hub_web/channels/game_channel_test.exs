# ==================================
# WIWIGA - Test Channel Jeu (roll_id)
# ==================================
# Vérifie la boucle complète client -> channel -> GameMatch :
# le roll_id traverse le transport et le retry est idempotent
# (mêmes dés, flag duplicate, pas de second lancer enregistré).

defmodule GameHubWeb.GameChannelTest do
  use ExUnit.Case, async: false
  use Phoenix.ChannelTest

  @endpoint GameHubWeb.Endpoint

  alias GameHub.GameMatch
  alias GameHubWeb.{GameChannel, UserSocket}

  setup do
    {:ok, match} =
      GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})

    GameMatch.add_player(match.match_id, "p1", "P1")
    GameMatch.add_player(match.match_id, "p2", "P2")
    GameMatch.start_match(match.match_id)
    {:ok, set} = GameMatch.start_set(match.match_id)
    first = List.first(set.current_set_state.turn_order)

    {:ok, _, socket} =
      socket(UserSocket, "user_id", %{user_id: first})
      |> subscribe_and_join(GameChannel, "game:" <> match.match_id)

    {:ok, match: match, first: first, socket: socket}
  end

  test "dice_rolled avec roll_id : reply + retry idempotent", %{
    socket: socket,
    first: first
  } do
    ref = push(socket, "dice_rolled", %{"roll_id" => "ch-e2e-1"})
    assert_reply ref, :ok, %{status: "rolled", duplicate: false} = reply
    assert reply.roll.player_id == first
    assert length(reply.roll.dice) == 2
    assert reply.roll.roll_id == "ch-e2e-1"

    # Retry réseau avec le MÊME roll_id : mêmes dés, pas de re-tirage.
    ref2 = push(socket, "dice_rolled", %{"roll_id" => "ch-e2e-1"})
    assert_reply ref2, :ok, %{duplicate: true} = retry
    assert retry.roll.dice == reply.roll.dice
    assert retry.roll.sum == reply.roll.sum
  end

  test "dice_rolled sans roll_id : comportement historique", %{socket: socket} do
    ref = push(socket, "dice_rolled", %{})
    assert_reply ref, :ok, %{status: "rolled"}
  end
end
