# ==================================
# WIWIGA - Behaviour adapters Email + helpers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.EmailAdapter

defmodule GameHub.Notifications.Adapters.EmailAdapter do
  @moduledoc """
  Contrat des adapters email (via Swoosh).

  Retour identique aux adapters SMS :
  `{:ok, %{provider_message_id}} | {:retryable, _} | {:permanent, _}`.
  """

  @callback send_email(to :: String.t(), subject :: String.t(), body :: String.t(), config :: map()) ::
              {:ok, %{provider_message_id: String.t() | nil}}
              | {:retryable, term()}
              | {:permanent, term()}

  @doc """
  Vérification sans envoi. Optionnel.
  """
  @callback check_health(config :: map()) ::
              {:ok, String.t()} | {:unknown, String.t()} | {:error, term()}

  @optional_callbacks check_health: 1

  @doc """
  Valide un email (format de base).
  """
  @spec valid_email?(String.t()) :: boolean()
  def valid_email?(email) when is_binary(email) do
    Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email)
  end

  def valid_email?(_), do: false

  @doc """
  Construit un email Swoosh texte + HTML brandé.
  Marketing : headers List-Unsubscribe (one-click, exigence Gmail).
  """
  @spec build_email(String.t(), String.t(), String.t(), String.t(), keyword()) :: Swoosh.Email.t()
  def build_email(from, to, subject, body, opts \\ []) do
    alias GameHub.Notifications.EmailLayout

    category = opts |> Keyword.get(:category, "transactional") |> to_string()
    app_url = opts |> Keyword.get(:app_url, "https://wiwiga.com") |> to_string()
    preferences_url = opts |> Keyword.get(:preferences_url, "https://wiwiga.com/notifications/preferences") |> to_string()

    email =
      Swoosh.Email.new()
      |> Swoosh.Email.from(from)
      |> Swoosh.Email.to(to)
      |> Swoosh.Email.subject(subject)
      |> Swoosh.Email.text_body(body)
      |> Swoosh.Email.html_body(EmailLayout.wrap(subject, body, category: category, app_url: app_url, preferences_url: preferences_url))

    if category == "marketing" do
      mailto = opts |> Keyword.get(:unsubscribe_mailto, "unsubscribe@wiwiga.com") |> to_string()

      Enum.reduce(EmailLayout.unsubscribe_headers(preferences_url, mailto), email, fn {name, value}, acc ->
        Swoosh.Email.header(acc, name, value)
      end)
    else
      email
    end
  end

  @doc """
  Classe une erreur Swoosh/adapters.
  """
  @spec classify_error(term()) :: {:retryable, term()} | {:permanent, term()}
  def classify_error({:error, %{reason: reason}}) when reason in [:timeout, :closed, :econnrefused], do: {:retryable, reason}
  def classify_error({:error, reason}) when is_binary(reason), do: {:permanent, reason}
  def classify_error(error), do: {:retryable, error}
end
