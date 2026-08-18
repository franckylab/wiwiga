# ==================================
# WIWIGA - Admin Analytics Controller
# ==================================
# Endpoints: Revenue, Players, Cohorts, LTV, Games, Monetary Flow, Wealth, Funnel

defmodule GameHubWeb.AdminAnalyticsController do
  use GameHubWeb, :controller

  alias GameHub.Admin.Analytics

  def revenue(conn, params) do
    period = Map.get(params, "period", "7d")
    data = Analytics.get_revenue_analytics(period)
    json(conn, %{data: data})
  end

  def players(conn, params) do
    period = Map.get(params, "period", "30d")
    data = Analytics.get_player_analytics(period)
    json(conn, %{data: data})
  end

  def cohorts(conn, _params) do
    data = Analytics.get_retention_cohorts(90)
    json(conn, %{data: data})
  end

  def ltv(conn, params) do
    period = Map.get(params, "period", "all")
    data = Analytics.get_ltv_estimate(period)
    json(conn, %{data: data})
  end

  def games(conn, params) do
    period = Map.get(params, "period", "7d")
    data = Analytics.get_game_performance(period)
    json(conn, %{data: data})
  end

  def monetary_flow(conn, params) do
    period = Map.get(params, "period", "7d")
    data = Analytics.get_monetary_flow(period)
    json(conn, %{data: data})
  end

  def wealth_distribution(conn, params) do
    period = Map.get(params, "period", "30d")
    data = Analytics.get_player_wealth_distribution(period)
    json(conn, %{data: data})
  end

  def conversion_funnel(conn, params) do
    period = Map.get(params, "period", "30d")
    data = Analytics.get_conversion_funnel(period)
    json(conn, %{data: data})
  end
end
