# ==================================
# WIWIGA - Schema Statistiques Jeu
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameStats.GameStat
# Description: Agrégat statistiques par joueur × jeu

defmodule GameHub.GameStats.GameStat do
  @moduledoc """
  Agrégat de statistiques par joueur et par type de jeu.

  Mis à jour en fin de match via `GameHub.GameStats.record_match_result/1`.

  ## Fields
    - `matches_played` / `wins` / `losses`
    - `total_wagered`: total misé (centimes)
    - `total_won_net`: total gagné net (centimes)
    - `biggest_win`: plus gros gain net sur un match
    - `current_streak` / `best_streak`: séries de victoires
    - `last_played_at`: dernier match joué
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:user_id, :game_type, :matches_played, :wins, :losses,
                                 :total_wagered, :total_won_net, :biggest_win,
                                 :current_streak, :best_streak, :last_played_at]}

  schema "game_stats" do
    field :user_id, :integer
    field :game_type, :string
    field :matches_played, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :total_wagered, :integer, default: 0
    field :total_won_net, :integer, default: 0
    field :biggest_win, :integer, default: 0
    field :current_streak, :integer, default: 0
    field :best_streak, :integer, default: 0
    field :last_played_at, :utc_datetime

    timestamps()
  end

  @doc """
  Changeset pour création/upsert d'un agrégat.
  """
  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:user_id, :game_type, :matches_played, :wins, :losses,
                    :total_wagered, :total_won_net, :biggest_win,
                    :current_streak, :best_streak, :last_played_at])
    |> validate_required([:user_id, :game_type])
    |> unique_constraint([:user_id, :game_type])
  end
end
