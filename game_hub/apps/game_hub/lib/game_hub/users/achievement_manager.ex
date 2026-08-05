# ==================================
# WIWIGA - Module Achievements (logique métier)
# ==================================
# Module: GameHub.Users.AchievementManager
# Description: Gestion des achievements — listing, unlock, vérification

defmodule GameHub.Users.AchievementManager do
  @moduledoc """
  Gestion des achievements/badges.
  
  - Liste tous les achievements avec statut unlock
  - Vérifie et débloque les achievements après une action
  - Seed des achievements par défaut
  """
  
  import Ecto.Query
  alias GameHub.{Repo, Users.Achievement, Users.UserAchievement, Users.Stats}
  
  @doc """
  Liste tous les achievements avec statut unlock pour un utilisateur.
  """
  def list_with_status(user_id) do
    achievements = Repo.all(
      from a in Achievement,
      order_by: [asc: a.tier, asc: a.code]
    )
    
    unlocked_ids = Repo.all(
      from ua in UserAchievement,
      where: ua.user_id == ^user_id,
      select: ua.achievement_id
    )
    
    unlocked_set = MapSet.new(unlocked_ids)
    
    Enum.map(achievements, fn a ->
      %{
        id: a.id,
        code: a.code,
        name: a.name,
        description: a.description,
        icon: a.icon,
        tier: a.tier,
        xp_reward: a.xp_reward,
        is_unlocked: MapSet.member?(unlocked_set, a.id),
        unlocked_at: get_unlocked_at(unlocked_ids, a.id, achievements)
      }
    end)
  end
  
  @doc """
  Vérifie et débloque les achievements éligibles pour un utilisateur.
  Appelé après recalcul des stats.
  """
  def check_and_unlock(user_id) do
    with {:ok, stats} <- Stats.get_stats(user_id) do
      achievements = Repo.all(Achievement)
      
      unlocked_ids = Repo.all(
        from ua in UserAchievement,
        where: ua.user_id == ^user_id,
        select: ua.achievement_id
      )
      
      locked = Enum.reject(achievements, &(&1.id in unlocked_ids))
      
      newly_unlocked = Enum.filter(locked, fn a ->
        condition_met?(a, stats)
      end)
      
      Enum.each(newly_unlocked, fn achievement ->
        unlock_achievement(user_id, achievement)
      end)
      
      {:ok, length(newly_unlocked)}
    end
  end
  
  @doc """
  Seed les achievements par défaut.
  """
  def seed_default_achievements do
    defaults = [
      %{code: "first_win", name: "Première Victoire", description: "Gagner sa première partie", icon: "emoji_events", tier: "bronze", condition_type: "wins", condition_value: 1, xp_reward: 100},
      %{code: "streak_5", name: "En Feu", description: "5 victoires consécutives", icon: "local_fire_department", tier: "silver", condition_type: "win_streak", condition_value: 5, xp_reward: 250},
      %{code: "streak_10", name: "Imbattable", description: "10 victoires consécutives", icon: "local_fire_department", tier: "gold", condition_type: "win_streak", condition_value: 10, xp_reward: 500},
      %{code: "games_10", name: "Débutant", description: "Jouer 10 parties", icon: "sports_esports", tier: "bronze", condition_type: "games_played", condition_value: 10, xp_reward: 50},
      %{code: "games_50", name: "Habitué", description: "Jouer 50 parties", icon: "sports_esports", tier: "silver", condition_type: "games_played", condition_value: 50, xp_reward: 150},
      %{code: "games_100", name: "Vétéran", description: "Jouer 100 parties", icon: "military_tech", tier: "gold", condition_type: "games_played", condition_value: 100, xp_reward: 300},
      %{code: "games_500", name: "Légende", description: "Jouer 500 parties", icon: "military_tech", tier: "diamond", condition_type: "games_played", condition_value: 500, xp_reward: 1000},
      %{code: "wins_10", name: "Sérieux", description: "Gagner 10 parties", icon: "emoji_events", tier: "silver", condition_type: "wins", condition_value: 10, xp_reward: 200},
      %{code: "wins_50", name: "Compétiteur", description: "Gagner 50 parties", icon: "emoji_events", tier: "gold", condition_type: "wins", condition_value: 50, xp_reward: 400},
      %{code: "wins_100", name: "Champion", description: "Gagner 100 parties", icon: "workspace_premium", tier: "diamond", condition_type: "wins", condition_value: 100, xp_reward: 800},
      %{code: "big_winner", name: "Gros Gain", description: "Gagner plus de 1 000 000 centimes total", icon: "attach_money", tier: "gold", condition_type: "total_winnings", condition_value: 1_000_000, xp_reward: 500},
      %{code: "xp_1000", name: "Montée en puissance", description: "Atteindre 1000 XP", icon: "trending_up", tier: "silver", condition_type: "xp_points", condition_value: 1000, xp_reward: 100},
      %{code: "xp_5000", name: "Vétéran XP", description: "Atteindre 5000 XP", icon: "trending_up", tier: "gold", condition_type: "xp_points", condition_value: 5000, xp_reward: 300},
      %{code: "xp_10000", name: "Maître", description: "Atteindre 10000 XP", icon: "diamond", tier: "diamond", condition_type: "xp_points", condition_value: 10000, xp_reward: 500}
    ]
    
    Enum.each(defaults, fn attrs ->
      case Repo.get_by(Achievement, code: attrs.code) do
        nil ->
          %Achievement{}
          |> Achievement.changeset(attrs)
          |> Repo.insert()
        
        _existing ->
          :skip
      end
    end)
    
    {:ok, length(defaults)}
  end
  
  # --- Fonctions privées ---
  
  defp condition_met?(achievement, stats) do
    case achievement.condition_type do
      "games_played" -> stats.games_played >= achievement.condition_value
      "wins" -> stats.wins >= achievement.condition_value
      "win_streak" -> stats.best_streak >= achievement.condition_value
      "total_winnings" -> stats.total_winnings >= achievement.condition_value
      "xp_points" -> stats.xp_points >= achievement.condition_value
      _ -> false
    end
  end
  
  defp unlock_achievement(user_id, achievement) do
    attrs = %{
      user_id: user_id,
      achievement_id: achievement.id,
      unlocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
    
    case %UserAchievement{} |> UserAchievement.changeset(attrs) |> Repo.insert() do
      {:ok, _} ->
        # Award XP reward
        if achievement.xp_reward > 0 do
          Stats.add_xp(user_id, achievement.xp_reward)
        end
      
      {:error, _} ->
        :skip
    end
  end
  
  defp get_unlocked_at(unlocked_ids, achievement_id, _achievements) do
    if achievement_id in unlocked_ids do
      case Repo.get_by(UserAchievement, achievement_id: achievement_id) do
        nil -> nil
        ua -> ua.unlocked_at
      end
    else
      nil
    end
  end
end
