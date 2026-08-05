# ==================================
# WIWIGA - Schema Achievement
# ==================================
# Module: GameHub.Users.Achievement
# Description: Définition des achievements/badges

defmodule GameHub.Users.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "achievements" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :icon, :string, default: "star"
    field :tier, :string, default: "bronze"
    field :condition_type, :string
    field :condition_value, :integer
    field :xp_reward, :integer, default: 0

    timestamps()
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:code, :name, :description, :icon, :tier, :condition_type, :condition_value, :xp_reward])
    |> validate_required([:code, :name, :description, :condition_type, :condition_value])
    |> validate_inclusion(:tier, ~w(bronze silver gold diamond))
    |> validate_inclusion(:condition_type, ~w(games_played wins win_streak total_winnings xp_points perfect_prediction))
    |> unique_constraint(:code)
  end
end
