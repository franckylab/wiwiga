# ==================================
# WIWIGA - Cache ETS Providers + Templates
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.ProviderCache
# Description: Cache ETS avec TTL, fallback hardcodé si DB indisponible

defmodule GameHub.Notifications.ProviderCache do
  @moduledoc """
  Cache ETS des providers et templates actifs.

  Pattern identique à `GameHub.GameRules` : TTL explicite,
  invalidation sur update DB, fallback hardcodé si DB indisponible.
  """

  use GenServer
  require Logger

  alias GameHub.Notifications.{Provider, Template}
  alias GameHub.Notifications.RoutingRule
  alias GameHub.Repo
  import Ecto.Query

  @table __MODULE__
  @ttl_seconds 300

  # === Templates in_app par défaut (fallback sans DB) ===
  @fallback_templates %{    "otp_login" => %{title: "Code de connexion", body_tpl: "Votre code WIWIGA : {{code}}", category: "security"},
    "wallet_credit" => %{title: "Jetons reçus", body_tpl: "+{{montant}} jetons : {{motif}}", category: "transactional"},
    "wallet_debit" => %{title: "Jetons débités", body_tpl: "-{{montant}} jetons : {{motif}}", category: "transactional"},
    "match_result" => %{title: "Résultat du match", body_tpl: "{{resultat}} : {{gain}} jetons", category: "game"},
    "friend_request" => %{title: "Demande d'ami", body_tpl: "{{pseudo}} vous a envoyé une demande d'ami", category: "social"},
    "friend_accepted" => %{title: "Ami ajouté", body_tpl: "Vous êtes maintenant amis avec {{pseudo}}", category: "social"},
    "cash_withdraw" => %{title: "Retrait effectué", body_tpl: "{{montant}} en cours de retrait vers Mobile Money", category: "transactional"},
    "achievement_unlocked" => %{title: "Succès débloqué", body_tpl: "{{nom}} (+{{xp}} XP)", category: "game"},
    "security_alert" => %{title: "Alerte sécurité", body_tpl: "{{message}}", category: "security"},
    "admin_broadcast" => %{title: "{{titre}}", body_tpl: "{{message}}", category: "transactional"},
    "promo_broadcast" => %{title: "{{titre}}", body_tpl: "{{message}}", category: "marketing"}
  }

  # === API Publique ===

  @doc """
  Démarre le cache.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Retourne le template actif pour (key, channel, locale).
  Fallback hardcodé in_app si DB indisponible.
  """
  @spec get_template(String.t(), String.t(), String.t()) :: map() | nil
  def get_template(key, channel \\ "in_app", locale \\ "fr") do
    cache_key = {:template, key, channel, locale}

    case lookup(cache_key) do
      {:hit, value} -> value
      :miss -> refresh_template(cache_key, key, channel, locale)
    end
  end

  @doc """
  Retourne les providers actifs d'un canal, triés par priorité.
  """
  @spec active_providers(String.t()) :: list(map())
  def active_providers(channel) do
    cache_key = {:providers, channel}

    case lookup(cache_key) do
      {:hit, value} -> value
      :miss -> refresh_providers(cache_key, channel)
    end
  end

  # Routage par défaut si DB vide/indisponible : inbox seule (sûr).
  # Les seeds installent les canaux riches (push...) modifiables en admin.
  @fallback_routing %{
    "otp_login" => ["in_app", "sms"],
    "wallet_credit" => ["in_app"],
    "wallet_debit" => ["in_app"],
    "cash_withdraw" => ["in_app"],
    "match_result" => ["in_app"],
    "friend_request" => ["in_app"],
    "friend_accepted" => ["in_app"],
    "achievement_unlocked" => ["in_app"],
    "security_alert" => ["in_app"],
    "admin_broadcast" => ["in_app"],
    "promo_broadcast" => ["in_app"]
  }

  @doc """
  Retourne la règle de routage d'un événement.
  `nil` si aucune ligne (repli : `%{channels: [...], is_active: true}`).
  """
  @spec get_routing(String.t()) :: map() | nil
  def get_routing(event_key) do
    cache_key = {:routing, event_key}

    case lookup(cache_key) do
      {:hit, value} -> value
      :miss -> refresh_routing(cache_key, event_key)
    end
  end

  @doc """
  Canaux de repli par événement (DB indisponible).
  """
  @spec fallback_routing(String.t()) :: list(String.t())
  def fallback_routing(event_key) do
    Map.get(@fallback_routing, event_key, ["in_app"])
  end

  @doc """
  Invalide tout le cache (après update admin).
  Fail-safe : :ok même si le cache est en redémarrage.
  """
  @spec invalidate_all() :: :ok
  def invalidate_all do
    try do
      GenServer.call(__MODULE__, :invalidate_all)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  @doc """
  Invalide une entrée (après update d'un provider/template).
  """
  @spec invalidate(tuple()) :: :ok
  def invalidate(cache_key) do
    try do
      :ets.delete(@table, cache_key)
    rescue
      _ -> :ok
    end

    :ok
  end

  # === Callbacks ===

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call(:invalidate_all, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  # === Privé ===

  defp lookup(cache_key) do
    case :ets.lookup(@table, cache_key) do
      [{_key, value, inserted_at}] ->
        if System.system_time(:second) - inserted_at < @ttl_seconds do
          {:hit, value}
        else
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp store(cache_key, value) do
    try do
      :ets.insert(@table, {cache_key, value, System.system_time(:second)})
    rescue
      ArgumentError -> :ok
    end

    value
  end

  defp refresh_template(cache_key, key, channel, locale) do
    template =
      try do
        Repo.one(
          from t in Template,
            where: t.key == ^key and t.channel == ^channel and t.locale == ^locale and t.is_active == true,
            order_by: [desc: t.version],
            limit: 1
        )
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end

    cond do
      template != nil ->
        store(cache_key, template)

      channel == "in_app" and Map.has_key?(@fallback_templates, key) ->
        # Fallback hardcodé pour l'inbox (règle ETS : fallback si DB indisponible)
        fallback = Map.fetch!(@fallback_templates, key)

        store(cache_key, %{
          key: key,
          channel: "in_app",
          locale: locale,
          version: 0,
          subject: fallback.title,
          body_tpl: fallback.body_tpl,
          required_variables: [],
          category: fallback.category,
          is_active: true
        })

      true ->
        nil
    end
  end

  defp refresh_providers(cache_key, channel) do
    providers =
      try do
        Repo.all(
          from p in Provider,
            where: p.channel == ^channel and p.is_active == true,
            order_by: [asc: p.priority, asc: p.id]
        )
      rescue
        _ -> []
      catch
        _, _ -> []
      end

    store(cache_key, providers)
  end

  defp refresh_routing(cache_key, event_key) do
    rule =
      try do
        Repo.get_by(RoutingRule, event_key: event_key)
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end

    store(cache_key, rule)
  end
end
