# ==================================
# WIWIGA - Module Admin SystemSettings
# ==================================
# Module: GameHub.Admin.SystemSettings
# Description: Settings système globaux avec cache ETS

defmodule GameHub.Admin.SystemSettings do
  @moduledoc """
  Module de gestion des paramètres système.
  
  Catégories:
  - `general`: nom plateforme, timezone, langue, maintenance mode
  - `email`: SMTP host, port, from address
  - `storage`: max upload size, image quality
  - `notification`: email notifications, push notifications
  
  Cache en ETS avec invalidation sur update.
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @cache_table :admin_settings_cache

  # ========================================
  # API publique
  # ========================================

  @doc """
  Initialise le cache ETS.
  """
  def init_cache do
    if :ets.info(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :named_table, :public, read_concurrency: true])
    end
    :ok
  end

  @doc """
  Récupère tous les settings groupés par catégorie.
  """
  @spec get_all_settings() :: map()
  def get_all_settings do
    init_cache()

    case safe_ets_lookup(:all_settings) do
      nil ->
        settings = load_all_settings()
        safe_ets_insert(:all_settings, settings)
        settings
      settings -> settings
    end
  end

  @doc """
  Récupère les settings d'une catégorie.
  """
  @spec get_category(String.t()) :: list(map())
  def get_category(category) do
    Repo.all(
      from s in "system_settings",
        where: s.category == ^category,
        order_by: [asc: s.key],
        select: %{
          id: s.id,
          key: s.key,
          value: s.value,
          category: s.category,
          description: s.description,
          updated_by: s.updated_by,
          updated_at: s.updated_at
        }
    )
  end

  @doc """
  Récupère un setting par sa clé.
  """
  @spec get(String.t()) :: {:ok, String.t() | nil} | {:error, term()}
  def get(key) do
    case Repo.one(
      from s in "system_settings",
        where: s.key == ^key,
        select: s.value
    ) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end

  @doc """
  Met à jour un setting.
  """
  @spec update(String.t(), String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def update(key, value, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Récupérer l'ancienne valeur pour l'audit
    old_value = Repo.one(
      from s in "system_settings",
        where: s.key == ^key,
        select: s.value
    )

    query = from s in "system_settings",
      where: s.key == ^key,
      update: [set: [value: ^value, updated_by: ^updated_by, updated_at: ^now]],
      select: %{id: s.id, key: s.key, value: s.value, category: s.category}

    result = Repo.update_all(query, [])

    case result do
      {count, [setting]} when count > 0 ->
        # Invalider le cache
        invalidate_cache()

        # Logger le changement
        AuditLog.log("admin_action", updated_by, "settings", key, %{
          "action" => "update_setting",
          "old_value" => old_value,
          "new_value" => value
        })

        {:ok, setting}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Récupère un booléen de configuration (ex: maintenance_mode).
  """
  @spec get_bool(String.t(), boolean()) :: boolean()
  def get_bool(key, default \\ false) do
    case get(key) do
      {:ok, "true"} -> true
      {:ok, "false"} -> false
      {:ok, nil} -> default
      _ -> default
    end
  end

  @doc """
  Vérifie si le mode maintenance est actif.
  """
  @spec maintenance_mode?() :: boolean()
  def maintenance_mode? do
    get_bool("maintenance_mode", false)
  end

  # ========================================
  # Helpers
  # ========================================

  defp load_all_settings do
    Repo.all(
      from s in "system_settings",
        order_by: [asc: s.category, asc: s.key],
        select: %{
          id: s.id,
          key: s.key,
          value: s.value,
          category: s.category,
          description: s.description,
          updated_by: s.updated_by,
          updated_at: s.updated_at
        }
    )
    |> Enum.group_by(& &1.category)
  rescue
    _ -> %{}
  end

  defp invalidate_cache do
    try do
      :ets.delete(@cache_table, :all_settings)
    rescue
      _ -> :ok
    end
  end

  defp safe_ets_lookup(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, value}] -> value
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp safe_ets_insert(key, value) do
    :ets.insert(@cache_table, {key, value})
  rescue
    _ -> :ok
  end
end
