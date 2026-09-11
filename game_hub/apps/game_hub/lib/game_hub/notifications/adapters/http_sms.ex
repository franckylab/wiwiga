# ==================================
# WIWIGA - Adapter SMS HTTP générique (eSMS Africa, MTN CM...)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.HttpSms
# Description: Adapter configurable pour tout provider SMS exposant
#              une API HTTP (eSMS Africa, MTN Developer, etc.).
#              Les chemins exacts sont lus depuis la config DB —
#              aucun endpoint deviné en dur.

defmodule GameHub.Notifications.Adapters.HttpSms do
  @moduledoc """
  Adapter SMS HTTP générique piloté par la config DB.

  ## Config
      %{
        "base_url" => "https://api.fournisseur.cm/v1/sms/send",  # requis
        "method" => "POST",            # POST (défaut) ou GET
        "auth_header" => "Bearer xxx", # sensible, chiffré (optionnel)
        "auth_query_key" => "api_key", # alternative query param (optionnel)
        "auth_query_value" => "...",   # sensible, chiffré (optionnel)
        "to_field" => "to",            # nom du champ destinataire
        "body_field" => "message",     # nom du champ message
        "sender_field" => "from",      # nom du champ expéditeur (optionnel)
        "sender_id" => "WIWIGA",       # valeur expéditeur (optionnel)
        "extra_fields" => %{},         # champs fixes supplémentaires
        "id_path" => "data/message_id" # chemin de l'ID dans la réponse JSON
      }

  ## Exemple eSMS Africa
      %{"base_url" => "<URL console eSMS>", "to_field" => "to",
        "body_field" => "message", "auth_header" => "Bearer <clé>"}
  """

  @behaviour GameHub.Notifications.Adapters.SmsAdapter

  alias GameHub.Notifications.Adapters.SmsAdapter

  @impl true
  def send_sms(to, body, config) do
    with {:ok, msisdn} <- SmsAdapter.normalize_msisdn(to),
         base_url when is_binary(base_url) and base_url != "" <- Map.get(config, "base_url") do
      payload = build_payload(msisdn, body, config)
      headers = build_headers(config)
      url = append_auth_query(base_url, config)
      method = config |> Map.get("method", "POST") |> to_string() |> String.upcase()

      result =
        case method do
          "GET" -> get_request(url <> "&" <> URI.encode_query(stringify(payload)), headers)
          _ -> SmsAdapter.post_json(url, headers, payload)
        end

      case result do
        {:ok, %{status: status, body: resp_body}} when status in [200, 201, 202] ->
          {:ok, %{provider_message_id: extract_id(resp_body, Map.get(config, "id_path", ""))}}

        {:ok, %{status: status, headers: headers, body: resp_body}} ->
          SmsAdapter.classify_response(status, headers || [], resp_body, :http_sms_rejected)

        {:error, reason} ->
          {:retryable, reason}
      end
    else
      {:error, :invalid_msisdn} -> {:permanent, :invalid_msisdn}
      _ -> {:permanent, :missing_base_url}
    end
  end

  defp build_payload(msisdn, body, config) do
    %{}
    |> Map.put(Map.get(config, "to_field", "to"), msisdn)
    |> Map.put(Map.get(config, "body_field", "message"), body)
    |> maybe_sender(config)
    |> Map.merge(Map.get(config, "extra_fields", %{}))
  end

  defp maybe_sender(payload, %{"sender_field" => field, "sender_id" => sender})
       when is_binary(field) and is_binary(sender) and sender != "" do
    Map.put(payload, field, sender)
  end

  defp maybe_sender(payload, _), do: payload

  defp build_headers(%{"auth_header" => auth}) when is_binary(auth) and auth != "" do
    [{"authorization", auth}]
  end

  defp build_headers(_), do: []

  defp append_auth_query(url, %{"auth_query_key" => key, "auth_query_value" => value})
       when is_binary(key) and is_binary(value) and value != "" do
    separator = if String.contains?(url, "?"), do: "&", else: "?"
    url <> separator <> URI.encode_query(%{key => value})
  end

  defp append_auth_query(url, _), do: url

  defp get_request(url, headers) do
    Finch.build(:get, url, headers)
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  defp extract_id(_body, ""), do: nil
  defp extract_id(_body, nil), do: nil

  defp extract_id(body, path) when is_binary(body) and is_binary(path) do
    with {:ok, decoded} <- Jason.decode(body) do
      path |> String.split("/") |> Enum.reduce(decoded, fn
        _key, nil -> nil
        key, acc when is_map(acc) -> Map.get(acc, key)
        _key, _acc -> nil
      end)
      |> case do
        id when is_binary(id) -> id
        id when is_integer(id) -> to_string(id)
        _ -> nil
      end
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp stringify(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

end
