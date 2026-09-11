# ==================================
# WIWIGA - Controller Webhooks DLR SMS
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.SmsWebhookController
# Description: Accusés de réception providers SMS (delivery receipts).
#              Toujours 200 (évite les retries providers), idempotent.

defmodule GameHubWeb.SmsWebhookController do
  @moduledoc """
  Webhooks d'accusés de réception SMS.

  ## Endpoint
      POST /api/webhooks/sms/:provider

  Corps accepté (générique + variantes providers) :
      {"message_id": "...", "status": "delivered"}
      {"MessageSid": "...", "MessageStatus": "delivered"}   (Twilio)
      {"messageId": "...", "state": "DELIVRD"}               (agrégateurs)
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications
  alias GameHub.Notifications.Adapters.SmsAdapter

  require Logger

  @delivered ~w(delivered delivrd DELIVRD DELIVERED success SUCCESS)
  @failed ~w(failed FAILED undelivered UNDELIVERED expired EXPIRED rejected REJECTED error ERROR)

  # Opt-out : mots entiers, FR + EN, insensible à la casse.
  # "STOP", "STOP ALL", "ne plus", "désinscrire"... (standard raisonnable,
  # au-delà duquel revue humaine via les logs).
  @stop_words ~w(stop stopall unsubscribe end quit cancel revoke optout)
  @stop_phrases ["ne plus", "desinscrire", "désinscrire", "retirez-moi", "retirez moi", "plus de sms", "plus de message"]
  @start_words ~w(start yes unstop)

  @doc """
  POST /api/webhooks/sms/:provider/inbound
  SMS entrants (STOP/START/HELP). Toujours 200.
  Corps générique : {from, text} (+ variantes from_/sender/body/message).
  """

  @doc """
  POST /api/webhooks/sms/:provider
  """
  def callback(conn, %{"provider" => provider} = params) do
    provider_name = normalize_provider(provider)
    message_id = find_message_id(params)
    status = find_status(params)

    result =
      cond do
        is_nil(message_id) ->
          Logger.warning("[SMS-DLR] sans ID message (provider=#{provider_name})")
          {:error, :missing_message_id}

        status in @delivered ->
          Notifications.mark_delivered(provider_name, message_id)

        status in @failed ->
          Notifications.mark_delivery_failed(provider_name, provider_message_id(message_id), "dlr=#{status}")

        true ->
          # Statut intermédiaire (sent, buffered...) : accusé sans changement
          {:ok, :acknowledged}
      end

    case result do
      {:ok, _} ->
        conn |> put_status(200) |> json(%{success: true})

      {:error, :not_found} ->
        # ID inconnu (test provider, vieux message) : 200 quand même
        conn |> put_status(200) |> json(%{success: true, message: "ID inconnu, ignoré"})

      {:error, reason} ->
        conn |> put_status(200) |> json(%{success: false, message: "Ignoré : #{inspect(reason)}"})
    end
  end

  defp normalize_provider(provider) do
    provider |> to_string() |> String.downcase() |> String.trim()
  end

  @doc """
  POST /api/webhooks/sms/:provider/inbound — voir moduledoc.
  """
  def inbound(conn, %{"provider" => provider} = params) do
    provider_name = normalize_provider(provider)
    from = find_inbound_field(params, ["from", "from_", "sender", "msisdn", "phone"])
    text = find_inbound_field(params, ["text", "body", "message", "content"])

    action =
      cond do
        is_nil(from) or from == "" -> :missing_sender
        opt_out?(text) -> handle_stop(provider_name, to_string(from), to_string(text))
        opt_in?(text) -> handle_start(provider_name, to_string(from))
        true -> :ignored
      end

    conn |> put_status(200) |> json(%{success: true, action: to_string(action)})
  end

  defp find_inbound_field(params, keys) do
    Enum.find_value(keys, fn key -> Map.get(params, key) end)
  end

  # Mot entier insensible à la casse (STOP dans "STOP PLEASE" compte,
  # mais pas dans "NONSTOP").
  defp opt_out?(nil), do: false
  defp opt_out?(""), do: false

  defp opt_out?(text) when is_binary(text) do
    words = text |> String.downcase() |> String.split(~r/[^a-zàâäéèêëîïôöùûüç]+/u, trim: true)
    lowered = String.downcase(text)

    Enum.any?(@stop_words, &(&1 in words)) or
      Enum.any?(@stop_phrases, &String.contains?(lowered, &1))
  end

  defp opt_in?(nil), do: false
  defp opt_in?(""), do: false

  defp opt_in?(text) when is_binary(text) do
    words = text |> String.downcase() |> String.split(~r/[^a-zàâäéèêëîïôöùûüç]+/u, trim: true)
    Enum.any?(@start_words, &(&1 in words))
  end

  # STOP : suppression immédiate + marketing coupé (sms/email/push) pour
  # l'utilisateur correspondant au numéro, s'il existe. Le transactionnel
  # (OTP) reste délivré (consentement distinct).
  defp handle_stop(provider_name, from, text) do
    msisdn =
      case SmsAdapter.normalize_msisdn(from) do
        {:ok, normalized} -> normalized
        _ -> from
      end

    Notifications.suppress("sms", msisdn, "stop_keyword", "sms:#{provider_name}")

    case GameHub.Repo.get_by(GameHub.Users.User, phone: msisdn) ||
           GameHub.Repo.get_by(GameHub.Users.User, phone: from) do
      nil ->
        :ok

      user ->
        for channel <- ["sms", "email", "push"] do
          Notifications.upsert_preference(user.id, "marketing", channel, false)
        end

        :ok
    end

    GameHub.AuditLog.log("sms_stop", nil, "notifications", msisdn, %{
      "provider" => provider_name,
      "text" => String.slice(text, 0, 160)
    })

    :unsubscribed
  rescue
    _ -> :unsubscribed
  catch
    _, _ -> :unsubscribed
  end

  # START/YES : réinscription explicite (suppression levée).
  defp handle_start(provider_name, from) do
    msisdn =
      case SmsAdapter.normalize_msisdn(from) do
        {:ok, normalized} -> normalized
        _ -> from
      end

    Notifications.unsuppress("sms", msisdn)

    GameHub.AuditLog.log("sms_start", nil, "notifications", msisdn, %{"provider" => provider_name})

    :resubscribed
  rescue
    _ -> :resubscribed
  catch
    _, _ -> :resubscribed
  end

  defp provider_message_id(message_id), do: to_string(message_id)

  defp find_message_id(params) do
    Enum.find_value(
      ["provider_message_id", "message_id", "messageId", "MessageSid", "sid", "id", "data.message_id"],
      fn key -> get_path(params, String.split(key, ".")) end
    )
  end

  defp find_status(params) do
    Enum.find_value(
      ["status", "state", "delivery_status", "MessageStatus", "data.status"],
      fn key -> get_path(params, String.split(key, ".")) end
    )
    |> to_string()
  end

  defp get_path(params, [key]) when is_map(params), do: Map.get(params, key)
  defp get_path(params, [head | tail]) when is_map(params) do
    case Map.get(params, head) do
      nil -> nil
      nested -> get_path(nested, tail)
    end
  end

  defp get_path(_, _), do: nil
end
