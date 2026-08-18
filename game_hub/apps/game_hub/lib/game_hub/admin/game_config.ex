# ==================================
# WIWIGA - Module Admin GameConfig
# ==================================
# Module: GameHub.Admin.GameConfig
# Description: Configuration des jeux - commissions, limites, equilibrage

defmodule GameHub.Admin.GameConfig do
  @moduledoc """
  Module de configuration des jeux.

  Permet de configurer par type de jeu:
  - Taux de commission (remplace le 5% hardcode)
  - Mises min/max
  - Nombre max de joueurs
  - Parametres d'equilibrage (JSONB)
  - Activation/desactivation

  Cache ETS pour les configurations actives.
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @cache_table :admin_game_config_cache

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
  # API publique
  # ========================================

  @doc """
  Liste toutes les configurations de jeux.
  """
  @spec list_configs() :: list(map())
  def list_configs do
    Repo.all(
      from gc in "game_configs",
        order_by: [asc: gc.game_type],
        select: %{
          id: gc.id,
          game_type: gc.game_type,
          commission_rate: gc.commission_rate,
          min_bet: gc.min_bet,
          max_bet: gc.max_bet,
          max_players: gc.max_players,
          is_enabled: gc.is_active,
          settings: gc.config,
          inserted_at: gc.inserted_at,
          updated_at: gc.updated_at
        }
    )
  end

  @doc """
  Recupere la configuration d'un type de jeu.
  Utilise le cache ETS.
  """
  @spec get_config(String.t()) :: map() | nil
  def get_config(game_type) do
    init_cache()

    case :ets.lookup(@cache_table, game_type) do
      [{^game_type, config}] -> config
      _ ->
        config = Repo.one(
          from gc in "game_configs",
            where: gc.game_type == ^game_type,
            select: %{
              id: gc.id,
              game_type: gc.game_type,
              commission_rate: gc.commission_rate,
              min_bet: gc.min_bet,
              max_bet: gc.max_bet,
              max_players: gc.max_players,
              is_enabled: gc.is_active,
              settings: gc.config
            }
        )

        if config do
          :ets.insert(@cache_table, {game_type, config})
        end

        config
    end
  rescue
    _ -> nil
  end

  @doc """
  Recupere le taux de commission pour un type de jeu.
  Retourne la valeur par defaut si non configure.
  """
  @spec get_commission_rate(String.t()) :: float()
  def get_commission_rate(game_type) do
    case get_config(game_type) do
      %{commission_rate: rate} when not is_nil(rate) -> rate
      _ -> 0.05 # defaut 5%
    end
  end

  @doc """
  Cree ou met a jour la configuration d'un jeu.
  """
  @spec upsert_config(map(), integer()) :: {:ok, map()} | {:error, term()}
  def upsert_config(attrs, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    game_type = Map.get(attrs, "game_type") || Map.get(attrs, :game_type)

    existing = Repo.one(
      from gc in "game_configs",
        where: gc.game_type == ^game_type,
        select: gc.id
    )

    result = if existing do
      query = from gc in "game_configs",
        where: gc.id == ^existing,
        update: [set: [
          commission_rate: ^Map.get(attrs, "commission_rate", 0.05),
          min_bet: ^Map.get(attrs, "min_bet", 100),
          max_bet: ^Map.get(attrs, "max_bet", 1_000_000),
          max_players: ^Map.get(attrs, "max_players", 10),
          is_active: ^Map.get(attrs, "is_enabled", true),
          config: ^Map.get(attrs, "settings", %{}),
          updated_at: ^now
        ]],
        select: %{id: gc.id, game_type: gc.game_type, commission_rate: gc.commission_rate,
                  min_bet: gc.min_bet, max_bet: gc.max_bet, max_players: gc.max_players,
                  is_enabled: gc.is_active, config: gc.config}

      Repo.update_all(query, [])
      |> case do
        {1, [config]} -> {:ok, config}
        _ -> {:error, :update_failed}
      end
    else
      Repo.insert_all("game_configs", [
        %{
          game_type: game_type,
          commission_rate: Map.get(attrs, "commission_rate", 0.05),
          min_bet: Map.get(attrs, "min_bet", 100),
          max_bet: Map.get(attrs, "max_bet", 1_000_000),
          max_players: Map.get(attrs, "max_players", 10),
          is_active: Map.get(attrs, "is_enabled", true),
          config: Map.get(attrs, "settings", %{}),
          inserted_at: now,
          updated_at: now
        }
      ], returning: true)
      |> case do
        {1, [config]} -> {:ok, config}
        _ -> {:error, :insert_failed}
      end
    end

    # Invalider le cache
    invalidate_cache(game_type)

    # Audit
    case result do
      {:ok, config} ->
        AuditLog.log("admin_action", updated_by, "game_configs", game_type, %{
          "action" => if(existing, do: "update_config", else: "create_config"),
          "commission_rate" => config.commission_rate
        })
      _ -> :ok
    end

    result
  end

  @doc """
  Active ou desactive un type de jeu.
  """
  @spec toggle_enabled(String.t(), boolean(), integer()) :: {:ok, map()} | {:error, term()}
  def toggle_enabled(game_type, enabled, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query = from gc in "game_configs",
      where: gc.game_type == ^game_type,
      update: [set: [is_active: ^enabled, updated_at: ^now]],
      select: %{id: gc.id, game_type: gc.game_type, is_enabled: gc.is_active}

    result = Repo.update_all(query, [])
    |> case do
      {1, [config]} -> {:ok, config}
      _ -> {:error, :not_found}
    end

    invalidate_cache(game_type)

    AuditLog.log("admin_action", updated_by, "game_configs", game_type, %{
      "action" => "toggle_enabled",
      "enabled" => enabled
    })

    result
  end

  @doc """
  Recupere les types de jeu actifs (enabled).
  """
  @spec list_enabled_games() :: list(String.t())
  def list_enabled_games do
    Repo.all(
      from gc in "game_configs",
        where: gc.is_active == true,
        select: gc.game_type
    )
  end

  # ========================================
  # Helpers
  # ========================================

  defp invalidate_cache(game_type) do
    try do
      :ets.delete(@cache_table, game_type)
    rescue
      _ -> :ok
    end
  end
end
