# ==================================
# WIWIGA - Worker Oban Push
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.PushWorker

defmodule GameHub.Notifications.Workers.PushWorker do
  @moduledoc """
  Worker d'envoi push (queue `notifications_push`).

  Args : `%{"notification_id" => id}`. Tokens résolus à l'exécution.
  """

  use Oban.Worker, queue: :notifications_push, max_attempts: 8

  alias GameHub.Notifications
  alias GameHub.Notifications.ChannelDispatch

  @impl true
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}} = job) do
    case Notifications.get_channel_delivery(notification_id, "push") do
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
            data = %{"notification_id" => to_string(notification.id), "event_type" => notification.event_type}
            {title, body} = push_content(notification)

            # Broadcasts : 1 publication topic (repli per-token sinon)
            send_result =
              case GameHub.Notifications.PushTopics.publish(notification.event_type, title, body, data) do
                {:error, :no_topic_support} ->
                  ChannelDispatch.send_push(notification.user_id, title, body, data)

                other ->
                  other
              end

            case send_result do
              # Publication topic (provider struct) ou per-token (liste)
              {:ok, %_{} = provider, message_id} ->
                mark_sent(delivery, provider.name, message_id, now)

              {:ok, [{:sent, provider_name, _token, message_id} | _]} ->
                mark_sent(delivery, provider_name, message_id, now)

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

  defp mark_sent(delivery, provider_name, message_id, now) do
    Notifications.update_delivery(delivery, %{
      status: "sent",
      provider_name: provider_name,
      provider_message_id: message_id,
      sent_at: now,
      error_message: nil
    })

    :ok
  end

  # Rendu via le template push actif (repli : titre/corps in_app stockés).
  defp push_content(notification) do
    locale = Notifications.user_locale(notification.user_id)

    case Notifications.render_for_channel(notification.event_type, "push", notification.variables || %{}, locale) do
      {:ok, title, body} -> {title, body}
      {:error, _} -> {notification.title, notification.body}
    end
  end

  defp truncate(reason), do: reason |> inspect() |> String.slice(0, 500)
end
