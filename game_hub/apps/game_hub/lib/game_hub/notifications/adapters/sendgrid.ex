# ==================================
# WIWIGA - Adapter Email SendGrid (Swoosh)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.Sendgrid

defmodule GameHub.Notifications.Adapters.Sendgrid do
  @moduledoc """
  Adapter email SendGrid.

  ## Config requise
      %{"api_key" => "...", "from" => "noreply@wiwiga.com"}  # clé chiffrée
  """

  @behaviour GameHub.Notifications.Adapters.EmailAdapter

  alias GameHub.Notifications.Adapters.EmailAdapter

  @impl true
  def send_email(to, subject, body, config) do
    with true <- EmailAdapter.valid_email?(to),
         %{"api_key" => api_key, "from" => from} when is_binary(api_key) and is_binary(from) <- config do
      email =
        EmailAdapter.build_email(from, to, subject, body,
          category: Map.get(config, "_category", "transactional"),
          app_url: Map.get(config, "app_url", "https://wiwiga.com"),
          preferences_url: Map.get(config, "preferences_url", "https://wiwiga.com/notifications/preferences"),
          unsubscribe_mailto: Map.get(config, "unsubscribe_mailto", "unsubscribe@wiwiga.com")
        )

      case Swoosh.Adapters.Sendgrid.deliver(email, api_key: api_key) do
        {:ok, _} -> {:ok, %{provider_message_id: nil}}
        {:error, reason} -> EmailAdapter.classify_error({:error, reason})
      end
    else
      false -> {:permanent, :invalid_email}
      _ -> {:permanent, :missing_credentials}
    end
  rescue
    e -> {:retryable, e}
  catch
    _, e -> {:retryable, e}
  end

  @doc """
  Santé sans envoi : lecture des scopes (valide la clé API).
  """
  @spec check_health(map()) :: {:ok, String.t()} | {:error, term()}
  @impl GameHub.Notifications.Adapters.EmailAdapter
  def check_health(%{"api_key" => api_key}) when is_binary(api_key) do
    req =
      Finch.build(:get, "https://api.sendgrid.com/v3/scopes", [
        {"authorization", "Bearer #{api_key}"},
        {"Accept", "application/json"}
      ])

    case Finch.request(req, GameHub.Finch, receive_timeout: 15_000) do
      {:ok, %{status: 200}} -> {:ok, "Clé SendGrid valide (aucun email envoyé)"}
      {:ok, %{status: status}} when status in [401, 403] -> {:error, {:auth_rejected, status}}
      {:ok, %{status: status}} -> {:error, {:unreachable, status}}
      {:error, reason} -> {:error, {:unreachable, reason}}
    end
  rescue
    e -> {:error, {:unreachable, e}}
  catch
    _, e -> {:error, {:unreachable, e}}
  end

  @impl GameHub.Notifications.Adapters.EmailAdapter
  def check_health(_), do: {:error, :missing_credentials}
end
