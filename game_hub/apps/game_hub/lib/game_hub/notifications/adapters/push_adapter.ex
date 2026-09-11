# ==================================
# WIWIGA - Behaviour adapters Push + helpers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Adapters.PushAdapter

defmodule GameHub.Notifications.Adapters.PushAdapter do
  @moduledoc """
  Contrat des adapters push (FCM v1, OneSignal...).

  Retour :
    - `{:ok, %{provider_message_id}}` — accepté
    - `{:token_invalid, token}` — token expiré (invalider, pas de retry)
    - `{:retryable, reason}` / `{:permanent, reason}`
  """

  @callback send_push(token :: String.t(), title :: String.t(), body :: String.t(), data :: map(), config :: map()) ::
              {:ok, %{provider_message_id: String.t() | nil}}
              | {:token_invalid, String.t()}
              | {:retryable, term()}
              | {:permanent, term()}

  @doc """
  Publication topic (1 appel pour N abonnés). Optionnel.
  """
  @callback publish_topic(topic :: String.t(), title :: String.t(), body :: String.t(), data :: map(), config :: map()) ::
              {:ok, %{provider_message_id: String.t() | nil}}
              | {:retryable, term()}
              | {:permanent, term()}

  @optional_callbacks publish_topic: 5

  @doc """
  Vérification sans envoi. Optionnel.
  """
  @callback check_health(config :: map()) ::
              {:ok, String.t()} | {:unknown, String.t()} | {:error, term()}

  @optional_callbacks check_health: 1
end
