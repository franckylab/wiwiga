# ============================================================
# Fichier: sms_provider.ex
# Description: Abstraction SMS provider (Campay, Twilio, etc.)
# ============================================================

defmodule GameHub.SmsProvider do
  @moduledoc """
  Abstraction pour l'envoi de SMS.
  
  Configuration via `config/config.exs`:
  
      config :game_hub, GameHub.SmsProvider,
        adapter: GameHub.SmsProvider.LogAdapter,    # Dev: log uniquement
        # adapter: GameHub.SmsProvider.CampayAdapter  # Production: Campay
  
  Adapters disponibles:
  - `LogAdapter` : Log le message (dev/test)
  - `CampayAdapter` : API Campay (production Afrique)
  """

  require Logger

  @type send_result :: :ok | {:error, String.t()}

  @doc """
  Envoie un SMS via le provider configuré.
  """
  @spec send_sms(String.t(), String.t()) :: send_result()
  def send_sms(phone, message) do
    adapter = adapter()
    adapter.send_sms(phone, message)
  end

  defp adapter do
    Application.get_env(:game_hub, GameHub.SmsProvider, [])
    |> Keyword.get(:adapter, GameHub.SmsProvider.LogAdapter)
  end

  # ============================================================
  # Adapter: Log (dev/test)
  # ============================================================
  defmodule LogAdapter do
    @moduledoc "Adapter qui log les SMS (développement)"
    
    @behaviour GameHub.SmsProviderBehaviour

    @impl true
    def send_sms(phone, message) do
      Logger.info("[SMS] To: #{mask_phone(phone)} | Message: #{message}")
      :ok
    end

    defp mask_phone(phone) when byte_size(phone) > 6 do
      prefix = String.slice(phone, 0, 4)
      suffix = String.slice(phone, -3, 3)
      "#{prefix}***#{suffix}"
    end
    defp mask_phone(phone), do: phone
  end

  # ============================================================
  # Adapter: Campay (production)
  # ============================================================
  defmodule CampayAdapter do
    @moduledoc "Adapter pour l'API Campay SMS"
    
    @behaviour GameHub.SmsProviderBehaviour

    @impl true
    def send_sms(phone, message) do
      config = Application.get_env(:game_hub, GameHub.SmsProvider, [])
      api_url = Keyword.get(config, :campay_url, "https://api.campay.net/api/v1/sms/send")
      api_token = Keyword.get(config, :campay_token, "")

      if api_token == "" do
        Logger.error("[SMS] Campay token non configuré")
        {:error, "SMS provider not configured"}
      else
        case :httpc.request(:post,
          {String.to_charlist(api_url), [], 'application/json',
           Jason.encode!(%{to: phone, message: message})},
          [hackney: [headers: [{"Authorization", "Bearer #{api_token}"}]]],
          []
        ) do
          {:ok, {{_, 200, _}, _, _}} ->
            Logger.info("[SMS] Envoyé via Campay à #{phone}")
            :ok

          {:ok, {{_, status, _}, _, body}} ->
            Logger.error("[SMS] Campay error #{status}: #{body}")
            {:error, "SMS sending failed (HTTP #{status})"}

          {:error, reason} ->
            Logger.error("[SMS] Campay request error: #{inspect(reason)}")
            {:error, "SMS request failed"}
        end
      end
    end
  end
end

# ============================================================
# Behaviour pour les adapters SMS
# ============================================================
defmodule GameHub.SmsProviderBehaviour do
  @moduledoc "Behaviour pour les adapters SMS"
  @callback send_sms(phone :: String.t(), message :: String.t()) :: :ok | {:error, String.t()}
end
