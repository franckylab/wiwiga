# ==================================
# WIWIGA - Module Admin PlayerProgression
# ==================================
# Module: GameHub.Admin.PlayerProgression
# Description: Configuration des niveaux joueur, XP, récompenses
#              Système de progression configurable par l'admin

defmodule GameHub.Admin.PlayerProgression do
  @moduledoc """
  Module de gestion de la progression joueur.

  ## Fonctionnalités
  - Configuration des tiers (Bronze → Légende)
  - Seuils XP configurables par tier
  - Récompenses par niveau (cashback, bonus, réductions)
  - Calcul du tier d'un joueur basé sur son XP
  - Cache ETS pour les configurations actives

  ## Tiers par défaut
  - Bronze (0-499 XP): Débutant
  - Silver (500-1999 XP): Apprenti
  - Gold (2000-4999 XP): Confirmé
  - Platinum (5000-9999 XP): Expert
  - Diamond (10000-24999 XP): Maître
  - Legend (25000+ XP): Légende

  ## Benefits configurables par tier
  - `cashback_rate`: Taux de cashback (0.0-1.0)
  - `withdrawal_bonus`: Bonus sur retrait (0.0-1.0)
  - `bet_discount`: Réduction commission (0.0-1.0)
  - `daily_bonus_multiplier`: Multiplicateur bonus journalier
  - `label`: Nom affiché du niveau
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @cache_table :admin_player_progression_cache

  # ========================================
  # Cache ETS
  # ========================================

  @doc "Initialise le cache ETS."
  def init_cache do
    if :ets.info(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :named_table, :public, read_concurrency: true])
    end
    :ok
  end

  # ========================================
  # API publique - Configuration des niveaux
  # ========================================

  @doc """
  Liste toutes les configurations de niveaux, triées par ordre.
  """
  @spec list_level_configs() :: list(map())
  def list_level_configs do
    Repo.all(
      from lc in "player_level_configs",
        order_by: [asc: lc.display_order],
        select: %{
          id: lc.id,
          tier: lc.tier,
          name: lc.name,
          min_xp: lc.min_xp,
          max_xp: lc.max_xp,
          icon: lc.icon,
          color: lc.color,
          benefits: lc.benefits,
          display_order: lc.display_order,
          is_active: lc.is_active
        }
    )
  end

  @doc """
  Récupère la configuration d'un niveau spécifique.
  """
  @spec get_level_config(String.t()) :: map() | nil
  def get_level_config(tier) do
    init_cache()

    case :ets.lookup(@cache_table, {:level, tier}) do
      [{_key, config}] -> config
      _ ->
        config = Repo.one(
          from lc in "player_level_configs",
            where: lc.tier == ^tier,
            select: %{
              id: lc.id, tier: lc.tier, name: lc.name,
              min_xp: lc.min_xp, max_xp: lc.max_xp,
              icon: lc.icon, color: lc.color,
              benefits: lc.benefits, display_order: lc.display_order,
              is_active: lc.is_active
            }
        )

        if config do
          :ets.insert(@cache_table, {{:level, tier}, config})
        end

        config
    end
  rescue
    _ -> nil
  end

  @doc """
  Détermine le tier d'un joueur basé sur son XP.
  Utilise le cache pour les configurations.
  """
  @spec calculate_tier(integer()) :: map()
  def calculate_tier(xp_points) when is_integer(xp_points) and xp_points >= 0 do
    configs = get_all_cached_levels()

    case Enum.find(configs, fn lc ->
      min = lc.min_xp || 0
      max = lc.max_xp
      xp_points >= min and (is_nil(max) or xp_points <= max)
    end) do
      nil -> default_bronze_config()
      config -> config
    end
  end

  @doc """
  Récupère les bénéfices d'un tier donné.
  """
  @spec get_benefits(String.t()) :: map()
  def get_benefits(tier) do
    case get_level_config(tier) do
      %{benefits: benefits} when is_map(benefits) -> benefits
      _ -> %{"cashback_rate" => 0.0, "withdrawal_bonus" => 0.0, "bet_discount" => 0.0, "daily_bonus_multiplier" => 1.0}
    end
  end

  @doc """
  Met à jour la configuration d'un niveau.
  """
  @spec update_level_config(String.t(), map(), integer()) :: {:ok, map()} | {:error, term()}
  def update_level_config(tier, attrs, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query = from lc in "player_level_configs",
      where: lc.tier == ^tier,
      update: [set: [
        name: ^Map.get(attrs, "name"),
        min_xp: ^Map.get(attrs, "min_xp"),
        max_xp: ^Map.get(attrs, "max_xp"),
        icon: ^Map.get(attrs, "icon"),
        color: ^Map.get(attrs, "color"),
        benefits: ^Map.get(attrs, "benefits", %{}),
        display_order: ^Map.get(attrs, "display_order"),
        is_active: ^Map.get(attrs, "is_active", true),
        updated_at: ^now
      ]],
      select: %{id: lc.id, tier: lc.tier, name: lc.name, min_xp: lc.min_xp, max_xp: lc.max_xp,
                icon: lc.icon, color: lc.color, benefits: lc.benefits}

    result = Repo.update_all(query, [])
    |> case do
      {1, [config]} -> {:ok, config}
      _ -> {:error, :not_found}
    end

    invalidate_cache({:level, tier})

    case result do
      {:ok, _config} ->
        AuditLog.log("admin_action", updated_by, "player_progression", tier, %{
          "action" => "update_level_config",
          "changes" => attrs
        })
      _ -> :ok
    end

    result
  end

  @doc """
  Calcule le cashback pour un joueur basé sur son tier.
  """
  @spec calculate_cashback(integer(), integer()) :: integer()
  def calculate_cashback(user_id, loss_amount) when loss_amount > 0 do
    xp = get_user_xp(user_id)
    tier_config = calculate_tier(xp)
    rate = unwrap_or_default(term(tier_config, [:benefits, "cashback_rate"]), 0.0)
    trunc(loss_amount * rate)
  end

  def calculate_cashback(_user_id, _loss_amount), do: 0

  @doc """
  Calcule la réduction de commission pour un joueur basé sur son tier.
  """
  @spec get_bet_discount_rate(integer()) :: float()
  def get_bet_discount_rate(user_id) do
    xp = get_user_xp(user_id)
    tier_config = calculate_tier(xp)
    unwrap_or_default(term(tier_config, [:benefits, "bet_discount"]), 0.0)
  end

  @doc """
  Récupère le multiplicateur de bonus journalier pour un joueur.
  """
  @spec get_daily_bonus_multiplier(integer()) :: float()
  def get_daily_bonus_multiplier(user_id) do
    xp = get_user_xp(user_id)
    tier_config = calculate_tier(xp)
    unwrap_or_default(term(tier_config, [:benefits, "daily_bonus_multiplier"]), 1.0)
  end

  # ========================================
  # Helpers privés
  # ========================================

  defp get_all_cached_levels do
    init_cache()

    case :ets.lookup(@cache_table, :all_levels) do
      [{:all_levels, levels}] -> levels
      _ ->
        levels = list_level_configs()
        :ets.insert(@cache_table, {:all_levels, levels})
        levels
    end
  rescue
    _ -> list_level_configs()
  end

  defp default_bronze_config do
    %{
      tier: "bronze", name: "Bronze", min_xp: 0, max_xp: 499,
      icon: "shield", color: "#CD7F32",
      benefits: %{"cashback_rate" => 0.0, "withdrawal_bonus" => 0.0, "bet_discount" => 0.0, "daily_bonus_multiplier" => 1.0}
    }
  end

  defp get_user_xp(user_id) do
    case Repo.one(
      from us in "user_stats",
        where: us.user_id == ^user_id,
        select: us.xp_points
    ) do
      nil -> 0
      xp when is_integer(xp) -> xp
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp term(struct, keys) do
    Enum.reduce(keys, struct, fn key, acc ->
      if is_map(acc), do: Map.get(acc, key), else: nil
    end)
  end

  defp unwrap_or_default(nil, default), do: default
  defp unwrap_or_default(value, _default), do: value

  defp invalidate_cache(key) do
    try do
      :ets.delete(@cache_table, key)
      :ets.delete(@cache_table, :all_levels)
    rescue
      _ -> :ok
    end
  end
end
