# ==================================
# WIWIGA - Controller Admin Metrics
# ==================================
# Module: GameHubWeb.AdminMetricsController
# Description: Endpoints de métriques admin
#              Financier, jeux, users, paiements, sécurité

defmodule GameHubWeb.AdminMetricsController do
  @moduledoc """
  Controller pour les métriques d'administration.
  
  ## Endpoints
    GET /api/admin/metrics/dashboard   - Résumé global
    GET /api/admin/metrics/financial   - Métriques financières
    GET /api/admin/metrics/games       - Métriques jeux
    GET /api/admin/metrics/users       - Métriques utilisateurs
    GET /api/admin/metrics/payments    - Métriques paiements
    GET /api/admin/metrics/security    - Métriques sécurité
    GET /api/admin/metrics/timeseries  - Données graphiques
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Metrics
  alias GameHub.Admin.Alerts
  alias GameHub.Admin.AlertThresholds

  @doc """
  GET /api/admin/metrics/dashboard
  Résumé global pour le dashboard.
  """
  def dashboard(conn, _params) do
    summary = Metrics.get_dashboard_summary()
    unresolved_alerts = Alerts.unresolved_count()
    critical_alerts = Alerts.critical_count()

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: Map.merge(summary, %{
        unresolved_alerts: unresolved_alerts,
        critical_alerts: critical_alerts
      })
    })
  end

  @doc """
  GET /api/admin/metrics/financial
  Métriques financières avec période optionnelle.
  """
  def financial(conn, params) do
    period = parse_period(params)

    metrics = Metrics.get_financial_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  @doc """
  GET /api/admin/metrics/games
  Métriques jeux.
  """
  def games(conn, params) do
    period = parse_period(params)

    metrics = Metrics.get_game_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  @doc """
  GET /api/admin/metrics/users
  Métriques utilisateurs.
  """
  def users(conn, params) do
    period = parse_period(params)

    metrics = Metrics.get_user_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  @doc """
  GET /api/admin/metrics/payments
  Métriques paiements.
  """
  def payments(conn, params) do
    period = parse_period(params)

    metrics = Metrics.get_payment_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  @doc """
  GET /api/admin/metrics/security
  Métriques sécurité.
  """
  def security(conn, params) do
    period = parse_period(params)

    metrics = Metrics.get_security_metrics(period)

    conn
    |> put_status(200)
    |> json(%{success: true, data: metrics})
  end

  @doc """
  GET /api/admin/metrics/timeseries
  Données timeseries pour graphiques.
  Query: ?metric=deposits|withdrawals|registrations|matches&period=7d
  """
  def timeseries(conn, params) do
    metric = Map.get(params, "metric", "deposits")
    period = parse_period(params)

    data = Metrics.get_timeseries(metric, period)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        metric: metric,
        period: period,
        points: data
      }
    })
  end

  # ========================================
  # Helpers
  # ========================================

  defp parse_period(params) do
    case Map.get(params, "period") do
      "custom" ->
        %{
          from: parse_datetime(params["from"]),
          to: parse_datetime(params["to"])
        }
      period when period in ["24h", "7d", "30d"] ->
        period
      _ ->
        "24h"
    end
  end

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(dt_string) do
    case DateTime.from_iso8601(dt_string) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  # ========================================
  # Alert Thresholds
  # ========================================

  @doc """
  GET /api/admin/alert-thresholds
  Liste les seuils configurés.
  """
  def list_thresholds(conn, _params) do
    thresholds = AlertThresholds.list_thresholds()

    conn
    |> put_status(200)
    |> json(%{success: true, data: thresholds})
  end

  @doc """
  PUT /api/admin/alert-thresholds/:id
  Met à jour un seuil.
  """
  def update_threshold(conn, %{"id" => id} = params) do
    threshold_id = String.to_integer(id)
    attrs = Map.take(params, ["threshold_value", "comparison", "severity", "is_enabled", "name"])

    case AlertThresholds.update_threshold(threshold_id, attrs) do
      {:ok, threshold} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: threshold})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, error: %{code: "NOT_FOUND", message: "Seuil non trouvé"}})
    end
  end

  @doc """
  POST /api/admin/alert-thresholds/check
  Force une vérification immédiate.
  """
  def trigger_check(conn, _params) do
    AlertThresholds.check_now()

    conn
    |> put_status(200)
    |> json(%{success: true, message: "Vérification déclenchée"})
  end

  @doc """
  POST /api/admin/alerts/:id/resolve
  Résout une alerte.
  """
  def resolve_alert(conn, %{"id" => id}) do
    admin_id = case conn.assigns[:current_user] do
      %{id: aid} when is_integer(aid) -> aid
      _ ->
        case conn.assigns[:current_user_id] do
          aid when is_integer(aid) -> aid
          aid when is_binary(aid) -> case Integer.parse(aid) do {n,_} -> n; :error -> 0 end
          _ -> case conn.assigns[:current_admin] do %{id: aid} -> aid; _ -> conn.private[:current_user_id] || 0 end |> then(fn v -> if is_binary(v) do case Integer.parse(v) do {n,_} -> n; :error -> 0 end else v end end)
        end
    end

    case Alerts.resolve_alert(String.to_integer(id), admin_id) do
      {:ok, alert} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: alert})

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{success: false, error: to_string(reason)})
    end
  end
end
