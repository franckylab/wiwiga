# ==================================
# WIWIGA - Caps anti-spam notifications (Redis)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.RateLimit
# Description: Quotas journaliers par utilisateur×canal + débit
  #              par provider. Fail-open si Redis indisponible
  #              (aucun blocage en cas de panne Redis).

defmodule GameHub.Notifications.RateLimit do
  @moduledoc """
  Garde-fous anti-spam et anti-runaway-coûts (SMS facturés).

  ## Quotas utilisateur (par jour calendaire UTC)
  Config `config :game_hub, :notification_caps` :
      %{sms: 10, email: 20, push: 50}
  `in_app` illimité (gratuit, local), `security` exemptée
  (déjà rate-limitée côté Auth).

  ## Débit provider (par minute glissante)
  `rate_limit_per_min` du provider. Dépassé → `:limited`
  (le worker snooze/retry au lieu d'envoyer).
  """

  @default_caps %{sms: 10, email: 20, push: 50}

  @doc """
  Vérifie et consomme 1 unité du quota user×canal.
  Retourne `:ok` ou `{:error, :capped}`.
  """
  @spec check_user(integer(), String.t(), String.t()) :: :ok | {:error, :capped}
  def check_user(_user_id, "in_app", _category), do: :ok
  def check_user(_user_id, _channel, "security"), do: :ok

  def check_user(user_id, channel, _category) do
    limit = user_limit(channel)

    if limit == :unlimited do
      :ok
    else
      day = Date.utc_today() |> Date.to_iso8601()
      key = "notif_cap:#{user_id}:#{channel}:#{day}"

      case Redix.command(GameHub.Redis, ["INCR", key]) do
        {:ok, 1} ->
          Redix.command(GameHub.Redis, ["EXPIRE", key, "172800"])
          :ok

        {:ok, count} when is_integer(count) ->
          if count <= limit, do: :ok, else: {:error, :capped}

        _ ->
          :ok
      end
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @doc """
  Vérifie le débit minute d'un provider.
  Retourne `:ok` ou `{:error, :limited}`.
  """
  @spec check_provider(integer(), integer()) :: :ok | {:error, :limited}
  def check_provider(provider_id, limit_per_min) when is_integer(limit_per_min) and limit_per_min > 0 do
    minute = div(System.system_time(:second), 60)
    key = "notif_rate:#{provider_id}:#{minute}"

    case Redix.command(GameHub.Redis, ["INCR", key]) do
      {:ok, 1} ->
        Redix.command(GameHub.Redis, ["EXPIRE", key, "120"])
        :ok

      {:ok, count} when is_integer(count) ->
        if count <= limit_per_min, do: :ok, else: {:error, :limited}

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  def check_provider(_, _), do: :ok

  @doc """
  Quota journalier configuré pour un canal (`:unlimited` si absent).
  """
  @spec user_limit(String.t()) :: non_neg_integer() | :unlimited
  def user_limit(channel) do
    caps = Application.get_env(:game_hub, :notification_caps, @default_caps)
    Map.get(caps, String.to_atom(channel), :unlimited)
  rescue
    _ -> :unlimited
  end
end
