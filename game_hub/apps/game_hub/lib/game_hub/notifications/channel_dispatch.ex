# ==================================
# WIWIGA - Envoi multi-provider avec failover
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.ChannelDispatch
# Description: Parcourt les providers actifs par priorité.
#              Premier succès gagne, sinon dernière erreur remonte.

defmodule GameHub.Notifications.ChannelDispatch do
  @moduledoc """
  Envoi avec failover sur les providers actifs (triés par priorité).
  """

  alias GameHub.Notifications
  alias GameHub.Notifications.{Adapters, DeviceToken}
  alias GameHub.Repo
  import Ecto.Query

  require Logger

  @doc """
  Envoie un SMS au premier provider disponible.
  Bloqué si le destinataire est supprimé (`:suppressed`),
  sauf catégorie `security` (OTP/alertes : consentement distinct).
  """
  @spec send_sms(String.t(), String.t(), String.t()) ::
          {:ok, map(), String.t()} | {:retryable, term()} | {:permanent, term()}
  def send_sms(to, body, category \\ "transactional") do
    if Notifications.suppressed?("sms", to, category) do
      {:permanent, :suppressed}
    else
      try_providers("sms", fn provider, config ->
        with {:ok, adapter} <- Adapters.for_provider("sms", provider.name) do
          adapter.send_sms(to, body, config)
        end
      end)
    end
  end

  @doc """
  Envoie un email au premier provider disponible.
  `opts` : category, app_url, preferences_url, unsubscribe_mailto
  (injectés dans la config sous clés `_*`, ignorées par les adapters).
  """
  @spec send_email(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map(), String.t()} | {:retryable, term()} | {:permanent, term()}
  def send_email(to, subject, body, opts \\ []) do
    category = opts |> Keyword.get(:category, "transactional") |> to_string()

    if Notifications.suppressed?("email", to, category) do
      {:permanent, :suppressed}
    else
      extra = %{
      "_category" => opts |> Keyword.get(:category, "transactional") |> to_string(),
      "_app_url" => opts |> Keyword.get(:app_url, "https://wiwiga.com") |> to_string(),
      "_preferences_url" => opts |> Keyword.get(:preferences_url, "https://wiwiga.com/notifications/preferences") |> to_string(),
      "_unsubscribe_mailto" => opts |> Keyword.get(:unsubscribe_mailto, "unsubscribe@wiwiga.com") |> to_string()
    }

    try_providers("email", fn provider, config ->
      with {:ok, adapter} <- Adapters.for_provider("email", provider.name) do
        adapter.send_email(to, subject, body, Map.merge(config, extra))
      end
    end)
    end
  end

  @doc """
  Envoie un push à tous les tokens valides d'un utilisateur.
  Invalide les tokens rejetés. Retourne un résumé par token.
  """
  @spec send_push(integer(), String.t(), String.t(), map()) ::
          {:ok, list()} | {:retryable, term()} | {:permanent, term()}
  def send_push(user_id, title, body, data \\ %{}) do    tokens = Repo.all(from d in DeviceToken, where: d.user_id == ^user_id and d.is_valid == true)

    if tokens == [] do
      {:permanent, :no_device_tokens}
    else
      providers = Notifications.active_channel_providers("push")

      if providers == [] do
        {:permanent, :no_active_provider}
      else
        results =
          Enum.flat_map(tokens, fn token ->
            Enum.map(providers, fn provider ->
              push_via_provider(provider, token.token, title, body, data)
            end)
          end)

        summarize_push(results)
      end
    end
  end

  @doc """
  Envoie un code OTP par SMS (synchrone, urgent).

  Pipeline multi-provider d'abord, provider legacy (`GameHub.SmsProvider`)
  en repli si aucun provider actif ou échec total. N'échoue jamais
  l'appelant : le code OTP reste vérifiable même si l'envoi échoue.
  """
  @spec send_otp_sms(String.t(), String.t()) :: :ok
  def send_otp_sms(phone, code) do
    body = "[WIWIGA] Code de vérification : #{code}"

    # Catégorie security : un STOP marketing ne bloque jamais un OTP.
    case send_sms(phone, body, "security") do
      {:ok, provider, _message_id} ->
        Logger.info("[OTP] SMS envoyé via #{provider.name} à #{mask_phone(phone)}")
        :ok

      {:retryable, reason} ->
        Logger.warning("[OTP] SMS multi-provider indisponible (#{truncate_reason(reason)}), repli legacy")
        legacy_sms(phone, body)

      {:permanent, :no_active_provider} ->
        legacy_sms(phone, body)

      {:permanent, reason} ->
        Logger.warning("[OTP] SMS rejeté (#{truncate_reason(reason)}), repli legacy")
        legacy_sms(phone, body)
    end
  end

  @doc """
  Envoie un code OTP par email (synchrone, urgent).
  Repli : log (comportement historique).
  """
  @spec send_otp_email(String.t(), String.t()) :: :ok
  def send_otp_email(email, code) do
    subject = "[WIWIGA] Code de vérification"
    body = "Votre code WIWIGA : #{code} (valable 5 minutes)."

    case send_email(email, subject, body) do
      {:ok, provider, _} ->
        Logger.info("[OTP] Email envoyé via #{provider.name} à #{mask_email(email)}")
        :ok

      {kind, reason} ->
        Logger.warning("[OTP] Email #{kind} (#{truncate_reason(reason)}), repli log")
        Logger.info("[EMAIL] OTP pour #{mask_email(email)}: #{code}")
        :ok
    end
  end

  # === Privé ===

  defp try_providers(channel, send_fun) do
    providers = Notifications.active_channel_providers(channel)

    case providers do
      [] ->
        {:permanent, :no_active_provider}

      [first | rest] ->
        Enum.reduce_while(rest, attempt(first, send_fun), fn provider, last_error ->
          case last_error do
            {:ok, _, _} -> {:halt, last_error}
            _ ->
              case attempt(provider, send_fun) do
                {:ok, _, _} = ok -> {:halt, ok}
                error -> {:cont, error}
              end
          end
        end)
    end
  end

  defp attempt(provider, send_fun) do
    alias GameHub.Notifications.RateLimit

    with :ok <- RateLimit.check_provider(provider.id, provider.rate_limit_per_min || 60) do
      config = Notifications.decrypted_config(provider)

      case send_fun.(provider, config) do
        {:ok, %{provider_message_id: message_id}} -> {:ok, provider, message_id}
        {:token_invalid, token} -> {:token_invalid, provider, token}
        {:retryable, reason} -> {:retryable, {provider.name, reason}}
        {:permanent, reason} -> {:permanent, {provider.name, reason}}
        {:error, :unknown_adapter} -> {:permanent, {provider.name, :unknown_adapter}}
      end
    else
      {:error, :limited} -> {:retryable, {provider.name, :provider_rate_limited}}
    end
  rescue
    e -> {:retryable, {provider.name, e}}
  catch
    _, e -> {:retryable, {provider.name, e}}
  end

  defp push_via_provider(provider, token, title, body, data) do
    alias GameHub.Notifications.RateLimit

    with :ok <- RateLimit.check_provider(provider.id, provider.rate_limit_per_min || 60) do
      config = Notifications.decrypted_config(provider)

      result =
        with {:ok, adapter} <- Adapters.for_provider("push", provider.name) do
          adapter.send_push(token, title, body, data, config)
        end

      case result do
        {:ok, %{provider_message_id: message_id}} ->
          {:sent, provider.name, token, message_id}

        {:token_invalid, _} ->
          Notifications.invalidate_device_token(token)
          {:token_invalid, provider.name, token}

        {:retryable, reason} ->
          {:retryable, {provider.name, token, reason}}

        {:permanent, reason} ->
          {:permanent, {provider.name, token, reason}}

        {:error, :unknown_adapter} ->
          {:permanent, {provider.name, token, :unknown_adapter}}
      end
    else
      {:error, :limited} -> {:retryable, {provider.name, token, :provider_rate_limited}}
    end
  rescue
    e -> {:retryable, {provider.name, token, e}}
  catch
    _, e -> {:retryable, {provider.name, token, e}}
  end

  defp summarize_push(results) do
    sent = Enum.filter(results, &match?({:sent, _, _, _}, &1))

    cond do
      sent != [] -> {:ok, sent}
      Enum.any?(results, &match?({:retryable, _}, &1)) -> {:retryable, results}
      true -> {:permanent, results}
    end
  end

  # Repli legacy : LogAdapter en dev, CampayAdapter si configuré en prod.
  defp legacy_sms(phone, body) do
    try do
      GameHub.SmsProvider.send_sms(phone, body)
    rescue
      e -> Logger.warning("[OTP] Repli legacy échoué : #{inspect(e)}")
    catch
      _, e -> Logger.warning("[OTP] Repli legacy échoué : #{inspect(e)}")
    end

    :ok
  end

  defp mask_phone(phone) when is_binary(phone) and byte_size(phone) > 6 do
    "#{String.slice(phone, 0, 4)}***#{String.slice(phone, -3, 3)}"
  end

  defp mask_phone(phone), do: to_string(phone)

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@") do
      [name, domain] -> "#{String.slice(name, 0, 2)}***@#{domain}"
      _ -> "***"
    end
  end

  defp truncate_reason(reason), do: reason |> inspect() |> String.slice(0, 200)
end
