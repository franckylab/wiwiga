# ==================================
# WIWIGA - Registre des adapters providers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters

defmodule GameHub.Notifications.Adapters do
  @moduledoc """
  Registre nom provider → module adapter.

  Surcharge possible en test via config :
      config :game_hub, :notification_adapter_overrides, %{"esms_africa" => MyStub}
  """

  alias GameHub.Notifications.Adapters.{AfricasTalking, FcmV1, HttpSms, OneSignal, OrangeCm, Sendgrid, Ses, Smtp, Twilio}

  @sms %{
    "orange_cm" => OrangeCm,
    "africas_talking" => AfricasTalking,
    "esms_africa" => HttpSms,
    "mtn_cm" => HttpSms,
    "twilio" => Twilio
  }

  @push %{
    "fcm_v1" => FcmV1,
    "onesignal" => OneSignal
  }

  @email %{
    "smtp" => Smtp,
    "sendgrid" => Sendgrid,
    "ses" => Ses
  }

  @doc """
  Retourne le module adapter pour un canal + nom de provider.
  """
  @spec for_provider(String.t(), String.t()) :: {:ok, module()} | {:error, :unknown_adapter}
  def for_provider(channel, name) do
    overrides = Application.get_env(:game_hub, :notification_adapter_overrides, %{})

    base =
      case channel do
        "sms" -> @sms
        "push" -> @push
        "email" -> @email
        _ -> %{}
      end

    case Map.get(overrides, name, Map.get(base, name)) do
      nil -> {:error, :unknown_adapter}
      module -> {:ok, module}
    end
  end
end
