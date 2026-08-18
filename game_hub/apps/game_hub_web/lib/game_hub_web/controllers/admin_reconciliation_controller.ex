# ==================================
# WIWIGA - Controller Admin Reconciliation
# ==================================
# Module: GameHubWeb.AdminReconciliationController
# Description: Endpoints réconciliation financière

defmodule GameHubWeb.AdminReconciliationController do
  @moduledoc """
  Controller pour la réconciliation financière.
  
  ## Endpoints
    GET /api/admin/reconciliation/daily?date=...
    GET /api/admin/reconciliation/discrepancies?period=...
    GET /api/admin/reconciliation/commissions?period=...&game_type=...
    GET /api/admin/reconciliation/balance
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Reconciliation

  @doc """
  GET /api/admin/reconciliation/daily
  Résumé journalier.
  """
  def daily(conn, params) do
    date = Map.get(params, "date")
    summary = Reconciliation.get_daily_summary(date)

    conn
    |> put_status(200)
    |> json(%{success: true, data: summary})
  end

  @doc """
  GET /api/admin/reconciliation/discrepancies
  Écarts détectés.
  """
  def discrepancies(conn, params) do
    period = Map.get(params, "period", "24h")
    discrepancies = Reconciliation.detect_discrepancies(period)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        period: period,
        discrepancies: discrepancies,
        count: length(discrepancies),
        has_issues: length(discrepancies) > 0
      }
    })
  end

  @doc """
  GET /api/admin/reconciliation/commissions
  Rapport commissions.
  """
  def commissions(conn, params) do
    period = Map.get(params, "period", "30d")
    game_type = Map.get(params, "game_type")

    report = Reconciliation.get_commission_report(period, game_type)

    conn
    |> put_status(200)
    |> json(%{success: true, data: report})
  end

  @doc """
  GET /api/admin/reconciliation/balance
  Solde plateforme.
  """
  def balance(conn, _params) do
    balance = Reconciliation.get_platform_balance()

    conn
    |> put_status(200)
    |> json(%{success: true, data: balance})
  end
end
