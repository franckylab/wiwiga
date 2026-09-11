# ==================================
# WIWIGA - Adapter Orange SMS Cameroun
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.OrangeCm
# API: developer.orange.com (SMS CM 2.0) — OAuth client_credentials
#      puis POST outbound SMS. Sender address pré-enregistré obligatoire.

defmodule GameHub.Notifications.Adapters.OrangeCm do
  @moduledoc """
  Adapter Orange SMS Cameroun.

  ## Config requise
      %{
        "client_id" => "...",          # sensible, chiffré
        "client_secret" => "...",      # sensible, chiffré
        "sender_address" => "tel:+237690000000",
        "sender_name" => "WIWIGA"      # optionnel
      }
  """

  @behaviour GameHub.Notifications.Adapters.SmsAdapter

  alias GameHub.Notifications.Adapters.SmsAdapter
  require Logger

  @token_url "https://api.orange.com/oauth/v3/token"
  @sms_url "https://api.orange.com/smsmessaging/v1/outbound"

  @impl true
  def send_sms(to, body, config) do
    with {:ok, msisdn} <- SmsAdapter.normalize_msisdn(to),
         {:ok, token} <- fetch_token(config),
         {:ok, message_id} <- send_message(msisdn, body, token, config) do
      {:ok, %{provider_message_id: message_id}}
    else
      {:error, :invalid_msisdn} -> {:permanent, :invalid_msisdn}
      {:retryable, reason} -> {:retryable, reason}
      {:permanent, reason} -> {:permanent, reason}
      {:error, reason} -> {:retryable, reason}
    end
  end

  defp fetch_token(%{"client_id" => id, "client_secret" => secret})
       when is_binary(id) and is_binary(secret) do
    auth = Base.encode64("#{id}:#{secret}")

    case SmsAdapter.post_form(@token_url, [{"authorization", "Basic #{auth}"}], "grant_type=client_credentials") do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token}} -> {:ok, token}
          _ -> {:permanent, :invalid_token_response}
        end

      {:ok, %{status: status}} when status in [400, 401, 403] ->
        {:permanent, {:orange_auth_rejected, status}}

      {:ok, %{status: _}} ->
        {:retryable, :orange_token_unavailable}

      {:error, reason} ->
        {:retryable, reason}
    end
  end

  defp fetch_token(_), do: {:permanent, :missing_credentials}

  @doc """
  Santé sans envoi : le token OAuth valide les credentials.
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.SmsAdapter
  def check_health(config) do
    case fetch_token(config) do
      {:ok, _token} -> {:ok, "OAuth Orange OK (aucun SMS envoyé)"}
      {:permanent, reason} -> {:error, reason}
      {:retryable, reason} -> {:error, {:unreachable, reason}}
    end
  end

  defp send_message(msisdn, body, token, config) do
    sender = Map.get(config, "sender_address", "")
    sender_name = Map.get(config, "sender_name", "WIWIGA")
    url = "#{@sms_url}/#{URI.encode_www_form(sender)}/requests"

    payload = %{
      "outboundSMSMessageRequest" => %{
        "address" => ["tel:#{msisdn}"],
        "senderAddress" => sender,
        "senderName" => sender_name,
        "outboundSMSTextMessage" => %{"message" => body}
      }
    }

    case SmsAdapter.post_json(url, [{"authorization", "Bearer #{token}"}], payload) do
      {:ok, %{status: status, body: resp_body}} when status in [200, 201] ->
        {:ok, extract_message_id(resp_body)}

      {:ok, %{status: status, headers: headers, body: resp_body}} ->
        SmsAdapter.classify_response(status, headers || [], resp_body, :orange_rejected)

      {:error, reason} ->
        {:retryable, reason}
    end
  end

  defp extract_message_id(body) do
    case Jason.decode(body) do
      {:ok, %{"outboundSMSMessageRequest" => %{"resourceReference" => %{"resourceURL" => url}}}} ->
        url |> String.split("/") |> List.last()

      _ ->
        nil
    end
  rescue
    _ -> nil
  end
end
