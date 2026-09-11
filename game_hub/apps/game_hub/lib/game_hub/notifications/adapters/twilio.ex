# ==================================
# WIWIGA - Adapter Twilio SMS (fallback global)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.Twilio

defmodule GameHub.Notifications.Adapters.Twilio do
  @moduledoc """
  Adapter Twilio Programmable SMS (fallback global si routes CM indisponibles).

  ## Config requise
      %{
        "account_sid" => "...",  # sensible, chiffré
        "auth_token" => "...",   # sensible, chiffré
        "from" => "+1234567890"  # numéro Twilio ou sender ID
      }
  """

  @behaviour GameHub.Notifications.Adapters.SmsAdapter

  alias GameHub.Notifications.Adapters.SmsAdapter

  @impl true
  def send_sms(to, body, config) do
    with {:ok, msisdn} <- SmsAdapter.normalize_msisdn(to),
         %{"account_sid" => sid, "auth_token" => token, "from" => from}
         when is_binary(sid) and is_binary(token) and is_binary(from) <- config do
      url = "https://api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json"
      auth = Base.encode64("#{sid}:#{token}")
      form = URI.encode_query(%{"To" => msisdn, "From" => from, "Body" => body})

      case SmsAdapter.post_form(url, [{"authorization", "Basic #{auth}"}], form) do
        {:ok, %{status: status, body: resp_body}} when status in [200, 201] ->
          {:ok, %{provider_message_id: extract_sid(resp_body)}}

        {:ok, %{status: status, headers: headers, body: resp_body}} ->
          SmsAdapter.classify_response(status, headers || [], resp_body, :twilio_rejected)

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      {:error, :invalid_msisdn} -> {:permanent, :invalid_msisdn}
      _ -> {:permanent, :missing_credentials}
    end
  end

  @doc """
  Santé sans envoi : lecture du compte (valide SID + token).
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.SmsAdapter
  def check_health(%{"account_sid" => sid, "auth_token" => token})
      when is_binary(sid) and is_binary(token) do
    url = "https://api.twilio.com/2010-04-01/Accounts/#{sid}.json"
    auth = Base.encode64("#{sid}:#{token}")

    case SmsAdapter.get(url, [{"authorization", "Basic #{auth}"}, {"Accept", "application/json"}]) do
      {:ok, %{status: 200}} -> {:ok, "Compte Twilio accessible (aucun SMS envoyé)"}
      {:ok, %{status: status}} when status in [400, 401, 403] -> {:error, {:auth_rejected, status}}
      {:ok, %{status: status}} -> {:error, {:unreachable, status}}
      {:error, reason} -> {:error, {:unreachable, reason}}
    end
  end

  @impl GameHub.Notifications.Adapters.SmsAdapter
  def check_health(_), do: {:error, :missing_credentials}

  defp extract_sid(body) do
    case Jason.decode(body) do
      {:ok, %{"sid" => sid}} -> sid
      _ -> nil
    end
  rescue
    _ -> nil
  end

end
