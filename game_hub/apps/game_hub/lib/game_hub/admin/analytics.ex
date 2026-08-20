# ==================================
# WIWIGA - Module Admin Analytics
# ==================================
# Module: GameHub.Admin.Analytics
# Description: KPI gaming avances - revenue, players, retention,
#              cohorts, LTV, game performance, monetary flow

defmodule GameHub.Admin.Analytics do
  @moduledoc """
  Module d'analytiques avancees pour l'administration.

  Calcule les KPI gaming standards de l'industrie:
  - Revenue: GGR, NGR, commissions, ARPU, ARPPU
  - Players: DAU, WAU, MAU, stickiness, Reg2Dep
  - Retention: D1, D7, D30 avec cohortes
  - LTV: estimation par segment
  - Games: performance par type de jeu
  - Monetary flow: flux complets FCFA/tokens
  - Wealth: distribution gains/pertes
  - Conversion: entonnoir inscrit -> VIP
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.GameStats.GameStat
  import Ecto.Query

  @type period :: String.t()
  @type date_range :: %{from: DateTime.t(), to: DateTime.t()}

  # ========================================
  # Revenue Analytics
  # ========================================

  @doc """
  Analytiques revenue completes.
  GGR, NGR, commissions, ARPU, ARPPU par periode.
  """
  @spec get_revenue_analytics(period | date_range) :: map()
  def get_revenue_analytics(period_or_range \\ "7d") do
    date_range = resolve_date_range(period_or_range)
    prev_range = previous_period(date_range)

    # Periode courante
    current = compute_revenue_metrics(date_range)
    # Periode precedente (pour delta)
    previous = compute_revenue_metrics(prev_range)

    # Commissions par type de jeu
    commissions_by_game = get_commissions_by_game(date_range)

    # Timeseries pour graphiques
    timeseries = get_revenue_timeseries(date_range)

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      ggr: current.ggr,
      ngr: current.ngr,
      total_commissions: current.commissions,
      total_deposits: current.deposits,
      total_withdrawals: current.withdrawals,
      total_bets: current.bets,
      total_winnings: current.winnings,
      arpu: current.arpu,
      arppu: current.arppu,
      # Delta vs periode precedente
      ggr_delta: compute_delta(current.ggr, previous.ggr),
      ngr_delta: compute_delta(current.ngr, previous.ngr),
      commission_delta: compute_delta(current.commissions, previous.commissions),
      deposits_delta: compute_delta(current.deposits, previous.deposits),
      # Details
      commissions_by_game: commissions_by_game,
      timeseries: timeseries
    }
  end

  defp compute_revenue_metrics(date_range) do
    deposits = aggregate_amount(date_range, "deposit")
    withdrawals = aggregate_amount(date_range, "withdrawal")
    bets = aggregate_amount(date_range, "bet")
    winnings = aggregate_amount(date_range, "winnings")
    commissions = aggregate_amount(date_range, "commission")

    ggr = bets.total - winnings.total
    ngr = ggr - commissions.total

    # Nombre d'utilisateurs actifs sur la periode
    active_users = count_active_users(date_range)
    # Nombre d'utilisateurs ayant fait au moins une transaction
    paying_users = count_paying_users(date_range)

    arpu = if active_users > 0, do: Float.round(deposits.total / active_users, 0), else: 0
    arppu = if paying_users > 0, do: Float.round(deposits.total / paying_users, 0), else: 0

    %{
      ggr: ggr,
      ngr: max(ngr, 0),
      commissions: commissions.total,
      deposits: deposits.total,
      withdrawals: withdrawals.total,
      bets: bets.total,
      winnings: winnings.total,
      arpu: arpu,
      arppu: arppu,
      active_users: active_users,
      paying_users: paying_users
    }
  end

  defp get_commissions_by_game(date_range) do
    Repo.all(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        group_by: gs.game_type,
        order_by: [desc: sum(gs.total_wagered)],
        select: %{
          game_type: gs.game_type,
          total_wagered: sum(gs.total_wagered),
          total_won: sum(gs.total_won_net),
          matches: sum(gs.matches_played),
          players: count(gs.user_id, :distinct),
          ggr: sum(gs.total_wagered) - sum(gs.total_won_net),
          estimated_commission: fragment("round(? * 0.05)", sum(gs.total_wagered))
        }
    )
  end

  defp get_revenue_timeseries(date_range) do
    interval = determine_interval(date_range)

    deposits_ts = query_wallet_timeseries("deposit", date_range, interval)
    bets_ts = query_wallet_timeseries("bet", date_range, interval)
    winnings_ts = query_wallet_timeseries("winnings", date_range, interval)

    # Fusionner les timeseries
    merge_timeseries([deposits_ts, bets_ts, winnings_ts], ["deposits", "bets", "winnings"])
  end

  # Raw SQL pour éviter le problème de GROUP BY avec les paramètres Ecto
  defp query_wallet_timeseries(type, date_range, interval) do
    sql = """
    SELECT date_trunc($1, inserted_at) AS timestamp,
           coalesce(sum(amount), 0) AS amount
    FROM wallet_transactions
    WHERE type = $2 AND inserted_at >= $3 AND inserted_at <= $4
    GROUP BY date_trunc($1, inserted_at)
    ORDER BY date_trunc($1, inserted_at)
    """
    %{rows: rows} = Repo.query!(sql, [interval, type, date_range.from, date_range.to])
    Enum.map(rows, fn [ts, amount] -> %{timestamp: ts, amount: amount} end)
  end

  # ========================================
  # Player Analytics
  # ========================================

  @doc """
  Analytiques joueurs completes.
  DAU, WAU, MAU, stickiness, Reg2Dep, nouveaux inscrits.
  """
  @spec get_player_analytics(period | date_range) :: map()
  def get_player_analytics(period_or_range \\ "30d") do
    date_range = resolve_date_range(period_or_range)
    now = DateTime.utc_now()

    # DAU: actifs aujourd'hui
    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00])
    dau = count_users_logged_in_since(today_start)

    # WAU: actifs cette semaine (7 derniers jours)
    week_ago = DateTime.add(now, -7 * 24 * 3600, :second)
    wau = count_users_logged_in_since(week_ago)

    # MAU: actifs ce mois (30 derniers jours)
    month_ago = DateTime.add(now, -30 * 24 * 3600, :second)
    mau = count_users_logged_in_since(month_ago)

    # Stickiness = DAU / MAU
    stickiness = if mau > 0, do: Float.round(dau / mau * 100, 1), else: 0.0

    # Total utilisateurs
    total_users = Repo.one(from u in User, select: count(u.id))

    # Nouveaux inscrits sur la periode
    new_users = Repo.one(
      from u in User,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to,
        select: count(u.id)
    )

    # Reg2Dep: % qui se sont inscrits ET ont fait un depot
    reg2dep_count = Repo.one(
      from u in User,
        join: t in WalletTransaction, on: t.user_id == u.id,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to and
               t.type == "deposit",
        select: count(u.id, :distinct)
    )
    reg2dep_rate = if new_users > 0, do: Float.round(reg2dep_count / new_users * 100, 1), else: 0.0

    # Joueurs actifs (ont joue sur la periode)
    active_players = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        select: count(gs.user_id, :distinct)
    )

    # Timeseries DAU
    dau_timeseries = get_dau_timeseries(date_range)

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      dau: dau,
      wau: wau,
      mau: mau,
      stickiness: stickiness,
      total_users: total_users,
      new_users: new_users,
      reg2dep_rate: reg2dep_rate,
      active_players: active_players,
      dau_timeseries: dau_timeseries
    }
  end

  defp get_dau_timeseries(date_range) do
    sql = """
    SELECT date_trunc('day', last_login_at) AS timestamp,
           count(id) AS count
    FROM users
    WHERE last_login_at >= $1 AND last_login_at <= $2
    GROUP BY date_trunc('day', last_login_at)
    ORDER BY date_trunc('day', last_login_at)
    """
    %{rows: rows} = Repo.query!(sql, [date_range.from, date_range.to])
    Enum.map(rows, fn [ts, count] -> %{timestamp: ts, count: count} end)
  end

  # ========================================
  # Retention Cohorts
  # ========================================

  @doc """
  Analyse de retention par cohortes.
  D1, D7, D30: % de joueurs qui reviennent apres 1, 7, 30 jours.
  """
  @spec get_retention_cohorts(integer()) :: map()
  def get_retention_cohorts(days_back \\ 90) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back * 24 * 3600, :second)

    # Cohortes par semaine d'inscription
    cohorts_sql = """
    SELECT date_trunc('week', inserted_at) AS week,
           count(id) AS total_registered
    FROM users
    WHERE inserted_at >= $1
    GROUP BY date_trunc('week', inserted_at)
    ORDER BY date_trunc('week', inserted_at)
    """
    %{rows: cohort_rows} = Repo.query!(cohorts_sql, [cutoff])
    cohorts = Enum.map(cohort_rows, fn [week, total] -> %{week: week, total_registered: total} end)

    # Pour chaque cohorte, calculer la retention
    retention_data = Enum.map(cohorts, fn cohort ->
      week_start = cohort.week
      total = cohort.total_registered

      # D1: revenus au moins 1 jour apres inscription
      d1 = count_returning_users(week_start, 1, 2)
      # D7: revenus entre 7 et 14 jours
      d7 = count_returning_users(week_start, 7, 14)
      # D30: revenus entre 30 et 60 jours
      d30 = count_returning_users(week_start, 30, 60)

      %{
        week: week_start,
        total: total,
        d1_count: d1,
        d1_rate: if(total > 0, do: Float.round(d1 / total * 100, 1), else: 0.0),
        d7_count: d7,
        d7_rate: if(total > 0, do: Float.round(d7 / total * 100, 1), else: 0.0),
        d30_count: d30,
        d30_rate: if(total > 0, do: Float.round(d30 / total * 100, 1), else: 0.0)
      }
    end)

    # Retention globale moyenne
    avg_d1 = retention_data |> Enum.map(& &1.d1_rate) |> safe_avg()
    avg_d7 = retention_data |> Enum.map(& &1.d7_rate) |> safe_avg()
    avg_d30 = retention_data |> Enum.map(& &1.d30_rate) |> safe_avg()

    %{
      cohorts: retention_data,
      avg_d1: avg_d1,
      avg_d7: avg_d7,
      avg_d30: avg_d30
    }
  end

  defp count_returning_users(week_start, min_days, max_days) do
    period_start = NaiveDateTime.add(week_start, min_days * 24 * 3600, :second)
    period_end = NaiveDateTime.add(week_start, max_days * 24 * 3600, :second)

    Repo.one(
      from u in User,
        where: u.inserted_at >= ^week_start and
               u.inserted_at < ^period_start and
               u.last_login_at >= ^period_start and
               u.last_login_at < ^period_end,
        select: count(u.id)
    ) || 0
  end

  # ========================================
  # LTV Estimate
  # ========================================

  @doc """
  Estimation de la Lifetime Value par segment.
  """
  @spec get_ltv_estimate(String.t()) :: map()
  def get_ltv_estimate(_period \\ "all") do
    # LTV = ARPU * duree de vie moyenne
    # Duree de vie moyenne = jours entre inscription et derniere connexion

    # Revenue total par utilisateur
    revenue_per_user = Repo.all(
      from u in User,
        left_join: t in WalletTransaction, on: t.user_id == u.id and t.type == "deposit",
        group_by: u.id,
        select: %{
          user_id: u.id,
          total_deposits: type(coalesce(sum(t.amount), 0), :integer),
          days_active: fragment("COALESCE(EXTRACT(DAY FROM ? - ?), 0)", u.last_login_at, u.inserted_at),
          inserted_at: u.inserted_at
        }
    )

    # Segmenter par tranche d'anciennete
    new_users = Enum.filter(revenue_per_user, fn u ->
      NaiveDateTime.diff(NaiveDateTime.utc_now(), u.inserted_at, :day) <= 30
    end)

    active_users = Enum.filter(revenue_per_user, fn u ->
      NaiveDateTime.diff(NaiveDateTime.utc_now(), u.inserted_at, :day) > 30
    end)

    # LTV nouveaux (30 premiers jours)
    new_avg_revenue = safe_avg(Enum.map(new_users, & &1.total_deposits))
    new_count = length(new_users)

    # LTV utilisateurs actifs (extrapolation)
    active_avg_revenue = safe_avg(Enum.map(active_users, & &1.total_deposits))
    active_avg_days = safe_avg(Enum.map(active_users, & &1.days_active))
    active_count = length(active_users)

    # LTV mensuelle
    ltv_monthly = if active_avg_days > 0,
      do: Float.round(active_avg_revenue / max(active_avg_days, 1) * 30, 0),
      else: 0

    %{
      new_users: %{
        count: new_count,
        avg_revenue_30d: round(new_avg_revenue),
        ltv_estimate: round(new_avg_revenue * 6) # extrapolation 6 mois
      },
      active_users: %{
        count: active_count,
        avg_revenue: round(active_avg_revenue),
        avg_lifetime_days: round(active_avg_days),
        ltv_monthly: ltv_monthly
      },
      overall: %{
        total_users: length(revenue_per_user),
        total_revenue: Enum.reduce(revenue_per_user, 0, fn u, acc -> acc + u.total_deposits end),
        avg_revenue_per_user: round(safe_avg(Enum.map(revenue_per_user, & &1.total_deposits)))
      }
    }
  end

  # ========================================
  # Game Performance
  # ========================================

  @doc """
  Performance par type de jeu.
  """
  @spec get_game_performance(period | date_range) :: map()
  def get_game_performance(period_or_range \\ "7d") do
    date_range = resolve_date_range(period_or_range)

    # Stats par type de jeu (raw SQL pour éviter les problèmes d'agrégats imbriqués)
    games_sql = """
    SELECT game_type,
           sum(matches_played) AS total_matches,
           sum(total_wagered) AS total_wagered,
           sum(total_won_net) AS total_won,
           count(DISTINCT user_id) AS total_players,
           round(sum(total_wagered)::numeric / nullif(sum(matches_played), 0)) AS avg_bet,
           max(biggest_win) AS biggest_win,
           sum(total_wagered) - sum(total_won_net) AS ggr,
           round(((sum(total_wagered) - sum(total_won_net))::numeric / nullif(sum(total_wagered), 0)) * 100, 2) AS house_edge
    FROM game_stats
    WHERE last_played_at >= $1 AND last_played_at <= $2
    GROUP BY game_type
    ORDER BY sum(total_wagered) DESC
    """
    %{rows: rows} = Repo.query!(games_sql, [date_range.from, date_range.to])
    games = Enum.map(rows, fn [game_type, total_matches, total_wagered, total_won, total_players, avg_bet, biggest_win, ggr, house_edge] ->
      %{game_type: game_type, total_matches: total_matches, total_wagered: total_wagered,
        total_won: total_won, total_players: total_players, avg_bet: avg_bet,
        biggest_win: biggest_win, ggr: ggr, house_edge: house_edge}
    end)

    # Totals
    total_matches = Enum.reduce(games, 0, fn g, acc -> acc + (g.total_matches || 0) end)
    total_wagered = Enum.reduce(games, 0, fn g, acc -> acc + (g.total_wagered || 0) end)
    total_ggr = Enum.reduce(games, 0, fn g, acc -> acc + (g.ggr || 0) end)

    # Timeseries par jeu
    games_timeseries = get_games_timeseries(date_range)

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      games: games,
      total_matches: total_matches,
      total_wagered: total_wagered,
      total_ggr: total_ggr,
      games_timeseries: games_timeseries
    }
  end

  defp get_games_timeseries(date_range) do
    interval = determine_interval(date_range)

    sql = """
    SELECT game_type,
           date_trunc($1, last_played_at) AS timestamp,
           sum(matches_played) AS matches,
           sum(total_wagered) AS wagered
    FROM game_stats
    WHERE last_played_at >= $2 AND last_played_at <= $3
    GROUP BY game_type, date_trunc($1, last_played_at)
    ORDER BY game_type, date_trunc($1, last_played_at)
    """
    %{rows: rows} = Repo.query!(sql, [interval, date_range.from, date_range.to])
    Enum.map(rows, fn [game_type, ts, matches, wagered] ->
      %{game_type: game_type, timestamp: ts, matches: matches, wagered: wagered}
    end)
  end

  # ========================================
  # Monetary Flow
  # ========================================

  @doc """
  Flux monetaires complets.
  Depos -> Wallet -> Mises -> Gains -> Retraits + Commission
  """
  @spec get_monetary_flow(period | date_range) :: map()
  def get_monetary_flow(period_or_range \\ "7d") do
    date_range = resolve_date_range(period_or_range)

    # Aggregations par type
    deposits = aggregate_amount(date_range, "deposit")
    withdrawals = aggregate_amount(date_range, "withdrawal")
    bets = aggregate_amount(date_range, "bet")
    winnings = aggregate_amount(date_range, "winnings")
    commissions = aggregate_amount(date_range, "commission")
    refunds = aggregate_amount(date_range, "refund")

    # Solde total plateforme (cast to integer for arithmetic)
    total_player_balance = Repo.one(from u in User, select: type(coalesce(sum(u.balance), 0), :integer)) || 0
    total_token_balance = Repo.one(from u in User, select: type(coalesce(sum(u.token_balance), 0), :integer)) || 0

    # Flux net
    net_flow = deposits.total - withdrawals.total

    # Vitesse de circulation = total transactions / solde moyen
    total_volume = deposits.total + withdrawals.total + bets.total + winnings.total
    avg_balance = max(total_player_balance, 1)
    velocity = Float.round(total_volume / avg_balance, 2)

    # Timeseries flux net journalier
    flow_timeseries = get_flow_timeseries(date_range)

    # Top mouvements par joueur
    top_movements = get_top_movements(date_range, 50)

    %{
      period: period_or_range,
      from: date_range.from,
      to: date_range.to,
      deposits: deposits,
      withdrawals: withdrawals,
      bets: bets,
      winnings: winnings,
      commissions: commissions,
      refunds: refunds,
      total_player_balance: total_player_balance,
      total_token_balance: total_token_balance,
      net_flow: net_flow,
      velocity: velocity,
      flow_timeseries: flow_timeseries,
      top_movements: top_movements
    }
  end

  defp get_flow_timeseries(date_range) do
    interval = determine_interval(date_range)

    inflows_sql = """
    SELECT date_trunc($1, inserted_at) AS timestamp,
           coalesce(sum(amount), 0) AS inflow
    FROM wallet_transactions
    WHERE type IN ('deposit', 'winnings', 'refund')
      AND inserted_at >= $2 AND inserted_at <= $3
    GROUP BY date_trunc($1, inserted_at)
    ORDER BY date_trunc($1, inserted_at)
    """
    %{rows: inflow_rows} = Repo.query!(inflows_sql, [interval, date_range.from, date_range.to])
    inflows = Enum.map(inflow_rows, fn [ts, amount] -> %{timestamp: ts, inflow: amount} end)

    outflows_sql = """
    SELECT date_trunc($1, inserted_at) AS timestamp,
           coalesce(sum(abs(amount)), 0) AS outflow
    FROM wallet_transactions
    WHERE type IN ('withdrawal', 'bet', 'commission')
      AND inserted_at >= $2 AND inserted_at <= $3
    GROUP BY date_trunc($1, inserted_at)
    ORDER BY date_trunc($1, inserted_at)
    """
    %{rows: outflow_rows} = Repo.query!(outflows_sql, [interval, date_range.from, date_range.to])
    outflows = Enum.map(outflow_rows, fn [ts, amount] -> %{timestamp: ts, outflow: amount} end)

    merge_timeseries([inflows, outflows], ["inflow", "outflow"])
  end

  defp get_top_movements(date_range, limit) do
    Repo.all(
      from t in WalletTransaction,
        join: u in User, on: t.user_id == u.id,
        where: t.inserted_at >= ^date_range.from and
               t.inserted_at <= ^date_range.to,
        order_by: [desc: fragment("abs(?)", t.amount)],
        limit: ^limit,
        select: %{
          id: t.id,
          user_id: t.user_id,
          username: u.username,
          type: t.type,
          amount: t.amount,
          balance_after: t.balance_after,
          inserted_at: t.inserted_at
        }
    )
  end

  # ========================================
  # Player Wealth Distribution
  # ========================================

  @doc """
  Distribution des gains/pertes par joueur.
  """
  @spec get_player_wealth_distribution(period | date_range) :: map()
  def get_player_wealth_distribution(period_or_range \\ "30d") do
    date_range = resolve_date_range(period_or_range)

    # P&L par joueur: gains - mises
    player_pl = Repo.all(
      from gs in GameStat,
        join: u in User, on: gs.user_id == u.id,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        group_by: [gs.user_id, u.id, u.username],
        select: %{
          user_id: gs.user_id,
          username: u.username,
          total_wagered: sum(gs.total_wagered),
          total_won: sum(gs.total_won_net),
          net_pl: sum(gs.total_won_net) - sum(gs.total_wagered),
          matches: sum(gs.matches_played),
          balance: u.balance
        }
    )

    # Quartiles
    sorted = Enum.sort_by(player_pl, & &1.net_pl)
    count = length(sorted)

    quartiles = if count >= 4 do
      q1_idx = div(count, 4)
      q2_idx = div(count, 2)
      q3_idx = div(count * 3, 4)

      q1 = Enum.at(sorted, q1_idx)
      q2 = Enum.at(sorted, q2_idx)
      q3 = Enum.at(sorted, q3_idx)

      [
        %{label: "Q1 (25% perdants)", net_pl: q1.net_pl, wagered: q1.total_wagered},
        %{label: "Q2", net_pl: q2.net_pl, wagered: q2.total_wagered},
        %{label: "Q3", net_pl: q3.net_pl, wagered: q3.total_wagered},
        %{label: "Q4 (25% gagnants)", net_pl: List.last(sorted).net_pl, wagered: List.last(sorted).total_wagered}
      ]
    else
      []
    end

    # Segments
    positive = Enum.filter(player_pl, fn p -> p.net_pl >= 0 end)
    negative = Enum.filter(player_pl, fn p -> p.net_pl < 0 end)

    # Top gagnants et perdants
    top_winners = sorted |> Enum.sort_by(& &1.net_pl, :desc) |> Enum.take(20)
    top_losers = Enum.take(sorted, 20)

    # Histogramme (buckets de P&L)
    histogram = build_pl_histogram(player_pl)

    %{
      period: period_or_range,
      total_players: count,
      positive_players: length(positive),
      negative_players: length(negative),
      positive_ratio: if(count > 0, do: Float.round(length(positive) / count * 100, 1), else: 0.0),
      quartiles: quartiles,
      top_winners: top_winners,
      top_losers: top_losers,
      histogram: histogram
    }
  end

  defp build_pl_histogram(players) do
    # Creer des buckets: <-100K, -100K..-50K, -50K..-10K, -10K..0, 0..10K, 10K..50K, 50K..100K, >100K
    buckets = [
      %{label: "< -100K", min: -999_999_999, max: -100_000},
      %{label: "-100K..-50K", min: -100_000, max: -50_000},
      %{label: "-50K..-10K", min: -50_000, max: -10_000},
      %{label: "-10K..0", min: -10_000, max: 0},
      %{label: "0..10K", min: 0, max: 10_000},
      %{label: "10K..50K", min: 10_000, max: 50_000},
      %{label: "50K..100K", min: 50_000, max: 100_000},
      %{label: "> 100K", min: 100_000, max: 999_999_999}
    ]

    Enum.map(buckets, fn bucket ->
      count = Enum.count(players, fn p ->
        p.net_pl >= bucket.min and p.net_pl < bucket.max
      end)
      %{label: bucket.label, count: count}
    end)
  end

  # ========================================
  # Conversion Funnel
  # ========================================

  @doc """
  Entonnoir de conversion.
  Inscrits -> Deposants -> Joueurs actifs -> VIP
  """
  @spec get_conversion_funnel(period | date_range) :: map()
  def get_conversion_funnel(period_or_range \\ "30d") do
    date_range = resolve_date_range(period_or_range)

    # 1. Inscrits
    registered = Repo.one(
      from u in User,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to,
        select: count(u.id)
    )

    # 2. Deposants (ont fait au moins 1 depot)
    depositors = Repo.one(
      from u in User,
        join: t in WalletTransaction, on: t.user_id == u.id,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to and
               t.type == "deposit",
        select: count(u.id, :distinct)
    )

    # 3. Joueurs actifs (ont joue au moins 1 partie)
    players = Repo.one(
      from u in User,
        join: gs in GameStat, on: gs.user_id == u.id,
        where: u.inserted_at >= ^date_range.from and
               u.inserted_at <= ^date_range.to and
               gs.last_played_at >= ^date_range.from,
        select: count(u.id, :distinct)
    )

    # 4. VIP (top 5% par mises)
    vip_threshold = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        select: fragment("percentile_cont(0.95) within group (order by ?)", gs.total_wagered)
    ) || 0

    vip_count = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^date_range.from and
               gs.last_played_at <= ^date_range.to,
        having: sum(gs.total_wagered) > ^vip_threshold,
        select: count(gs.user_id, :distinct)
    ) || 0

    # Taux de conversion par etape
    reg = max(registered || 0, 1)
    stages = [
      %{stage: "registered", label: "Inscrits", count: registered || 0, rate: 100.0},
      %{stage: "depositors", label: "Deposants", count: depositors || 0,
        rate: Float.round((depositors || 0) / reg * 100, 1)},
      %{stage: "players", label: "Joueurs actifs", count: players || 0,
        rate: Float.round((players || 0) / reg * 100, 1)},
      %{stage: "vip", label: "VIP", count: vip_count,
        rate: Float.round(vip_count / reg * 100, 1)}
    ]

    %{
      period: period_or_range,
      stages: stages,
      overall_conversion: Float.round(vip_count / reg * 100, 2)
    }
  end

  # ========================================
  # Helpers
  # ========================================

  defp resolve_date_range(%{from: _, to: _} = range), do: range
  defp resolve_date_range(period) do
    now = DateTime.utc_now()
    from = case period do
      "24h" -> DateTime.add(now, -24 * 3600, :second)
      "7d"  -> DateTime.add(now, -7 * 24 * 3600, :second)
      "30d" -> DateTime.add(now, -30 * 24 * 3600, :second)
      "90d" -> DateTime.add(now, -90 * 24 * 3600, :second)
      _     -> DateTime.add(now, -7 * 24 * 3600, :second)
    end
    %{from: from, to: now}
  end

  defp previous_period(date_range) do
    diff = DateTime.diff(date_range.to, date_range.from, :second)
    %{
      from: DateTime.add(date_range.from, -diff, :second),
      to: date_range.from
    }
  end

  defp aggregate_amount(date_range, type) do
    result = Repo.one(
      from t in WalletTransaction,
        where: t.type == ^type and
               t.inserted_at >= ^date_range.from and
               t.inserted_at <= ^date_range.to,
        select: %{
          total: type(coalesce(sum(t.amount), 0), :integer),
          count: count(t.id),
          avg: coalesce(avg(t.amount), 0) |> type(:integer)
        }
    ) || %{total: 0, count: 0, avg: 0}

    %{total: result.total, count: result.count, avg: result.avg}
  end

  defp count_active_users(date_range) do
    Repo.one(
      from u in User,
        where: u.last_login_at >= ^date_range.from and
               u.last_login_at <= ^date_range.to,
        select: count(u.id)
    ) || 1
  end

  defp count_paying_users(date_range) do
    Repo.one(
      from t in WalletTransaction,
        where: t.type == "deposit" and
               t.inserted_at >= ^date_range.from and
               t.inserted_at <= ^date_range.to,
        select: count(t.user_id, :distinct)
    ) || 1
  end

  defp count_users_logged_in_since(since) do
    Repo.one(
      from u in User,
        where: u.last_login_at >= ^since,
        select: count(u.id)
    ) || 0
  end

  defp compute_delta(current, previous) do
    if previous > 0 do
      Float.round((current - previous) / previous * 100, 1)
    else
      if current > 0, do: 100.0, else: 0.0
    end
  end

  defp determine_interval(date_range) do
    diff = DateTime.diff(date_range.to, date_range.from, :hour)
    cond do
      diff <= 24 -> "hour"
      diff <= 168 -> "day"
      true -> "day"
    end
  end

  defp merge_timeseries(series_list, keys) do
    all_timestamps = series_list
    |> List.flatten()
    |> Enum.map(& &1.timestamp)
    |> Enum.uniq()
    |> Enum.sort()

    Enum.map(all_timestamps, fn ts ->
      point = %{"timestamp" => ts}
      Enum.reduce(Enum.with_index(series_list), point, fn {series, idx}, acc ->
        key = Enum.at(keys, idx)
        value = Enum.find(series, fn s -> s.timestamp == ts end)
        Map.put(acc, key, if(value, do: Map.get(value, Map.keys(value) |> Enum.find(fn k -> k != :timestamp end), 0), else: 0))
      end)
    end)
  end

  defp safe_avg([]), do: 0.0
  defp safe_avg(values) do
    clean = values |> Enum.reject(&is_nil/1) |> Enum.map(fn v -> if is_struct(v, Decimal), do: Decimal.to_float(v), else: v end)
    case clean do
      [] -> 0.0
      xs -> Enum.sum(xs) / length(xs)
    end
  end
end
