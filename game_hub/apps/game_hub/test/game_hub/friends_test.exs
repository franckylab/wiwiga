# ==================================
# WIWIGA - Tests Friends
# ==================================
defmodule GameHub.FriendsTest do
  use ExUnit.Case, async: false

  alias GameHub.Friends
  alias GameHub.Friends.{Friendship, FriendMessage, FriendActivity}

  # Ces tests nécessitent une DB de test configurée
  # Ils sont marqués @moduletag :requires_db

  @moduletag :requires_db

  describe "Friendship schema" do
    test "create_changeset valide les champs requis" do
      changeset = Friendship.create_changeset(%Friendship{}, %{user_id: 1, friend_id: 2, status: "pending"})
      assert changeset.valid?
    end

    test "create_changeset refuse self-friendship" do
      changeset = Friendship.create_changeset(%Friendship{}, %{user_id: 1, friend_id: 1})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :friend_id)
    end

    test "create_changeset refuse status invalide" do
      changeset = Friendship.create_changeset(%Friendship{}, %{user_id: 1, friend_id: 2, status: "invalid"})
      refute changeset.valid?
    end

    test "accept_changeset change le status" do
      friendship = %Friendship{status: "pending"}
      changeset = Friendship.accept_changeset(friendship)
      assert Ecto.Changeset.get_change(changeset, :status) == "accepted"
    end

    test "block_changeset change le status" do
      friendship = %Friendship{status: "pending"}
      changeset = Friendship.block_changeset(friendship)
      assert Ecto.Changeset.get_change(changeset, :status) == "blocked"
    end
  end

  describe "FriendMessage schema" do
    test "create_changeset valide avec content" do
      changeset = FriendMessage.create_changeset(%FriendMessage{}, %{
        sender_id: 1, receiver_id: 2, content: "Hello!"
      })
      assert changeset.valid?
    end

    test "create_changeset valide avec emoji_type" do
      changeset = FriendMessage.create_changeset(%FriendMessage{}, %{
        sender_id: 1, receiver_id: 2, emoji_type: "thumbs_up"
      })
      assert changeset.valid?
    end

    test "create_changeset refuse sans content ni emoji" do
      changeset = FriendMessage.create_changeset(%FriendMessage{}, %{
        sender_id: 1, receiver_id: 2
      })
      refute changeset.valid?
    end
  end

  describe "FriendActivity schema" do
    test "create_changeset valide les actions" do
      for action <- ~w(game_won game_lost friend_added level_up bet_placed achievement_unlocked) do
        changeset = FriendActivity.create_changeset(%FriendActivity{}, %{
          user_id: 1, action: action, metadata: %{}
        })
        assert changeset.valid?, "Action '#{action}' devrait être valide"
      end
    end

    test "create_changeset refuse action invalide" do
      changeset = FriendActivity.create_changeset(%FriendActivity{}, %{
        user_id: 1, action: "invalid_action"
      })
      refute changeset.valid?
    end
  end
end
