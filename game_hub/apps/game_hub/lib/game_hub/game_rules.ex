# ==================================
# WIWIGA - Module GameRules (Cache ETS)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameRules
# Description: Accès aux règles de jeu avec cache ETS (TTL 5 min)

defmodule GameHub.GameRules do
  @moduledoc """
  Module central d'accès aux règles de jeu.

  ## Architecture
  - Lecture depuis DB PostgreSQL
  - Cache en ETS avec TTL 5 minutes
  - Invalidation automatique sur update DB

  ## Usage
      # Récupérer les règles dice/normal
      {:ok, rules} = GameHub.GameRules.get_rules("dice", "normal")

      # Valider une config de partie
      :ok = GameHub.GameRules.validate_match_config(rules, %{sets: 3, dice: 2})

      # Calculer commission
      {:ok, commission} = GameHub.GameRules.calculate_commission("dice", 10000)
  """

  use GenServer

  import Ecto.Query
  alias GameHub.Repo
  alias GameHub.Games.GameRule
  alias GameHub.Admin.GameConfig

  @cache_table :game_rules_cache
  @cache_ttl_seconds 300

  # === API Publique ===

  @doc """
  Démarre le cache ETS. Appelé depuis le supervision tree.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Table ETS nommée pour le cache
    table = :ets.new(@cache_table, [:named_table, :set, :public, read_concurrency: true])
    # Planifier le nettoyage périodique
    schedule_cleanup()
    {:ok, table}
  end

  @impl true
  def handle_info(:cleanup_cache, table) do
    # Purger les entrées expirées
    now = System.system_time(:second)

    :ets.tab2list(@cache_table)
    |> Enum.each(fn {key, _rule, cached_at} ->
      if now - cached_at >= @cache_ttl_seconds do
        :ets.delete(@cache_table, key)
      end
    end)

    schedule_cleanup()
    {:noreply, table}
  end

  @doc """
  Récupère les règles d'un type de jeu.

  ## Parameters
    - `game_type`: "dice", "ludo", etc.
    - `rule_type`: "normal", "cible", etc.

  ## Returns
    - `{:ok, %GameRule{}}` depuis cache ou DB
    - `{:error, :rules_not_found}`
  """
  @spec get_rules(String.t(), String.t()) :: {:ok, GameRule.t()} | {:error, atom()}
  def get_rules(game_type, rule_type) do
    cache_key = {game_type, rule_type}

    case read_cache(cache_key) do
      {:hit, rule} ->
        {:ok, rule}

      :miss ->
        case load_from_db(game_type, rule_type) do
          nil -> {:error, :rules_not_found}
          rule ->
            write_cache(cache_key, rule)
            {:ok, rule}
        end
    end
  end

  @doc """
  Récupère les règles avec valeurs par défaut si non trouvées.
  """
  @spec get_rules_or_default(String.t(), String.t()) :: GameRule.t()
  def get_rules_or_default(game_type, rule_type) do
    case get_rules(game_type, rule_type) do
      {:ok, rule} -> rule
      {:error, :rules_not_found} -> default_config_hardcoded(game_type, rule_type)
    end
  end

  @doc """
  Liste toutes les règles actives pour un type de jeu.
  """
  @spec list_rules(String.t()) :: [GameRule.t()]
  def list_rules(game_type) do
    query = from r in GameRule,
      where: r.game_type == ^game_type and r.is_active == true,
      order_by: [asc: r.rule_type]

    Repo.all(query)
  end

  @doc """
  Liste toutes les règles actives (tous jeux) — usage admin.
  """
  @spec list_all() :: [GameRule.t()]
  def list_all do
    query = from r in GameRule,
      where: r.is_active == true,
      order_by: [asc: r.game_type, asc: r.rule_type]

    Repo.all(query)
  end

  @doc """
  Valide la configuration d'un match contre les règles.

  ## Parameters
    - `rules`: %GameRule{} chargé
    - `config`: %{sets: integer, dice: integer, bet_amount: integer, players: integer}

  ## Returns
    - `:ok` si valide
    - `{:error, reasons}` si invalide
  """
  @spec validate_match_config(GameRule.t(), map()) :: :ok | {:error, [String.t()]}
  def validate_match_config(%GameRule{config: rc}, match_config) do
    errors = []

    # Valider nombre de sets
    sets = Map.get(match_config, :sets, rc["default_sets"])
    min_sets = rc["min_sets"] || 1
    max_sets = rc["max_sets"] || 11

    errors = if sets < min_sets or sets > max_sets do
      ["Nombre de sets (#{sets}) doit être entre #{min_sets} et #{max_sets}" | errors]
    else
      errors
    end

    # Valider nombre de dés
    dice = Map.get(match_config, :dice, rc["default_dice"])
    min_dice = rc["min_dice"] || 1
    max_dice = rc["max_dice"] || 5

    errors = if dice < min_dice or dice > max_dice do
      ["Nombre de dés (#{dice}) doit être entre #{min_dice} et #{max_dice}" | errors]
    else
      errors
    end

    # Valider mise (si Partie avec mise / staked)
    bet_amount = Map.get(match_config, :bet_amount, 0)

    errors = if bet_amount > 0 do
      min_bet = rc["min_bet"] || 100
      max_bet = rc["max_bet"] || 500_000

      if bet_amount < min_bet or bet_amount > max_bet do
        ["Mise (#{bet_amount}) doit être entre #{min_bet} et #{max_bet} jetons" | errors]
      else
        errors
      end
    else
      errors
    end

    # Valider nombre de joueurs
    players = Map.get(match_config, :players, 2)
    min_players = rc["min_players"] || 2
    max_players = rc["max_players"] || 5

    errors = if players < min_players or players > max_players do
      ["Nombre de joueurs (#{players}) doit être entre #{min_players} et #{max_players}" | errors]
    else
      errors
    end

    case errors do
      [] -> :ok
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  @doc """
  Calcule la commission sur un montant.

  ## Returns
    - `{:ok, commission_amount}` en integer
    - `{:error, :rules_not_found}`
  """
  @spec calculate_commission(String.t(), integer()) :: {:ok, integer()} | {:error, atom()}
  def calculate_commission(game_type, amount) when amount > 0 do
    rate = case get_rules(game_type, "normal") do
      {:ok, rules} ->
        GameRule.get_config_decimal(rules, "commission_rate", nil)
      _ ->
        nil
    end

    # Fallback: GameConfig admin → défaut 5%
    rate = case rate do
      nil -> Decimal.new(GameConfig.get_commission_rate(game_type))
      r -> r
    end

    commission = amount |> Decimal.new() |> Decimal.mult(rate) |> Decimal.to_float() |> trunc()
    {:ok, commission}
  end

  def calculate_commission(_game_type, _amount), do: {:ok, 0}

  @doc """
  Récupère la configuration par défaut pour un type/règle.
  """
  @spec default_config(String.t(), String.t()) :: map()
  def default_config(game_type, rule_type) do
    case get_rules(game_type, rule_type) do
      {:ok, %GameRule{config: config}} -> config
      _ -> default_config_hardcoded(game_type, rule_type)
    end
  end

  @sets_modes ~w(fixed random)

  @doc """
  Résout le nombre de sets d'une partie — source unique de vérité.

  ## Modes (`sets_mode` dans `game_rules.config`)
    - `"fixed"` (défaut) : utilise `requested` (salles créées par un joueur,
      borné à `[min_sets, max_sets]`), sinon `default_sets`.
    - `"random"` : tirage serveur uniforme dans
      `[sets_random_min, sets_random_max]` quand `requested` est absent
      (partie rapide : équité + cohérence entre tous les joueurs du lobby).

  Règle de cohérence : une valeur explicite (salle déjà créée) n'est JAMAIS
  retirée — elle est seulement bornée. Le tirage n'a lieu qu'une fois, à la
  création (salle ou match rapide), puis la valeur est figée.

  Le tirage utilise `:crypto.strong_rand_bytes/1` (contrainte projet :
  aléatoire côté serveur uniquement).

  ## Returns
    - `{:ok, sets_count, sets_mode}`
  """
  @spec resolve_sets_count(String.t(), String.t(), integer() | nil) ::
          {:ok, integer(), String.t()}
  def resolve_sets_count(game_type, rule_type, requested \\ nil) do
    rules = get_rules_or_default(game_type, rule_type)
    rc = rules.config || %{}
    min = to_int(rc["min_sets"], 1)
    max = to_int(rc["max_sets"], 11) |> max(min)
    mode = if rc["sets_mode"] in @sets_modes, do: rc["sets_mode"], else: "fixed"

    cond do
      is_integer(requested) ->
        {:ok, clamp_int(requested, min, max), mode}

      mode == "random" ->
        rmin = to_int(rc["sets_random_min"], min) |> clamp_int(min, max)
        rmax = to_int(rc["sets_random_max"], max) |> clamp_int(rmin, max)
        {:ok, draw_uniform(rmin, rmax), "random"}

      true ->
        {:ok, to_int(rc["default_sets"], 3) |> clamp_int(min, max), "fixed"}
    end
  end

  @doc """
  Aperçu de la configuration des sets pour affichage (lobby, création).

  Retourne `%{mode, fixed, random_min, random_max, min_sets, max_sets,
  default_sets}` — le client affiche "BO3" ou "Aléatoire (1–5)" sans deviner.
  """
  @spec sets_preview(String.t(), String.t()) :: map()
  def sets_preview(game_type, rule_type) do
    rules = get_rules_or_default(game_type, rule_type)
    rc = rules.config || %{}
    min = to_int(rc["min_sets"], 1)
    max = to_int(rc["max_sets"], 11) |> max(min)
    mode = if rc["sets_mode"] in @sets_modes, do: rc["sets_mode"], else: "fixed"
    rmin = to_int(rc["sets_random_min"], min) |> clamp_int(min, max)
    rmax = to_int(rc["sets_random_max"], max) |> clamp_int(rmin, max)

    %{
      mode: mode,
      fixed: to_int(rc["default_sets"], 3) |> clamp_int(min, max),
      random_min: rmin,
      random_max: rmax,
      min_sets: min,
      max_sets: max,
      default_sets: to_int(rc["default_sets"], 3) |> clamp_int(min, max)
    }
  end

  @doc """
  Invalide le cache pour une règle spécifique (appelé après update DB).
  """
  @spec invalidate_cache(String.t(), String.t()) :: :ok
  def invalidate_cache(game_type, rule_type) do
    :ets.delete(@cache_table, {game_type, rule_type})
    :ok
  end

  @doc """
  Invalide tout le cache des règles.
  """
  @spec invalidate_all_cache() :: :ok
  def invalidate_all_cache do
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  @doc """
  Met à jour la configuration d'une règle et invalide le cache.
  """
  @spec update_config(String.t(), String.t(), map()) :: {:ok, GameRule.t()} | {:error, atom()}
  def update_config(game_type, rule_type, new_config) do
    case get_rules(game_type, rule_type) do
      {:ok, rule} ->
        changeset = GameRule.config_changeset(rule, new_config)

        case Repo.update(changeset) do
          {:ok, updated_rule} ->
            invalidate_cache(game_type, rule_type)
            {:ok, updated_rule}

          {:error, _reason} ->
            {:error, :update_failed}
        end

      error ->
        error
    end
  end

  # === Cache Privé ===

  defp read_cache(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, rule, cached_at}] ->
        # Vérifier TTL
        now = System.system_time(:second)

        if now - cached_at < @cache_ttl_seconds do
          {:hit, rule}
        else
          :ets.delete(@cache_table, key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError ->
      # Table ETS pas encore créée
      :miss
  end

  defp write_cache(key, rule) do
    :ets.insert(@cache_table, {key, rule, System.system_time(:second)})
  rescue
    ArgumentError -> :ok
  end

  defp load_from_db(game_type, rule_type) do
    query = from r in GameRule,
      where: r.game_type == ^game_type and r.rule_type == ^rule_type and r.is_active == true

    Repo.one(query)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_cache, 60_000)
  end

  # Tirage uniforme crypto-safe dans [min, max] (inclus).
  # Même primitive que les lancers de dés (`:crypto.strong_rand_bytes/1`).
  defp draw_uniform(min, max) when max <= min, do: min

  defp draw_uniform(min, max) do
    range = max - min + 1

    :crypto.strong_rand_bytes(1)
    |> :binary.decode_unsigned()
    |> rem(range)
    |> Kernel.+(min)
  end

  defp to_int(nil, default), do: default
  defp to_int(val, _default) when is_integer(val), do: val

  defp to_int(val, default) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {n, ""} -> n
      _ -> default
    end
  end

  defp to_int(_, default), do: default

  defp clamp_int(val, min, max), do: val |> max(min) |> min(max)

  # === Defaults Hardcodées (fallback) ===

  defp default_config_hardcoded("dice", "normal") do
    %GameRule{
      game_type: "dice",
      rule_type: "normal",
      name: "Normal",
      description: "High roll séquentiel, ordre tournant",
      config: %{
        "min_sets" => 1, "max_sets" => 11, "default_sets" => 3,
        "sets_mode" => "fixed", "sets_random_min" => 1, "sets_random_max" => 5,
        "min_dice" => 1, "max_dice" => 5, "default_dice" => 2,
        "dice_faces" => 6, "commission_rate" => 0.05,
        "min_bet" => 100, "max_bet" => 500_000,
        "min_players" => 2, "max_players" => 5,
        "tie_rule" => "replay", "turn_order" => "rotating"
      },
      is_active: true
    }
  end

  defp default_config_hardcoded("dice", "cible") do
    %GameRule{
      game_type: "dice",
      rule_type: "cible",
      name: "Cible",
      description: "Vote pour nombre cible, plus proche gagne",
      config: %{
        "min_sets" => 1, "max_sets" => 11, "default_sets" => 3,
        "sets_mode" => "fixed", "sets_random_min" => 1, "sets_random_max" => 5,
        "min_dice" => 1, "max_dice" => 5, "default_dice" => 2,
        "dice_faces" => 6, "commission_rate" => 0.05,
        "min_bet" => 100, "max_bet" => 500_000,
        "min_players" => 2, "max_players" => 5,
        "tie_rule" => "replay", "target_vote_mode" => "average"
      },
      is_active: true
    }
  end

  defp default_config_hardcoded(game_type, rule_type) do
    %GameRule{
      game_type: game_type,
      rule_type: rule_type,
      name: String.capitalize(rule_type),
      config: %{},
      is_active: true
    }
  end
end
