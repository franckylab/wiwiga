# ==================================
# WIWIGA - Adapter Push OneSignal
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.OneSignal

defmodule GameHub.Notifications.Adapters.OneSignal do
  @moduledoc """
  Adapter OneSignal (au-dessus de FCM/APNs, segmentation côté console).

  ## Config requise
      %{
        "app_id" => "...",
        "api_key" => "..."  # REST API key, sensible, chiffré
      }
  """

  @behaviour GameHub.Notifications.Adapters.PushAdapter

  @url "https://onesignal.com/api/v1/notifications"

  @impl true
  def send_push(token, title, body, data, config) do
    with %{"app_id" => app_id, "api_key" => api_key}
         when is_binary(app_id) and is_binary(api_key) <- config do
      payload = %{
        "app_id" => app_id,
        "include_player_ids" => [token],
        "headings" => %{"en" => title, "fr" => title},
        "contents" => %{"en" => body, "fr" => body},
        "data" => data
      }

      headers = [{"authorization", "Basic #{api_key}"}]

      case post_json(@url, headers, payload) do
        {:ok, %{status: status, body: resp_body}} when status in [200, 201] ->
          handle_onesignal_response(resp_body, token)

        {:ok, %{status: 400, body: resp_body}} ->
          if invalid_player_id?(resp_body) do
            {:token_invalid, token}
          else
            {:permanent, {:onesignal_rejected, 400, truncate(resp_body)}}
          end

        {:ok, %{status: status, body: _resp_body}} when status in [401, 403] ->
          {:permanent, {:onesignal_auth_rejected, status}}

        {:ok, %{status: 429, headers: headers, body: resp_body}} ->
          {:retryable, {:rate_limited, GameHub.Notifications.Adapters.SmsAdapter.retry_after_seconds(headers || []), {:onesignal_unavailable, 429, truncate(resp_body)}}}

        {:ok, %{status: status, body: resp_body}} ->
          {:retryable, {:onesignal_unavailable, status, truncate(resp_body)}}

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      _ -> {:permanent, :missing_credentials}
    end
  end

  defp handle_onesignal_response(body, token) do
    case Jason.decode(to_string(body)) do
      {:ok, %{"errors" => %{"invalid_player_ids" => ids}}} when is_list(ids) ->
        if token in ids, do: {:token_invalid, token}, else: {:permanent, {:onesignal_errors, truncate(body)}}

      {:ok, %{"id" => id}} ->
        {:ok, %{provider_message_id: id}}

      _ ->
        {:ok, %{provider_message_id: nil}}
    end
  rescue
    _ -> {:ok, %{provider_message_id: nil}}
  end

  defp invalid_player_id?(body) do
    String.contains?(to_string(body), ["invalid_player_ids", "All included players are not subscribed"])
  end

  @doc """
  Santé sans envoi : lecture de l'app (valide app_id + clé).
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.PushAdapter
  def check_health(%{"app_id" => app_id, "api_key" => api_key})
      when is_binary(app_id) and is_binary(api_key) do
    url = "https://onesignal.com/api/v1/apps/#{app_id}"

    case post_json_get(url, api_key) do
      {:ok, %{status: 200}} -> {:ok, "App OneSignal accessible (aucun push envoyé)"}
      {:ok, %{status: status}} when status in [400, 401, 403] -> {:error, {:auth_rejected, status}}
      {:ok, %{status: status}} -> {:error, {:unreachable, status}}
      {:error, reason} -> {:error, {:unreachable, reason}}
    end
  end

  @impl GameHub.Notifications.Adapters.PushAdapter
  def check_health(_), do: {:error, :missing_credentials}

  defp post_json_get(url, api_key) do
    Finch.build(:get, url, [{"authorization", "Basic #{api_key}"}, {"Accept", "application/json"}])
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  defp post_json(url, headers, payload) do
    Finch.build(:post, url, [{"content-type", "application/json"} | headers], Jason.encode!(payload))
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  defp truncate(body), do: body |> to_string() |> String.slice(0, 300)
end
