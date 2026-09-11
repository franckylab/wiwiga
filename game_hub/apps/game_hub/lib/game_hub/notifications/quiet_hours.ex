# ==================================
# WIWIGA - Heures creuses (marché Cameroun, UTC+1 fixe, sans DST)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.QuietHours

defmodule GameHub.Notifications.QuietHours do
  @moduledoc """
  Report des envois marketing la nuit (22h–7h heure de Douala).

  Le Cameroun est à UTC+1 toute l'année (pas de DST) : la fenêtre creuse
  locale 22h–7h correspond à 21h–6h UTC en dur. Seul le marketing est
  reporté ; urgent/high passent toujours.
  """

  @doc """
  Secondes à attendre avant un envoi (0 = envoyer maintenant).
  `now_utc` injectable pour les tests.
  """
  @spec defer_seconds(String.t(), String.t(), DateTime.t()) :: non_neg_integer()
  def defer_seconds(category, priority, now_utc \\ DateTime.utc_now())

  def defer_seconds("marketing", priority, now_utc) when priority not in ["urgent", "high"] do
    # Fenêtre creuse locale 22h–7h = 21h–6h UTC (décalage fixe, pas de DST)
    if now_utc.hour >= 21 or now_utc.hour < 6 do
      midnight = %{now_utc | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
      six_today = DateTime.add(midnight, 6 * 3600, :second)

      target =
        if DateTime.compare(now_utc, six_today) == :lt do
          six_today
        else
          DateTime.add(six_today, 24 * 3600, :second)
        end

      max(0, DateTime.diff(target, now_utc, :second))
    else
      0
    end
  end

  def defer_seconds(_, _, _), do: 0

  @doc """
  Report personnalisé d'un utilisateur (préférences `quiet_hours`).
  S'applique au marketing/social/jeu sur push/sms/email (jamais in_app
  silencieux, jamais sécurité/transactionnel). Retourne les secondes
  d'attente (0 = maintenant). `now_utc` injectable pour les tests.
  """
  @spec user_defer(integer(), String.t(), DateTime.t()) :: non_neg_integer()
  def user_defer(user_id, category, now_utc \\ DateTime.utc_now())

  def user_defer(user_id, category, now_utc) when category in ["marketing", "social", "game"] do
    case GameHub.Repo.get(GameHub.Users.User, user_id) do
      %{preferences: %{"quiet_hours" => %{"enabled" => true, "start" => start, "end" => finish}}} ->
        maybe_defer(now_utc, start, finish)

      %{preferences: %{quiet_hours: %{enabled: true, start: start, end: finish}}} ->
        maybe_defer(now_utc, start, finish)

      _ ->
        0
    end
  rescue
    _ -> 0
  catch
    _, _ -> 0
  end

  def user_defer(_, _, _), do: 0

  defp maybe_defer(now_utc, start, finish) when is_integer(start) and is_integer(finish) do
    local_hour = Integer.mod(now_utc.hour + 1, 24)

    if in_window?(local_hour, start, finish) do
      seconds_until_end(now_utc, finish)
    else
      0
    end
  end

  defp maybe_defer(_, _, _), do: 0

  # Fenêtre [start, end[ modulo 24h (ex. 22h→7h).
  defp in_window?(hour, start, finish) when start <= finish, do: hour >= start and hour < finish
  defp in_window?(hour, start, finish), do: hour >= start or hour < finish

  # Secondes jusqu'à `end`h locales = (`end`-1)h UTC… converti : fin locale
  # `end`h = `end`-1h UTC (décalage +1).
  defp seconds_until_end(now_utc, finish_local) do
    finish_utc_hour = Integer.mod(finish_local - 1, 24)
    midnight = %{now_utc | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    target_today = DateTime.add(midnight, finish_utc_hour * 3600, :second)

    target =
      if DateTime.compare(now_utc, target_today) == :lt do
        target_today
      else
        DateTime.add(target_today, 24 * 3600, :second)
      end

    max(0, DateTime.diff(target, now_utc, :second))
  end
end
