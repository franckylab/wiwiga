# ==================================
# WIWIGA - Adapter Push FCM HTTP v1
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.FcmV1
# API: firebase.google.com/docs/cloud-messaging (OAuth2 service account)

defmodule GameHub.Notifications.Adapters.FcmV1 do
  @moduledoc """
  Adapter Firebase Cloud Messaging HTTP v1.

  ## Config requise
      %{
        "project_id" => "wiwiga-app",
        "service_account_json" => "{...}"  # sensible, chiffré (JSON compte de service)
      }

  Sans credentials : `{:permanent, :missing_credentials}` (le worker
  annule — à configurer depuis l'admin, puis replay).
  """

  @behaviour GameHub.Notifications.Adapters.PushAdapter

  @fcm_scope "https://www.googleapis.com/auth/firebase.messaging"

  @impl true
  def send_push(token, title, body, data, config) do
    with {:ok, project_id, access_token} <- auth(config) do
      url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"

      payload = %{
        "message" => %{
          "token" => token,
          "notification" => %{"title" => title, "body" => body},
          "data" => stringify_data(data),
          "android" => %{"priority" => "high"},
          # Navigateurs : priorité haute (défaut FCM = normale, livraison
          # potentiellement différée — inacceptable pour gains/sécurité).
          "webpush" => %{"headers" => %{"Urgency" => "high"}},
          "apns" => %{"headers" => %{"apns-priority" => "10"}}
        }
      }

      headers = [{"authorization", "Bearer #{access_token}"}]

      case post_json(url, headers, payload) do
        {:ok, %{status: 200, body: resp_body}} ->
          {:ok, %{provider_message_id: extract_name(resp_body)}}

        {:ok, %{status: 404, body: resp_body}} ->
          if token_not_registered?(resp_body) do
            {:token_invalid, token}
          else
            {:permanent, {:fcm_not_found, truncate(resp_body)}}
          end

        {:ok, %{status: status, body: resp_body}} when status in [400, 403] ->
          {:permanent, {:fcm_rejected, status, truncate(resp_body)}}

        {:ok, %{status: 429, headers: headers, body: resp_body}} ->
          {:retryable, {:rate_limited, GameHub.Notifications.Adapters.SmsAdapter.retry_after_seconds(headers || []), {:fcm_unavailable, 429, truncate(resp_body)}}}

        {:ok, %{status: status, body: resp_body}} ->
          {:retryable, {:fcm_unavailable, status, truncate(resp_body)}}

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      # Diagnostic fidèle : un échange OAuth rejeté (clé révoquée, horloge
      # désynchronisée...) ne doit pas passer pour des credentials absents.
      {:error, reason} -> {:permanent, reason}
      _ -> {:permanent, :missing_credentials}
    end
  end

  @doc """
  Publie sur un topic (1 appel pour N abonnés — broadcasts).
  """
  @spec publish_topic(String.t(), String.t(), String.t(), map(), map()) ::
          {:ok, %{provider_message_id: String.t() | nil}} | {:retryable, term()} | {:permanent, term()}
  @impl GameHub.Notifications.Adapters.PushAdapter
  def publish_topic(topic, title, body, data, config) do
    with {:ok, project_id, access_token} <- auth(config) do
      url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"

      payload = %{
        "message" => %{
          "topic" => topic,
          "notification" => %{"title" => title, "body" => body},
          "data" => stringify_data(data),
          "android" => %{"priority" => "high"},
          "webpush" => %{"headers" => %{"Urgency" => "high"}}
        }
      }

      headers = [{"authorization", "Bearer #{access_token}"}]

      case post_json(url, headers, payload) do
        {:ok, %{status: 200, body: resp_body}} ->
          {:ok, %{provider_message_id: extract_name(resp_body)}}

        {:ok, %{status: status, body: resp_body}} when status in [400, 403, 404] ->
          {:permanent, {:fcm_topic_rejected, status, truncate(resp_body)}}

        {:ok, %{status: 429, headers: resp_headers, body: resp_body}} ->
          {:retryable, {:rate_limited, GameHub.Notifications.Adapters.SmsAdapter.retry_after_seconds(resp_headers || []), {:fcm_unavailable, 429, truncate(resp_body)}}}

        {:ok, %{status: status, body: resp_body}} ->
          {:retryable, {:fcm_unavailable, status, truncate(resp_body)}}

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      {:error, reason} -> {:permanent, reason}
      _ -> {:permanent, :missing_credentials}
    end
  end

  @doc """
  Abonne/désabonne des tokens à un topic (IID, best-effort).
  Retourne `:ok` même en cas d'échec partiel (le per-token reste le repli).
  """
  @spec subscribe_topic(list(String.t()), String.t(), map()) :: :ok | {:error, term()}
  def subscribe_topic(tokens, topic, config) when is_list(tokens) and tokens != [] do
    with {:ok, _project_id, access_token} <- auth(config) do
      payload = %{"to" => "/topics/#{topic}", "registration_tokens" => tokens}

      case post_json("https://iid.googleapis.com/iid/v1:batchAdd", [{"authorization", "Bearer #{access_token}"}], payload) do
        {:ok, %{status: status}} when status in [200, 201] -> :ok
        {:ok, %{status: status}} -> {:error, {:iid_rejected, status}}
        {:error, reason} -> {:error, reason}
      end
    else
      _ -> {:error, :missing_credentials}
    end
  end

  def subscribe_topic(_, _, _), do: :ok

  @doc """
  Désabonne des tokens d'un topic (best-effort, voir subscribe_topic/3).
  """
  @spec unsubscribe_topic(list(String.t()), String.t(), map()) :: :ok | {:error, term()}
  def unsubscribe_topic(tokens, topic, config) when is_list(tokens) and tokens != [] do
    with {:ok, _project_id, access_token} <- auth(config) do
      payload = %{"to" => "/topics/#{topic}", "registration_tokens" => tokens}

      case post_json("https://iid.googleapis.com/iid/v1:batchRemove", [{"authorization", "Bearer #{access_token}"}], payload) do
        {:ok, %{status: status}} when status in [200, 201] -> :ok
        {:ok, %{status: status}} -> {:error, {:iid_rejected, status}}
        {:error, reason} -> {:error, reason}
      end
    else
      _ -> {:error, :missing_credentials}
    end
  end

  def unsubscribe_topic(_, _, _), do: :ok

  defp auth(%{"project_id" => project_id, "service_account_json" => sa_json})
       when is_binary(project_id) and is_binary(sa_json) and sa_json != "" do
    with {:ok, credentials} <- decode_service_account(sa_json),
         {:ok, access_token} <- fetch_access_token(credentials) do
      {:ok, project_id, access_token}
    end
  end

  defp auth(_), do: {:error, :missing_credentials}

  @doc """
  Santé sans réseau : valide le format des credentials (JSON + clé RSA
  signable, PKCS#8 ou PKCS#1). Ne consomme aucun quota.
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.PushAdapter
  def check_health(%{"project_id" => project_id, "service_account_json" => sa_json})
      when is_binary(project_id) and is_binary(sa_json) and sa_json != "" do
    case decode_service_account(sa_json) do
      {:ok, %{"private_key" => pem}} ->
        if rsa_key_from_pem(pem) != nil do
          {:ok, "Credentials FCM valides (envoi non testé)"}
        else
          {:error, :invalid_private_key}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl GameHub.Notifications.Adapters.PushAdapter
  def check_health(_), do: {:error, :missing_credentials}

  defp decode_service_account(sa_json) do
    case Jason.decode(sa_json) do
      {:ok, %{"client_email" => _, "private_key" => _} = creds} -> {:ok, creds}
      _ -> {:error, :invalid_service_account}
    end
  rescue
    _ -> {:error, :invalid_service_account}
  end

  defp fetch_access_token(%{"client_email" => email, "private_key" => pem}) do
    # JWT signé RS256 (OAuth2 service account), via :public_key + :httpc
    # pour éviter une dépendance supplémentaire.
    now = System.system_time(:second)

    claims = %{
      "iss" => email,
      "scope" => @fcm_scope,
      "aud" => "https://oauth2.googleapis.com/token",
      "iat" => now,
      "exp" => now + 3600
    }

    with {:ok, jwt} <- sign_jwt(claims, pem),
         {:ok, %{status: 200, body: body}} <-
           post_form(
             "https://oauth2.googleapis.com/token",
             [],
             URI.encode_query(%{"grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion" => jwt})
           ),
         {:ok, %{"access_token" => token}} <- Jason.decode(body) do
      {:ok, token}
    else
      _ -> {:error, :token_fetch_failed}
    end
  rescue
    _ -> {:error, :token_fetch_failed}
  catch
    _, _ -> {:error, :token_fetch_failed}
  end

  defp sign_jwt(claims, pem) when is_binary(pem) do
    case rsa_key_from_pem(pem) do
      nil ->
        {:error, :invalid_private_key}

      rsa_key ->
        header = Base.url_encode64(Jason.encode!(%{"alg" => "RS256", "typ" => "JWT"}), padding: false)
        payload = Base.url_encode64(Jason.encode!(claims), padding: false)
        signing_input = "#{header}.#{payload}"
        signature = :public_key.sign(signing_input, :sha256, rsa_key)
        {:ok, "#{signing_input}.#{Base.url_encode64(signature, padding: false)}"}
    end
  rescue
    _ -> {:error, :jwt_sign_failed}
  catch
    _, _ -> {:error, :jwt_sign_failed}
  end

  defp sign_jwt(_, _), do: {:error, :invalid_private_key}

  # Extrait la clé RSA d'un PEM : Google fournit du PKCS#8
  # (`BEGIN PRIVATE KEY` → entrée `PrivateKeyInfo`), certains outils du
  # PKCS#1 (`BEGIN RSA PRIVATE KEY` → entrée `RSAPrivateKey`).
  # `pem_entry_decode/1` normalise les deux vers un record RSA signable.
  @spec rsa_key_from_pem(String.t()) :: tuple() | nil
  defp rsa_key_from_pem(pem) do
    pem
    |> :public_key.pem_decode()
    |> Enum.find_value(fn
      {tag, _der, _info} = entry when tag in [:RSAPrivateKey, :PrivateKeyInfo] ->
        try do
          case :public_key.pem_entry_decode(entry) do
            {:RSAPrivateKey, _, _, _, _, _, _, _, _, _, _} = key -> key
            _ -> nil
          end
        rescue
          _ -> nil
        catch
          _, _ -> nil
        end

      _ ->
        nil
    end)
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  defp post_json(url, headers, payload) do
    Finch.build(:post, url, [{"content-type", "application/json"} | headers], Jason.encode!(payload))
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  defp post_form(url, headers, body) do
    Finch.build(:post, url, [{"content-type", "application/x-www-form-urlencoded"} | headers], body)
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  defp token_not_registered?(body) do
    String.contains?(to_string(body), ["NOT_REGISTERED", "UNREGISTERED", "INVALID_ARGUMENT"])
  end

  defp extract_name(body) do
    case Jason.decode(to_string(body)) do
      {:ok, %{"name" => name}} -> name
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp stringify_data(data) when is_map(data) do
    Map.new(data, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp stringify_data(_), do: %{}

  defp truncate(body), do: body |> to_string() |> String.slice(0, 300)
end
