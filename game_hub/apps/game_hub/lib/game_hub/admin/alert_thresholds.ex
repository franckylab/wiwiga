# ==================================
# WIWIGA - GenServer Alert Thresholds Monitoring
# ==================================
# Module: GameHub.Admin.AlertThresholds
# Description: Monitoring automatique avec seuils configurables
#              Vérifie périodiquement les métriques critiques

defmodule GameHub.Admin.AlertThresholds do
  @moduledoc """
  GenServer de monitoring automatique.
  
  Vérifie toutes les 60 secondes les seuils configurés :
  - Auth échouées (count sur 1h)
  - Latence DB (ms)
  - Solde plateforme (FCFA minimum)
  - Erreurs paiement (count sur 1h)
  - Parties actives anormales
  
  Les seuils sont configurables en DB (table `alert_thresholds`).
  """

  use GenServer
  require Logger

  alias GameHub.Repo
  alias GameHub.Admin.Alerts
  alias GameHub.Admin.Metrics
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @check_interval_ms 60_000  # 60 secondes

  # ========================================
  # API publique
  # ========================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Force une vérification immédiate des seuils."
  def check_now do
    GenServer.cast(__MODULE__, :check)
  end

  @doc "Liste les seuils configurés."
  def list_thresholds do
    Repo.all(
      from t in "alert_thresholds",
        where: t.is_enabled == true,
        order_by: [asc: t.metric_key]
    )
  end

  @doc "Met à jour un seuil."
  def update_threshold(id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    set_values = Map.merge(attrs, %{"updated_at" => now})

    query = from t in "alert_thresholds",
      where: t.id == ^id,
      select: t,
      update: [set: ^set_values]

    {count, results} = Repo.update_all(query, [])

    case {count, results} do
      {1, [threshold]} -> {:ok, threshold}
      _ -> {:error, :not_found}
    end
  end

  # ========================================
  # GenServer callbacks
  # ========================================

  @impl true
  def init(_opts) do
    # Initialiser le cache métriques
    Metrics.init_cache()

    # Planifier la première vérification
    schedule_check()

    Logger.info("[AlertThresholds] Monitoring démarré (check toutes les #{@check_interval_ms}ms)")
    {:ok, %{last_check: nil, checks_count: 0}}
  end

  @impl true
  def handle_cast(:check, state) do
    new_state = perform_check(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:periodic_check, state) do
    new_state = perform_check(state)
    schedule_check()
    {:noreply, new_state}
  end

  # ========================================
  # Vérifications
  # ========================================

  defp perform_check(state) do
    thresholds = safe_list_thresholds()

    Enum.each(thresholds, fn threshold ->
      check_threshold(threshold)
    end)

    # Vérifications par défaut si pas de seuils configurés
    if Enum.empty?(thresholds) do
      run_default_checks()
    end

    %{
      state
      | last_check: DateTime.utc_now(),
        checks_count: state.checks_count + 1
    }
  rescue
    error ->
      Logger.error("[AlertThresholds] Erreur vérification: #{inspect(error)}")
      %{state | last_check: DateTime.utc_now()}
  end

  defp check_threshold(threshold) do
    current_value = get_metric_value(threshold.metric_key)

    if current_value != nil and exceeds_threshold?(current_value, threshold) do
      Alerts.create_alert(%{
        alert_type: determine_alert_type(threshold.metric_key),
        severity: threshold.severity || "warning",
        title: "Seil dépassé: #{threshold.name || threshold.metric_key}",
        message: "#{threshold.metric_key} = #{current_value} (seuil: #{threshold.threshold_value} #{threshold.comparison})",
        metadata: %{
          "metric_key" => threshold.metric_key,
          "current_value" => current_value,
          "threshold_value" => threshold.threshold_value,
          "comparison" => threshold.comparison
        }
      })
    end
  rescue
    error ->
      Logger.warning("[AlertThresholds] Erreur sur seuil #{threshold.metric_key}: #{inspect(error)}")
  end

  defp run_default_checks do
    # Vérification auth échouées (seuil par défaut: 10 en 1h)
    Alerts.check_thresholds()

    # Vérifier solde plateforme
    check_platform_balance()

    # Vérifier erreurs paiement
    check_payment_errors()

    # Vérifier parties actives
    check_active_games()
  end

  defp check_platform_balance do
    total_balance = Repo.one(
      from u in "users",
        select: coalesce(sum(u.balance), 0)
    )

    # Alerte si solde total > 100M centimes (1M FCFA)
    if total_balance > 100_000_000 do
      Alerts.create_alert(%{
        alert_type: "financial",
        severity: "info",
        title: "Solde plateforme élevé",
        message: "Solde total: #{div(total_balance, 100)} FCFA",
        metadata: %{"total_balance" => total_balance}
      })
    end
  rescue
    _ -> :ok
  end

  defp check_payment_errors do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    count = Repo.one(
      from a in AuditLog,
        where: a.action == "payment_failed" and
               a.inserted_at >= ^one_hour_ago,
        select: count(a.id)
    )

    if count >= 5 do
      Alerts.create_alert(%{
        alert_type: "payment",
        severity: "warning",
        title: "Erreurs paiement élevées",
        message: "#{count} erreurs de paiement détectées dans la dernière heure",
        metadata: %{"error_count" => count, "period" => "1h"}
      })
    end
  rescue
    _ -> :ok
  end

  defp check_active_games do
    summary = Metrics.get_dashboard_summary()
    active_games = Map.get(summary, :active_games, 0)

    # Alerte si > 500 parties simultanées
    if active_games > 500 do
      Alerts.create_alert(%{
        alert_type: "game",
        severity: "warning",
        title: "Activité jeux élevée",
        message: "#{active_games} parties actives simultanément",
        metadata: %{"active_games" => active_games}
      })
    end
  rescue
    _ -> :ok
  end

  # ========================================
  # Helpers
  # ========================================

  defp schedule_check do
    Process.send_after(self(), :periodic_check, @check_interval_ms)
  end

  defp safe_list_thresholds do
    list_thresholds()
  rescue
    _ -> []
  end

  defp get_metric_value("failed_auths_1h") do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)
    Repo.one(
      from a in AuditLog,
        where: a.action == "password_login_failed" and a.inserted_at >= ^one_hour_ago,
        select: count(a.id)
    )
  end

  defp get_metric_value("db_latency_ms") do
    start_time = System.monotonic_time(:millisecond)
    try do
      Repo.query!("SELECT 1")
      System.monotonic_time(:millisecond) - start_time
    rescue
      _ -> 9999
    end
  end

  defp get_metric_value("platform_balance") do
    Repo.one(from u in "users", select: coalesce(sum(u.balance), 0))
  end

  defp get_metric_value("payment_errors_1h") do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)
    Repo.one(
      from a in AuditLog,
        where: a.action == "payment_failed" and a.inserted_at >= ^one_hour_ago,
        select: count(a.id)
    )
  end

  defp get_metric_value("active_games") do
    summary = Metrics.get_dashboard_summary()
    Map.get(summary, :active_games, 0)
  end

  defp get_metric_value(_), do: nil

  defp exceeds_threshold?(value, %{comparison: "gt", threshold_value: threshold}) do
    value > threshold
  end

  defp exceeds_threshold?(value, %{comparison: "lt", threshold_value: threshold}) do
    value < threshold
  end

  defp exceeds_threshold?(value, %{comparison: "gte", threshold_value: threshold}) do
    value >= threshold
  end

  defp exceeds_threshold?(value, %{comparison: "lte", threshold_value: threshold}) do
    value <= threshold
  end

  defp exceeds_threshold?(value, %{comparison: "eq", threshold_value: threshold}) do
    value == threshold
  end

  defp exceeds_threshold?(_, _), do: false

  defp determine_alert_type(key) do
    cond do
      String.contains?(key, "auth") -> "security"
      String.contains?(key, "payment") -> "payment"
      String.contains?(key, "balance") -> "financial"
      String.contains?(key, "game") -> "game"
      String.contains?(key, "latency") || String.contains?(key, "db") -> "system"
      true -> "system"
    end
  end
end
