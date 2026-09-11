# ==================================
# WIWIGA - Planificateur santé providers (cron)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.HealthCheckSchedulerWorker

defmodule GameHub.Notifications.Workers.HealthCheckSchedulerWorker do
  @moduledoc """
  Planifie un health-check par provider actif supporté (cron 6h).

  Args : `%{}`. Les adapters sans `check_health/1` sont ignorés
  (badge `unchecked`, vérification manuelle via Tester).
  """

  use Oban.Worker, queue: :notifications_sms, max_attempts: 2

  alias GameHub.Notifications
  alias GameHub.Notifications.Adapters
  alias GameHub.Notifications.Workers.HealthCheckWorker

  @impl true
  def perform(%Oban.Job{}) do
    Notifications.list_providers(%{"is_active" => "true"})
    |> Enum.filter(fn provider ->
      case Adapters.for_provider(provider.channel, provider.name) do
        {:ok, adapter} -> function_exported?(adapter, :check_health, 1)
        _ -> false
      end
    end)
    |> Enum.each(fn provider ->
      %{provider_id: provider.id}
      |> HealthCheckWorker.new(queue: :notifications_sms)
      |> Oban.insert()
    end)

    :ok
  end
end
