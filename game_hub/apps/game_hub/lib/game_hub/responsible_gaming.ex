# ==================================
# WIWIGA - Module Responsible Gaming
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.ResponsibleGaming
# Description: Conformité jeu responsable — limites configurables,
#   appliquées côté serveur avant chaque mise/dépôt/participation.
#
# Limites gérées (toutes en jetons, toutes en minutes pour les durées) :
#   - Mise max par coup (perso `max_bet_amount`, sinon global `max_bet_per_round`)
#   - Total misé par jour (`daily_wager_limit`)
#   - Perte NETTE jour/semaine/mois (mises − gains, pas mises brutes)
#   - Participations payantes par jour (`daily_matches_limit`)
#   - Dépôts par jour (`daily_deposit_limit`)
#   - Temps de session (`session_time_limit_minutes`)
#   - Pause courte (`cooling_off_until`), auto-exclusion (avec sync `users`)
#   - Hausse de limite différée 24h (standard), baisse immédiate
#
# Fuseau : Africa/Douala = UTC+1 permanent (pas de DST) — les périodes
# jour/semaine/mois sont calculées en heure locale, pas en UTC.

defmodule GameHub.ResponsibleGaming do
  @moduledoc """
  Module de gestion du jeu responsable.

  Obligations (Règle 19 + standards) :
  - Limites de dépôt/mise/perte/parties configurables (perso + défauts plateforme)
  - Auto-exclusion temporaire/permanente + pause courte (cooling-off)
  - Rappels de réalité + limites de temps de session
  - Hausse différée 24h, baisse immédiate
  """

  alias GameHub.Repo
  alias GameHub.ResponsibleGaming.ResponsibleGamingLimit
  alias GameHub.Admin.PlatformConfig
  alias GameHub.Tokens.TokenTransaction
  import Ecto.Query

  # Table ETS pour le tracking de session en mémoire
  @session_table :rg_session_tracker

  # Africa/Douala : UTC+1 toute l'année (aucun changement d'heure).
  @douala_offset_seconds 3600

  # Délai légal standard avant effet d'une hausse de limite.
  @pending_delay_hours 24

  # Clés de limites soumises au différé 24h sur hausse.
  @delayed_limit_keys ~w(daily_deposit_limit daily_loss_limit weekly_loss_limit
    monthly_loss_limit daily_wager_limit max_bet_amount daily_matches_limit
    session_time_limit_minutes reality_check_interval_minutes)a

  # === Sessions ===

  @doc """
  Initialise le tracker de session ETS.
  Appeler au démarrage de l'application.
  """
  def init_session_tracker do
    if :ets.info(@session_table) == :undefined do
      :ets.new(@session_table, [:set, :named_table, :public, read_concurrency: true])
    end
    :ok
  end

  @doc """
  Démarre une session de jeu pour un utilisateur.
  """
  @spec start_session(integer() | String.t()) :: :ok
  def start_session(user_id) do
    init_session_tracker()
    :ets.insert(@session_table, {session_key(user_id), System.monotonic_time(:second)})
    :ok
  end

  @doc """
  Arrête une session de jeu.
  """
  @spec end_session(integer() | String.t()) :: :ok
  def end_session(user_id) do
    init_session_tracker()
    :ets.delete(@session_table, session_key(user_id))
    :ok
  end

  @doc """
  Temps écoulé de la session en cours (secondes), nil si aucune.
  """
  @spec session_elapsed_seconds(integer() | String.t()) :: integer() | nil
  def session_elapsed_seconds(user_id) do
    init_session_tracker()

    case :ets.lookup(@session_table, session_key(user_id)) do
      [{_, start_time}] -> max(0, System.monotonic_time(:second) - start_time)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  # === Portes d'entrée (enforcement) ===

  @doc """
  Vérifie si un utilisateur peut placer un pari.

  ## Returns
    - `:ok`
    - `{:error, reason}` avec reason parmi :self_excluded, :cooling_off,
      :max_bet_exceeded, :daily_wager_reached, :daily_limit_reached,
      :weekly_limit_reached, :monthly_limit_reached, :daily_matches_reached,
      :session_time_exceeded
  """
  @spec check_before_bet(integer() | String.t(), integer()) :: :ok | {:error, atom()}
  def check_before_bet(user_id, bet_amount) do
    user_id = normalize_user_id(user_id)
    limits = apply_due_pending(user_id)
    usage = daily_usage(user_id, limits)

    cond do
      excluded?(limits) -> {:error, :self_excluded}
      cooling_off?(limits) -> {:error, :cooling_off}
      bet_amount > effective_max_bet(limits) -> {:error, :max_bet_exceeded}
      usage.staked + bet_amount > effective_daily_wager(limits) -> {:error, :daily_wager_reached}
      usage.net_loss + bet_amount > effective_daily_loss(limits) -> {:error, :daily_limit_reached}
      weekly_limit_hit?(user_id, limits) -> {:error, :weekly_limit_reached}
      monthly_limit_hit?(user_id, limits) -> {:error, :monthly_limit_reached}
      usage.matches >= effective_daily_matches(limits) -> {:error, :daily_matches_reached}
      session_time_exceeded?(user_id, effective_session_minutes(limits)) -> {:error, :session_time_exceeded}
      true -> :ok
    end
  end

  @doc """
  Vérifie si un utilisateur peut participer (salle gratuite, lobby, revanche
  sans mise) — exclusion, pause courte et temps de session uniquement.
  """
  @spec check_playable(integer() | String.t()) :: :ok | {:error, atom()}
  def check_playable(user_id) do
    user_id = normalize_user_id(user_id)
    limits = apply_due_pending(user_id)

    cond do
      excluded?(limits) -> {:error, :self_excluded}
      cooling_off?(limits) -> {:error, :cooling_off}
      session_time_exceeded?(user_id, effective_session_minutes(limits)) ->
        {:error, :session_time_exceeded}
      true -> :ok
    end
  end

  @doc """
  Vérifie si un utilisateur peut déposer (achat de jetons).
  """
  @spec check_deposit(integer() | String.t(), integer()) :: :ok | {:error, atom()}
  def check_deposit(user_id, amount) do
    user_id = normalize_user_id(user_id)
    limits = apply_due_pending(user_id)
    usage = daily_usage(user_id, limits)

    cond do
      excluded?(limits) -> {:error, :self_excluded}
      cooling_off?(limits) -> {:error, :cooling_off}
      usage.deposits + amount > effective_daily_deposit(limits) ->
        {:error, :daily_deposit_reached}
      true -> :ok
    end
  end

  # === Limites ===

  @doc """
  Définit les limites de jeu pour un utilisateur.

  Règle standard : les baisses (plus strictes) s'appliquent immédiatement,
  les hausses prennent effet après 24h (`pending_config`).
  """
  @spec set_limits(integer(), map()) :: {:ok, ResponsibleGamingLimit.t()} | {:error, Ecto.Changeset.t()}
  def set_limits(user_id, limits_data) do
    limits = get_or_create_limits(user_id) |> maybe_apply_pending_struct()

    {immediate, pending} = split_immediate_vs_pending(limits, limits_data)

    attrs =
      if map_size(pending) == 0 do
        Map.merge(immediate, %{pending_config: %{}, pending_effective_at: nil})
      else
        merged_pending = Map.merge(limits.pending_config || %{}, pending)

        Map.merge(immediate, %{
          pending_config: merged_pending,
          pending_effective_at: DateTime.utc_now() |> DateTime.add(@pending_delay_hours, :hour)
        })
      end

    limits
    |> ResponsibleGamingLimit.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Récupère les limites d'un utilisateur.
  """
  @spec get_limits(integer()) :: ResponsibleGamingLimit.t() | nil
  def get_limits(user_id) do
    Repo.get_by(ResponsibleGamingLimit, user_id: user_id)
  end

  @doc """
  Auto-exclusion : `duration_days` 1..3650, 0 = permanente.
  Synchronise `users.self_excluded` (source unique lue par l'admin).
  """
  @spec self_exclude(integer(), integer(), String.t()) ::
          {:ok, ResponsibleGamingLimit.t()} | {:error, atom() | Ecto.Changeset.t()}
  def self_exclude(user_id, duration_days, reason) do
    with :ok <- validate_exclusion_duration(duration_days),
         :ok <- validate_exclusion_reason(reason) do
      self_exclusion_until =
        if duration_days == 0 do
          DateTime.utc_now() |> DateTime.add(100 * 365, :day)
        else
          DateTime.utc_now() |> DateTime.add(duration_days, :day)
        end

      result =
        get_or_create_limits(user_id)
        |> ResponsibleGamingLimit.changeset(%{
          self_exclusion_until: self_exclusion_until,
          self_exclusion_reason: String.trim(reason)
        })
        |> Repo.update()

      case result do
        {:ok, limits} ->
          sync_user_excluded_flag(user_id, true)
          end_session(user_id)
          {:ok, limits}

        err ->
          err
      end
    end
  end

  @doc """
  Lève une auto-exclusion (fin naturelle ou override admin justifié).
  Efface les DEUX sources (limits + users) pour éviter toute désynchro.
  """
  @spec lift_exclusion(integer()) :: {:ok, ResponsibleGamingLimit.t()} | {:error, term()}
  def lift_exclusion(user_id) do
    result =
      get_or_create_limits(user_id)
      |> ResponsibleGamingLimit.changeset(%{
        self_exclusion_until: nil,
        self_exclusion_reason: nil
      })
      |> Repo.update()

    case result do
      {:ok, limits} ->
        sync_user_excluded_flag(user_id, false)
        {:ok, limits}

      err ->
        err
    end
  end

  @doc """
  Démarre une pause courte (cooling-off) de `days` jours (1..30).
  """
  @spec start_cooling_off(integer(), integer()) ::
          {:ok, ResponsibleGamingLimit.t()} | {:error, atom() | Ecto.Changeset.t()}
  def start_cooling_off(user_id, days) when is_integer(days) and days >= 1 and days <= 30 do
    result =
      get_or_create_limits(user_id)
      |> ResponsibleGamingLimit.changeset(%{
        cooling_off_until: DateTime.utc_now() |> DateTime.add(days, :day)
      })
      |> Repo.update()

    case result do
      {:ok, limits} ->
        end_session(user_id)
        {:ok, limits}

      err ->
        err
    end
  end

  def start_cooling_off(_user_id, _days), do: {:error, :invalid_duration}

  @doc """
  Usage du jour (heure de Douala) : mises, perte nette, participations,
  dépôts — en jetons. Source unique pour checks ET messages/API.
  """
  @spec daily_usage(integer(), ResponsibleGamingLimit.t() | nil) :: map()
  def daily_usage(user_id, _limits \\ nil) do
    {start_utc, end_utc} = douala_day_range(Date.utc_today())

    staked = sum_tokens(user_id, ["bet"], start_utc, end_utc, :abs) || 0
    pnl = sum_tokens(user_id, ["bet", "winnings"], start_utc, end_utc, :signed) || 0

    matches =
      Repo.one(
        from t in TokenTransaction,
          where:
            t.user_id == ^user_id and t.type == "bet" and
              t.inserted_at >= ^start_utc and t.inserted_at < ^end_utc,
          select: count(t.id)
      ) || 0

    deposits = sum_tokens(user_id, ["purchase"], start_utc, end_utc, :signed) || 0

    %{
      staked: staked,
      net_loss: max(0, -pnl),
      matches: matches,
      deposits: max(0, deposits),
      session_elapsed_seconds: session_elapsed_seconds(user_id)
    }
  end

  @doc """
  Période jour Douala (minuit locale → minuit suivante) exprimée en UTC.
  """
  @spec douala_day_range(Date.t()) :: {DateTime.t(), DateTime.t()}
  def douala_day_range(date) do
    # Minuit Douala = 23h00Z la veille (UTC+1 permanent).
    {:ok, start_utc} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
    start_utc = DateTime.add(start_utc, -@douala_offset_seconds, :second)
    {start_utc, DateTime.add(start_utc, 86_400, :second)}
  end

  # === États publics (contrôleurs, API) ===

  @doc "Auto-exclusion active ?"
  @spec excluded?(ResponsibleGamingLimit.t() | nil) :: boolean()
  def excluded?(nil), do: false

  def excluded?(%ResponsibleGamingLimit{} = limits) do
    not is_nil(limits.self_exclusion_until) and
      DateTime.compare(DateTime.utc_now(), limits.self_exclusion_until) == :lt
  end

  @doc "Pause courte active ?"
  @spec cooling_off?(ResponsibleGamingLimit.t() | nil) :: boolean()
  def cooling_off?(nil), do: false

  def cooling_off?(%ResponsibleGamingLimit{} = limits) do
    not is_nil(limits.cooling_off_until) and
      DateTime.compare(DateTime.utc_now(), limits.cooling_off_until) == :lt
  end

  # === Limites effectives (perso sinon défauts plateforme) ===

  @doc "Mise max par coup effective (jetons)."
  @spec effective_max_bet(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_max_bet(nil),
    do: PlatformConfig.get_int("gaming", "max_bet_per_round", 10_000)

  def effective_max_bet(%ResponsibleGamingLimit{max_bet_amount: max})
      when is_integer(max) and max > 0,
      do: min(max, PlatformConfig.get_int("gaming", "max_bet_per_round", 10_000))

  def effective_max_bet(_),
    do: PlatformConfig.get_int("gaming", "max_bet_per_round", 10_000)

  @doc "Total misé/jour effectif (jetons)."
  @spec effective_daily_wager(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_daily_wager(%ResponsibleGamingLimit{daily_wager_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_daily_wager(_),
    do: PlatformConfig.get_int("gaming", "default_daily_wager_limit", 25_000)

  @doc "Perte nette/jour effective (jetons)."
  @spec effective_daily_loss(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_daily_loss(%ResponsibleGamingLimit{daily_loss_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_daily_loss(_),
    do: PlatformConfig.get_int("gaming", "default_daily_loss_limit", 500_000)

  @doc "Perte nette/semaine effective (jetons, nil = pas de limite)."
  @spec effective_weekly_loss(ResponsibleGamingLimit.t() | nil) :: integer() | nil
  def effective_weekly_loss(%ResponsibleGamingLimit{weekly_loss_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_weekly_loss(_), do: nil

  @doc "Perte nette/mois effective (jetons, nil = pas de limite)."
  @spec effective_monthly_loss(ResponsibleGamingLimit.t() | nil) :: integer() | nil
  def effective_monthly_loss(%ResponsibleGamingLimit{monthly_loss_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_monthly_loss(_), do: nil

  @doc "Participations payantes/jour effectives."
  @spec effective_daily_matches(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_daily_matches(%ResponsibleGamingLimit{daily_matches_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_daily_matches(_),
    do: PlatformConfig.get_int("gaming", "default_daily_matches_limit", 20)

  @doc "Dépôts/jour effectifs (jetons)."
  @spec effective_daily_deposit(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_daily_deposit(%ResponsibleGamingLimit{daily_deposit_limit: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_daily_deposit(_),
    do: PlatformConfig.get_int("gaming", "default_daily_deposit_limit", 1_000_000)

  @doc "Durée de session effective (minutes)."
  @spec effective_session_minutes(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_session_minutes(%ResponsibleGamingLimit{session_time_limit_minutes: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_session_minutes(_),
    do: PlatformConfig.get_int("gaming", "default_session_time_minutes", 120)

  @doc "Intervalle de rappel réalité effectif (minutes)."
  @spec effective_reality_interval(ResponsibleGamingLimit.t() | nil) :: integer()
  def effective_reality_interval(%ResponsibleGamingLimit{reality_check_interval_minutes: v})
      when is_integer(v) and v > 0,
      do: v

  def effective_reality_interval(_),
    do: PlatformConfig.get_int("gaming", "reality_check_interval_minutes", 30)

  @doc """
  P&L net signé par utilisateur sur une période (mises − gains, jetons).
  Source unique pour l'overview admin et les indicateurs de risque.
  """
  @spec net_pnl_by_user([String.t()], DateTime.t(), DateTime.t()) :: [
          %{user_id: integer(), pnl: integer()}
        ]
  def net_pnl_by_user(types, start_utc, end_utc) do
    Repo.all(
      from t in TokenTransaction,
        where:
          t.type in ^types and t.inserted_at >= ^start_utc and
            t.inserted_at < ^end_utc,
        group_by: t.user_id,
        select: %{user_id: t.user_id, pnl: fragment("COALESCE(SUM(?), 0)", t.token_amount)}
    )
  rescue
    _ -> []
  end

  @doc "Perte nette semaine Douala (lundi-dimanche, jetons)."
  @spec weekly_loss(integer()) :: integer()
  def weekly_loss(user_id) do
    {start_utc, end_utc} = douala_week_range()
    max(0, -(sum_tokens(user_id, ["bet", "winnings"], start_utc, end_utc, :signed) || 0))
  end

  @doc "Perte nette mois calendaire Douala (jetons)."
  @spec monthly_loss(integer()) :: integer()
  def monthly_loss(user_id) do
    {start_utc, end_utc} = douala_month_range()
    max(0, -(sum_tokens(user_id, ["bet", "winnings"], start_utc, end_utc, :signed) || 0))
  end

  @doc """
  Message humain + détails stables pour un motif de blocage.
  Source unique (contrôleurs jeu/salles/dépôts) — le frontend exploite
  `details.reason` (codes stables) plutôt que le texte.
  """
  @spec block_message(atom(), integer(), integer()) :: {String.t(), map()}
  def block_message(reason, user_id, bet_amount \\ 0) do
    limits = try do: get_limits(user_id), rescue: (_ -> nil)
    usage = try do: daily_usage(user_id, limits), rescue: (_ -> %{staked: 0, net_loss: 0, matches: 0, deposits: 0})
    settings_path = "Profil > Jeu responsable"

    case reason do
      :self_excluded ->
        {"Vous êtes en période d'auto-exclusion. Vous ne pouvez pas jouer pour le moment. Contactez le support si besoin.",
         %{reason: "self_excluded"}}

      :cooling_off ->
        {"Vous êtes en pause courte (cooling-off). Revenez après la fin de votre pause, ou contactez le support.",
         %{reason: "cooling_off"}}

      :max_bet_exceeded ->
        max_bet = effective_max_bet(limits)
        {"Mise trop élevée. Maximum autorisé : #{max_bet} jetons.",
         %{reason: "max_bet_exceeded", max_bet: max_bet, attempted: bet_amount}}

      :daily_wager_reached ->
        limit = effective_daily_wager(limits)
        {"Total misé aujourd'hui : #{usage.staked} jetons (limite #{limit}). Revenez demain ou ajustez vos limites dans #{settings_path}.",
         %{reason: "daily_wager_reached", limit: limit, total: usage.staked, bet_amount: bet_amount}}

      :daily_limit_reached ->
        limit = effective_daily_loss(limits)
        {"Perte nette du jour : #{usage.net_loss} jetons (limite #{limit}). Revenez demain ou ajustez vos limites dans #{settings_path}.",
         %{reason: "daily_limit_reached", limit: limit, total: usage.net_loss, bet_amount: bet_amount}}

      :weekly_limit_reached ->
        total = weekly_loss(user_id)
        {"Perte nette de la semaine : #{total} jetons (limite hebdomadaire atteinte). Revenez la semaine prochaine.",
         %{reason: "weekly_limit_reached", total: total, bet_amount: bet_amount}}

      :monthly_limit_reached ->
        total = monthly_loss(user_id)
        {"Perte nette du mois : #{total} jetons (limite mensuelle atteinte). Revenez le mois prochain.",
         %{reason: "monthly_limit_reached", total: total, bet_amount: bet_amount}}

      :daily_matches_reached ->
        limit = effective_daily_matches(limits)
        {"Nombre de parties du jour atteint (#{usage.matches}/#{limit}). Revenez demain.",
         %{reason: "daily_matches_reached", limit: limit, total: usage.matches}}

      :daily_deposit_reached ->
        limit = effective_daily_deposit(limits)
        {"Dépôts du jour : #{usage.deposits} jetons (limite #{limit}). Revenez demain.",
         %{reason: "daily_deposit_reached", limit: limit, total: usage.deposits}}

      :session_time_exceeded ->
        limit = effective_session_minutes(limits)
        {"Temps de session dépassé (#{limit} min). Faites une pause : quittez vos parties, la session repartira à zéro.",
         %{reason: "session_time_exceeded", limit_minutes: limit}}

      other ->
        {"Jeu responsable : #{inspect(other)}. Vérifiez vos limites dans #{settings_path}.",
         %{reason: inspect(other)}}
    end
  end

  # === Fonctions Privées ===

  defp weekly_limit_hit?(user_id, limits) do
    case effective_weekly_loss(limits) do
      nil -> false
      weekly_limit -> weekly_loss(user_id) >= weekly_limit
    end
  end

  defp monthly_limit_hit?(user_id, limits) do
    case effective_monthly_loss(limits) do
      nil -> false
      monthly_limit -> monthly_loss(user_id) >= monthly_limit
    end
  end

  # Applique les hausses différées arrivées à échéance (paresseux, sans cron).
  defp apply_due_pending(user_id) do
    case get_limits(user_id) do
      %ResponsibleGamingLimit{pending_effective_at: eff, pending_config: pending} = limits
      when is_map(pending) and map_size(pending) > 0 and not is_nil(eff) ->
        if DateTime.compare(DateTime.utc_now(), eff) != :lt do
          case limits
               |> ResponsibleGamingLimit.changeset(
                 Map.merge(stringify_keys(pending), %{pending_config: %{}, pending_effective_at: nil})
               )
               |> Repo.update() do
            {:ok, updated} -> updated
            _ -> limits
          end
        else
          limits
        end

      limits ->
        limits
    end
  end

  defp maybe_apply_pending_struct(%ResponsibleGamingLimit{user_id: user_id} = limits) do
    case apply_due_pending(user_id) do
      %ResponsibleGamingLimit{} = updated -> updated
      _ -> limits
    end
  end

  # Baisse = immédiat ; hausse = différé 24h. Seules les clés de limites
  # gèrent le différé ; le reste passe en immédiat.
  defp split_immediate_vs_pending(limits, attrs) do
    string_attrs = stringify_keys(attrs)

    Enum.reduce(string_attrs, {%{}, %{}}, fn {key, val}, {imm, pend} ->
      atom_key =
        try do
          String.to_existing_atom(key)
        rescue
          _ -> nil
        end

      cond do
        is_nil(atom_key) ->
          {imm, pend}

        atom_key not in @delayed_limit_keys ->
          {Map.put(imm, atom_key, val), pend}

        not is_integer(val) ->
          {Map.put(imm, atom_key, val), pend}

        true ->
          current = Map.get(limits, atom_key)

          if is_integer(current) and val > current do
            {imm, Map.put(pend, key, val)}
          else
            {Map.put(imm, atom_key, val), pend}
          end
      end
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp session_time_exceeded?(user_id, limit_minutes) do
    init_session_tracker()

    case :ets.lookup(@session_table, session_key(user_id)) do
      [{_, start_time}] ->
        elapsed = System.monotonic_time(:second) - start_time

        if elapsed > limit_minutes * 60 do
          # Auto-guérison : sans partie active (salle ou match), la session
          # est orpheline (ex: redémarrage, leave manqué) → on la réinitialise
          # au lieu de bloquer indéfiniment.
          if has_active_play?(user_id) do
            true
          else
            end_session(user_id)
            false
          end
        else
          false
        end

      _ ->
        false
    end
  rescue
    _ -> false
  end

  # Partie active = salle suivie ou match non terminé.
  # Toute erreur de lookup = prudence (on garde la session).
  defp has_active_play?(user_id) do
    room_active? =
      try do
        case GameHub.GameRoom.get_active_room_for_player(user_id) do
          {:ok, _} -> true
          _ -> false
        end
      rescue
        _ -> true
      end

    if room_active? do
      true
    else
      try do
        case GameHub.GameMatch.get_active_match_for_player(user_id) do
          {:ok, _} -> true
          _ -> false
        end
      rescue
        _ -> true
      end
    end
  end

  # Normalise l'identifiant (évite les ratés de limites sur mismatch int/string).
  defp normalize_user_id(user_id) when is_integer(user_id), do: user_id

  defp normalize_user_id(user_id) when is_binary(user_id) do
    case Integer.parse(String.trim(user_id)) do
      {n, ""} -> n
      _ -> user_id
    end
  end

  defp normalize_user_id(user_id), do: user_id

  defp session_key(user_id) when is_integer(user_id), do: user_id

  defp session_key(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {n, ""} -> n
      _ -> user_id
    end
  end

  defp session_key(user_id), do: user_id

  defp sum_tokens(user_id, types, start_utc, end_utc, :abs) do
    Repo.one(
      from t in TokenTransaction,
        where:
          t.user_id == ^user_id and t.type in ^types and
            t.inserted_at >= ^start_utc and t.inserted_at < ^end_utc,
        select: fragment("COALESCE(SUM(ABS(?)), 0)", t.token_amount)
    )
  end

  defp sum_tokens(user_id, types, start_utc, end_utc, :signed) do
    Repo.one(
      from t in TokenTransaction,
        where:
          t.user_id == ^user_id and t.type in ^types and
            t.inserted_at >= ^start_utc and t.inserted_at < ^end_utc,
        select: fragment("COALESCE(SUM(?), 0)", t.token_amount)
    )
  end

  # Semaine Douala : lundi 00h00 → lundi suivant (heure locale).
  defp douala_week_range do
    local_today =
      DateTime.utc_now()
      |> DateTime.add(@douala_offset_seconds, :second)
      |> DateTime.to_date()

    monday = Date.add(local_today, -(Date.day_of_week(local_today) - 1))
    {start_utc, _} = douala_day_range(monday)
    {start_utc, DateTime.add(start_utc, 7 * 86_400, :second)}
  end

  # Mois calendaire Douala : 1er 00h00 → 1er du mois suivant.
  defp douala_month_range do
    local_today =
      DateTime.utc_now()
      |> DateTime.add(@douala_offset_seconds, :second)
      |> DateTime.to_date()

    first = %Date{year: local_today.year, month: local_today.month, day: 1}
    {start_utc, _} = douala_day_range(first)

    next =
      if first.month == 12,
        do: %Date{year: first.year + 1, month: 1, day: 1},
        else: %Date{year: first.year, month: first.month + 1, day: 1}

    {next_start, _} = douala_day_range(next)
    {start_utc, next_start}
  end

  defp validate_exclusion_duration(days) when is_integer(days) and days >= 0 and days <= 3650, do: :ok
  defp validate_exclusion_duration(_), do: {:error, :invalid_duration}

  defp validate_exclusion_reason(reason) when is_binary(reason) do
    if String.length(String.trim(reason)) >= 3, do: :ok, else: {:error, :invalid_reason}
  end

  defp validate_exclusion_reason(_), do: {:error, :invalid_reason}

  # Synchronise le drapeau `users.self_excluded` (lu par l'admin/stats).
  # Best effort : l'enforcement lit toujours `responsible_gaming_limits`.
  defp sync_user_excluded_flag(user_id, flag) when is_integer(user_id) do
    try do
      case Repo.get(GameHub.Users.User, user_id) do
        nil ->
          :ok

        user ->
          user
          |> GameHub.Users.User.changeset(%{self_excluded: flag})
          |> Repo.update()
          |> then(fn _ -> :ok end)
      end
    rescue
      _ -> :ok
    end
  end

  defp sync_user_excluded_flag(_, _), do: :ok

  # Récupère la ligne de limites en la créant si absente (sinon tout
  # Repo.update ultérieur lèverait NoPrimaryKeyValueError).
  defp get_or_create_limits(user_id) do
    case get_limits(user_id) do
      nil ->
        case %ResponsibleGamingLimit{user_id: user_id}
             |> ResponsibleGamingLimit.changeset(%{})
             |> Repo.insert() do
          {:ok, limits} ->
            limits

          {:error, _} ->
            # Course concurrente : relire la ligne créée par l'autre processus.
            get_limits(user_id) || %ResponsibleGamingLimit{user_id: user_id}
        end

      limits ->
        limits
    end
  end
end
