# ==================================
# WIWIGA - Worker Oban Broadcast admin (bulk)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Workers.BroadcastWorker
# Description: Diffusion à tous les actifs par lots insert_all
#              (2 requêtes/lot), prefs re-vérifiées, lots chaînés
#              avec délai (lissage de charge), heures creuses.

defmodule GameHub.Notifications.Workers.BroadcastWorker do
  @moduledoc """
  Worker de broadcast admin.

  Args : `%{"title", "message", "event_id", "last_id", "category"}`.
  - Exclut les opt-out (matrice prefs, re-vérifiée à chaque lot).
  - 2 requêtes par lot (insert_all notifications + deliveries).
  - Lot suivant chaîné avec délai (lissage), heures creuses marketing.
  """

  use Oban.Worker, queue: :notifications_sms, max_attempts: 3

  alias GameHub.Notifications.{Delivery, Notification, Preference, QuietHours}
  alias GameHub.Repo
  import Ecto.Query

  require Logger

  @batch_size 500
  @batch_delay_seconds 15

  @impl true
  def perform(%Oban.Job{args: %{"title" => title, "message" => message} = args}) do
    event_id = Map.get(args, "event_id", generate_event_id())
    last_id = Map.get(args, "last_id", 0)
    category = Map.get(args, "category", "transactional")

    # Heures creuses marketing : re-planifie au matin (même event_id)
    case QuietHours.defer_seconds(category, "low") do
      0 -> run_batch(title, message, event_id, last_id, category)
      seconds -> reschedule(args, seconds)
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :missing_args}

  defp run_batch(title, message, event_id, last_id, category) do
    user_ids =
      Repo.all(
        from u in GameHub.Users.User,
          left_join: p in Preference,
          on: p.user_id == u.id and p.category == ^category and p.channel == "in_app",
          where: u.id > ^last_id and u.is_active == true and (is_nil(p.id) or p.enabled == true),
          order_by: [asc: u.id],
          limit: ^@batch_size,
          select: u.id
      )

    # Timestamps natifs (schémas), sent_at UTC (deliveries).
    now_utc = DateTime.utc_now() |> DateTime.truncate(:second)
    now = DateTime.to_naive(now_utc)
    variables = %{"titre" => title, "message" => message}

    rows =
      Enum.map(user_ids, fn user_id ->
        %{
          event_type: "admin_broadcast",
          user_id: user_id,
          template_key: "admin_broadcast",
          template_version: 1,
          title: title,
          body: message,
          variables: variables,
          category: category,
          priority: "low",
          status: "sent",
          idempotency_key: idempotency_key(event_id, user_id),
          is_read: false,
          inserted_at: now,
          updated_at: now
        }
      end)

    sent =
      if rows == [] do
        0
      else
        {_, inserted} = Repo.insert_all(Notification, rows, returning: [:id])

        deliveries =
          Enum.map(inserted, fn %{id: id} ->
            %{notification_id: id, channel: "in_app", provider_name: "inbox", attempt_number: 1, status: "sent", sent_at: now_utc, inserted_at: now, updated_at: now}
          end)

        Repo.insert_all(Delivery, deliveries)

        Enum.each(Enum.zip(user_ids, inserted), fn {user_id, %{id: id}} ->
          broadcast_one(user_id, id, title, message, category)
        end)

        length(rows)
      end

    Logger.info("[Broadcast] event=#{event_id} lot après #{last_id} : #{sent} envoyées (catégorie #{category})")

    if sent > 0 do
      GameHub.Notifications.Telemetry.emit([:broadcast_batch], %{sent: sent}, %{event_id: event_id, category: category})
    end

    # Push temps réel : 1 publication topic au premier lot (si routé push).
    # L'inbox reste la source de vérité (prefs strictes).
    if last_id == 0 and sent > 0 and push_routed?(category) do
      topic = if category == "marketing", do: "promos", else: "all"

      case GameHub.Notifications.PushTopics.publish_topic(topic, title, message, %{"event_id" => event_id}) do
        {:ok, _, _} -> Logger.info("[Broadcast] event=#{event_id} push topic #{topic} publié")
        _ -> :ok
      end
    end

    case List.last(user_ids) do
      nil ->
        Logger.info("[Broadcast] event=#{event_id} terminé")
        :ok

      _last when sent < @batch_size ->
        Logger.info("[Broadcast] event=#{event_id} terminé (#{sent} au dernier lot)")
        :ok

      last ->
        %{title: title, message: message, event_id: event_id, last_id: last, category: category}
        |> __MODULE__.new(queue: :notifications_sms, priority: 5, schedule_in: @batch_delay_seconds)
        |> Oban.insert()
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp reschedule(args, seconds) do
    args
    |> __MODULE__.new(queue: :notifications_sms, priority: 5, schedule_in: seconds)
    |> Oban.insert()
    |> case do
      {:ok, _} ->
        Logger.info("[Broadcast] reporté de #{seconds}s (heures creuses)")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Push routé selon la catégorie du broadcast (défini en admin) :
  # marketing → `promo_broadcast` (topic `promos`), sinon `admin_broadcast`
  # (topic `all`). Le kill-switch `is_active: false` coupe aussi le topic.
  defp push_routed?(category) do
    event_key = if category == "marketing", do: "promo_broadcast", else: "admin_broadcast"

    case GameHub.Notifications.routing_for(event_key) do
      %{channels: channels} -> "push" in channels
      _ -> false
    end
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  defp broadcast_one(user_id, notification_id, title, body, category) do    payload = %{event: "notification_created", payload: %{id: notification_id, event_type: "admin_broadcast", title: title, body: body, category: category, priority: "low"}}

    try do
      Phoenix.PubSub.broadcast(GameHub.PubSub, "user:#{user_id}:notifications", payload)
      Phoenix.PubSub.broadcast(GameHub.PubSub, "user:#{user_id}", payload)
    rescue
      _ -> :ok
    end

    :ok
  end

  defp idempotency_key(event_id, user_id) do
    :crypto.hash(:sha256, "#{event_id}:#{user_id}:admin_broadcast:in_app") |> Base.encode16(case: :lower)
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
