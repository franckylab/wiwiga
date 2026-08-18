# ==================================
# WIWIGA - Module Admin Metrics
# ==================================
# Module: GameHub.Admin.Metrics
# Description: Collecte centralisée de métriques admin
#              Financier, jeux, utilisateurs, paiements, sécurité

defmodule GameHub.Admin.Metrics do
  @moduledoc """
  Module de collecte de métriques pour l'administration.

  Fournit des agrégats sur différentes périodes :
  - `24h` : dernières 24 heures
  - `7d`  : 7 derniers jours
  - `30d` : 30 derniers jours
  - `custom` : période personnalisée (from/to)
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.GameStats.GameStat
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  # ========================================
  # Conversions Decimal → types Elixir
  # ========================================

  defp to_int(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d))
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: round(v)
  defp to_int(_), do: 0

  # ========================================
  # Types
  # ========================================

  @type period :: String.t()
  @type date_range :: %{from: DateTime.t(), to: DateTime.t()}

  # ========================================
  # Cache ETS pour dashboard summary
  # ========================================

  @cache_table :admin_dashboard_cache
  @cache_ttl_seconds 30

  @doc """
  Initialise la table ETS pour le cache dashboard.
  À appeler au démarrage de l'application.
  """
  def init_cache do
    if :ets.info(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :named_table, :public, read_concurrency: true])
    end
    :ok
  end

  @doc """
  Invalide le cache dashboard.
  À appeler après les changements de configuration.
  """
  def invalidate_dashboard_cache do
    try do
      :ets.delete_all_objects(@cache_table)
    rescue
      _ -> :ok
    end
    :ok
  end

  defp cached_fetch(key, ttl_seconds, fetch_fn) do
    now = System.system_time(:second)

    case safe_ets_lookup(key) do
      {value, cached_at} when now - cached_at < ttl_seconds ->
        value
      _ ->
        value = fetch_fn.()
        safe_ets_insert(key, value, now)
        value
    end
  end

  defp safe_ets_lookup(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, value, timestamp}] -> {value, timestamp}
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp safe_ets_insert(key, value, timestamp) do
    :ets.insert(@cache_table, {key, value, timestamp})
  rescue
    _ -> :ok
  end

  # ========================================
  # Métriques Financières
  # ========================================

  @doc """
  Métriques financières pour une période donnée.
  Retourne: dépôts, retraits, volume, commissions, revenue net.
  """
  @spec get_financial_metrics(period | date_range) :: map()
  def get_financial_metrics(period_or_range \\ "24h") do
    date_range = resolve_date_range(period_or_range)

    deposits = aggregate_transactions(date_range, "deposit")
    withdrawals = aggregate_transactions(date_range, "withdrawal")
    bets = aggregate_transactions(date_range, "bet")
    winnings = aggregate_transactions(date_range, "winnings")

    total_deposits = to_int(deposits.total_amount)
    total_withdrawals = to_int(withdrawals.total_amount)
    total_bets = to_int(bets.total_amount)
    total_winnings = to_int(winnings.total_amount)

    # Revenue = commissions (5% des mises en moyenne)
    estimated_commission = round(total_bets * 0.05)
    net_revenue = estimated_commission

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      total_deposits: total_deposits,
      deposit_count: deposits.count,
      total_withdrawals: total_withdrawals,
      withdrawal_count: withdrawals.count,
      total_bets: total_bets,
      bet_count: bets.count,
      total_winnings: total_winnings,
      win_count: winnings.count,
      estimated_commission: estimated_commission,
      net_revenue: net_revenue,
      net_flow: total_deposits - total_withdrawals,
      ggr: total_bets - total_winnings
    }
  end

  # ========================================
  # Métriques Jeux
  # ========================================

  @doc """
  Métriques jeux pour une période donnée.
  Retourne: parties jouées, mise moyenne, GGR, joueurs actifs.
  """
  @spec get_game_metrics(period | date_range) :: map()
  def get_game_metrics(period_or_range \\ "24h") do
    date_range = resolve_date_range(period_or_range)

    # Stats agrégées depuis game_stats
    game_stats = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        select: %{
          total_matches: coalesce(sum(gs.matches_played), 0),
          total_wagered: coalesce(sum(gs.total_wagered), 0),
          total_won: coalesce(sum(gs.total_won_net), 0),
          active_players: count(gs.user_id, :distinct)
        }
    ) || %{total_matches: 0, total_wagered: 0, total_won: 0, active_players: 0}

    # Parties par type de jeu
    games_by_type = Repo.all(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        group_by: gs.game_type,
        select: %{
          game_type: gs.game_type,
          matches: sum(gs.matches_played),
          wagered: sum(gs.total_wagered),
          players: count(gs.user_id, :distinct)
        }
    )

    avg_bet = if game_stats.total_matches > 0,
      do: round(to_int(game_stats.total_wagered) / to_int(game_stats.total_matches)),
      else: 0

    ggr = to_int(game_stats.total_wagered) - to_int(game_stats.total_won)

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      total_matches: game_stats.total_matches,
      total_wagered: game_stats.total_wagered,
      total_won_net: game_stats.total_won,
      active_players: game_stats.active_players,
      average_bet: avg_bet,
      ggr: ggr,
      games_by_type: games_by_type
    }
  end

  # ========================================
  # Métriques Utilisateurs
  # ========================================

  @doc """
  Métriques utilisateurs pour une période donnée.
  Retourne: inscriptions, actifs, connexions, rétention.
  """
  @spec get_user_metrics(period | date_range) :: map()
  def get_user_metrics(period_or_range \\ "24h") do
    date_range = resolve_date_range(period_or_range)

    # Total utilisateurs
    total_users = Repo.one(from u in User, select: count(u.id))

    # Nouvelles inscriptions sur la période
    new_users = Repo.one(
      from u in User,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to,
        select: count(u.id)
    )

    # Utilisateurs actifs (connectés sur la période)
    active_users = Repo.one(
      from u in User,
        where: u.last_login_at >= ^date_range.from and
               u.last_login_at <= ^date_range.to,
        select: count(u.id)
    )

    # KYC
    kyc_verified = Repo.one(
      from u in User,
        where: u.has_verified_kyc == true,
        select: count(u.id)
    )

    kyc_pending = total_users - kyc_verified

    # Auto-exclus
    self_excluded = Repo.one(
      from u in User,
        where: u.self_excluded == true,
        select: count(u.id)
    )

    # Inactifs (pas connecté depuis 30 jours)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
    inactive_users = Repo.one(
      from u in User,
        where: u.is_active == true and
               (is_nil(u.last_login_at) or u.last_login_at < ^thirty_days_ago),
        select: count(u.id)
    )

    # Par rôle
    users_by_role = Repo.all(
      from u in User,
        group_by: u.role,
        select: %{role: u.role, count: count(u.id)}
    )

    # Événements audit 24h
    since_24h = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
    audit_24h = Repo.one(
      from a in AuditLog,
        where: a.inserted_at >= ^since_24h,
        select: count(a.id)
    )

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      total_users: total_users,
      new_users: new_users,
      active_users: active_users,
      kyc_verified: kyc_verified,
      kyc_pending: kyc_pending,
      self_excluded: self_excluded,
      inactive_users: inactive_users,
      users_by_role: Map.new(users_by_role, fn r -> {r.role, r.count} end),
      audit_events_24h: audit_24h
    }
  end

  # ========================================
  # Métriques Paiements
  # ========================================

  @doc """
  Métriques paiements pour une période donnée.
  """
  @spec get_payment_metrics(period | date_range) :: map()
  def get_payment_metrics(period_or_range \\ "24h") do
    date_range = resolve_date_range(period_or_range)

    deposits = aggregate_transactions(date_range, "deposit")
    withdrawals = aggregate_transactions(date_range, "withdrawal")

    # NOTE: WalletTransaction n'a pas de champ status - les transactions en DB
    # sont par design des succès (le module Wallet ne crée que des transactions réussies).
    # Le taux de succès réel nécessite le suivi des tentatives via audit logs ou
    # une table payment_attempts dédiée.
    # En attendant, on utilise les échecs d'auth paiement depuis l'audit log.
    failed_deposits = count_audit_events(date_range, "payment_failed", "deposit")
    failed_withdrawals = count_audit_events(date_range, "payment_failed", "withdrawal")

    total_deposit_attempts = deposits.count + failed_deposits
    successful_deposits = deposits.count

    total_withdrawal_attempts = withdrawals.count + failed_withdrawals
    successful_withdrawals = withdrawals.count

    deposit_success_rate = if total_deposit_attempts > 0,
      do: Float.round(successful_deposits / total_deposit_attempts * 100, 1),
      else: 100.0

    withdrawal_success_rate = if total_withdrawal_attempts > 0,
      do: Float.round(successful_withdrawals / total_withdrawal_attempts * 100, 1),
      else: 100.0

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      total_deposits: to_int(deposits.total_amount),
      deposit_count: deposits.count,
      avg_deposit: to_int(deposits.avg_amount),
      total_withdrawals: to_int(withdrawals.total_amount),
      withdrawal_count: withdrawals.count,
      avg_withdrawal: to_int(withdrawals.avg_amount),
      deposit_success_rate: deposit_success_rate,
      withdrawal_success_rate: withdrawal_success_rate,
      payment_volume: to_int(deposits.total_amount) + to_int(withdrawals.total_amount)
    }
  end

  # ========================================
  # Métriques Sécurité
  # ========================================

  @doc """
  Métriques sécurité pour une période donnée.
  """
  @spec get_security_metrics(period | date_range) :: map()
  def get_security_metrics(period_or_range \\ "24h") do
    date_range = resolve_date_range(period_or_range)

    # Auth échouées
    failed_auths = Repo.one(
      from a in AuditLog,
        where: a.action in ["password_login_failed", "otp_verified"] and
               a.inserted_at >= ^date_range.from and
               a.inserted_at <= ^date_range.to,
        select: count(a.id)
    )

    # Rate limiting
    rate_limited = Repo.one(
      from a in AuditLog,
        where: a.action == "rate_limited" and
               a.inserted_at >= ^date_range.from and
               a.inserted_at <= ^date_range.to,
        select: count(a.id)
    )

    # Actions admin
    admin_actions = Repo.one(
      from a in AuditLog,
        where: a.action == "admin_action" and
               a.inserted_at >= ^date_range.from and
               a.inserted_at <= ^date_range.to,
        select: count(a.id)
    )

    # Bans actifs
    active_bans = Repo.one(
      from b in "user_bans",
        where: b.is_active == true,
        select: count(b.id)
    )

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      failed_auth_attempts: failed_auths,
      rate_limited_events: rate_limited,
      admin_actions: admin_actions,
      active_bans: active_bans
    }
  end

  # ========================================
  # Dashboard Résumé
  # ========================================

  @doc """
  Résumé global pour le dashboard admin.
  Combine toutes les métriques clés.
  """
  @spec get_dashboard_summary() :: map()
  def get_dashboard_summary do
    init_cache()
    cached_fetch(:dashboard_summary, @cache_ttl_seconds, fn ->
      compute_dashboard_summary()
    end)
  end

  defp compute_dashboard_summary do
    financial_24h = get_financial_metrics("24h")
    user_metrics = get_user_metrics("24h")
    game_metrics = get_game_metrics("24h")
    security_metrics = get_security_metrics("24h")

    # Sessions actives (via Redis si disponible)
    active_sessions = get_active_sessions_count()

    # Solde total plateforme
    total_balance = Repo.one(
      from u in User,
        select: coalesce(sum(u.balance), 0)
    )

    total_token_balance = Repo.one(
      from u in User,
        select: coalesce(sum(u.token_balance), 0)
    )

    %{
      # Financier
      revenue_24h: financial_24h.net_revenue,
      deposits_24h: financial_24h.total_deposits,
      withdrawals_24h: financial_24h.total_withdrawals,
      ggr_24h: financial_24h.ggr,

      # Utilisateurs
      total_users: user_metrics.total_users,
      active_users: user_metrics.active_users,
      new_users_24h: user_metrics.new_users,
      active_24h: user_metrics.active_users,
      new_users_7d: 0, # Calculé séparément si nécessaire
      kyc_verified: user_metrics.kyc_verified,
      kyc_pending: user_metrics.kyc_pending,
      self_excluded: user_metrics.self_excluded,
      inactive_users: user_metrics.inactive_users,
      users_by_role: user_metrics.users_by_role,
      audit_events_24h: user_metrics.audit_events_24h,

      # Jeux
      active_games: game_metrics.active_players,
      matches_24h: game_metrics.total_matches,
      total_wagered_24h: game_metrics.total_wagered,

      # Sessions
      active_sessions: active_sessions,
      active_devices: 0,

      # Plateforme
      total_balance: total_balance,
      total_token_balance: total_token_balance,

      # Sécurité
      failed_auths_24h: security_metrics.failed_auth_attempts,
      rate_limited_24h: security_metrics.rate_limited_events,

      # Timestamp
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # ========================================
  # Timeseries (données graphiques)
  # ========================================

  @doc """
  Données timeseries pour graphiques.
  Regroupe les métriques par intervalle (hour/day).
  """
  @spec get_timeseries(String.t(), period | date_range) :: list()
  def get_timeseries(metric, period_or_range \\ "7d") do
    date_range = resolve_date_range(period_or_range)
    interval = determine_interval(date_range)

    case metric do
      "deposits" -> timeseries_transactions(date_range, "deposit", interval)
      "withdrawals" -> timeseries_transactions(date_range, "withdrawal", interval)
      "registrations" -> timeseries_registrations(date_range, interval)
      "matches" -> timeseries_game_matches(date_range, interval)
      _ -> []
    end
  end

  # ========================================
  # Fonctions Privées
  # ========================================

  defp resolve_date_range(%{from: _, to: _} = range), do: range
  defp resolve_date_range(period) do
    now = DateTime.utc_now()
    from = case period do
      "24h" -> DateTime.add(now, -24 * 3600, :second)
      "7d"  -> DateTime.add(now, -7 * 24 * 3600, :second)
      "30d" -> DateTime.add(now, -30 * 24 * 3600, :second)
      _     -> DateTime.add(now, -24 * 3600, :second)
    end
    %{from: from, to: now}
  end

  defp count_audit_events(date_range, action, entity_type) do
    Repo.one(
      from a in AuditLog,
        where: a.action == ^action and
               a.entity_type == ^entity_type and
               a.inserted_at >= ^date_range.from and
               a.inserted_at <= ^date_range.to,
        select: count(a.id)
    ) || 0
  rescue
    _ -> 0
  end

  defp aggregate_transactions(date_range, type) do
    Repo.one(
      from t in WalletTransaction,
        where: t.type == ^type and
               t.inserted_at >= ^date_range.from and
               t.inserted_at <= ^date_range.to,
        select: %{
          total_amount: coalesce(sum(t.amount), 0) |> type(:decimal),
          count: count(t.id),
          avg_amount: coalesce(avg(t.amount), 0) |> type(:decimal)
        }
    ) || %{total_amount: 0, count: 0, avg_amount: 0}
  end

  defp get_active_sessions_count do
    case Redix.command(GameHub.Redis, ["DBSIZE"]) do
      {:ok, size} when is_integer(size) -> min(size, 1000)
      _ -> 0
    end
  rescue
    _ -> 0
  catch
    :exit, _ -> 0
  end

  defp determine_interval(date_range) do
    diff = DateTime.diff(date_range.to, date_range.from, :hour)
    cond do
      diff <= 24 -> "hour"
      diff <= 168 -> "day"
      true -> "day"
    end
  end

  defp timeseries_transactions(date_range, type, interval) do
    Repo.all(
      from t in WalletTransaction,
        where: t.type == ^type and
               t.inserted_at >= ^date_range.from and
               t.inserted_at <= ^date_range.to,
        group_by: fragment("date_trunc(?, inserted_at)", ^interval),
        order_by: fragment("date_trunc(?, inserted_at)", ^interval),
        select: %{
          timestamp: fragment("date_trunc(?, inserted_at)", ^interval),
          amount: coalesce(sum(t.amount), 0),
          count: count(t.id)
        }
    )
  end

  defp timeseries_registrations(date_range, interval) do
    Repo.all(
      from u in User,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to,
        group_by: fragment("date_trunc(?, inserted_at)", ^interval),
        order_by: fragment("date_trunc(?, inserted_at)", ^interval),
        select: %{
          timestamp: fragment("date_trunc(?, inserted_at)", ^interval),
          count: count(u.id)
        }
    )
  end

  defp timeseries_game_matches(date_range, interval) do
    Repo.all(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        group_by: fragment("date_trunc(?, inserted_at)", ^interval),
        order_by: fragment("date_trunc(?, inserted_at)", ^interval),
        select: %{
          timestamp: fragment("date_trunc(?, inserted_at)", ^interval),
          matches: sum(gs.matches_played),
          wagered: sum(gs.total_wagered)
        }
    )
  end
end
