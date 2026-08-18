# ==================================
# WIWIGA - Module Admin PlatformConfig
# ==================================
# Module: GameHub.Admin.PlatformConfig
# Description: Configuration centralisée de tous les aspects de la plateforme
#              Payment, Security, Registration, Social, Ranking, Gaming, Notification

defmodule GameHub.Admin.PlatformConfig do
  @moduledoc """
  Module de configuration centralisée de la plateforme.

  ## Catégories
  - `payment`: Dépôts, retraits, frais, KYC, limites
  - `security`: Rate limiting, 2FA, sessions, verrouillage
  - `registration`: Vérification, bonus bienvenue, âge, parrainage
  - `social`: Amis, chat, leaderboard social
  - `ranking`: Leaderboard, métriques, récompenses
  - `gaming`: Parties, timeouts, commissions, limites
  - `notification`: Push, email, webhooks, alertes

  ## Architecture
  - Table `platform_configs` avec category + key unique
  - Cache ETS par catégorie
  - Validation des valeurs selon les règles configurées
  - Audit des changements
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @cache_table :admin_platform_config_cache

  @valid_categories ~w(payment security registration social ranking gaming notification)

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
  # API publique - Lecture
  # ========================================

  @doc """
  Liste toutes les configurations groupées par catégorie.
  """
  @spec get_all_grouped() :: map()
  def get_all_grouped do
    init_cache()

    case safe_ets_lookup(:all_grouped) do
      nil ->
        grouped = load_all_grouped()
        safe_ets_insert(:all_grouped, grouped)
        grouped
      grouped -> grouped
    end
  end

  @doc """
  Récupère les configurations d'une catégorie.
  """
  @spec get_category(String.t()) :: list(map())
  def get_category(category) when category in @valid_categories do
    init_cache()

    case safe_ets_lookup({:category, category}) do
      nil ->
        configs = load_category(category)
        safe_ets_insert({:category, category}, configs)
        configs
      configs -> configs
    end
  end

  def get_category(_), do: []

  @doc """
  Récupère une valeur de configuration spécifique.
  Retourne la valeur typée (integer, float, boolean, string).
  """
  @spec get_value(String.t(), String.t(), term()) :: term()
  def get_value(category, key, default \\ nil) do
    case Repo.one(
      from pc in "platform_configs",
        where: pc.category == ^category and pc.key == ^key,
        select: %{value: pc.value, value_type: pc.value_type, default_value: pc.default_value}
    ) do
      nil -> default
      %{value: nil, default_value: dv} -> parse_typed_value(dv, "string")
      %{value: val, value_type: vtype} -> parse_typed_value(val, vtype)
    end
  rescue
    _ -> default
  end

  @doc """
  Récupère un entier de configuration.
  """
  @spec get_int(String.t(), String.t(), integer()) :: integer()
  def get_int(category, key, default \\ 0) do
    case get_value(category, key, default) do
      val when is_integer(val) -> val
      val when is_float(val) -> trunc(val)
      val when is_binary(val) ->
        case Integer.parse(val) do
          {n, _} -> n
          :error -> default
        end
      _ -> default
    end
  end

  @doc """
  Récupère un float de configuration.
  """
  @spec get_float(String.t(), String.t(), float()) :: float()
  def get_float(category, key, default \\ 0.0) do
    case get_value(category, key, default) do
      val when is_float(val) -> val
      val when is_integer(val) -> val / 1
      val when is_binary(val) ->
        case Float.parse(val) do
          {n, _} -> n
          :error -> default
        end
      _ -> default
    end
  end

  @doc """
  Récupère un booléen de configuration.
  """
  @spec get_bool(String.t(), String.t(), boolean()) :: boolean()
  def get_bool(category, key, default \\ false) do
    case get_value(category, key, default) do
      val when is_boolean(val) -> val
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  # ========================================
  # API publique - Écriture
  # ========================================

  @doc """
  Met à jour une valeur de configuration.
  """
  @spec update(String.t(), String.t(), String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def update(category, key, value, updated_by) do
    # Valider la catégorie
    if category not in @valid_categories do
      {:error, :invalid_category}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Récupérer l'ancienne valeur pour audit
      old_value = Repo.one(
        from pc in "platform_configs",
          where: pc.category == ^category and pc.key == ^key,
          select: pc.value
      )

      query = from pc in "platform_configs",
        where: pc.category == ^category and pc.key == ^key,
        update: [set: [value: ^value, updated_by: ^updated_by, updated_at: ^now]],
        select: %{id: pc.id, category: pc.category, key: pc.key, value: pc.value,
                  value_type: pc.value_type, label: pc.label}

      result = Repo.update_all(query, [])
      |> case do
        {count, [config]} when count > 0 -> {:ok, config}
        _ -> {:error, :not_found}
      end

      # Invalider le cache
      invalidate_cache(category)

      # Audit
      case result do
        {:ok, _config} ->
          AuditLog.log("admin_action", updated_by, "platform_config", "#{category}.#{key}", %{
            "action" => "update_config",
            "old_value" => old_value,
            "new_value" => value,
            "category" => category
          })
        _ -> :ok
      end

      result
    end
  end

  @doc """
  Met à jour plusieurs configurations d'une catégorie en batch.
  """
  @spec update_batch(String.t(), list(map()), integer()) :: {:ok, integer()} | {:error, term()}
  def update_batch(category, updates, updated_by) when is_list(updates) do
    results = Enum.map(updates, fn %{key: key, value: value} ->
      update(category, key, value, updated_by)
    end)

    successes = Enum.count(results, fn {:ok, _} -> true; _ -> false end)
    errors = Enum.reject(results, fn {:ok, _} -> true; _ -> false end)

    if length(errors) > 0 and successes == 0 do
      {:error, :all_updates_failed}
    else
      {:ok, successes}
    end
  end

  # ========================================
  # API publique - Helpers spécifiques
  # ========================================

  @doc "Vérifie si le KYC est requis pour un retrait du montant donné."
  @spec kyc_required_for_withdrawal?(integer()) :: boolean()
  def kyc_required_for_withdrawal?(amount) do
    kyc_required = get_bool("payment", "kyc_required_for_withdrawal", true)
    threshold = get_int("payment", "kyc_withdrawal_threshold", 500_000)
    kyc_required and amount >= threshold
  end

  @doc "Vérifie si un montant de dépôt est dans les limites."
  @spec valid_deposit?(integer()) :: boolean()
  def valid_deposit?(amount) do
    min = get_int("payment", "min_deposit", 500)
    max = get_int("payment", "max_deposit", 5_000_000)
    amount >= min and amount <= max
  end

  @doc "Vérifie si un montant de retrait est dans les limites."
  @spec valid_withdrawal?(integer()) :: boolean()
  def valid_withdrawal?(amount) do
    min = get_int("payment", "min_withdrawal", 2000)
    max_daily = get_int("payment", "max_withdrawal", 2_000_000)
    amount >= min and amount <= max_daily
  end

  @doc "Récupère le taux de frais de retrait."
  @spec get_withdrawal_fee_rate() :: float()
  def get_withdrawal_fee_rate do
    get_float("payment", "withdrawal_fee_percent", 0.0) / 100
  end

  @doc "Récupère le bonus de bienvenue."
  @spec get_welcome_bonus() :: %{amount: integer(), wagering: integer()}
  def get_welcome_bonus do
    %{
      amount: get_int("registration", "welcome_bonus_amount", 1000),
      wagering: get_int("registration", "welcome_bonus_wagering", 3)
    }
  end

  @doc "Récupère les limites de rate limiting."
  @spec get_rate_limits() :: %{api_per_minute: integer(), game_per_minute: integer()}
  def get_rate_limits do
    %{
      api_per_minute: get_int("security", "rate_limit_api_per_minute", 60),
      game_per_minute: get_int("security", "rate_limit_game_per_minute", 30)
    }
  end

  @doc "Récupère la configuration des récompenses leaderboard."
  @spec get_leaderboard_rewards() :: list(%{rank: integer(), amount: integer()})
  def get_leaderboard_rewards do
    [
      %{rank: 1, amount: get_int("ranking", "leaderboard_reward_top1", 100_000)},
      %{rank: 2, amount: get_int("ranking", "leaderboard_reward_top2", 50_000)},
      %{rank: 3, amount: get_int("ranking", "leaderboard_reward_top3", 25_000)}
    ]
  end

  @doc "Liste les catégories valides."
  @spec valid_categories() :: list(String.t())
  def valid_categories, do: @valid_categories

  # ========================================
  # Helpers privés
  # ========================================

  defp load_all_grouped do
    Repo.all(
      from pc in "platform_configs",
        order_by: [asc: pc.category, asc: pc.key],
        select: %{
          id: pc.id, category: pc.category, key: pc.key, value: pc.value,
          value_type: pc.value_type, label: pc.label, description: pc.description,
          default_value: pc.default_value, validation_rules: pc.validation_rules,
          is_editable: pc.is_editable, updated_by: pc.updated_by, updated_at: pc.updated_at
        }
    )
    |> Enum.group_by(& &1.category)
  rescue
    _ -> %{}
  end

  defp load_category(category) do
    Repo.all(
      from pc in "platform_configs",
        where: pc.category == ^category,
        order_by: [asc: pc.key],
        select: %{
          id: pc.id, category: pc.category, key: pc.key, value: pc.value,
          value_type: pc.value_type, label: pc.label, description: pc.description,
          default_value: pc.default_value, validation_rules: pc.validation_rules,
          is_editable: pc.is_editable, updated_by: pc.updated_by, updated_at: pc.updated_at
        }
    )
  rescue
    _ -> []
  end

  defp parse_typed_value(nil, _type), do: nil
  defp parse_typed_value(val, "integer") do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp parse_typed_value(val, "float") do
    case Float.parse(to_string(val)) do
      {n, _} -> n
      :error -> 0.0
    end
  end
  defp parse_typed_value(val, "boolean") do
    to_string(val) == "true"
  end
  defp parse_typed_value(val, "json") do
    case Jason.decode(to_string(val)) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end
  defp parse_typed_value(val, _type), do: to_string(val)

  defp invalidate_cache(category) do
    try do
      :ets.delete(@cache_table, {:category, category})
      :ets.delete(@cache_table, :all_grouped)
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
