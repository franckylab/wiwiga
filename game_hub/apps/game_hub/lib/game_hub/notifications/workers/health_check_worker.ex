# ==================================
# WIWIGA - Worker santé périodique providers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.HealthCheckWorker

defmodule GameHub.Notifications.Workers.HealthCheckWorker do
  @moduledoc """
  Vérifie la santé d'un provider SANS envoyer de message.

  Args : `%{"provider_id" => id}`. Planifié par
  `HealthCheckSchedulerWorker` (cron 6h), lançable à la demande.
  """

  use Oban.Worker, queue: :notifications_sms, max_attempts: 2

  alias GameHub.Notifications

  @impl true
  def perform(%Oban.Job{args: %{"provider_id" => provider_id}}) do
    case Notifications.check_provider_health(provider_id) do
      {:ok, _} -> :ok
      {:error, :not_found} -> {:cancel, :not_found}
      {:error, :provider_inactive} -> {:cancel, :provider_inactive}
      {:error, reason} -> {:cancel, inspect(reason) |> String.slice(0, 200)}
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :missing_args}
end
