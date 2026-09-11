# ==================================
# WIWIGA - Adapter Africa's Talking SMS
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.AfricasTalking
# API: api.africastalking.com/version1/messaging (apiKey header)

defmodule GameHub.Notifications.Adapters.AfricasTalking do
  @moduledoc """
  Adapter Africa's Talking (agrégateur panafricain, routes MTN/Orange CM).

  ## Config requise
      %{
        "api_key" => "...",      # sensible, chiffré
        "username" => "wiwiga",  # username Africa's Talking
        "sender_id" => "WIWIGA"  # optionnel, pré-enregistré
      }
  """

  @behaviour GameHub.Notifications.Adapters.SmsAdapter

  alias GameHub.Notifications.Adapters.SmsAdapter

  @url "https://api.africastalking.com/version1/messaging"

  @impl true
  def send_sms(to, body, config) do
    with {:ok, msisdn} <- SmsAdapter.normalize_msisdn(to),
         %{"api_key" => api_key, "username" => username} when is_binary(api_key) and is_binary(username) <- config do
      payload =
        %{"username" => username, "to" => msisdn, "message" => body}
        |> maybe_put("from", Map.get(config, "sender_id"))

      form = URI.encode_query(payload)

      case SmsAdapter.post_form(@url, [{"apiKey", api_key}, {"Accept", "application/json"}], form) do
        {:ok, %{status: 201, body: resp_body}} ->
          {:ok, %{provider_message_id: extract_message_id(resp_body)}}

        {:ok, %{status: status, headers: headers, body: resp_body}} ->
          SmsAdapter.classify_response(status, headers || [], resp_body, :at_rejected)

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      {:error, :invalid_msisdn} -> {:permanent, :invalid_msisdn}
      _ -> {:permanent, :missing_credentials}
    end
  end

  @doc """
  Santé sans envoi : lecture du compte (solde) via l'API user.
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.SmsAdapter
  def check_health(%{"api_key" => api_key, "username" => username})
      when is_binary(api_key) and is_binary(username) do
    url = "https://api.africastalking.com/version1/user?username=#{URI.encode_www_form(username)}"

    case SmsAdapter.get(url, [{"apiKey", api_key}, {"Accept", "application/json"}]) do
      {:ok, %{status: 200}} -> {:ok, "Compte Africa's Talking accessible (aucun SMS envoyé)"}
      {:ok, %{status: status}} when status in [400, 401, 403] -> {:error, {:auth_rejected, status}}
      {:ok, %{status: status}} -> {:error, {:unreachable, status}}
      {:error, reason} -> {:error, {:unreachable, reason}}
    end
  end

  @impl GameHub.Notifications.Adapters.SmsAdapter
  def check_health(_), do: {:error, :missing_credentials}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp extract_message_id(body) do
    case Jason.decode(body) do
      {:ok, %{"SMSMessageData" => %{"Recipients" => [%{"messageId" => id} | _]}}} -> id
      _ -> nil
    end
  rescue
    _ -> nil
  end

end
