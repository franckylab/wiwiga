# ==================================
# WIWIGA - Retry différé des workers (Retry-After)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.WorkerRetry
# Description: Extrait le délai demandé par le provider
#              ({:rate_limited, secondes}) ou applique le repli.

defmodule GameHub.Notifications.WorkerRetry do
  @moduledoc """
  Traduit une raison d'échec en `{:snooze, secondes}` ou lève pour retry
  avec backoff Oban. Plafonne à 15 minutes (un provider qui demande plus
  attendra le prochain retry de toute façon).
  """

  @max_snooze_seconds 900
  @default_snooze_seconds 120

  @doc """
  Retourne `{:snooze, secondes}`.
  - `{:rate_limited, secs}` trouvé dans la raison → ce délai (plafonné).
  - `fallback_429?` : raison contenant "429" → 120s par défaut.
  - Sinon lève (retry backoff Oban).
  """
  @spec snooze_or_raise(term(), boolean()) :: {:snooze, pos_integer()} | no_return()
  def snooze_or_raise(reason, fallback_429? \\ true) do
    case extract_seconds(reason) do
      nil ->
        if fallback_429? and match_429?(reason) do
          {:snooze, @default_snooze_seconds}
        else
          raise "notification_retryable: #{truncate(reason)}"
        end

      secs ->
        {:snooze, secs |> max(1) |> min(@max_snooze_seconds)}
    end
  end

  # Cherche {:rate_limited, secondes} jusqu'à 3 niveaux (ChannelDispatch
  # imbrique {provider, raison} et {provider, token, raison}).
  defp extract_seconds({:rate_limited, secs}) when is_integer(secs) and secs > 0, do: secs
  defp extract_seconds({:rate_limited, _}), do: nil

  defp extract_seconds(tuple) when is_tuple(tuple) and tuple_size(tuple) <= 4 do
    tuple |> Tuple.to_list() |> Enum.find_value(nil, &extract_seconds/1)
  end

  defp extract_seconds(list) when is_list(list) do
    Enum.find_value(list, nil, &extract_seconds/1)
  end

  defp extract_seconds(_), do: nil

  defp match_429?(reason) do
    reason |> inspect() |> String.contains?("429")
  end

  defp truncate(reason), do: reason |> inspect() |> String.slice(0, 500)
end
