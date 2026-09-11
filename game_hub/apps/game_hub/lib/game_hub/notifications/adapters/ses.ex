# ==================================
# WIWIGA - Adapter Email SES (Swoosh)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.Ses

defmodule GameHub.Notifications.Adapters.Ses do
  @moduledoc """
  Adapter email Amazon SES.

  ## Config requise
      %{"access_key" => "...", "secret" => "...", "region" => "eu-west-1",
        "from" => "noreply@wiwiga.com"}  # secrets chiffrés
  """

  @behaviour GameHub.Notifications.Adapters.EmailAdapter

  alias GameHub.Notifications.Adapters.EmailAdapter

  @impl true
  def send_email(to, subject, body, config) do
    with true <- EmailAdapter.valid_email?(to),
         %{"access_key" => key, "secret" => secret, "from" => from}
         when is_binary(key) and is_binary(secret) and is_binary(from) <- config do
      email =
        EmailAdapter.build_email(from, to, subject, body,
          category: Map.get(config, "_category", "transactional"),
          app_url: Map.get(config, "app_url", "https://wiwiga.com"),
          preferences_url: Map.get(config, "preferences_url", "https://wiwiga.com/notifications/preferences"),
          unsubscribe_mailto: Map.get(config, "unsubscribe_mailto", "unsubscribe@wiwiga.com")
        )
      ses_config = [access_key: key, secret: secret, region: Map.get(config, "region", "eu-west-1")]

      case Swoosh.Adapters.AmazonSES.deliver(email, ses_config) do
        {:ok, %{id: message_id}} -> {:ok, %{provider_message_id: message_id}}
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
end
