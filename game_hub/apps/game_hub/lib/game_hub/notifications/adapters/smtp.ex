# ==================================
# WIWIGA - Adapter Email SMTP (Swoosh)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.Smtp

defmodule GameHub.Notifications.Adapters.Smtp do
  @moduledoc """
  Adapter email SMTP générique (Swoosh + gen_smtp).

  ## Config requise
      %{
        "relay" => "smtp.exemple.com",
        "port" => 587,
        "username" => "...",        # sensible, chiffré
        "password" => "...",        # sensible, chiffré
        "from" => "noreply@wiwiga.com",
        "tls" => "always"           # always | never | if_available
      }
  """

  @behaviour GameHub.Notifications.Adapters.EmailAdapter

  alias GameHub.Notifications.Adapters.EmailAdapter

  @impl true
  def send_email(to, subject, body, config) do
    with true <- EmailAdapter.valid_email?(to),
         %{"relay" => relay, "from" => from} when is_binary(relay) and is_binary(from) <- config do
      email = EmailAdapter.build_email(from, to, subject, body, email_opts(config))
      smtp_config = [
        relay: relay,
        port: Map.get(config, "port", 587),
        username: Map.get(config, "username", ""),
        password: Map.get(config, "password", ""),
        tls: tls_mode(Map.get(config, "tls", "always")),
        auth: :always,
        retries: 1
      ]

      case Swoosh.Adapters.SMTP.deliver(email, smtp_config) do
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

  defp tls_mode("never"), do: :never
  defp tls_mode("if_available"), do: :if_available
  defp tls_mode(_), do: :always

  # Options de mise en page lues depuis la config (clés `_*$` injectées
  # par ChannelDispatch, `app_url` personnalisable par provider).
  defp email_opts(config) do
    [
      category: Map.get(config, "_category", "transactional"),
      app_url: Map.get(config, "app_url", "https://wiwiga.com"),
      preferences_url: Map.get(config, "preferences_url", "https://wiwiga.com/notifications/preferences"),
      unsubscribe_mailto: Map.get(config, "unsubscribe_mailto", "unsubscribe@wiwiga.com")
    ]
  end
end
