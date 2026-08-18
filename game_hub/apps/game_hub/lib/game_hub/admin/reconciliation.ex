# ==================================
# WIWIGA - Module Admin Reconciliation
# ==================================
# Module: GameHub.Admin.Reconciliation
# Description: Réconciliation financière - détection écarts, rapports

defmodule GameHub.Admin.Reconciliation do
  @moduledoc """
  Module de réconciliation financière.
  
  Fonctionnalités:
  - Résumé journalier (dépôts, retraits, mises, gains, commissions)
  - Détection des écarts entre transactions wallet et résultats de jeu
  - Rapport commissions par période et type de jeu
  - Solde total plateforme vs engagements joueurs
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.GameStats.GameStat
  import Ecto.Query

  # Helpers de conversion Decimal → integer
  defp to_int(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d))
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: round(v)
  defp to_int(_), do: 0

  # ========================================
  # Résumé journalier
  # ========================================

  @doc """
  Résumé financier journalier.
  """
  @spec get_daily_summary(Date.t() | String.t()) :: map()
  def get_daily_summary(date \\ nil) do
    date = parse_date(date)
    {start_dt, end_dt} = day_bounds(date)

    deposits = aggregate_day(start_dt, end_dt, "deposit")
    withdrawals = aggregate_day(start_dt, end_dt, "withdrawal")
    bets = aggregate_day(start_dt, end_dt, "bet")
    winnings = aggregate_day(start_dt, end_dt, "winnings")
    commissions = aggregate_day(start_dt, end_dt, "commission")

    # Convertir les montants Decimal en integer avant arithmétique
    dep_amt = to_int(deposits.total_amount)
    wth_amt = to_int(withdrawals.total_amount)
    bet_amt = to_int(bets.total_amount)
    win_amt = to_int(winnings.total_amount)
    com_amt = to_int(commissions.total_amount)

    # GGR = mises - gains
    ggr = bet_amt - win_amt

    # Revenue net = commissions + GGR estimé
    net_revenue = com_amt + max(ggr, 0)

    %{
      date: Date.to_iso8601(date),
      deposits: %{amount: dep_amt, count: deposits.count},
      withdrawals: %{amount: wth_amt, count: withdrawals.count},
      bets: %{amount: bet_amt, count: bets.count},
      winnings: %{amount: win_amt, count: winnings.count},
      commissions: %{amount: com_amt, count: commissions.count},
      ggr: ggr,
      net_revenue: net_revenue,
      net_flow: dep_amt - wth_amt
    }
  end

  # ========================================
  # Détection des écarts
  # ========================================

  @doc """
  Détecte les écarts entre transactions wallet et résultats de jeu.
  """
  @spec detect_discrepancies(String.t()) :: list(map())
  def detect_discrepancies(period \\ "24h") do
    {start_dt, end_dt} = resolve_period(period)
    discrepancies = []

    # 1. Vérifier: total bets vs total wagered dans game_stats
    wallet_bets = Repo.one(
      from t in WalletTransaction,
        where: t.type == "bet" and
               t.inserted_at >= ^start_dt and
               t.inserted_at <= ^end_dt,
        select: %{total: coalesce(sum(t.amount), 0) |> type(:decimal), count: count(t.id)}
    ) || %{total: Decimal.new(0), count: 0}

    game_wagered = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^start_dt and
               gs.last_played_at <= ^end_dt,
        select: %{total: coalesce(sum(gs.total_wagered), 0) |> type(:decimal), count: coalesce(sum(gs.matches_played), 0)}
    ) || %{total: Decimal.new(0), count: 0}

    wb_total = to_int(wallet_bets.total)
    gw_total = to_int(game_wagered.total)

    discrepancies = if abs(wb_total - gw_total) > 100 do
      discrepancies ++ [%{
        type: "bet_mismatch",
        severity: if(abs(wb_total - gw_total) > 10000, do: "critical", else: "warning"),
        description: "Écart entre mises wallet (#{wb_total}) et game_stats (#{gw_total})",
        wallet_value: wb_total,
        game_value: gw_total,
        difference: wb_total - gw_total
      }]
    else
      discrepancies
    end

    # 2. Vérifier: total winnings vs total_won dans game_stats
    wallet_wins = Repo.one(
      from t in WalletTransaction,
        where: t.type == "winnings" and
               t.inserted_at >= ^start_dt and
               t.inserted_at <= ^end_dt,
        select: %{total: coalesce(sum(t.amount), 0) |> type(:decimal), count: count(t.id)}
    ) || %{total: Decimal.new(0), count: 0}

    game_won = Repo.one(
      from gs in GameStat,
        where: gs.last_played_at >= ^start_dt and
               gs.last_played_at <= ^end_dt,
        select: %{total: coalesce(sum(gs.total_won_net), 0) |> type(:decimal)}
    ) || %{total: Decimal.new(0)}

    ww_total = to_int(wallet_wins.total)
    gwon_total = to_int(game_won.total)

    discrepancies = if abs(ww_total - gwon_total) > 100 do
      discrepancies ++ [%{
        type: "winnings_mismatch",
        severity: if(abs(ww_total - gwon_total) > 10000, do: "critical", else: "warning"),
        description: "Écart entre gains wallet (#{ww_total}) et game_stats (#{gwon_total})",
        wallet_value: ww_total,
        game_value: gwon_total,
        difference: ww_total - gwon_total
      }]
    else
      discrepancies
    end

    discrepancies
  end

  # ========================================
  # Rapport commissions
  # ========================================

  @doc """
  Rapport des commissions par période.
  """
  @spec get_commission_report(String.t(), String.t() | nil) :: map()
  def get_commission_report(period \\ "30d", game_type \\ nil) do
    {start_dt, end_dt} = resolve_period(period)

    # Commissions par type de transaction
    commissions_by_type = Repo.all(
      from t in WalletTransaction,
        where: t.type == "commission" and
               t.inserted_at >= ^start_dt and
               t.inserted_at <= ^end_dt,
        group_by: t.type,
        select: %{
          type: t.type,
          total: sum(t.amount) |> type(:decimal),
          count: count(t.id)
        }
    )

    # Commissions estimées par type de jeu (5% des mises)
    commissions_by_game = if game_type do
      Repo.all(
        from gs in GameStat,
          where: gs.game_type == ^game_type and
                 gs.last_played_at >= ^start_dt and
                 gs.last_played_at <= ^end_dt,
          select: %{
            game_type: gs.game_type,
            estimated_commission: fragment("? * 0.05", sum(gs.total_wagered)) |> type(:decimal),
            total_wagered: sum(gs.total_wagered) |> type(:decimal),
            matches: sum(gs.matches_played)
          }
      )
    else
      Repo.all(
        from gs in GameStat,
          where: gs.last_played_at >= ^start_dt and
                 gs.last_played_at <= ^end_dt,
          group_by: gs.game_type,
          select: %{
            game_type: gs.game_type,
            estimated_commission: fragment("? * 0.05", sum(gs.total_wagered)) |> type(:decimal),
            total_wagered: sum(gs.total_wagered) |> type(:decimal),
            matches: sum(gs.matches_played)
          }
      )
    end

    total_commission = Enum.reduce(commissions_by_type, 0, fn c, acc -> acc + to_int(c.total) end)
    total_estimated = Enum.reduce(commissions_by_game, 0, fn g, acc -> acc + to_int(g.estimated_commission) end)

    %{
      period: period,
      game_type: game_type,
      from: start_dt,
      to: end_dt,
      total_commission: total_commission,
      total_estimated: total_estimated,
      by_type: commissions_by_type,
      by_game: commissions_by_game,
      discrepancy: total_commission - total_estimated
    }
  end

  # ========================================
  # Solde plateforme
  # ========================================

  @doc """
  Solde total plateforme vs engagements joueurs.
  """
  @spec get_platform_balance() :: map()
  def get_platform_balance do
    # Total FCFA détenus par les joueurs
    total_player_balance = to_int(Repo.one(
      from u in User,
        select: coalesce(sum(u.balance), 0) |> type(:decimal)
    ))

    # Total tokens détenus par les joueurs
    total_token_balance = to_int(Repo.one(
      from u in User,
        select: coalesce(sum(u.token_balance), 0) |> type(:decimal)
    ))

    # Total dépôts (tout temps)
    total_deposits = to_int(Repo.one(
      from t in WalletTransaction,
        where: t.type == "deposit",
        select: coalesce(sum(t.amount), 0) |> type(:decimal)
    ))

    # Total retraits (tout temps)
    total_withdrawals = to_int(Repo.one(
      from t in WalletTransaction,
        where: t.type == "withdrawal",
        select: coalesce(sum(fragment("abs(?)", t.amount)), 0) |> type(:decimal)
    ))

    # Flux net entrant
    net_flow = total_deposits - total_withdrawals

    # Engagements = ce que la plateforme doit aux joueurs
    total_engagement = total_player_balance

    # Réserve théorique = flux net - engagement
    reserve = net_flow - total_engagement

    %{
      total_player_balance: total_player_balance,
      total_token_balance: total_token_balance,
      total_deposits: total_deposits,
      total_withdrawals: total_withdrawals,
      net_flow: net_flow,
      total_engagement: total_engagement,
      reserve: reserve,
      reserve_ratio: if(total_engagement > 0, do: Float.round(reserve / total_engagement * 100, 1), else: 100.0)
    }
  end

  # ========================================
  # Helpers
  # ========================================

  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(%Date{} = d), do: d
  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
  end

  defp day_bounds(date) do
    start_dt = DateTime.new!(date, ~T[00:00:00.000])
    end_dt = DateTime.new!(date, ~T[23:59:59.999])
    {start_dt, end_dt}
  end

  defp resolve_period(period) do
    now = DateTime.utc_now()
    start_dt = case period do
      "24h" -> DateTime.add(now, -24 * 3600, :second)
      "7d"  -> DateTime.add(now, -7 * 24 * 3600, :second)
      "30d" -> DateTime.add(now, -30 * 24 * 3600, :second)
      _     -> DateTime.add(now, -24 * 3600, :second)
    end
    {start_dt, now}
  end

  defp aggregate_day(start_dt, end_dt, type) do
    Repo.one(
      from t in WalletTransaction,
        where: t.type == ^type and
               t.inserted_at >= ^start_dt and
               t.inserted_at <= ^end_dt,
        select: %{total_amount: coalesce(sum(t.amount), 0), count: count(t.id)}
    ) || %{total_amount: 0, count: 0}
  end
end
