# ==================================
# WIWIGA - Module Statistiques Utilisateur
# ==================================
# Module: GameHub.Users.Stats
# Description: Gestion des statistiques profil
#              Agrégation depuis game_stats + XP/rank calculation

defmodule GameHub.Users.Stats do
  @moduledoc """
  Statistiques utilisateur pour le profil.
  
  Agrège les données de game_stats (par jeu) en stats globales.
  Gère le calcul XP et le rank tier.
  """
  
  import Ecto.Query
  alias GameHub.{Repo, Users.UserStat}
  alias GameHub.GameStats.GameStat
  
  @doc """
  Récupère les stats d'un utilisateur.
  Crée une entrée vide si elle n'existe pas.
  """
  def get_stats(user_id) do
    case Repo.get_by(UserStat, user_id: user_id) do
      nil -> create_empty_stats(user_id)
      stats -> {:ok, stats}
    end
  end
  
  @doc """
  Recalcule les stats globales d'un utilisateur depuis game_stats.
  Appelé après chaque partie terminée.
  """
  def recalculate(user_id) do
    # Agrégation depuis game_stats (tous les types de jeu)
    aggregates = Repo.one(
      from gs in GameStat,
      where: gs.user_id == ^user_id,
      select: %{
        games_played: coalesce(sum(gs.matches_played), 0),
        wins: coalesce(sum(gs.wins), 0),
        losses: coalesce(sum(gs.losses), 0),
        total_wagered: coalesce(sum(gs.total_wagered), 0),
        total_won_net: coalesce(sum(gs.total_won_net), 0),
        current_streak: coalesce(max(gs.current_streak), 0),
        best_streak: coalesce(max(gs.best_streak), 0),
        last_played: max(gs.last_played_at)
      }
    )
    
    # Calcul XP: win=+100, loss=+25, streak bonus=+50 par 3+ streak
    xp = calculate_xp(aggregates)
    rank = UserStat.rank_from_xp(xp)
    
    attrs = %{
      user_id: user_id,
      games_played: aggregates.games_played,
      wins: aggregates.wins,
      losses: aggregates.losses,
      total_winnings: max(aggregates.total_won_net, 0),
      total_bets: aggregates.total_wagered,
      current_streak: aggregates.current_streak,
      best_streak: aggregates.best_streak,
      xp_points: xp,
      rank_tier: rank,
      last_game_at: aggregates.last_played
    }
    
    # Upsert
    case Repo.get_by(UserStat, user_id: user_id) do
      nil ->
        %UserStat{}
        |> UserStat.changeset(attrs)
        |> Repo.insert()
      
      existing ->
        existing
        |> UserStat.changeset(attrs)
        |> Repo.update()
    end
  end
  
  @doc """
  Ajoute des XP directement (ex: reward achievement).
  """
  def add_xp(user_id, xp_amount) do
    case get_stats(user_id) do
      {:ok, stats} ->
        new_xp = stats.xp_points + xp_amount
        new_rank = UserStat.rank_from_xp(new_xp)
        
        stats
        |> UserStat.changeset(%{xp_points: new_xp, rank_tier: new_rank})
        |> Repo.update()
      
      error -> error
    end
  end
  
  # --- Fonctions privées ---
  
  defp create_empty_stats(user_id) do
    attrs = %{user_id: user_id}
    
    case %UserStat{} |> UserStat.changeset(attrs) |> Repo.insert() do
      {:ok, stats} -> {:ok, stats}
      {:error, _} -> {:ok, %UserStat{user_id: user_id}}
    end
  end
  
  defp calculate_xp(%{wins: wins, losses: losses, best_streak: best_streak}) do
    win_xp = wins * 100
    loss_xp = losses * 25
    streak_bonus = if best_streak >= 3, do: (best_streak - 2) * 50, else: 0
    
    win_xp + loss_xp + streak_bonus
  end
end
