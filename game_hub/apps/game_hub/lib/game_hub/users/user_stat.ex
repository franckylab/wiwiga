# ==================================
# WIWIGA - Schema User Stats
# ==================================
# Module: GameHub.Users.UserStat
# Description: Statistiques agrégées profil utilisateur
#              Calculées depuis game_stats après chaque partie

defmodule GameHub.Users.UserStat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "user_stats" do
    belongs_to :user, GameHub.Users.User

    field :games_played, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :draws, :integer, default: 0
    field :total_winnings, :integer, default: 0
    field :total_bets, :integer, default: 0
    field :current_streak, :integer, default: 0
    field :best_streak, :integer, default: 0
    field :xp_points, :integer, default: 0
    field :rank_tier, :string, default: "bronze"
    field :last_game_at, :utc_datetime

    timestamps()
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [
      :user_id, :games_played, :wins, :losses, :draws,
      :total_winnings, :total_bets, :current_streak, :best_streak,
      :xp_points, :rank_tier, :last_game_at
    ])
    |> validate_required([:user_id])
    |> validate_number(:games_played, greater_than_or_equal_to: 0)
    |> validate_number(:wins, greater_than_or_equal_to: 0)
    |> validate_number(:losses, greater_than_or_equal_to: 0)
    |> validate_number(:xp_points, greater_than_or_equal_to: 0)
    |> validate_inclusion(:rank_tier, ~w(bronze silver gold platinum diamond))
    |> unique_constraint(:user_id)
  end

  @doc """
  Calcule le rank tier basé sur les XP points.
  """
  def rank_from_xp(xp) when xp >= 20000, do: "diamond"
  def rank_from_xp(xp) when xp >= 10000, do: "platinum"
  def rank_from_xp(xp) when xp >= 5000, do: "gold"
  def rank_from_xp(xp) when xp >= 2000, do: "silver"
  def rank_from_xp(_xp), do: "bronze"
end
