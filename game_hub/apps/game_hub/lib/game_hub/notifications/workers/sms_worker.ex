# ==================================
# WIWIGA - Worker Oban SMS
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.SmsWorker

defmodule GameHub.Notifications.Workers.SmsWorker do
  @moduledoc """
  Worker d'envoi SMS (queue `notifications_sms`).

  Args : `%{"notification_id" => id, "to" => msisdn}`.
  Failover providers au moment de l'exécution (config fraîche DB).
  """

  use Oban.Worker, queue: :notifications_sms, max_attempts: 8

  alias GameHub.Notifications
  alias GameHub.Notifications.ChannelDispatch

  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"notification_id" => notification_id, "to" => to}} = job) do
    case Notifications.get_channel_delivery(notification_id, "sms") do
      nil ->
        {:cancel, :delivery_not_found}

      %{status: status} when status in ["cancelled", "sent", "delivered"] ->
        {:cancel, {:already_final, status}}

      delivery ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        Notifications.update_delivery(delivery, %{status: "processing", attempt_number: job.attempt})

        notification = Notifications.get_notification(notification_id)
        body = sms_body(notification)
        category = if notification, do: notification.category, else: "transactional"

        case ChannelDispatch.send_sms(to, body, category) do
          {:ok, provider, message_id} ->
            Notifications.update_delivery(delivery, %{
              status: "sent",
              provider_id: provider.id,
              provider_name: provider.name,
              provider_message_id: message_id,
              sent_at: now,
              error_message: nil
            })

            :ok

          {:retryable, reason} ->
            Notifications.update_delivery(delivery, %{status: "retrying", error_message: truncate(reason)})
            maybe_snooze(reason)

          {:permanent, reason} ->
            Notifications.update_delivery(delivery, %{status: "failed", error_message: truncate(reason)})
            {:cancel, truncate(reason)}
        end
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :missing_args}

  # Rendu via le template SMS actif (repli : corps in_app stocké).
  defp sms_body(nil), do: ""

  defp sms_body(notification) do
    locale = Notifications.user_locale(notification.user_id)

    case Notifications.render_for_channel(notification.event_type, "sms", notification.variables || %{}, locale) do
      {:ok, _title, sms_body} -> sms_body
      {:error, _} -> notification.body
    end
  end

  # 429 provider → snooze (délai Retry-After honoré), sinon backoff Oban.
  defp maybe_snooze(reason) do
    GameHub.Notifications.WorkerRetry.snooze_or_raise(reason, true)
  end

  defp truncate(reason), do: reason |> inspect() |> String.slice(0, 500)
end
