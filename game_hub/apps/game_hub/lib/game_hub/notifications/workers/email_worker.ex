# ==================================
# WIWIGA - Worker Oban Email
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.EmailWorker

defmodule GameHub.Notifications.Workers.EmailWorker do
  @moduledoc """
  Worker d'envoi email (queue `notifications_email`).

  Args : `%{"notification_id" => id, "to" => email}`.
  Sujet = titre rendu de la notification.
  """

  use Oban.Worker, queue: :notifications_email, max_attempts: 8

  alias GameHub.Notifications
  alias GameHub.Notifications.ChannelDispatch

  @impl true
  def perform(%Oban.Job{args: %{"notification_id" => notification_id, "to" => to}} = job) do
    case Notifications.get_channel_delivery(notification_id, "email") do
      nil ->
        {:cancel, :delivery_not_found}

      %{status: status} when status in ["cancelled", "sent", "delivered"] ->
        {:cancel, {:already_final, status}}

      delivery ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        Notifications.update_delivery(delivery, %{status: "processing", attempt_number: job.attempt})

        case Notifications.get_notification(notification_id) do
          nil ->
            {:cancel, :notification_not_found}

          notification ->
            {subject, body} = email_content(notification)

            case ChannelDispatch.send_email(to, subject, body, category: notification.category) do
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
                GameHub.Notifications.WorkerRetry.snooze_or_raise(reason, false)

              {:permanent, reason} ->
                Notifications.update_delivery(delivery, %{status: "failed", error_message: truncate(reason)})
                {:cancel, truncate(reason)}
            end
        end
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :missing_args}

  # Rendu via le template email actif (repli : titre/corps in_app stockés).
  defp email_content(notification) do
    locale = Notifications.user_locale(notification.user_id)

    case Notifications.render_for_channel(notification.event_type, "email", notification.variables || %{}, locale) do
      {:ok, subject, body} -> {subject, body}
      {:error, _} -> {notification.title, notification.body}
    end
  end

  defp truncate(reason), do: reason |> inspect() |> String.slice(0, 500)
end
