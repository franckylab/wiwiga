# ==================================
# WIWIGA - Module Admin XPRules
# ==================================
# Module: GameHub.Admin.XPRules
# Description: Configuration des règles de gain XP par type de jeu
#              Permet à l'admin de définir combien d'XP est gagné
#              pour chaque action (victoire, défaite, participation, etc.)

defmodule GameHub.Admin.XPRules do
  @moduledoc """
  Gestion des règles XP par type de jeu.

  ## Règles configurables
  - `win_xp`: XP gagné pour une victoire
  - `loss_xp`: XP gagné pour une défaite (participation)
  - `draw_xp`: XP gagné pour un match nul
  - `participation_xp`: XP fixe pour avoir joué
  - `streak_bonus`: XP bonus par victoire consécutive
  - `max_streak_bonus`: Maximum de bonus de série
  - `xp_multiplier`: Multiplicateur global (événements spéciaux)

  ## Exemple de config par jeu
  - dice: win=50, loss=10, draw=25, participation=5
  - ludo: win=30, loss=5, draw=15, participation=5
  - cards: win=40, loss=10, draw=20, participation=5
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @cache_table :admin_xp_rules_cache

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
  Liste toutes les règles XP configurées.
  """
  @spec list_xp_rules() :: list(map())
  def list_xp_rules do
    Repo.all(
      from xr in "xp_rules",
        order_by: [asc: xr.game_type],
        select: %{
          id: xr.id,
          game_type: xr.game_type,
          win_xp: xr.win_xp,
          loss_xp: xr.loss_xp,
          draw_xp: xr.draw_xp,
          participation_xp: xr.participation_xp,
          streak_bonus: xr.streak_bonus,
          max_streak_bonus: xr.max_streak_bonus,
          xp_multiplier: xr.xp_multiplier,
          is_active: xr.is_active,
          inserted_at: xr.inserted_at,
          updated_at: xr.updated_at
        }
    )
  end

  @doc """
  Récupère les règles XP pour un type de jeu.
  Utilise le cache pour les règles actives.
  """
  @spec get_xp_rules(String.t()) :: map()
  def get_xp_rules(game_type) do
    init_cache()

    case :ets.lookup(@cache_table, {:xp, game_type}) do
      [{_key, rules}] -> rules
      _ ->
        rules = Repo.one(
          from xr in "xp_rules",
            where: xr.game_type == ^game_type and xr.is_active == true,
            select: %{
              id: xr.id, game_type: xr.game_type,
              win_xp: xr.win_xp, loss_xp: xr.loss_xp,
              draw_xp: xr.draw_xp, participation_xp: xr.participation_xp,
              streak_bonus: xr.streak_bonus, max_streak_bonus: xr.max_streak_bonus,
              xp_multiplier: xr.xp_multiplier, is_active: xr.is_active
            }
        )

        rules = rules || default_xp_rules(game_type)

        if rules do
          :ets.insert(@cache_table, {{:xp, game_type}, rules})
        end

        rules
    end
  rescue
    _ -> default_xp_rules(game_type)
  end

  @doc """
  Calcule l'XP gagné pour un joueur après une partie.

  ## Paramètres
  - `game_type`: Type de jeu (dice, ludo, cards...)
  - `result`: Résultat pour le joueur (:win, :loss, :draw)
  - `win_streak`: Nombre de victoires consécutives (optionnel)

  ## Retourne
  Le montant d'XP total gagné
  """
  @spec calculate_xp(String.t(), atom(), integer()) :: integer()
  def calculate_xp(game_type, result, win_streak \\ 0) do
    rules = get_xp_rules(game_type)
    multiplier = rules.xp_multiplier || 1.0

    base_xp = case result do
      :win -> rules.win_xp || 50
      :loss -> rules.loss_xp || 10
      :draw -> rules.draw_xp || 25
      _ -> rules.participation_xp || 5
    end

    # Bonus de série (uniquement pour les victoires)
    streak_xp = if result == :win and win_streak > 1 do
      streak_bonus = (rules.streak_bonus || 5) * (win_streak - 1)
      max_bonus = rules.max_streak_bonus || 50
      min(streak_bonus, max_bonus)
    else
      0
    end

    # XP de participation toujours ajouté
    participation = rules.participation_xp || 5

    total = trunc((base_xp + streak_xp + participation) * multiplier)
    max(total, 0)
  end

  @doc """
  Crée ou met à jour les règles XP pour un type de jeu.
  """
  @spec upsert_xp_rules(String.t(), map(), integer()) :: {:ok, map()} | {:error, term()}
  def upsert_xp_rules(game_type, attrs, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Vérifier si les règles existent déjà
    existing = Repo.one(
      from xr in "xp_rules",
        where: xr.game_type == ^game_type,
        select: xr.id
    )

    result = case existing do
      nil ->
        # Insert
        {1, _} = Repo.insert_all("xp_rules", [%{
          game_type: game_type,
          win_xp: Map.get(attrs, "win_xp", 50),
          loss_xp: Map.get(attrs, "loss_xp", 10),
          draw_xp: Map.get(attrs, "draw_xp", 25),
          participation_xp: Map.get(attrs, "participation_xp", 5),
          streak_bonus: Map.get(attrs, "streak_bonus", 5),
          max_streak_bonus: Map.get(attrs, "max_streak_bonus", 50),
          xp_multiplier: Map.get(attrs, "xp_multiplier", 1.0),
          is_active: Map.get(attrs, "is_active", true),
          inserted_at: now,
          updated_at: now
        }])
        {:ok, get_xp_rules_raw(game_type)}

      id ->
        # Update
        query = from xr in "xp_rules",
          where: xr.id == ^id,
          update: [set: [
            win_xp: ^Map.get(attrs, "win_xp", 50),
            loss_xp: ^Map.get(attrs, "loss_xp", 10),
            draw_xp: ^Map.get(attrs, "draw_xp", 25),
            participation_xp: ^Map.get(attrs, "participation_xp", 5),
            streak_bonus: ^Map.get(attrs, "streak_bonus", 5),
            max_streak_bonus: ^Map.get(attrs, "max_streak_bonus", 50),
            xp_multiplier: ^Map.get(attrs, "xp_multiplier", 1.0),
            is_active: ^Map.get(attrs, "is_active", true),
            updated_at: ^now
          ]],
          select: %{id: xr.id, game_type: xr.game_type, win_xp: xr.win_xp,
                    loss_xp: xr.loss_xp, draw_xp: xr.draw_xp}

        Repo.update_all(query, [])
        |> case do
          {1, [rules]} -> {:ok, rules}
          _ -> {:error, :update_failed}
        end
    end

    invalidate_cache(game_type)

    case result do
      {:ok, rules} ->
        AuditLog.log("admin_action", updated_by, "xp_rules", game_type, %{
          "action" => "upsert_xp_rules",
          "data" => attrs
        })
        {:ok, rules}
      error -> error
    end
  end

  @doc """
  Supprime les règles XP pour un type de jeu.
  """
  @spec delete_xp_rules(String.t(), integer()) :: :ok | {:error, term()}
  def delete_xp_rules(game_type, deleted_by) do
    query = from xr in "xp_rules", where: xr.game_type == ^game_type

    case Repo.delete_all(query) do
      {n, _} when n > 0 ->
        invalidate_cache(game_type)
        AuditLog.log("admin_action", deleted_by, "xp_rules", game_type, %{
          "action" => "delete_xp_rules"
        })
        :ok
      _ -> {:error, :not_found}
    end
  end

  # ========================================
  # Helpers privés
  # ========================================

  defp get_xp_rules_raw(game_type) do
    Repo.one(
      from xr in "xp_rules",
        where: xr.game_type == ^game_type,
        select: %{id: xr.id, game_type: xr.game_type, win_xp: xr.win_xp,
                  loss_xp: xr.loss_xp, draw_xp: xr.draw_xp,
                  participation_xp: xr.participation_xp,
                  streak_bonus: xr.streak_bonus, max_streak_bonus: xr.max_streak_bonus,
                  xp_multiplier: xr.xp_multiplier, is_active: xr.is_active}
    )
  end

  defp default_xp_rules(game_type) do
    # Valeurs par défaut selon le type de jeu
    defaults = case game_type do
      "dice" -> %{win_xp: 50, loss_xp: 10, draw_xp: 25, participation_xp: 5}
      "ludo" -> %{win_xp: 30, loss_xp: 5, draw_xp: 15, participation_xp: 5}
      "cards" -> %{win_xp: 40, loss_xp: 10, draw_xp: 20, participation_xp: 5}
      _ -> %{win_xp: 25, loss_xp: 5, draw_xp: 15, participation_xp: 3}
    end

    %{
      id: nil,
      game_type: game_type,
      win_xp: defaults.win_xp,
      loss_xp: defaults.loss_xp,
      draw_xp: defaults.draw_xp,
      participation_xp: defaults.participation_xp,
      streak_bonus: 5,
      max_streak_bonus: 50,
      xp_multiplier: 1.0,
      is_active: true
    }
  end

  defp invalidate_cache(game_type) do
    try do
      :ets.delete(@cache_table, {:xp, game_type})
    rescue
      _ -> :ok
    end
  end
end
