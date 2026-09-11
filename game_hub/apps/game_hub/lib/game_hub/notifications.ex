# ==================================
# WIWIGA - Module Central Notifications Multi-Canal
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications
# Description: Router central + inbox in_app + config persistante

defmodule GameHub.Notifications do
  @moduledoc """
  Service central de notifications multi-canal.

  ## Flux
      Notifications.dispatch("wallet_credit", user_id, %{"montant" => "500", "motif" => "gain"})
      # → vérifie préférences → rend template in_app → insert ACID
      # → trace delivery in_app sent → broadcast PubSub user:{id}:notifications

  Les canaux push/sms/email sont tracés en `queued` en Phase 0
  et envoyés par workers Oban en Phase 1+.
  """

  alias GameHub.Repo
  alias GameHub.Notifications.{Adapters, Delivery, DeviceToken, Notification, Preference, Provider, Template, ProviderCache, TemplateRenderer, ConfigCrypto}
  alias GameHub.Notifications.RoutingRule
  alias GameHub.Notifications.{Suppression}
  alias GameHub.Notifications.Workers.{SmsWorker, PushWorker, EmailWorker}
  import Ecto.Query

  @channels ~w(in_app push sms email)

  @channel_workers %{
    "sms" => {SmsWorker, :notifications_sms},
    "push" => {PushWorker, :notifications_push},
    "email" => {EmailWorker, :notifications_email}
  }

  # ========================================
  # Dispatcher central
  # ========================================

  @doc """
  Dispatche un événement vers un utilisateur.

  ## Options
    - `:channels` — surcharge des canaux (sinon routage admin de l'événement)
    - `:priority` — surcharge de la priorité template
    - `:event_id` — id externe pour idempotence (défaut généré)
    - `:category` — surcharge de catégorie
    - `:title` — surcharge de titre (sans template)
    - `:body` — surcharge de corps (sans template)
    - `:action` — surcharge du deep-link
    - `:to` — destinataire sms (msisdn) / email (adresse), requis pour ces canaux

  Un événement désactivé en admin retourne `{:error, :disabled}`
  (sauf `:channels` explicites, réservés aux appels internes).
  """
  @spec dispatch(String.t(), integer(), map(), keyword()) ::
          {:ok, Notification.t()} | {:error, term()}
  def dispatch(event_type, user_id, variables \\ %{}, opts \\ []) do
    explicit_channels = Keyword.get(opts, :channels)
    event_id = Keyword.get(opts, :event_id, generate_event_id())
    category_override = Keyword.get(opts, :category)
    title_override = Keyword.get(opts, :title)
    body_override = Keyword.get(opts, :body)
    recipient = Keyword.get(opts, :to)

    routing = routing_for(event_type)

    if explicit_channels == nil and not routing.is_active do
      {:error, :disabled}
    else
      channels = explicit_channels || routing.channels
      do_dispatch(event_type, user_id, variables, opts, channels, category_override, title_override, body_override, recipient, event_id)
    end
  end

  defp do_dispatch(event_type, user_id, variables, opts, channels, category_override, title_override, body_override, recipient, event_id) do
    template = ProviderCache.get_template(event_type, "in_app")
    category = category_override || template_category(template, "transactional")
    # Priorité : option > template > défaut (les templates sécurité/mkg portent la leur)
    priority = Keyword.get(opts, :priority, Map.get(template || %{}, :default_priority) || "normal")
    # Deep-link : option > template (nil = l'app décide par événement)
    action = Keyword.get(opts, :action, Map.get(template || %{}, :action))

    allowed_channels = filter_allowed_channels(user_id, category, channels)
    kept_channels = apply_rate_caps(user_id, category, allowed_channels)

    cond do
      allowed_channels == [] ->
        {:error, :opted_out}

      kept_channels == [] ->
        {:error, :rate_limited}
      true ->
        dispatch_kept(event_type, user_id, variables, template, category, kept_channels, priority, action, title_override, body_override, recipient, event_id)
    end
  end

  # Corps du dispatch une fois les canaux filtrés (préférences + caps).
  defp dispatch_kept(event_type, user_id, variables, template, category, channels, priority, action, title_override, body_override, recipient, event_id) do
      {title, body} = render_or_override(template, title_override, body_override, variables)
      idempotency_key = build_idempotency_key(event_id, user_id, event_type, "in_app")

      attrs = %{
        event_type: event_type,
        user_id: user_id,
        template_key: event_type,
        template_version: template_version(template),
        title: title,
        body: body,
        variables: variables,
        category: category,
        priority: priority,
        status: "sent",
        idempotency_key: idempotency_key,
        is_read: false,
        action: action
      }

      Repo.transaction(fn ->
        with {:ok, notification} <- insert_notification(attrs),
             :ok <- enqueue_channel_jobs(notification, channels -- ["in_app"], recipient),
             {:ok, _} <- trace_in_app_delivery(notification),
             :ok <- broadcast_notification(notification) do
          notification
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> case do
        {:ok, notification} ->
          GameHub.Notifications.Telemetry.emit([:dispatch], %{count: 1}, %{
            event_type: event_type,
            category: category,
            channels: Enum.join(channels, ",")
          })

          {:ok, notification}
        {:error, %Ecto.Changeset{} = changeset} ->
          # Idempotence : doublon → retourne l'existant
          if changeset.errors[:idempotency_key] do
            get_by_idempotency(idempotency_key)
          else
            {:error, changeset}
          end

        {:error, reason} ->
          {:error, reason}
      end
  end

  @doc """
  Diffuse une annonce admin à un lot d'utilisateurs (batch).
  Chaque envoi reste idempotent via `event_id` unique par batch.
  """
  @spec broadcast_to_users(String.t(), list(integer()), map(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def broadcast_to_users(event_type, user_ids, variables \\ %{}, opts \\ []) do
    event_id = Keyword.get(opts, :event_id, generate_event_id())

    results =
      Enum.map(user_ids, fn user_id ->
        dispatch(event_type, user_id, variables, Keyword.put(opts, :event_id, event_id))
      end)

    sent = Enum.count(results, &match?({:ok, _}, &1))
    {:ok, sent}
  end

  @doc """
  Planifie un broadcast à TOUS les utilisateurs actifs (lots bulk de 500,
  prefs re-vérifiées, heures creuses marketing, lots chaînés avec délai).

  ## Options
    - `:category` — transactional (défaut) ou marketing
    - `:scheduled_at` — DateTime UTC d'envoi (planifié, sinon immédiat)

  Retourne l'event_id du batch (idempotent, rejouable sans doublon).
  """
  @spec broadcast_to_all(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def broadcast_to_all(title, message, opts \\ []) do
    category = opts |> Keyword.get(:category, "transactional") |> to_string()

    if category not in ["transactional", "marketing"] do
      {:error, :invalid_category}
    else
      event_id = generate_event_id()

      schedule_in =
        case Keyword.get(opts, :scheduled_at) do
          %DateTime{} = at -> max(0, DateTime.diff(at, DateTime.utc_now(), :second))
          _ -> 0
        end

      %{title: title, message: message, event_id: event_id, last_id: 0, category: category}
      |> GameHub.Notifications.Workers.BroadcastWorker.new(queue: :notifications_sms, priority: 5, schedule_in: schedule_in)
      |> Oban.insert()
      |> case do
        {:ok, _job} -> {:ok, event_id}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Supprime un template (les envois passés référencent la clé en texte,
  aucune contrainte FK — sans danger).
  """
  @spec delete_template(integer()) :: {:ok, non_neg_integer()}
  def delete_template(template_id) do
    {count, _} = Repo.delete_all(from t in Template, where: t.id == ^template_id)
    ProviderCache.invalidate_all()
    {:ok, count}
  end

  @doc """
  Supprime un provider (deliveries passées conservées, provider_id annulé
  via on_delete nilify — sans danger).
  """
  @spec delete_provider(integer()) :: {:ok, non_neg_integer()}
  def delete_provider(provider_id) do
    {count, _} = Repo.delete_all(from p in Provider, where: p.id == ^provider_id)
    ProviderCache.invalidate_all()
    {:ok, count}
  end

  # ========================================
  # Routage événements → canaux (admin)
  # ========================================

  # Canaux riches installés par les seeds (modifiables en admin).
  # Repli sans DB : inbox seule (voir ProviderCache.fallback_routing/1).
  @seed_routing %{
    "otp_login" => ["in_app", "sms"],
    "wallet_credit" => ["in_app", "push"],
    "wallet_debit" => ["in_app", "push"],
    "cash_withdraw" => ["in_app", "push"],
    "match_result" => ["in_app", "push"],
    "friend_request" => ["in_app", "push"],
    "friend_accepted" => ["in_app", "push"],
    "achievement_unlocked" => ["in_app", "push"],
    "security_alert" => ["in_app", "push"],
    "admin_broadcast" => ["in_app", "push"],
    "promo_broadcast" => ["in_app"]
  }

  @doc """
  Règle de routage effective d'un événement :
  `%{channels: [...], is_active: bool}` (repli inbox si aucune ligne).
  """
  @spec routing_for(String.t()) :: %{channels: list(String.t()), is_active: boolean()}
  def routing_for(event_key) do
    case ProviderCache.get_routing(event_key) do
      %{channels: channels, is_active: active} -> %{channels: channels || ["in_app"], is_active: active != false}
      nil -> %{channels: ProviderCache.fallback_routing(event_key), is_active: true}
    end
  end

  @doc """
  Liste les règles de routage (lignes DB + événements sans ligne).
  """
  @spec list_routing() :: list(map())
  def list_routing do
    stored = Repo.all(RoutingRule) |> Map.new(fn r -> {r.event_key, r} end)

    @seed_routing
    |> Map.keys()
    |> Enum.map(fn event_key ->
      case Map.get(stored, event_key) do
        nil ->
          %{event_key: event_key, channels: ProviderCache.fallback_routing(event_key), is_active: true, customized: false}

        rule ->
          %{event_key: rule.event_key, channels: rule.channels, is_active: rule.is_active, customized: true, id: rule.id}
      end
    end)
    |> Enum.sort_by(& &1.event_key)
  end

  @doc """
  Crée ou met à jour la règle d'un événement puis invalide le cache.
  """
  @spec upsert_routing(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def upsert_routing(event_key, attrs) when is_binary(event_key) do
    attrs = attrs |> stringify_map() |> Map.put("event_key", event_key)

    result =
      case Repo.get_by(RoutingRule, event_key: event_key) do
        nil -> %RoutingRule{} |> RoutingRule.changeset(attrs) |> Repo.insert()
        rule -> rule |> RoutingRule.changeset(attrs) |> Repo.update()
      end

    case result do
      {:ok, rule} ->
        ProviderCache.invalidate_all()
        {:ok, %{event_key: rule.event_key, channels: rule.channels, is_active: rule.is_active, customized: true, id: rule.id}}

      error ->
        error
    end
  end

  # ========================================
  # Inbox joueur
  # ========================================

  @doc """
  Liste les notifications d'un utilisateur (pagination, max 50).
  """
  @spec list_for_user(integer(), map()) :: {:ok, list(), integer()}
  def list_for_user(user_id, params \\ %{}) do
    page = params |> Map.get("page", "1") |> to_integer(1) |> max(1)
    limit = params |> Map.get("limit", "20") |> to_integer(20) |> min(50)
    offset = (page - 1) * limit

    base = from n in Notification, where: n.user_id == ^user_id, order_by: [desc: n.inserted_at]

    base =
      case Map.get(params, "is_read") do
        "true" -> from n in base, where: n.is_read == true
        "false" -> from n in base, where: n.is_read == false
        _ -> base
      end

    base =
      case Map.get(params, "category") do
        nil -> base
        category -> from n in base, where: n.category == ^category
      end

    base =
      case Map.get(params, "q") do
        nil -> base
        "" -> base
        query ->
          pattern = "%#{String.replace(query, ~r/[%_]/, "")}%"
          from n in base, where: ilike(n.title, ^pattern) or ilike(n.body, ^pattern)
      end

    total = base |> Ecto.Query.exclude(:order_by) |> then(fn q -> Repo.one(from n in q, select: count(n.id)) end) || 0
    items = Repo.all(from n in base, limit: ^limit, offset: ^offset)
    {:ok, items, total || 0}
  end

  @doc """
  Compteur de non-lues d'un utilisateur.
  """
  @spec unread_count(integer()) :: non_neg_integer()
  def unread_count(user_id) do
    Repo.one(from n in Notification, where: n.user_id == ^user_id and n.is_read == false, select: count(n.id)) || 0
  end

  @doc """
  Marque une notification comme lue (vérifie la propriété).
  """
  @spec mark_read(integer(), integer()) :: {:ok, Notification.t()} | {:error, term()}
  def mark_read(user_id, notification_id) do
    case Repo.get_by(Notification, id: notification_id, user_id: user_id) do
      nil -> {:error, :not_found}
      notification -> notification |> Notification.mark_read_changeset() |> Repo.update()
    end
  end

  @doc """
  Marque toute l'inbox comme lue.
  """
  @spec mark_all_read(integer()) :: {:ok, non_neg_integer()}
  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {count, _} = Repo.update_all(from(n in Notification, where: n.user_id == ^user_id and n.is_read == false), set: [is_read: true, read_at: now])
    {:ok, count}
  end

  @doc """
  Supprime une notification de l'inbox (vérifie la propriété).
  Les tentatives sont supprimées en cascade (FK).
  """
  @spec delete_notification(integer(), integer()) :: {:ok, non_neg_integer()}
  def delete_notification(user_id, notification_id) do
    {count, _} = Repo.delete_all(from n in Notification, where: n.user_id == ^user_id and n.id == ^notification_id)
    {:ok, count}
  end

  # ========================================
  # Préférences
  # ========================================

  @doc """
  Liste les préférences d'un utilisateur.
  """
  @spec list_preferences(integer()) :: list(Preference.t())
  def list_preferences(user_id) do
    Repo.all(from p in Preference, where: p.user_id == ^user_id)
  end

  @doc """
  Active/désactive un canal pour une catégorie (security forcée à true).
  Un changement marketing/push resynchronise le topic `promos`.
  """
  @spec upsert_preference(integer(), String.t(), String.t(), boolean()) ::
          {:ok, Preference.t()} | {:error, term()}
  def upsert_preference(user_id, category, channel, enabled) do
    result =
      case Repo.get_by(Preference, user_id: user_id, category: category, channel: channel) do
        nil ->
          %Preference{}
          |> Preference.changeset(%{user_id: user_id, category: category, channel: channel, enabled: enabled})
          |> Repo.insert()

        preference ->
          preference
          |> Preference.changeset(%{enabled: enabled})
          |> Repo.update()
      end

    case result do
      {:ok, pref} ->
        if category == "marketing" and channel == "push" do
          GameHub.Notifications.PushTopics.sync_promos(user_id, pref.enabled)
        end

        {:ok, pref}

      error ->
        error
    end
  end

  # Préférence effective (défaut true, security toujours true).
  defp preference_enabled?(user_id, category, channel) do
    case Repo.get_by(Preference, user_id: user_id, category: category, channel: channel) do
      %{enabled: enabled} -> enabled != false
      nil -> true
    end
  rescue
    _ -> true
  catch
    _, _ -> true
  end

  # ========================================
  # Device tokens (push)
  # ========================================

  @doc """
  Enregistre un token push (upsert par token).
  Abonne aux topics `all` (+ `promos` si marketing push actif).
  """
  @spec register_device_token(integer(), String.t(), String.t(), String.t() | nil) ::
          {:ok, DeviceToken.t()} | {:error, term()}
  def register_device_token(user_id, platform, token, app_version \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      case Repo.get_by(DeviceToken, token: token) do
        nil ->
          %DeviceToken{}
          |> DeviceToken.changeset(%{user_id: user_id, platform: platform, token: token, app_version: app_version, last_seen_at: now, is_valid: true})
          |> Repo.insert()

        existing ->
          existing
          |> DeviceToken.changeset(%{user_id: user_id, platform: platform, app_version: app_version, last_seen_at: now, is_valid: true})
          |> Repo.update()
      end

    case result do
      {:ok, device} ->
        marketing_push? = preference_enabled?(user_id, "marketing", "push")
        GameHub.Notifications.PushTopics.subscribe_token(token, marketing_push?)
        {:ok, device}

      error ->
        error
    end
  end

  @doc """
  Supprime un token push (logout / désinscription).
  Désabonne des topics au passage.
  """
  @spec unregister_device_token(String.t()) :: {:ok, non_neg_integer()}
  def unregister_device_token(token) do
    GameHub.Notifications.PushTopics.unsubscribe_token(token)
    {count, _} = Repo.delete_all(from d in DeviceToken, where: d.token == ^token)
    {:ok, count}
  end

  @doc """
  Invalide un token (retour provider NotRegistered).
  Désabonne des topics au passage.
  """
  @spec invalidate_device_token(String.t()) :: {:ok, DeviceToken.t()} | {:error, term()}
  def invalidate_device_token(token) do
    GameHub.Notifications.PushTopics.unsubscribe_token(token)

    case Repo.get_by(DeviceToken, token: token) do
      nil -> {:error, :not_found}
      device -> device |> DeviceToken.invalidate_changeset() |> Repo.update()
    end
  end

  @doc """
  Retourne une notification par ID.
  """
  @spec get_notification(integer()) :: Notification.t() | nil
  def get_notification(notification_id) do
    Repo.get(Notification, notification_id)
  end

  @doc """
  Locale d'un utilisateur (préférences `locale`/`language`, défaut `fr`).
  Seules `fr`/`en` sont reconnues, le reste retombe sur `fr`.
  """
  @spec user_locale(integer()) :: String.t()
  def user_locale(user_id) do
    case Repo.get(GameHub.Users.User, user_id) do
      %{preferences: %{"locale" => locale}} when locale in ["fr", "en"] -> locale
      %{preferences: %{"language" => locale}} when locale in ["fr", "en"] -> locale
      %{preferences: %{locale: locale}} when locale in ["fr", "en"] -> locale
      %{preferences: %{language: locale}} when locale in ["fr", "en"] -> locale
      _ -> "fr"
    end
  rescue
    _ -> "fr"
  catch
    _, _ -> "fr"
  end

  @doc """
  Rend titre + corps pour un canal (`sms`/`push`/`email`/`in_app`).
  Chaîne de repli : (clé, canal, locale) → (clé, canal, fr) → `:fallback`.
  """
  @spec render_for_channel(String.t(), String.t(), map(), String.t()) ::
          {:ok, String.t(), String.t()} | {:error, :no_template}
  def render_for_channel(event_key, channel, variables, locale \\ "fr") do
    template =
      ProviderCache.get_template(event_key, channel, locale) ||
        if locale != "fr" do
          ProviderCache.get_template(event_key, channel, "fr")
        end

    case template do
      nil ->
        {:error, :no_template}

      template ->
        {title, body} = render_or_override(template, nil, nil, variables)
        {:ok, title, body}
    end
  end

  @doc """
  Variables requises (union tous canaux/locales) pour une clé d'événement.
  Pilote l'aide à l'édition côté admin.
  """
  @spec template_variables(String.t()) :: list(String.t())
  def template_variables(event_key) do
    from(t in Template,
      where: t.key == ^event_key and t.is_active == true,
      select: t.required_variables
    )
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  @doc """
  Retourne la tentative d'un canal pour une notification.
  """
  @spec get_channel_delivery(integer(), String.t()) :: Delivery.t() | nil
  def get_channel_delivery(notification_id, channel) do
    Repo.get_by(Delivery, notification_id: notification_id, channel: channel)
  end

  @doc """
  Met à jour une tentative de livraison.
  Émet la télémétrie `[:delivery]` (canal, statut, provider).
  """
  @spec update_delivery(Delivery.t(), map()) :: {:ok, Delivery.t()} | {:error, Ecto.Changeset.t()}
  def update_delivery(%Delivery{} = delivery, attrs) do
    case delivery |> Delivery.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        GameHub.Notifications.Telemetry.emit([:delivery], %{count: 1}, %{
          channel: updated.channel,
          status: updated.status,
          provider: updated.provider_name
        })

        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Liste les tokens push valides d'un utilisateur.
  """
  @spec list_valid_device_tokens(integer()) :: list(DeviceToken.t())
  def list_valid_device_tokens(user_id) do
    Repo.all(from d in DeviceToken, where: d.user_id == ^user_id and d.is_valid == true)
  end

  # ========================================
  # Suppressions (opt-out définitif)
  # ========================================

  @doc """
  Ajoute une valeur à la liste de suppression (idempotent).
  """
  @spec suppress(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Suppression.t()} | {:error, term()}
  def suppress(channel, value, reason, source) do
    %Suppression{}
    |> Suppression.changeset(%{channel: channel, value: value, reason: reason, source: source})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Retire une valeur (réinscription explicite START/YES).
  """
  @spec unsuppress(String.t(), String.t()) :: {:ok, non_neg_integer()}
  def unsuppress(channel, value) do
    normalized = value |> to_string() |> String.trim() |> String.downcase()
    {count, _} = Repo.delete_all(from s in Suppression, where: s.channel == ^channel and s.value == ^normalized)
    {:ok, count}
  end

  @doc """
  Vérifie la suppression. Sécurité exemptée (un STOP marketing ne bloque
  jamais un OTP). Fail-open si la base est injoignable (disponibilité OTP).
  """
  @spec suppressed?(String.t(), String.t(), String.t()) :: boolean()
  def suppressed?(_channel, _value, "security"), do: false

  def suppressed?(channel, value, _category) when channel in ["sms", "email"] do
    normalized = value |> to_string() |> String.trim() |> String.downcase()
    Repo.exists?(from s in Suppression, where: s.channel == ^channel and s.value == ^normalized)
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  def suppressed?(_, _, _), do: false

  @doc """
  Marque une livraison comme reçue (webhook DLR provider).
  """
  @spec mark_delivered(String.t(), String.t()) :: {:ok, Delivery.t()} | {:error, term()}
  def mark_delivered(provider_name, provider_message_id) do
    case Repo.get_by(Delivery, provider_name: provider_name, provider_message_id: provider_message_id) do
      nil -> {:error, :not_found}
      delivery -> update_delivery(delivery, %{status: "delivered", delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    end
  end

  @doc """
  Marque une livraison comme échouée définitivement (webhook DLR provider).
  """
  @spec mark_delivery_failed(String.t(), String.t(), String.t()) :: {:ok, Delivery.t()} | {:error, term()}
  def mark_delivery_failed(provider_name, provider_message_id, error_message) do
    case Repo.get_by(Delivery, provider_name: provider_name, provider_message_id: provider_message_id) do
      nil -> {:error, :not_found}
      delivery -> update_delivery(delivery, %{status: "failed", error_message: error_message})
    end
  end

  # ========================================
  # Admin — Providers (config centralisée)
  # ========================================

  @doc """
  Liste les providers avec filtres.
  Enrichit chaque provider de compteurs de config (sans les valeurs) :
  `config_keys` (clés présentes) et `secrets_set` (secrets renseignés).
  """
  @spec list_providers(map()) :: list(Provider.t())
  def list_providers(filters \\ %{}) do
    base = from p in Provider, order_by: [asc: p.channel, asc: p.priority, asc: p.id]

    base =
      case Map.get(filters, "channel") do
        nil -> base
        channel -> from p in base, where: p.channel == ^channel
      end

    base =
      case Map.get(filters, "is_active") do
        "true" -> from p in base, where: p.is_active == true
        "false" -> from p in base, where: p.is_active == false
        _ -> base
      end

    base
    |> Repo.all()
    |> Enum.map(&with_config_counts/1)
  end

  @doc """
  Providers actifs d'un canal via cache ETS (hot-path envois).
  Même forme que `list_providers/1`, sans requête DB (TTL 5 min,
  invalidé à chaque changement admin).
  """
  @spec active_channel_providers(String.t()) :: list(Provider.t())
  def active_channel_providers(channel) do
    ProviderCache.active_providers(channel)
    |> Enum.map(&with_config_counts/1)
  rescue
    _ -> list_providers(%{"channel" => channel, "is_active" => "true"})
  catch
    _, _ -> list_providers(%{"channel" => channel, "is_active" => "true"})
  end

  # Compteurs non sensibles pour l'admin (jamais de valeurs).
  defp with_config_counts(%Provider{} = provider) do    stored = provider.config || %{}
    decrypted = ConfigCrypto.decrypt_config(stored)
    sensitive = schema_sensitive_keys(provider.name, stored)

    secrets_set =
      Enum.count(sensitive, fn key ->
        case Map.get(decrypted, key) do
          nil -> false
          "" -> false
          _ -> true
        end
      end)

    %{provider | config_keys: map_size(stored), secrets_set: secrets_set}
  end

  @doc """
  Crée un provider puis invalide le cache.
  Les secrets de `config` sont chiffrés avant stockage (heuristique
  de nom + champs sensibles du schéma du provider).
  """
  @spec create_provider(map()) :: {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def create_provider(attrs) do
    stringified = stringify_map(attrs)
    sensitive = schema_sensitive_keys(Map.get(stringified, "name", ""), Map.get(stringified, "config", %{}))

    case %Provider{} |> Provider.changeset(encrypt_config_attr(stringified, sensitive)) |> Repo.insert() do
      {:ok, provider} -> ProviderCache.invalidate_all(); {:ok, provider}
      error -> error
    end
  end

  @doc """
  Met à jour un provider puis invalide le cache.
  Les secrets de `config` sont chiffrés avant stockage.
  """
  @spec update_provider(integer(), map()) :: {:ok, Provider.t()} | {:error, term()}
  def update_provider(provider_id, attrs) do
    case Repo.get(Provider, provider_id) do
      nil ->
        {:error, :not_found}

      provider ->
        stringified = stringify_map(attrs)
        sensitive = schema_sensitive_keys(provider.name, Map.get(stringified, "config", provider.config || %{}))

        case provider |> Provider.changeset(encrypt_config_attr(stringified, sensitive)) |> Repo.update() do
          {:ok, updated} -> ProviderCache.invalidate_all(); {:ok, updated}
          error -> error
        end
    end
  end

  @doc """
  Retourne la config déchiffrée d'un provider (usage adapters uniquement,
  ne jamais logger ni exposer via API).
  """
  @spec decrypted_config(Provider.t()) :: map()
  def decrypted_config(%Provider{config: config}) do
    ConfigCrypto.decrypt_config(config || %{})
  end

  # Schémas des champs de config par provider (pilotent le formulaire admin).
  # sensitive: masqué à la lecture, vide = conserver la valeur existante.
  @config_schemas %{
    "orange_cm" => [
      %{key: "client_id", label: "Client ID", sensitive: true, required: true},
      %{key: "client_secret", label: "Client secret", sensitive: true, required: true},
      %{key: "sender_address", label: "Adresse d'envoi", sensitive: false, required: true, help: "Ex. tel:+237690000000 (pré-enregistrée)"},
      %{key: "sender_name", label: "Nom d'envoi", sensitive: false, required: false, default: "WIWIGA"}
    ],
    "africas_talking" => [
      %{key: "username", label: "Username", sensitive: false, required: true},
      %{key: "api_key", label: "Clé API", sensitive: true, required: true},
      %{key: "sender_id", label: "Sender ID", sensitive: false, required: false}
    ],
    "esms_africa" => [
      %{key: "base_url", label: "URL d'envoi", sensitive: false, required: true, help: "URL exacte de la console eSMS"},
      %{key: "to_field", label: "Champ destinataire", sensitive: false, required: false, default: "to"},
      %{key: "body_field", label: "Champ message", sensitive: false, required: false, default: "message"},
      %{key: "sender_field", label: "Champ expéditeur", sensitive: false, required: false},
      %{key: "sender_id", label: "Expéditeur", sensitive: false, required: false},
      %{key: "auth_header", label: "Header auth", sensitive: true, required: false, help: "Ex. Bearer ..."},
      %{key: "id_path", label: "Chemin de l'ID", sensitive: false, required: false, help: "Ex. data/message_id"}
    ],
    "mtn_cm" => [
      %{key: "base_url", label: "URL d'envoi", sensitive: false, required: true, help: "URL exacte du portail MTN"},
      %{key: "to_field", label: "Champ destinataire", sensitive: false, required: false, default: "to"},
      %{key: "body_field", label: "Champ message", sensitive: false, required: false, default: "message"},
      %{key: "sender_field", label: "Champ expéditeur", sensitive: false, required: false},
      %{key: "sender_id", label: "Expéditeur", sensitive: false, required: false},
      %{key: "auth_header", label: "Header auth", sensitive: true, required: false},
      %{key: "id_path", label: "Chemin de l'ID", sensitive: false, required: false}
    ],
    "twilio" => [
      %{key: "account_sid", label: "Account SID", sensitive: true, required: true},
      %{key: "auth_token", label: "Auth token", sensitive: true, required: true},
      %{key: "from", label: "Expéditeur", sensitive: false, required: true}
    ],
    "fcm_v1" => [
      %{key: "project_id", label: "Project ID", sensitive: false, required: true},
      %{key: "service_account_json", label: "Compte de service (JSON)", sensitive: true, required: true, multiline: true}
    ],
    "onesignal" => [
      %{key: "app_id", label: "App ID", sensitive: false, required: true},
      %{key: "api_key", label: "REST API key", sensitive: true, required: true}
    ],
    "smtp" => [
      %{key: "relay", label: "Serveur SMTP", sensitive: false, required: true},
      %{key: "port", label: "Port", sensitive: false, required: false, default: "587"},
      %{key: "username", label: "Utilisateur", sensitive: false, required: false},
      %{key: "password", label: "Mot de passe", sensitive: true, required: false},
      %{key: "from", label: "Expéditeur", sensitive: false, required: true},
      %{key: "tls", label: "TLS", sensitive: false, required: false, default: "always"}
    ],
    "sendgrid" => [
      %{key: "api_key", label: "Clé API", sensitive: true, required: true},
      %{key: "from", label: "Expéditeur", sensitive: false, required: true}
    ],
    "ses" => [
      %{key: "access_key", label: "Access key", sensitive: true, required: true},
      %{key: "secret", label: "Secret", sensitive: true, required: true},
      %{key: "region", label: "Région", sensitive: false, required: false, default: "eu-west-1"},
      %{key: "from", label: "Expéditeur", sensitive: false, required: true}
    ]
  }

  @doc """
  Schéma des champs de config d'un provider (formulaire admin).
  Provider inconnu : schéma générique déduit des clés stockées.
  """
  @spec provider_config_schema(String.t(), map()) :: list(map())
  def provider_config_schema(name, stored_config \\ %{}) do
    case Map.get(@config_schemas, name) do
      nil ->
        stored_config
        |> Map.keys()
        |> Enum.map(fn key ->
          %{key: to_string(key), label: to_string(key), sensitive: ConfigCrypto.sensitive_key?(to_string(key)), required: false}
        end)

      fields ->
        fields
    end
  end

  @doc """
  Config assainie pour l'admin : valeurs en clair sauf secrets
  (remplacés par `%{set: bool, hint: ...}`, vide = conserver).
  `hint` décrit le secret configuré SANS l'exposer (ex. compte de
  service FCM) pour que l'admin voie ce qui est enregistré.
  """
  @spec get_provider_config(integer()) :: {:ok, map()} | {:error, term()}
  def get_provider_config(provider_id) do
    case Repo.get(Provider, provider_id) do
      nil ->
        {:error, :not_found}

      provider ->
        stored = provider.config || %{}
        decrypted = ConfigCrypto.decrypt_config(stored)

        fields =
          provider_config_schema(provider.name, stored)
          |> Enum.map(fn field ->
            key = field.key
            raw = Map.get(decrypted, key)

            if Map.get(field, :sensitive, false) do
              Map.merge(field, %{
                value: "",
                set: raw not in [nil, ""],
                hint: secret_hint(provider.name, key, raw)
              })
            else
              default = Map.get(field, :default)
              Map.merge(field, %{value: to_string(raw || default || ""), set: raw not in [nil, ""]})
            end
          end)

        {:ok, %{provider_id: provider.id, channel: provider.channel, name: provider.name, fields: fields}}
    end
  end

  # Aperçu non secret d'un secret configuré (nil si non renseigné).
  # Ne retourne JAMAIS la valeur : métadonnées publiques uniquement.
  @spec secret_hint(String.t(), String.t(), term()) :: String.t() | nil
  defp secret_hint("fcm_v1", "service_account_json", raw) when is_binary(raw) and raw != "" do
    case Jason.decode(raw) do
      {:ok, %{"client_email" => email} = creds} when is_binary(email) and email != "" ->
        key_id = creds |> Map.get("private_key_id", "") |> to_string()
        short = key_id |> String.slice(-6..-1//1)
        suffix = if short == "", do: "", else: " (clé …#{short})"
        "Configuré : #{email}#{suffix} — coller un nouveau JSON pour remplacer"

      _ ->
        "Configuré (JSON illisible — remplacez-le)"
    end
  end

  defp secret_hint(_, _, raw) when is_binary(raw) and raw != "" do
    "Configuré — laisser vide pour conserver"
  end

  defp secret_hint(_, _, _), do: nil

  @doc """
  Fusionne une config partielle (secrets vides = conserver l'existant).
  """
  @spec update_provider_config(integer(), map()) :: {:ok, map()} | {:error, term()}
  def update_provider_config(provider_id, params) when is_map(params) do
    case Repo.get(Provider, provider_id) do
      nil ->
        {:error, :not_found}

      provider ->
        stored = ConfigCrypto.decrypt_config(provider.config || %{})
        schema = provider_config_schema(provider.name, stored)
        sensitive_keys = for f <- schema, Map.get(f, :sensitive, false), do: f.key

        merged =
          Enum.reduce(stringify_map(params), stored, fn {key, value}, acc ->
            cond do
              key in sensitive_keys and to_string(value || "") == "" -> acc
              true -> Map.put(acc, key, value)
            end
          end)

        case update_provider(provider_id, %{"config" => merged}) do
          {:ok, updated} -> get_provider_config(updated.id)
          error -> error
        end
    end
  end

  defp stringify_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  # Le rejet FCM concerne-t-il le destinataire (token inconnu/expiré/
  # malformé) plutôt que la configuration ? Dans ce cas la connexion
  # est prouvée fonctionnelle (authentification OK).
  @spec fcm_token_issue?(term()) :: boolean()
  defp fcm_token_issue?(body) do
    text = to_string(body)
    String.contains?(text, ["NOT_REGISTERED", "UNREGISTERED", "INVALID_ARGUMENT"])
  end

  # Token d'un autre projet Firebase (mismatch expéditeur) : la connexion
  # est OK, c'est l'appareil qui n'est pas sur le bon projet.
  @spec fcm_sender_mismatch?(term()) :: boolean()
  defp fcm_sender_mismatch?(body) do
    body |> to_string() |> String.contains?("SENDER_ID_MISMATCH")
  end

  # Message d'erreur lisible extrait de la réponse FCM (tronqué).
  # La réponse est souvent déjà tronquée par l'adapter (JSON incomplet) :
  # repli regex sur le champ "message" avant le brut.
  @spec fcm_error_message(term()) :: String.t()
  defp fcm_error_message(body) do
    text = to_string(body)

    case Jason.decode(text) do
      {:ok, %{"error" => %{"message" => message}}} when is_binary(message) ->
        String.slice(message, 0, 200)

      _ ->
        case Regex.run(~r/"message"\s*:\s*"((?:[^"\\]|\\.)*)"/, text, capture: :all_but_first) do
          [message] -> message |> String.replace(~r/\\"/, "\"") |> String.slice(0, 200)
          _ -> String.slice(text, 0, 200)
        end
    end
  rescue
    _ -> "destinataire invalide"
  catch
    _, _ -> "destinataire invalide"
  end

  @doc """
  Vérifie la santé d'un provider SANS envoyer de message.
  Persiste `last_health_check_at/status` (`healthy`/`down`/`unchecked`)
  et `last_error`. Retourne le détail lisible pour l'admin.
  """
  @spec check_provider_health(integer()) :: {:ok, map()} | {:error, term()}
  def check_provider_health(provider_id) do
    case Repo.get(Provider, provider_id) do
      nil ->
        {:error, :not_found}

      %{is_active: false} ->
        {:error, :provider_inactive}

      provider ->
        config = decrypted_config(provider)
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        result =
          with {:ok, adapter} <- Adapters.for_provider(provider.channel, provider.name),
               # Chargement explicite : en dev (code lazy) l'adapter peut ne
               # pas être chargé, et function_exported?/3 répondrait false.
               {:module, _} <- Code.ensure_loaded(adapter),
               true <- function_exported?(adapter, :check_health, 1) do
            adapter.check_health(config)
          else
            _ -> {:unknown, "vérification non supportée — utiliser Tester (envoi réel)"}
          end

        persist_health(provider, now, result)
    end
  end

  # Persiste le résultat du health-check (best-effort, jamais d'exception).
  defp persist_health(provider, now, result) do
    {status, detail, error} =
      case result do
        {:ok, detail} -> {"healthy", to_string(detail), nil}
        {:unknown, detail} -> {"unchecked", to_string(detail), nil}
        {:error, reason} -> {"down", nil, reason |> inspect() |> String.slice(0, 500)}
      end

    provider
    |> Provider.health_changeset(%{last_health_check_at: now, last_health_status: status, last_error: error})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, %{status: updated.last_health_status, detail: detail, checked_at: now}}
      {:error, _} -> {:ok, %{status: status, detail: detail, checked_at: now}}
    end
  end

  @doc """
  Teste la connexion d'un provider par un envoi réel.
  In-App : toujours disponible. Push : `recipient` = token de test.

  Sémantique des retours (bouton Tester de l'admin) :
  - `{:ok, %{status: "sent"}}` : message accepté.
  - `{:ok, %{status: "token_invalid" | "rejected"}}` : la connexion au
    provider FONCTIONNE (authentification OK, réponse du service reçue),
    mais le destinataire test est rejeté — utiliser le token d'un
    appareil connecté. Retourné en 200, pas en erreur.
  - `{:error, _}` : problème provider/config/réseau (bouton Santé + logs).
  """
  @spec test_provider(integer(), map()) :: {:ok, map()} | {:error, term()}
  def test_provider(provider_id, params \\ %{}) do
    case Repo.get(Provider, provider_id) do
      nil ->
        {:error, :not_found}

      %{is_active: false} ->
        {:error, :provider_inactive}

      %{channel: "in_app"} ->
        {:ok, %{status: "ok", detail: "Canal in_app toujours disponible"}}

      %{channel: channel} = provider ->
        # Espaces seuls = destinataire absent (le navigateur peut envoyer " ").
        recipient = params |> Map.get("recipient", Map.get(params, :recipient, "")) |> to_string() |> String.trim()

        if recipient == "" do
          {:error, :recipient_required}
        else
          config = decrypted_config(provider)

          result =
            case channel do
              "sms" ->
                with {:ok, adapter} <- Adapters.for_provider("sms", provider.name) do
                  adapter.send_sms(recipient, "WIWIGA test : connexion OK", config)
                end

              "email" ->
                with {:ok, adapter} <- Adapters.for_provider("email", provider.name) do
                  adapter.send_email(recipient, "WIWIGA : test de connexion", "Ce message confirme que le provider email fonctionne.", config)
                end

              "push" ->
                with {:ok, adapter} <- Adapters.for_provider("push", provider.name) do
                  adapter.send_push(recipient, "WIWIGA", "Test de connexion OK", %{"test" => "true"}, config)
                end

              _ ->
                {:error, :unknown_channel}
            end

          case result do
            {:ok, %{provider_message_id: message_id}} ->
              {:ok, %{status: "sent", detail: "Message test accepté", provider_message_id: message_id, provider: provider.name}}

            # Le service a répondu : la connexion fonctionne, seul le
            # destinataire test est en cause (token inconnu/expiré/malformé).
            {:token_invalid, _} ->
              {:ok,
               %{
                 status: "token_invalid",
                 detail:
                   "Connexion #{provider.name} OK (service joint), mais le destinataire test est invalide ou expiré. Utilisez le token FCM d'un appareil connecté.",
                 provider: provider.name
               }}

            {:permanent, {:fcm_rejected, status, body}} ->
              cond do
                fcm_token_issue?(body) ->
                  {:ok,
                   %{
                     status: "rejected",
                     detail:
                       "Connexion FCM OK (code #{status}), destinataire rejeté : #{fcm_error_message(body)}. Utilisez le token FCM d'un appareil connecté.",
                     provider: provider.name
                   }}

                fcm_sender_mismatch?(body) ->
                  {:ok,
                   %{
                     status: "sender_mismatch",
                     detail:
                       "Connexion FCM OK, mais ce token appartient à un AUTRE projet Firebase (SENDER_ID_MISMATCH). L'appareil doit utiliser le projet « wiwiga-d9a7e » (google-services.json / config Web correspondante).",
                     provider: provider.name
                   }}

                true ->
                  {:error, {:provider_rejected, inspect({:fcm_rejected, status, body}) |> String.slice(0, 300)}}
              end

            {:retryable, reason} ->
              {:error, {:provider_retryable, inspect(reason) |> String.slice(0, 300)}}

            {:permanent, reason} ->
              {:error, {:provider_rejected, inspect(reason) |> String.slice(0, 300)}}

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  # ========================================
  # Admin — Templates
  # ========================================

  @doc """
  Liste les templates avec filtres.
  """
  @spec list_templates(map()) :: list(Template.t())
  def list_templates(filters \\ %{}) do
    base = from t in Template, order_by: [asc: t.key, asc: t.channel, desc: t.version]

    base =
      case Map.get(filters, "key") do
        nil -> base
        key -> from t in base, where: t.key == ^key
      end

    base =
      case Map.get(filters, "channel") do
        nil -> base
        channel -> from t in base, where: t.channel == ^channel
      end

    Repo.all(base)
  end

  @doc """
  Crée un template puis invalide le cache.
  """
  @spec create_template(map()) :: {:ok, Template.t()} | {:error, Ecto.Changeset.t()}
  def create_template(attrs) do
    case %Template{} |> Template.changeset(attrs) |> Repo.insert() do
      {:ok, template} -> ProviderCache.invalidate_all(); {:ok, template}
      error -> error
    end
  end

  @doc """
  Met à jour un template puis invalide le cache.
  """
  @spec update_template(integer(), map()) :: {:ok, Template.t()} | {:error, term()}
  def update_template(template_id, attrs) do
    case Repo.get(Template, template_id) do
      nil ->
        {:error, :not_found}

      template ->
        case template |> Template.changeset(attrs) |> Repo.update() do
          {:ok, updated} -> ProviderCache.invalidate_all(); {:ok, updated}
          error -> error
        end
    end
  end

  @doc """
  Prévisualise le rendu d'un template avec des variables de test.
  Pour le canal SMS, ajoute le comptage de segments (coût).
  """
  @spec preview_template(integer(), map()) :: {:ok, map()} | {:error, term()}
  def preview_template(template_id, variables \\ %{}) do
    alias GameHub.Notifications.SmsSegments

    case Repo.get(Template, template_id) do
      nil ->
        {:error, :not_found}

      template ->
        case TemplateRenderer.render(template.body_tpl, variables, template.required_variables || []) do
          {:ok, body} ->
            base = %{subject: template.subject, body: body, variables: TemplateRenderer.extract_variables(template.body_tpl)}

            result =
              if template.channel == "sms" do
                Map.put(base, :segments, SmsSegments.count(body))
              else
                base
              end

            {:ok, result}

          error ->
            error
        end
    end
  end

  @doc """
  Prévisualise un corps NON sauvegardé (aide à l'édition).
  """
  @spec preview_body(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def preview_body(channel, body_tpl, variables \\ %{}) do
    alias GameHub.Notifications.SmsSegments

    case TemplateRenderer.render(to_string(body_tpl || ""), variables, []) do
      {:ok, body} ->
        result = %{body: body, variables: TemplateRenderer.extract_variables(to_string(body_tpl || ""))}

        result =
          if channel == "sms" do
            Map.put(result, :segments, SmsSegments.count(body))
          else
            result
          end

        {:ok, result}

      error ->
        error
    end
  end

  # ========================================
  # Admin — Logs + stats + replay
  # ========================================

  @doc """
  Liste les notifications (logs) avec pagination pour l'admin.
  """
  @spec list_logs(map()) :: {:ok, list(), integer()}
  def list_logs(params \\ %{}) do
    page = params |> Map.get("page", "1") |> to_integer(1) |> max(1)
    limit = params |> Map.get("limit", "20") |> to_integer(20) |> min(50)
    offset = (page - 1) * limit

    base = from n in Notification, order_by: [desc: n.inserted_at]

    base =
      case Map.get(params, "status") do
        nil -> base
        status -> from n in base, where: n.status == ^status
      end

    base =
      case Map.get(params, "event_type") do
        nil -> base
        event_type -> from n in base, where: n.event_type == ^event_type
      end

    base =
      case Map.get(params, "user_id") do
        nil -> base
        user_id -> from n in base, where: n.user_id == ^to_integer(user_id, 0)
      end

    base =
      case Map.get(params, "q") do
        nil -> base
        "" -> base
        query ->
          pattern = "%#{String.replace(query, ~r/[%_]/, "")}%"
          from n in base, where: ilike(n.title, ^pattern) or ilike(n.body, ^pattern)
      end

    total = base |> Ecto.Query.exclude(:order_by) |> then(fn q -> Repo.one(from n in q, select: count(n.id)) end) || 0
    items = Repo.all(from n in base, limit: ^limit, offset: ^offset)
    {:ok, items, total || 0}
  end

  @doc """
  Détail d'une notification + ses tentatives.
  """
  @spec get_log(integer()) :: {:ok, map()} | {:error, term()}
  def get_log(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, :not_found}
      notification ->
        deliveries = Repo.all(from d in Delivery, where: d.notification_id == ^notification_id, order_by: [asc: d.attempt_number])
        {:ok, %{notification: notification, deliveries: deliveries}}
    end
  end

  @doc """
  Rejoue une notification (nouvel event_id, respecte l'opt-out).
  """
  @spec replay(integer()) :: {:ok, Notification.t()} | {:error, term()}
  def replay(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, :not_found}
      notification -> dispatch(notification.event_type, notification.user_id, notification.variables || %{}, priority: notification.priority)
    end
  end

  @doc """
  Statistiques par statut / canal pour le dashboard admin.
  """
  @spec stats() :: map()
  def stats do
    by_status =
      from(n in Notification, group_by: n.status, select: {n.status, count(n.id)})
      |> Repo.all()
      |> Map.new()

    by_channel =
      from(d in Delivery, group_by: d.channel, select: {d.channel, count(d.id)})
      |> Repo.all()
      |> Map.new()

    %{by_status: by_status, by_channel: by_channel, unread_total: Repo.one(from n in Notification, where: n.is_read == false, select: count(n.id)) || 0}
  end

  @doc """
  Série temporelle quotidienne (jours calendaires UTC) : total + par statut.
  `days` 1..90 (défaut 14). Sert les graphiques admin.
  """
  @spec timeseries(non_neg_integer()) :: list(map())
  def timeseries(days \\ 14) do
    days = days |> max(1) |> min(90)
    since = Date.utc_today() |> Date.add(-(days - 1))

    rows =
      from(n in Notification,
        where: fragment("?::date", n.inserted_at) >= ^since,
        group_by: [fragment("?::date", n.inserted_at), n.status],
        select: {fragment("?::date", n.inserted_at), n.status, count(n.id)}
      )
      |> Repo.all()

    by_day =
      Enum.group_by(rows, fn {date, _status, _count} -> date end, fn {_date, status, count} -> {status, count} end)

    Enum.map(0..(days - 1), fn offset ->
      date = Date.add(since, offset)
      counts = Map.new(Map.get(by_day, date, []))
      sent = Map.get(counts, "sent", 0) + Map.get(counts, "delivered", 0)
      failed = Map.get(counts, "failed", 0)
      queued = Map.get(counts, "queued", 0) + Map.get(counts, "retrying", 0) + Map.get(counts, "processing", 0)

      %{date: Date.to_iso8601(date), total: sent + failed + queued, sent: sent, failed: failed, queued: queued}
    end)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  @doc """
  Seed des providers et templates par défaut (idempotent).
  """
  @spec seed_defaults() :: {:ok, map()}
  def seed_defaults do
    providers = [
      %{channel: "in_app", name: "inbox", display_name: "Inbox WIWIGA", is_active: true, is_default: true, priority: 0},
      %{channel: "sms", name: "esms_africa", display_name: "eSMS Africa (MTN/Orange CM)", is_active: false, priority: 10, config: %{}},
      %{channel: "sms", name: "orange_cm", display_name: "Orange SMS Cameroun", is_active: false, priority: 20, config: %{}},
      %{channel: "sms", name: "mtn_cm", display_name: "MTN Cameroun SMS", is_active: false, priority: 30, config: %{}},
      %{channel: "sms", name: "africas_talking", display_name: "Africa's Talking", is_active: false, priority: 40, config: %{}},
      %{channel: "sms", name: "twilio", display_name: "Twilio (fallback global)", is_active: false, priority: 50, config: %{}},
      %{channel: "push", name: "fcm_v1", display_name: "Firebase Cloud Messaging", is_active: false, priority: 10, config: %{}},
      %{channel: "push", name: "onesignal", display_name: "OneSignal", is_active: false, priority: 20, config: %{}},
      %{channel: "email", name: "smtp", display_name: "SMTP générique", is_active: false, priority: 10, config: %{}},
      %{channel: "email", name: "sendgrid", display_name: "SendGrid", is_active: false, priority: 20, config: %{}},
      %{channel: "email", name: "ses", display_name: "Amazon SES", is_active: false, priority: 30, config: %{}}
    ]

    templates =
      [
        %{key: "otp_login", channel: "in_app", subject: "Code de connexion", body_tpl: "Votre code WIWIGA : {{code}}", category: "security", required_variables: ["code"], default_priority: "urgent", action: nil},
        %{key: "wallet_credit", channel: "in_app", subject: "Jetons reçus", body_tpl: "+{{montant}} jetons : {{motif}}", category: "transactional", required_variables: ["montant"], default_priority: "normal", action: "/transactions"},
        %{key: "wallet_debit", channel: "in_app", subject: "Jetons débités", body_tpl: "-{{montant}} jetons : {{motif}}", category: "transactional", required_variables: ["montant"], default_priority: "normal", action: "/transactions"},
        %{key: "match_result", channel: "in_app", subject: "Résultat du match", body_tpl: "{{resultat}} : {{gain}} jetons", category: "game", required_variables: ["resultat"], default_priority: "normal", action: "/games"},
        %{key: "friend_request", channel: "in_app", subject: "Demande d'ami", body_tpl: "{{pseudo}} vous a envoyé une demande d'ami", category: "social", required_variables: ["pseudo"], default_priority: "normal", action: "/friends"},
        %{key: "security_alert", channel: "in_app", subject: "Alerte sécurité", body_tpl: "{{message}}", category: "security", required_variables: ["message"], default_priority: "high", action: nil},
        %{key: "admin_broadcast", channel: "in_app", subject: "Annonce WIWIGA", body_tpl: "{{message}}", category: "transactional", required_variables: ["message"], default_priority: "normal", action: nil},
        %{key: "promo_broadcast", channel: "in_app", subject: "Promotion", body_tpl: "{{message}}", category: "marketing", required_variables: ["message"], default_priority: "low", action: nil}
      ] ++ sms_templates() ++ push_templates() ++ email_templates() ++ social_templates()

    Enum.each(providers, fn attrs ->
      %Provider{} |> Provider.changeset(attrs) |> Repo.insert(on_conflict: :nothing, conflict_target: [:channel, :name])
    end)

    Enum.each(templates, fn attrs ->
      %Template{} |> Template.changeset(Map.merge(%{locale: "fr", version: 1}, attrs)) |> Repo.insert(on_conflict: :nothing, conflict_target: [:key, :channel, :locale, :version])
    end)

    Enum.each(@seed_routing, fn {event_key, channels} ->
      %RoutingRule{}
      |> RoutingRule.changeset(%{event_key: event_key, channels: channels, is_active: true})
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:event_key])
    end)

    ProviderCache.invalidate_all()
    {:ok, %{providers: length(providers), templates: length(templates), routing: map_size(@seed_routing)}}
  end

  # Templates SMS : courts (1 segment si possible), sans accents superflus.
  defp sms_templates do
    [
      %{key: "otp_login", channel: "sms", body_tpl: "Votre code WIWIGA : {{code}}", category: "security", required_variables: ["code"]},
      %{key: "wallet_credit", channel: "sms", body_tpl: "WIWIGA : +{{montant}} jetons ({{motif}})", category: "transactional", required_variables: ["montant"]},
      %{key: "wallet_debit", channel: "sms", body_tpl: "WIWIGA : -{{montant}} jetons ({{motif}})", category: "transactional", required_variables: ["montant"]},
      %{key: "match_result", channel: "sms", body_tpl: "WIWIGA : {{resultat}} ({{gain}} jetons)", category: "game", required_variables: ["resultat"]},
      %{key: "friend_request", channel: "sms", body_tpl: "WIWIGA : {{pseudo}} vous a envoye une demande d'ami", category: "social", required_variables: ["pseudo"]},
      %{key: "security_alert", channel: "sms", body_tpl: "WIWIGA securite : {{message}}", category: "security", required_variables: ["message"]},
      %{key: "admin_broadcast", channel: "sms", body_tpl: "WIWIGA : {{message}}", category: "transactional", required_variables: ["message"]},
      %{key: "promo_broadcast", channel: "sms", body_tpl: "WIWIGA promo : {{message}}", category: "marketing", required_variables: ["message"]}
    ]
  end

  # Templates push : titre court + corps concis.
  defp push_templates do
    [
      %{key: "otp_login", channel: "push", subject: "Code de connexion", body_tpl: "Votre code WIWIGA : {{code}}", category: "security", required_variables: ["code"]},
      %{key: "wallet_credit", channel: "push", subject: "+{{montant}} jetons", body_tpl: "{{motif}} — solde mis à jour", category: "transactional", required_variables: ["montant"]},
      %{key: "wallet_debit", channel: "push", subject: "-{{montant}} jetons", body_tpl: "{{motif}} — solde mis à jour", category: "transactional", required_variables: ["montant"]},
      %{key: "match_result", channel: "push", subject: "{{resultat}}", body_tpl: "Gain : {{gain}} jetons. Revanche ?", category: "game", required_variables: ["resultat"]},
      %{key: "friend_request", channel: "push", subject: "Demande d'ami", body_tpl: "{{pseudo}} veut vous ajouter", category: "social", required_variables: ["pseudo"]},
      %{key: "security_alert", channel: "push", subject: "Alerte sécurité", body_tpl: "{{message}}", category: "security", required_variables: ["message"]},
      %{key: "admin_broadcast", channel: "push", subject: "{{titre}}", body_tpl: "{{message}}", category: "transactional", required_variables: ["titre", "message"]},
      %{key: "promo_broadcast", channel: "push", subject: "{{titre}}", body_tpl: "{{message}}", category: "marketing", required_variables: ["titre", "message"]}
    ]
  end

  # Événements sociaux/financiers/succès (in_app + push + sms + email).
  defp social_templates do
    [
      %{key: "friend_accepted", channel: "in_app", subject: "Ami ajouté", body_tpl: "Vous êtes maintenant amis avec {{pseudo}}", category: "social", required_variables: ["pseudo"], default_priority: "normal", action: "/friends"},
      %{key: "friend_accepted", channel: "push", subject: "Ami ajouté", body_tpl: "{{pseudo}} a accepté votre demande", category: "social", required_variables: ["pseudo"], default_priority: "normal"},
      %{key: "friend_accepted", channel: "sms", body_tpl: "WIWIGA : {{pseudo}} a accepte votre demande d'ami", category: "social", required_variables: ["pseudo"], default_priority: "normal"},
      %{key: "friend_accepted", channel: "email", subject: "Nouvel ami — WIWIGA", body_tpl: "Bonjour,\n\n{{pseudo}} a accepté votre demande d'ami.\n\nL'équipe WIWIGA", category: "social", required_variables: ["pseudo"], default_priority: "normal"},
      %{key: "cash_withdraw", channel: "in_app", subject: "Retrait effectué", body_tpl: "{{montant}} en cours de retrait vers Mobile Money", category: "transactional", required_variables: ["montant"], default_priority: "high", action: "/transactions"},
      %{key: "cash_withdraw", channel: "push", subject: "Retrait effectué", body_tpl: "{{montant}} vers Mobile Money", category: "transactional", required_variables: ["montant"], default_priority: "high"},
      %{key: "cash_withdraw", channel: "sms", body_tpl: "WIWIGA : retrait de {{montant}} en cours", category: "transactional", required_variables: ["montant"], default_priority: "high"},
      %{key: "cash_withdraw", channel: "email", subject: "Retrait en cours — WIWIGA", body_tpl: "Bonjour,\n\nUn retrait de {{montant}} vers Mobile Money est en cours.\n\nL'équipe WIWIGA", category: "transactional", required_variables: ["montant"], default_priority: "high"},
      %{key: "achievement_unlocked", channel: "in_app", subject: "Succès débloqué", body_tpl: "{{nom}} (+{{xp}} XP)", category: "game", required_variables: ["nom", "xp"], default_priority: "normal", action: "/profile"},
      %{key: "achievement_unlocked", channel: "push", subject: "Succès débloqué", body_tpl: "{{nom}} (+{{xp}} XP)", category: "game", required_variables: ["nom", "xp"], default_priority: "normal"},
      %{key: "achievement_unlocked", channel: "sms", body_tpl: "WIWIGA : succes {{nom}} (+{{xp}} XP)", category: "game", required_variables: ["nom", "xp"], default_priority: "normal"},
      %{key: "achievement_unlocked", channel: "email", subject: "Succès débloqué — WIWIGA", body_tpl: "Bonjour,\n\nSuccès débloqué : {{nom}} (+{{xp}} XP).\n\nL'équipe WIWIGA", category: "game", required_variables: ["nom", "xp"], default_priority: "normal"}
    ]
  end

  # Templates email : sujet court (marque en fin, ≤ 50 caractères),
  # corps avec formule. Version texte toujours envoyée aussi.
  defp email_templates do    [
      %{key: "otp_login", channel: "email", subject: "Votre code : {{code}} — WIWIGA", body_tpl: "Bonjour,\n\nVotre code de vérification WIWIGA : {{code}} (valable 5 minutes).\n\nSi vous n'êtes pas à l'origine de cette demande, ignorez ce message.\n\nL'équipe WIWIGA", category: "security", required_variables: ["code"], default_priority: "urgent"},
      %{key: "wallet_credit", channel: "email", subject: "+{{montant}} jetons — WIWIGA", body_tpl: "Bonjour,\n\nVous avez reçu {{montant}} jetons ({{motif}}).\n\nL'équipe WIWIGA", category: "transactional", required_variables: ["montant"], default_priority: "normal"},
      %{key: "wallet_debit", channel: "email", subject: "-{{montant}} jetons — WIWIGA", body_tpl: "Bonjour,\n\n{{montant}} jetons ont été débités ({{motif}}).\n\nL'équipe WIWIGA", category: "transactional", required_variables: ["montant"], default_priority: "normal"},
      %{key: "match_result", channel: "email", subject: "{{resultat}} — WIWIGA", body_tpl: "Bonjour,\n\n{{resultat}} — gain : {{gain}} jetons.\n\nL'équipe WIWIGA", category: "game", required_variables: ["resultat"], default_priority: "normal"},
      %{key: "friend_request", channel: "email", subject: "Demande d'ami — WIWIGA", body_tpl: "Bonjour,\n\n{{pseudo}} vous a envoyé une demande d'ami sur WIWIGA.\n\nL'équipe WIWIGA", category: "social", required_variables: ["pseudo"], default_priority: "normal"},
      %{key: "security_alert", channel: "email", subject: "Alerte sécurité — WIWIGA", body_tpl: "Bonjour,\n\n{{message}}\n\nSi ce n'était pas vous, sécurisez votre compte.\n\nL'équipe WIWIGA", category: "security", required_variables: ["message"], default_priority: "high"},
      %{key: "admin_broadcast", channel: "email", subject: "{{titre}} — WIWIGA", body_tpl: "Bonjour,\n\n{{message}}\n\nL'équipe WIWIGA", category: "transactional", required_variables: ["titre", "message"], default_priority: "normal"},
      %{key: "promo_broadcast", channel: "email", subject: "{{titre}} — WIWIGA", body_tpl: "Bonjour,\n\n{{message}}\n\nPour ne plus recevoir nos promotions : Notifications > Préférences > Promos.\n\nL'équipe WIWIGA", category: "marketing", required_variables: ["titre", "message"], default_priority: "low"}
    ]
  end

  # ========================================
  # Privé
  # ========================================

  defp insert_notification(attrs) do
    %Notification{} |> Notification.changeset(attrs) |> Repo.insert()
  end

  # Chiffre les secrets de config avant insert/update.
  # Normalise aussi les clés en strings (Ecto refuse les clés mixtes).
  defp encrypt_config_attr(attrs, sensitive_keys) when is_map(attrs) do
    stringified = stringify_map(attrs)

    case Map.get(stringified, "config") do
      config when is_map(config) ->
        Map.put(stringified, "config", ConfigCrypto.encrypt_config(config, sensitive_keys))

      _ ->
        stringified
    end
  end

  defp encrypt_config_attr(attrs, _), do: attrs

  # Clés sensibles = schéma du provider (+ heuristique ConfigCrypto).
  defp schema_sensitive_keys(name, stored_config) when is_binary(name) do
    provider_config_schema(name, stored_config)
    |> Enum.filter(&Map.get(&1, :sensitive, false))
    |> Enum.map(& &1.key)
  end

  defp schema_sensitive_keys(_, _), do: []

  defp trace_in_app_delivery(notification) do
    %Delivery{}
    |> Delivery.changeset(%{notification_id: notification.id, channel: "in_app", provider_name: "inbox", attempt_number: 1, status: "sent", sent_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.insert()
    |> case do
      {:ok, _} ->
        GameHub.Notifications.Telemetry.emit([:delivery], %{count: 1}, %{channel: "in_app", status: "sent", provider: "inbox"})
        {:ok, notification}

      error ->
        error
    end
  end

  # Enqueue Oban transactionnel : le job n'existe que si la notification committe.
  # Priorité Oban (0 = servi d'abord) : urgent/high → 0, normal → 1, low → 5.
  # Heures creuses utilisateur : push/sms/email différés (inbox immédiate,
  # silencieuse). Sans destinataire sms/email → delivery annulée, pas de job.
  defp enqueue_channel_jobs(_notification, [], _recipient), do: :ok

  defp enqueue_channel_jobs(notification, channels, recipient) do
    alias GameHub.Notifications.QuietHours

    job_priority = oban_priority(notification.priority)
    quiet_delay = QuietHours.user_defer(notification.user_id, notification.category)

    Enum.each(channels, fn channel ->
      case {channel, recipient} do
        {channel, to} when channel in ["sms", "email"] and (to == nil or to == "") ->
          %Delivery{}
          |> Delivery.changeset(%{
            notification_id: notification.id,
            channel: channel,
            attempt_number: 1,
            status: "cancelled",
            error_message: "destinataire manquant (option :to requise)"
          })
          |> Repo.insert(on_conflict: :nothing)

        _ ->
          {worker, queue} = Map.fetch!(@channel_workers, channel)

          args =
            case channel do
              "push" -> %{"notification_id" => notification.id, "channel" => channel}
              _ -> %{"notification_id" => notification.id, "channel" => channel, "to" => to_string(recipient)}
            end

          with {:ok, delivery} <-
                 %Delivery{}
                 |> Delivery.changeset(%{notification_id: notification.id, channel: channel, attempt_number: 1, status: "queued"})
                 |> Repo.insert(on_conflict: :nothing),
               {:ok, job} <- worker.new(args, queue: queue, priority: job_priority, schedule_in: quiet_delay) |> Oban.insert() do
            delivery |> Delivery.changeset(%{oban_job_id: job.id}) |> Repo.update()
          else
            _ -> :ok
          end
      end
    end)

    :ok
  end

  # Voies prioritaires : l'urgent ne subit jamais le bulk.
  defp oban_priority("urgent"), do: 0
  defp oban_priority("high"), do: 0
  defp oban_priority("low"), do: 5
  defp oban_priority(_), do: 1

  defp broadcast_notification(notification) do
    topic = "user:#{notification.user_id}:notifications"

    payload = %{
      event: "notification_created",
      payload: %{
        id: notification.id,
        event_type: notification.event_type,
        title: notification.title,
        body: notification.body,
        category: notification.category,
        priority: notification.priority,
        inserted_at: notification.inserted_at
      }
    }

    try do
      Phoenix.PubSub.broadcast(GameHub.PubSub, topic, payload)
      Phoenix.PubSub.broadcast(GameHub.PubSub, "user:#{notification.user_id}", payload)
    rescue
      _ -> :ok
    end

    :ok
  end

  defp filter_allowed_channels(user_id, category, channels) do
    prefs = list_preferences(user_id) |> Map.new(fn p -> {{p.category, p.channel}, p.enabled} end)

    Enum.filter(channels, fn channel ->
      cond do
        category == "security" -> true
        true -> Map.get(prefs, {category, channel}, true)
      end
    end)
  end

  # Retire les canaux dont le quota journalier est épuisé (push/sms/email).
  defp apply_rate_caps(user_id, category, channels) do
    alias GameHub.Notifications.RateLimit

    Enum.filter(channels, fn channel ->
      case RateLimit.check_user(user_id, channel, category) do
        :ok -> true
        {:error, :capped} -> false
      end
    end)
  end

  defp render_or_override(nil, title_override, body_override, _variables) do
    {title_override || "Notification", body_override || ""}
  end

  defp render_or_override(template, title_override, body_override, variables) do
    raw_title =
      cond do
        title_override != nil -> title_override
        is_map(template) and Map.has_key?(template, :subject) -> template.subject || template.key
        is_map(template) -> Map.get(template, "subject") || Map.get(template, :key, "Notification")
        true -> "Notification"
      end

    # Le sujet est aussi un template (email subject = titre rendu)
    title =
      case TemplateRenderer.render(to_string(raw_title || "Notification"), variables, []) do
        {:ok, rendered} -> rendered
        {:error, _} -> to_string(raw_title || "Notification")
      end

    body_tpl =
      cond do
        body_override != nil -> body_override
        is_map(template) and Map.has_key?(template, :body_tpl) -> template.body_tpl
        is_map(template) -> Map.get(template, "body_tpl", "")
        true -> ""
      end

    required =
      cond do
        is_map(template) and Map.has_key?(template, :required_variables) -> template.required_variables || []
        is_map(template) -> Map.get(template, "required_variables", []) || []
        true -> []
      end

    case TemplateRenderer.render(body_tpl, variables, required) do
      {:ok, body} -> {title || "Notification", body}
      {:error, _} -> {title || "Notification", body_tpl}
    end
  end

  defp template_category(nil, default), do: default
  defp template_category(%{category: category}, _default) when is_binary(category), do: category
  defp template_category(%{} = template, default), do: Map.get(template, :category) || Map.get(template, "category", default) || default

  defp template_version(nil), do: 1
  defp template_version(%{version: version}) when is_integer(version), do: version
  defp template_version(%{} = template), do: Map.get(template, :version) || Map.get(template, "version", 1) || 1

  defp build_idempotency_key(event_id, user_id, template_key, channel) do
    raw = "#{event_id}:#{user_id}:#{template_key}:#{channel}"
    :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
  end

  defp get_by_idempotency(idempotency_key) do
    case Repo.get_by(Notification, idempotency_key: idempotency_key) do
      nil -> {:error, :conflict}
      notification -> {:ok, notification}
    end
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp to_integer(value, _default) when is_integer(value), do: value

  defp to_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp to_integer(_, default), do: default

  @doc """
  Retourne les canaux supportés.
  """
  @spec channels() :: list(String.t())
  def channels, do: @channels
end
