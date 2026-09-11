# ==================================
# WIWIGA - Behaviour adapters SMS + helpers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.SmsAdapter

defmodule GameHub.Notifications.Adapters.SmsAdapter do
  @moduledoc """
  Contrat des adapters SMS.

  Retour :
    - `{:ok, %{provider_message_id: id}}` — accepté par le provider
    - `{:retryable, reason}` — timeout, 5xx, 429 (worker retry/backoff)
    - `{:permanent, reason}` — 400, numéro invalide, auth rejetée (cancel)
  """

  @callback send_sms(to :: String.t(), body :: String.t(), config :: map()) ::
              {:ok, %{provider_message_id: String.t() | nil}}
              | {:retryable, term()}
              | {:permanent, term()}

  @doc """
  Vérification sans envoi (credentials, connectivité).
  Optionnel : `{:ok, détail} | {:unknown, détail} | {:error, motif}`.
  """
  @callback check_health(config :: map()) ::
              {:ok, String.t()} | {:unknown, String.t()} | {:error, term()}

  @optional_callbacks check_health: 1

  @doc """
  Normalise un numéro camerounais en E.164 `+237XXXXXXXXX`.
  Accepte `6XXXXXXXX`, `2376XXXXXXXX`, `+2376XXXXXXXX`.
  """
  @spec normalize_msisdn(String.t()) :: {:ok, String.t()} | {:error, :invalid_msisdn}
  def normalize_msisdn(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/[^0-9]/, "")

    normalized =
      cond do
        String.length(digits) == 9 -> "237" <> digits
        String.length(digits) == 12 and String.starts_with?(digits, "237") -> digits
        true -> nil
      end

    case normalized do
      nil -> {:error, :invalid_msisdn}
      msisdn -> {:ok, "+" <> msisdn}
    end
  end

  def normalize_msisdn(_), do: {:error, :invalid_msisdn}

  @doc """
  Classe un statut HTTP en retryable/permanent.
  """
  @spec classify_http_status(integer()) :: :retryable | :permanent
  def classify_http_status(status) when status == 429 or (status >= 500 and status <= 599), do: :retryable
  def classify_http_status(_), do: :permanent

  @doc """
  Classe une réponse HTTP complète : 429 → retryable avec le délai
  `Retry-After` du provider (secondes, plafonné à 900), 5xx → retryable,
  sinon permanent. `tag` qualifie la raison (ex. `:orange_rejected`).
  """
  @spec classify_response(integer(), list(), String.t(), atom()) ::
          {:retryable, term()} | {:permanent, term()}
  def classify_response(429, headers, body, tag) do
    {:retryable, {:rate_limited, retry_after_seconds(headers), {tag, 429, truncate(body)}}}
  end

  def classify_response(status, _headers, body, tag) when status >= 500 and status <= 599 do
    {:retryable, {tag, status, truncate(body)}}
  end

  def classify_response(status, _headers, body, tag) do
    {:permanent, {tag, status, truncate(body)}}
  end

  @doc """
  Lit le header `Retry-After` (secondes). Défaut 120, plafond 900.
  Les dates HTTP ne sont pas supportées (repli sur le défaut).
  """
  @spec retry_after_seconds(list()) :: pos_integer()
  def retry_after_seconds(headers) do
    headers
    |> Enum.find_value(nil, fn
      {name, value} when is_binary(name) ->
        if String.downcase(name) == "retry-after", do: to_string(value), else: nil

      _ ->
        nil
    end)
    |> parse_retry_after()
  end

  defp parse_retry_after(nil), do: 120

  defp parse_retry_after(value) do
    case Integer.parse(String.trim(value)) do
      {secs, _} when secs > 0 -> min(secs, 900)
      _ -> 120
    end
  end

  defp truncate(body) when is_binary(body), do: String.slice(body, 0, 300)
  defp truncate(_), do: ""

  @doc """
  Requête HTTP JSON via Finch (timeouts courts, pas de crash).
  """
  @spec post_json(String.t(), list(), map()) :: {:ok, Finch.Response.t()} | {:error, term()}
  def post_json(url, headers, payload) do
    body = Jason.encode!(payload)

    Finch.build(:post, url, [{"content-type", "application/json"} | headers], body)
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  @doc """
  Requête HTTP form via Finch.
  """
  @spec post_form(String.t(), list(), String.t()) :: {:ok, Finch.Response.t()} | {:error, term()}
  def post_form(url, headers, body) do
    Finch.build(:post, url, [{"content-type", "application/x-www-form-urlencoded"} | headers], body)
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  @doc """
  Requête HTTP GET via Finch.
  """
  @spec get(String.t(), list()) :: {:ok, Finch.Response.t()} | {:error, term()}
  def get(url, headers \\ []) do
    Finch.build(:get, url, headers)
    |> Finch.request(GameHub.Finch, receive_timeout: 15_000)
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end
end
