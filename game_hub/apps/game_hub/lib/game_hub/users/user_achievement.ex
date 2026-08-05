# ==================================
# WIWIGA - Schema User Achievement
# ==================================
# Module: GameHub.Users.UserAchievement
# Description: Achievement débloqué par un utilisateur

defmodule GameHub.Users.UserAchievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "user_achievements" do
    belongs_to :user, GameHub.Users.User
    belongs_to :achievement, GameHub.Users.Achievement
    field :unlocked_at, :utc_datetime

    timestamps()
  end

  def changeset(user_achievement, attrs) do
    user_achievement
    |> cast(attrs, [:user_id, :achievement_id, :unlocked_at])
    |> validate_required([:user_id, :achievement_id, :unlocked_at])
    |> unique_constraint([:user_id, :achievement_id])
  end
end
