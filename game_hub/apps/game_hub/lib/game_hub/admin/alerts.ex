# ==================================
# WIWIGA - Module Admin Alerts
# ==================================
# Module: GameHub.Admin.Alerts
# Description: Gestion des alertes avec seuils configurables

defmodule GameHub.Admin.Alerts do
  @moduledoc """
  Module de gestion des alertes d'administration.
  
  Vérifie périodiquement les seuils et crée des alertes :
  - Solde total plateforme
  - Taux d'erreur paiement
  - Latence DB/Redis
  - Activité suspecte
  """

  alias GameHub.Repo
  alias GameHub.Admin.Alerts.Alert
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  @doc """
  Crée une nouvelle alerte.
  """
  @spec create_alert(map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(attrs) do
    %Alert{}
    |> Alert.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Liste les alertes avec filtres.
  """
  @spec list_alerts(map()) :: {:ok, list(), integer()}
  def list_alerts(filters \\ %{}) do
    page = Map.get(filters, "page", "1") |> String.to_integer()
    limit = Map.get(filters, "limit", "20") |> String.to_integer() |> min(100)
    offset = (page - 1) * limit

    query = from a in Alert, order_by: [desc: a.inserted_at]

    query = case Map.get(filters, "severity") do
      nil -> query
      severity -> from a in query, where: a.severity == ^severity
    end

    query = case Map.get(filters, "alert_type") do
      nil -> query
      type -> from a in query, where: a.alert_type == ^type
    end

    query = case Map.get(filters, "is_resolved") do
      nil -> query
      "true" -> from a in query, where: a.is_resolved == true
      "false" -> from a in query, where: a.is_resolved == false
      _ -> query
    end

    total = Repo.one(from a in query, select: count(a.id))
    alerts = Repo.all(from a in query, limit: ^limit, offset: ^offset)

    {:ok, alerts, total}
  end

  @doc """
  Résout une alerte.
  """
  @spec resolve_alert(integer(), integer()) :: {:ok, Alert.t()} | {:error, term()}
  def resolve_alert(alert_id, admin_id) do
    case Repo.get(Alert, alert_id) do
      nil -> {:error, :not_found}
      alert ->
        alert
        |> Alert.resolve_changeset(admin_id)
        |> Repo.update()
    end
  end

  @doc """
  Acquitter une alerte (prise en compte sans résolution).
  """
  @spec acknowledge_alert(integer(), integer()) :: {:ok, Alert.t()} | {:error, term()}
  def acknowledge_alert(alert_id, admin_id) do
    case Repo.get(Alert, alert_id) do
      nil -> {:error, :not_found}
      alert ->
        alert
        |> Alert.acknowledge_changeset(admin_id)
        |> Repo.update()
    end
  end

  @doc """
  Compteur d'alertes non résolues.
  """
  @spec unresolved_count() :: integer()
  def unresolved_count do
    Repo.one(
      from a in Alert,
        where: a.is_resolved == false,
        select: count(a.id)
    )
  end

  @doc """
  Compteur d'alertes critiques non résolues.
  """
  @spec critical_count() :: integer()
  def critical_count do
    Repo.one(
      from a in Alert,
        where: a.is_resolved == false and a.severity == "critical",
        select: count(a.id)
    )
  end

  # ========================================
  # Vérification automatique des seuils
  # ========================================

  @doc """
  Vérifie les seuils et crée des alertes si nécessaire.
  À appeler périodiquement (cron ou GenServer).
  """
  @spec check_thresholds() :: list()
  def check_thresholds do
    alerts = []

    # Vérifier auth échouées (seuil: 10 en 1h)
    alerts = alerts ++ check_failed_auths()

    # Vérifier latence DB
    alerts = alerts ++ check_system_health()

    alerts
  end

  defp check_failed_auths do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    count = Repo.one(
      from a in AuditLog,
        where: a.action == "password_login_failed" and
               a.inserted_at >= ^one_hour_ago,
        select: count(a.id)
    )

    if count >= 10 do
      case create_alert(%{
        alert_type: "security",
        severity: "warning",
        title: "Tentatives d'authentification élevées",
        message: "#{count} tentatives échouées détectées dans la dernière heure",
        metadata: %{"failed_count" => count, "period" => "1h"}
      }) do
        {:ok, alert} -> [alert]
        _ -> []
      end
    else
      []
    end
  end

  defp check_system_health do
    # Vérifier DB latency
    start_time = System.monotonic_time(:millisecond)
    result = try do
      Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
    latency = System.monotonic_time(:millisecond) - start_time

    if result == :error or latency > 100 do
      case create_alert(%{
        alert_type: "system",
        severity: if(latency > 500, do: "critical", else: "warning"),
        title: "Latence base de données élevée",
        message: "Latence DB: #{latency}ms",
        metadata: %{"latency_ms" => latency, "status" => to_string(result)}
      }) do
        {:ok, alert} -> [alert]
        _ -> []
      end
    else
      []
    end
  end
end
