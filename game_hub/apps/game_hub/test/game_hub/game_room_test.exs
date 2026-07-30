# ==================================
# WIWIGA - Tests GameRoom
# ==================================
defmodule GameHub.GameRoomTest do
  use ExUnit.Case, async: false

  alias GameHub.GameRoom

  setup do
    start_supervised!(GameRoom)
    :ok
  end

  describe "create_room/1" do
    test "crée une room free" do
      params = %{
        creator_id: "user_1",
        creator_name: "Testeur",
        game_type: "dice",
        rule_type: "normal",
        mode: :free,
        sets_count: 3,
        dice_count: 2,
        max_players: 4
      }

      assert {:ok, room} = GameRoom.create_room(params)
      assert room.creator_id == "user_1"
      assert room.mode == :free
      assert room.status == :waiting
      assert room.bet_amount == 0
      assert room.sets_count == 3
      assert room.room_code =~ ~r/^WIWIGA-[A-Z0-9]{4}$/
      assert length(room.players) == 1
    end

    test "crée une room betting" do
      params = %{
        creator_id: "user_1",
        game_type: "dice",
        mode: :betting,
        bet_amount: 5000,
        creator_name: "Testeur"
      }

      assert {:ok, room} = GameRoom.create_room(params)
      assert room.mode == :betting
      assert room.bet_amount == 5000
    end
  end

  describe "join_room/3" do
    test "un joueur rejoint la room" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      assert {:ok, updated} = GameRoom.join_room(room.room_id, "u2", "Joueur 2")
      assert length(updated.players) == 2
    end

    test "refuse si room pleine" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, max_players: 2, creator_name: "U1"})
      GameRoom.join_room(room.room_id, "u2")
      assert {:error, :room_full} = GameRoom.join_room(room.room_id, "u3")
    end

    test "refuse doublon" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      assert {:error, :already_in_room} = GameRoom.join_room(room.room_id, "u1")
    end
  end

  describe "leave_room/2" do
    test "un joueur quitte la room" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      GameRoom.join_room(room.room_id, "u2")
      assert {:ok, _} = GameRoom.leave_room(room.room_id, "u2")
    end

    test "si créateur part → room annulée" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      GameRoom.join_room(room.room_id, "u2")
      assert {:ok, :room_cancelled} = GameRoom.leave_room(room.room_id, "u1")
    end
  end

  describe "join_by_code/3" do
    test "rejoint par code" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      assert {:ok, joined} = GameRoom.join_by_code(room.room_code, "u2", "Joueur 2")
      assert joined.room_id == room.room_id
    end

    test "code invalide" do
      assert {:error, :room_not_found} = GameRoom.join_by_code("INVALID", "u1")
    end
  end

  describe "start_match/2" do
    test "démarre le match si créateur + 2 joueurs" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      GameRoom.join_room(room.room_id, "u2", "P2")
      assert {:ok, result} = GameRoom.start_match(room.room_id, "u1")
      assert result.room.status == :in_progress
      assert result.match.match_id != nil
    end

    test "refuse si pas créateur" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      GameRoom.join_room(room.room_id, "u2")
      assert {:error, :not_creator} = GameRoom.start_match(room.room_id, "u2")
    end

    test "refuse si pas assez de joueurs" do
      {:ok, room} = GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      assert {:error, :not_enough_players} = GameRoom.start_match(room.room_id, "u1")
    end
  end

  describe "list_waiting_rooms/2" do
    test "liste les rooms en attente" do
      GameRoom.create_room(%{creator_id: "u1", game_type: "dice", mode: :free, creator_name: "U1"})
      GameRoom.create_room(%{creator_id: "u2", game_type: "dice", mode: :betting, bet_amount: 500, creator_name: "U2"})

      all = GameRoom.list_waiting_rooms()
      assert length(all) == 2

      free = GameRoom.list_waiting_rooms(nil, :free)
      assert length(free) == 1

      betting = GameRoom.list_waiting_rooms(nil, :betting)
      assert length(betting) == 1
    end
  end

  describe "generate_room_code/0" do
    test "génère un code au format WIWIGA-XXXX" do
      code = GameRoom.generate_room_code()
      assert code =~ ~r/^WIWIGA-[A-Z0-9]{4}$/
    end
  end
end
