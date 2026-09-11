# ==================================
# WIWIGA - Controller Webhook SES/SNS
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.SesWebhookController
# Description: Bounces/plaintes SES via SNS (suppression immédiate).
#              Signature SNS vérifiée (RSA-SHA1, cert mis en cache).
#              Toujours 200 (pas de retry SNS inutile).

defmodule GameHubWeb.SesWebhookController do
  @moduledoc """
  Webhook SES via SNS.

  ## Endpoint
      POST /api/webhooks/ses

  Configuration AWS requise : topic SNS abonné en HTTPS sur cet endpoint,
  branché aux notifications bounce + complaint de l'identité SES.
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications

  require Logger

  @cert_cache __MODULE__.CertCache
  @cert_ttl_seconds 3600

  @doc """
  POST /api/webhooks/ses
  """
  def callback(conn, params) do
    result =
      case Map.get(params, "Type") do
        "SubscriptionConfirmation" -> confirm_subscription(params)
        "Notification" -> handle_notification(params)
        _ -> {:error, :unknown_type}
      end

    case result do
      {:ok, action} -> conn |> put_status(200) |> json(%{success: true, action: to_string(action)})
      {:error, reason} -> conn |> put_status(200) |> json(%{success: false, message: "Ignoré : #{inspect(reason)}"})
    end
  end

  # === Confirmation d'abonnement SNS (GET signé côté AWS) ===

  defp confirm_subscription(%{"SubscribeURL" => url}) do
    with {:ok, uri} <- https_sns_url(url),
         {:ok, %{status: status}} <- Finch.build(:get, URI.to_string(uri), []) |> Finch.request(GameHub.Finch, receive_timeout: 10_000),
         true <- status in [200, 201, 202] do
      Logger.info("[SES] Abonnement SNS confirmé")
      {:ok, :subscription_confirmed}
    else
      _ -> {:error, :confirmation_failed}
    end
  rescue
    _ -> {:error, :confirmation_failed}
  catch
    _, _ -> {:error, :confirmation_failed}
  end

  defp confirm_subscription(_), do: {:error, :missing_subscribe_url}

  # === Notifications bounce/complaint/delivery ===

  defp handle_notification(params) do
    with :ok <- verify_signature(params),
         {:ok, message} <- decode_message(params) do
      dispatch_message(message)
    end
  end

  defp decode_message(%{"Message" => message}) when is_binary(message) do
    case Jason.decode(message) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> {:error, :invalid_message}
    end
  end

  defp decode_message(_), do: {:error, :missing_message}

  defp dispatch_message(%{"notificationType" => "Bounce"} = message) do
    bounce = Map.get(message, "bounce", %{})
    ses_id = get_in(message, ["mail", "messageId"])

    case Map.get(bounce, "bounceType") do
      "Permanent" ->
        recipients = bounce |> Map.get("bouncedRecipients", []) |> Enum.map(&Map.get(&1, "emailAddress")) |> Enum.reject(&is_nil/1)
        Enum.each(recipients, &suppress_email(&1, "hard_bounce", "ses"))

        if ses_id, do: Notifications.mark_delivery_failed("ses", to_string(ses_id), "hard_bounce")

        audit("ses_hard_bounce", %{"recipients" => recipients, "ses_id" => ses_id})
        {:ok, :bounce_processed}

      _ ->
        # Transient / Undetermined : log seul (retry côté SES/worker)
        {:ok, :transient_ignored}
    end
  end

  defp dispatch_message(%{"notificationType" => "Complaint"} = message) do
    complaint = Map.get(message, "complaint", %{})
    recipients = complaint |> Map.get("complainedRecipients", []) |> Enum.map(&Map.get(&1, "emailAddress")) |> Enum.reject(&is_nil/1)
    Enum.each(recipients, &suppress_email(&1, "complaint", "ses"))

    audit("ses_complaint", %{"recipients" => recipients})
    {:ok, :complaint_processed}
  end

  defp dispatch_message(%{"notificationType" => "Delivery", "mail" => %{"messageId" => ses_id}}) do
    Notifications.mark_delivered("ses", to_string(ses_id))
    {:ok, :delivery_confirmed}
  end

  defp dispatch_message(_), do: {:error, :unsupported_type}

  defp suppress_email(email, reason, source) do
    Notifications.suppress("email", email, reason, source)

    case GameHub.Repo.get_by(GameHub.Users.User, email: String.downcase(to_string(email))) do
      nil -> :ok
      user -> Notifications.upsert_preference(user.id, "marketing", "email", false)
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp audit(type, payload) do
    GameHub.AuditLog.log(type, nil, "notifications", "ses", payload)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  # === Vérification signature SNS (RSA-SHA1, spec AWS) ===

  defp verify_signature(%{"Signature" => sig, "SigningCertURL" => cert_url} = params) when is_binary(sig) do
    with {:ok, cert_uri} <- https_sns_url(cert_url),
         {:ok, public_key} <- fetch_public_key(cert_uri),
         {:ok, decoded_sig} <- Base.decode64(sig),
         true <- :public_key.verify(string_to_sign(params), :sha, decoded_sig, public_key) do
      :ok
    else
      _ -> {:error, :invalid_signature}
    end
  rescue
    _ -> {:error, :invalid_signature}
  catch
    _, _ -> {:error, :invalid_signature}
  end

  defp verify_signature(_), do: {:error, :missing_signature}

  # Ordre exact imposé par AWS (champs absents omis, \n final inclus).
  defp string_to_sign(%{"Type" => "SubscriptionConfirmation"} = params) do
    ["Message", "MessageId", "SubscribeURL", "Timestamp", "TopicArn", "Type"]
    |> Enum.flat_map(fn key -> [key, "\n", Map.get(params, key, ""), "\n"] end)
    |> IO.iodata_to_binary()
  end

  defp string_to_sign(params) do
    ["Message", "MessageId"]
    |> with_optional_subject(params)
    |> Kernel.++(["Timestamp", "TopicArn", "Type"])
    |> Enum.flat_map(fn key -> [key, "\n", Map.get(params, key, ""), "\n"] end)
    |> IO.iodata_to_binary()
  end

  defp with_optional_subject(keys, %{"Subject" => _}), do: keys ++ ["Subject"]
  defp with_optional_subject(keys, _), do: keys

  defp https_sns_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme == "https" and is_binary(uri.host) and
         Regex.match?(~r/^sns\.[a-z0-9-]+\.amazonaws\.com(\.cn)?$/, uri.host) do
      {:ok, uri}
    else
      {:error, :untrusted_host}
    end
  end

  defp https_sns_url(_), do: {:error, :untrusted_host}

  defp fetch_public_key(cert_uri) do
    ensure_cert_cache()

    case :ets.lookup(@cert_cache, cert_uri.host <> cert_uri.path) do
      [{_, key, inserted_at}] ->
        if System.system_time(:second) - inserted_at < @cert_ttl_seconds do
          {:ok, key}
        else
          download_public_key(cert_uri)
        end

      [] ->
        download_public_key(cert_uri)
    end
  end

  defp download_public_key(cert_uri) do
    with {:ok, %{status: 200, body: pem}} <-
           Finch.build(:get, URI.to_string(cert_uri), []) |> Finch.request(GameHub.Finch, receive_timeout: 10_000),
         [{:Certificate, der, :not_encrypted}] <- :public_key.pem_decode(pem),
         otp_cert <- :public_key.pkix_decode_cert(der, :otp),
         {:OTPTBSCertificate, _, _, _, _, _, _, _, {:OTPSubjectPublicKeyInfo, _, public_key}, _, _, _} <-
           elem(otp_cert, 1) do
      :ets.insert(@cert_cache, {cert_uri.host <> cert_uri.path, public_key, System.system_time(:second)})
      {:ok, public_key}
    else
      _ -> {:error, :cert_fetch_failed}
    end
  rescue
    _ -> {:error, :cert_fetch_failed}
  catch
    _, _ -> {:error, :cert_fetch_failed}
  end

  defp ensure_cert_cache do
    case :ets.whereis(@cert_cache) do
      :undefined -> :ets.new(@cert_cache, [:set, :public, :named_table])
      _ -> :ok
    end
  rescue
    _ -> :ok
  end
end
