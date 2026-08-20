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
          name: gc.name,
          description: gc.description,
          commission_rate: gc.commission_rate,
          commission_mode: gc.commission_mode,
          min_bet: gc.min_bet,
          max_bet: gc.max_bet,
          min_bet_tokens: gc.min_bet_tokens,
          is_enabled: gc.is_active,
          coming_soon: gc.coming_soon,
          display_order: gc.display_order,
          settings: gc.config,
          inserted_at: gc.inserted_at,
          updated_at: gc.updated_at
        }
    )
    |> Enum.map(&serialize_config/1)
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
              name: gc.name,
              description: gc.description,
              commission_rate: gc.commission_rate,
              commission_mode: gc.commission_mode,
              min_bet: gc.min_bet,
              max_bet: gc.max_bet,
              min_bet_tokens: gc.min_bet_tokens,
              is_enabled: gc.is_active,
              coming_soon: gc.coming_soon,
              display_order: gc.display_order,
              settings: gc.config
            }
        )
        |> serialize_config()

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

    # Préparer les valeurs, en acceptant les params du controller ou des valeurs par défaut
    commission_rate = Map.get(attrs, "commission_rate", 0.05)
    min_bet = Map.get(attrs, "min_bet", 100)
    max_bet = Map.get(attrs, "max_bet", 1_000_000)
    min_bet_tokens = Map.get(attrs, "min_bet_tokens")
    is_active = Map.get(attrs, "is_enabled", Map.get(attrs, "is_active", true))
    settings = Map.get(attrs, "settings", Map.get(attrs, "config", %{}))
    name = Map.get(attrs, "name")
    description = Map.get(attrs, "description")
    coming_soon = Map.get(attrs, "coming_soon")
    display_order = Map.get(attrs, "display_order")

    result = if existing do
      # Construire la liste des champs à mettre à jour dynamiquement
      updates = [
        commission_rate: commission_rate,
        min_bet: min_bet,
        max_bet: max_bet,
        is_active: is_active,
        config: settings,
        updated_at: now
      ]

      # Ajouter les champs optionnels seulement s'ils sont fournis
      updates = maybe_add_field(updates, :name, name)
      updates = maybe_add_field(updates, :description, description)
      updates = maybe_add_field(updates, :coming_soon, coming_soon)
      updates = maybe_add_field(updates, :display_order, display_order)
      updates = maybe_add_field(updates, :min_bet_tokens, min_bet_tokens)

      query = from gc in "game_configs",
        where: gc.id == ^existing,
        update: [set: ^updates],
        select: %{
          id: gc.id, game_type: gc.game_type, name: gc.name,
          commission_rate: gc.commission_rate, commission_mode: gc.commission_mode,
          min_bet: gc.min_bet, max_bet: gc.max_bet, min_bet_tokens: gc.min_bet_tokens,
          is_enabled: gc.is_active, coming_soon: gc.coming_soon,
          display_order: gc.display_order, config: gc.config
        }

      Repo.update_all(query, [])
      |> case do
        {1, [config]} -> {:ok, serialize_config(config)}
        _ -> {:error, :update_failed}
      end
    else
      insert_data = %{
        game_type: game_type,
        commission_rate: commission_rate,
        min_bet: min_bet,
        max_bet: max_bet,
        is_active: is_active,
        config: settings,
        inserted_at: now,
        updated_at: now
      }
      |> maybe_put(:name, name)
      |> maybe_put(:description, description)
      |> maybe_put(:coming_soon, coming_soon)
      |> maybe_put(:display_order, display_order)
      |> maybe_put(:min_bet_tokens, min_bet_tokens)

      Repo.insert_all("game_configs", [insert_data], returning: true)
      |> case do
        {1, [config]} -> {:ok, serialize_config(config)}
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
          "commission_rate" => config[:commission_rate]
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
      select: %{
        id: gc.id,
        game_type: gc.game_type,
        is_enabled: gc.is_active
      }

    result = Repo.update_all(query, [])
    |> case do
      {1, [config]} -> {:ok, serialize_config(config)}
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

  # ========================================
  # Helpers — Sérialisation
  # ========================================

  # Convertit les Decimal en float pour la sérialisation JSON
  defp serialize_config(nil), do: nil

  defp serialize_config(%{} = config) do
    config
    |> maybe_convert_decimal(:commission_rate)
  end

  defp maybe_convert_decimal(map, key) do
    case Map.get(map, key) do
      %Decimal{} = val -> Map.put(map, key, Decimal.to_float(val))
      _ -> map
    end
  end

  # Helpers pour champs optionnels dans upsert
  defp maybe_add_field(updates, _key, nil), do: updates
  defp maybe_add_field(updates, key, value) do
    Keyword.put(updates, key, value)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
