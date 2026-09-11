# ==================================
# WIWIGA - Topics push (fan-out broadcast)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.PushTopics
# Description: Abonnements FCM ("all", "promos") + publication
#              topic pour les broadcasts (1 appel au lieu de N).
#              Tout est best-effort : le per-token reste le repli.

defmodule GameHub.Notifications.PushTopics do
  @moduledoc """
  Topics push pour les diffusions de masse.

  - `"all"` : tous les tokens (annonces transactionnelles).
  - `"promos"` : tokens des utilisateurs avec push marketing actif.
  - Les lignes inbox respectent toujours les prefs ; le topic n'est
    qu'un transport best-effort pour le push temps réel.
  """

  alias GameHub.Notifications
  alias GameHub.Notifications.Adapters

  require Logger

  @doc """
  Topic d'un événement broadcast (`nil` = envoi per-token classique).
  """
  @spec topic_for_event(String.t()) :: String.t() | nil
  def topic_for_event("admin_broadcast"), do: "all"
  def topic_for_event("promo_broadcast"), do: "promos"
  def topic_for_event(_), do: nil

  @doc """
  Publie sur le topic de l'événement via le premier provider compatible.
  `{:error, :no_topic_support}` → repli per-token par l'appelant.
  """
  @spec publish(String.t(), String.t(), String.t(), map()) ::
          {:ok, map(), String.t() | nil} | {:retryable, term()} | {:permanent, term()} | {:error, :no_topic_support}
  def publish(event_type, title, body, data \\ %{}) do
    case topic_for_event(event_type) do
      nil -> {:error, :no_topic_support}
      topic -> publish_topic(topic, title, body, data)
    end
  end

  @doc """
  Publie directement sur un topic nommé (broadcasts).
  """
  @spec publish_topic(String.t(), String.t(), String.t(), map()) ::
          {:ok, map(), String.t() | nil} | {:retryable, term()} | {:permanent, term()} | {:error, :no_topic_support}
  def publish_topic(topic, title, body, data \\ %{}) do
    providers = Notifications.active_channel_providers("push")

    Enum.find_value(providers, {:error, :no_topic_support}, fn provider ->
      with {:ok, adapter} <- Adapters.for_provider("push", provider.name),
           # Chargement explicite (code lazy en dev, voir check_provider_health).
           {:module, _} <- Code.ensure_loaded(adapter),
           true <- function_exported?(adapter, :publish_topic, 5) do
        config = Notifications.decrypted_config(provider)

        case adapter.publish_topic(topic, title, body, data, config) do
          {:ok, %{provider_message_id: message_id}} -> {:ok, provider, message_id}
          {:retryable, reason} -> {:retryable, {provider.name, reason}}
          {:permanent, reason} -> {:permanent, {provider.name, reason}}
        end
      else
        _ -> nil
      end
    end)
  end

  @doc """
  Abonne un token aux topics (best-effort, jamais d'exception).
  """
  @spec subscribe_token(String.t(), boolean()) :: :ok
  def subscribe_token(token, marketing_opt_in? \\ true) do
    with {:ok, adapter, config} <- topic_adapter() do
      safe_call(fn -> adapter.subscribe_topic([token], "all", config) end)

      if marketing_opt_in? do
        safe_call(fn -> adapter.subscribe_topic([token], "promos", config) end)
      end
    end

    :ok
  end

  @doc """
  Désabonne un token des topics (logout, token invalide).
  """
  @spec unsubscribe_token(String.t()) :: :ok
  def unsubscribe_token(token) do
    with {:ok, adapter, config} <- topic_adapter() do
      safe_call(fn -> adapter.unsubscribe_topic([token], "all", config) end)
      safe_call(fn -> adapter.unsubscribe_topic([token], "promos", config) end)
    end

    :ok
  end

  @doc """
  Resynchronise les abonnements "promos" d'un utilisateur
  (appelé sur changement de préférence marketing push).
  """
  @spec sync_promos(integer(), boolean()) :: :ok
  def sync_promos(user_id, enabled?) do
    tokens = Notifications.list_valid_device_tokens(user_id) |> Enum.map(& &1.token)

    if tokens != [] do
      with {:ok, adapter, config} <- topic_adapter() do
        if enabled? do
          safe_call(fn -> adapter.subscribe_topic(tokens, "promos", config) end)
        else
          safe_call(fn -> adapter.unsubscribe_topic(tokens, "promos", config) end)
        end
      end
    end

    :ok
  end

  defp topic_adapter do
    providers = Notifications.active_channel_providers("push")

    Enum.find_value(providers, {:error, :no_topic_support}, fn provider ->
      with {:ok, adapter} <- Adapters.for_provider("push", provider.name),
           {:module, _} <- Code.ensure_loaded(adapter),
           true <- function_exported?(adapter, :subscribe_topic, 3) do
        {:ok, adapter, Notifications.decrypted_config(provider)}
      else
        _ -> nil
      end
    end)
  end

  defp safe_call(fun) do
    fun.()
  rescue
    e ->
      Logger.debug("[PushTopics] ignoré : #{inspect(e)}")
      :ok
  catch
    _, _ -> :ok
  end
end
