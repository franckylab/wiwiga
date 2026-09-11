defmodule GameHub.NotificationsPhase1Test do
  @moduledoc """
  Tests Phase 1 : chiffrement config, enqueue Oban, workers, failover.
  """

  use ExUnit.Case, async: false
  use Oban.Testing, repo: GameHub.Repo

  alias GameHub.Notifications
  alias GameHub.Notifications.{ConfigCrypto, Delivery}
  alias GameHub.Notifications.Workers.{SmsWorker, PushWorker, EmailWorker}
  alias GameHub.Repo
  alias GameHub.Users.User

  import Ecto.Query

  # === Stubs adapters (registre surchargé, aucun HTTP réel) ===

  defmodule StubSmsOk do
    @behaviour GameHub.Notifications.Adapters.SmsAdapter
    @impl true
    def send_sms(_to, _body, _config), do: {:ok, %{provider_message_id: "stub-sms-1"}}
  end

  defmodule StubSmsRetryable do
    @behaviour GameHub.Notifications.Adapters.SmsAdapter
    @impl true
    def send_sms(_to, _body, _config), do: {:retryable, :timeout}
  end

  defmodule StubSmsPermanent do
    @behaviour GameHub.Notifications.Adapters.SmsAdapter
    @impl true
    def send_sms(_to, _body, _config), do: {:permanent, :invalid_msisdn}
  end

  defmodule StubEmailOk do
    @behaviour GameHub.Notifications.Adapters.EmailAdapter
    @impl true
    def send_email(_to, _subject, _body, _config), do: {:ok, %{provider_message_id: "stub-mail-1"}}
  end

  defmodule StubPushOk do
    @behaviour GameHub.Notifications.Adapters.PushAdapter
    @impl true
    def send_push(_token, _title, _body, _data, _config), do: {:ok, %{provider_message_id: "stub-push-1"}}
  end

  setup do
    GameHub.TestHelpers.cleanup_test_data()
    GameHub.Notifications.ProviderCache.invalidate_all()

    uniq = System.unique_integer([:positive])

    user =
      Repo.insert!(%User{
        phone: "+237699#{String.pad_leading(to_string(rem(uniq, 900000) + 100000), 6, "0")}",
        username: "phase1_#{uniq}",
        name: "Phase1 Test",
        balance: 10_000,
        token_balance: 1000,
        is_active: true,
        has_verified_kyc: true
      })

    Application.delete_env(:game_hub, :notification_adapter_overrides)
    on_exit(fn -> Application.delete_env(:game_hub, :notification_adapter_overrides) end)

    {:ok, user: user, uniq: uniq}
  end

  defp stub_overrides(map) do
    Application.put_env(:game_hub, :notification_adapter_overrides, map)
  end

  defp create_sms_provider(name, active \\ true) do
    Notifications.create_provider(%{
      "channel" => "sms",
      "name" => name,
      "display_name" => "SMS #{name}",
      "is_active" => active,
      "priority" => 10,
      "config" => %{"api_key" => "secret-#{name}", "sender_id" => "WIWIGA"}
    })
  end

  describe "ConfigCrypto" do
    test "chiffre les secrets, laisse le clair intact" do
      config = %{"api_key" => "sk-live-123", "sender_id" => "WIWIGA", "port" => 587}
      encrypted = ConfigCrypto.encrypt_config(config)

      assert encrypted["sender_id"] == "WIWIGA"
      assert encrypted["port"] == 587
      assert ConfigCrypto.encrypted?(encrypted["api_key"])
      refute encrypted["api_key"] =~ "sk-live-123"

      assert ConfigCrypto.decrypt_config(encrypted)["api_key"] == "sk-live-123"
    end

    test "valeur déjà chiffrée non re-chiffrée, illisible → chaîne vide" do
      once = ConfigCrypto.encrypt_config(%{"token" => "abc"})
      assert ConfigCrypto.encrypt_config(once) == once
      assert ConfigCrypto.decrypt_config(%{"token" => "v1.aGk.bm9uZXNpc3RhbnQ"})["token"] == ""
    end

    test "détection des clés sensibles" do
      assert ConfigCrypto.sensitive_key?("api_key")
      assert ConfigCrypto.sensitive_key?("client_secret")
      assert ConfigCrypto.sensitive_key?("auth_token")
      refute ConfigCrypto.sensitive_key?("sender_id")
      refute ConfigCrypto.sensitive_key?("base_url")
    end
  end

  describe "chiffrement config providers" do
    test "secret stocké chiffré, lu en clair via decrypted_config", %{uniq: uniq} do
      assert {:ok, provider} = create_sms_provider("stub_sms_ok_#{uniq}")

      raw = Repo.get!(GameHub.Notifications.Provider, provider.id)
      assert ConfigCrypto.encrypted?(raw.config["api_key"])
      assert Notifications.decrypted_config(raw)["api_key"] == "secret-stub_sms_ok_#{uniq}"
      # La config n'est jamais exposée via l'encodeur JSON
      refute Map.has_key?(Jason.decode!(Jason.encode!(provider)), "config")
    end
  end

  describe "dispatch multi-canal" do
    test "enqueue un job Oban par canal + delivery queued", %{user: user, uniq: uniq} do
      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "test"},
                 channels: ["in_app", "sms", "email", "push"],
                 to: "+237690000001",
                 event_id: "multi-#{uniq}"
               )

      assert_enqueued(worker: SmsWorker, args: %{"notification_id" => notif.id, "channel" => "sms", "to" => "+237690000001"})
      assert_enqueued(worker: EmailWorker, args: %{"notification_id" => notif.id, "channel" => "email"})
      assert_enqueued(worker: PushWorker, args: %{"notification_id" => notif.id, "channel" => "push"})

      assert %Delivery{status: "queued"} = Notifications.get_channel_delivery(notif.id, "sms")
      assert %Delivery{status: "queued"} = Notifications.get_channel_delivery(notif.id, "email")
      assert %Delivery{status: "queued"} = Notifications.get_channel_delivery(notif.id, "push")
    end

    test "sms sans destinataire → delivery annulée, aucun job", %{user: user, uniq: uniq} do
      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "test"},
                 channels: ["sms"],
                 event_id: "noto-#{uniq}"
               )

      assert %Delivery{status: "cancelled"} = Notifications.get_channel_delivery(notif.id, "sms")
    end

    test "sujet rendu avec variables", %{user: user, uniq: uniq} do
      Notifications.create_template(%{
        "key" => "subj_test_#{uniq}",
        "channel" => "in_app",
        "locale" => "fr",
        "version" => 1,
        "subject" => "Bonjour {{pseudo}}",
        "body_tpl" => "corps",
        "category" => "transactional",
        "is_active" => true
      })

      assert {:ok, notif} =
               Notifications.dispatch("subj_test_#{uniq}", user.id, %{"pseudo" => "Ali"}, event_id: "subj-#{uniq}")

      assert notif.title == "Bonjour Ali"
    end
  end

  describe "SmsWorker" do
    test "succès → delivery sent avec ID provider", %{user: user, uniq: uniq} do
      stub_overrides(%{"stub_sms_ok_#{uniq}" => StubSmsOk})
      assert {:ok, _} = create_sms_provider("stub_sms_ok_#{uniq}")

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["sms"],
                 to: "+237690000001",
                 event_id: "w-ok-#{uniq}"
               )

      assert :ok = perform_job(SmsWorker, %{"notification_id" => notif.id, "to" => "+237690000001"})
      assert %Delivery{status: "sent", provider_message_id: "stub-sms-1"} = Notifications.get_channel_delivery(notif.id, "sms")
    end

    test "permanent → delivery failed + cancel", %{user: user, uniq: uniq} do
      stub_overrides(%{"stub_sms_perm_#{uniq}" => StubSmsPermanent})
      assert {:ok, _} = create_sms_provider("stub_sms_perm_#{uniq}")

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["sms"],
                 to: "+237690000001",
                 event_id: "w-perm-#{uniq}"
               )

      assert {:cancel, _} = perform_job(SmsWorker, %{"notification_id" => notif.id, "to" => "+237690000001"})
      assert %Delivery{status: "failed"} = Notifications.get_channel_delivery(notif.id, "sms")
    end

    test "delivery inexistante → cancel sans envoi", %{uniq: uniq} do
      stub_overrides(%{"stub_sms_ok_#{uniq}" => StubSmsOk})
      assert {:cancel, :delivery_not_found} = perform_job(SmsWorker, %{"notification_id" => -1, "to" => "+237690000001"})
    end

    test "failover : retryable puis succès sur provider suivant", %{user: user, uniq: uniq} do
      stub_overrides(%{
        "stub_sms_retry_#{uniq}" => StubSmsRetryable,
        "stub_sms_ok2_#{uniq}" => StubSmsOk
      })

      assert {:ok, _} = create_sms_provider("stub_sms_retry_#{uniq}")
      assert {:ok, second} = Notifications.create_provider(%{
        "channel" => "sms",
        "name" => "stub_sms_ok2_#{uniq}",
        "display_name" => "ok2",
        "is_active" => true,
        "priority" => 20,
        "config" => %{}
      })
      assert second.priority == 20

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["sms"],
                 to: "+237690000001",
                 event_id: "w-fo-#{uniq}"
               )

      assert :ok = perform_job(SmsWorker, %{"notification_id" => notif.id, "to" => "+237690000001"})
      assert %Delivery{status: "sent", provider_name: "stub_sms_ok2_" <> _} = Notifications.get_channel_delivery(notif.id, "sms")
    end
  end

  describe "PushWorker et EmailWorker" do
    test "push sans token → failed permanent", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.create_provider(%{
        "channel" => "push", "name" => "stub_push_#{uniq}", "display_name" => "push",
        "is_active" => true, "priority" => 10, "config" => %{}
      })
      stub_overrides(%{"stub_push_#{uniq}" => StubPushOk})

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["push"], event_id: "p-notok-#{uniq}"
               )

      assert {:cancel, _} = perform_job(PushWorker, %{"notification_id" => notif.id})
      assert %Delivery{status: "failed"} = Notifications.get_channel_delivery(notif.id, "push")
    end

    test "push avec token → sent", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.create_provider(%{
        "channel" => "push", "name" => "stub_push2_#{uniq}", "display_name" => "push",
        "is_active" => true, "priority" => 10, "config" => %{}
      })
      stub_overrides(%{"stub_push2_#{uniq}" => StubPushOk})
      assert {:ok, _} = Notifications.register_device_token(user.id, "android", "fcm-device-token-#{uniq}")

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["push"], event_id: "p-ok-#{uniq}"
               )

      assert :ok = perform_job(PushWorker, %{"notification_id" => notif.id})
      assert %Delivery{status: "sent", provider_message_id: "stub-push-1"} = Notifications.get_channel_delivery(notif.id, "push")
    end

    test "email succès → sent", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.create_provider(%{
        "channel" => "email", "name" => "stub_mail_#{uniq}", "display_name" => "mail",
        "is_active" => true, "priority" => 10, "config" => %{}
      })
      stub_overrides(%{"stub_mail_#{uniq}" => StubEmailOk})

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["email"], to: "test@exemple.com", event_id: "m-ok-#{uniq}"
               )

      assert :ok = perform_job(EmailWorker, %{"notification_id" => notif.id, "to" => "test@exemple.com"})
      assert %Delivery{status: "sent"} = Notifications.get_channel_delivery(notif.id, "email")
    end
  end

  describe "DLR" do
    test "mark_delivered et mark_delivery_failed", %{user: user, uniq: uniq} do
      stub_overrides(%{"stub_sms_ok_#{uniq}" => StubSmsOk})
      assert {:ok, _} = create_sms_provider("stub_sms_ok_#{uniq}")

      assert {:ok, notif} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                 channels: ["sms"], to: "+237690000001", event_id: "dlr-#{uniq}"
               )

      assert :ok = perform_job(SmsWorker, %{"notification_id" => notif.id, "to" => "+237690000001"})
      assert {:ok, delivered} = Notifications.mark_delivered("stub_sms_ok_#{uniq}", "stub-sms-1")
      assert delivered.status == "delivered"

      assert {:error, :not_found} = Notifications.mark_delivered("stub_sms_ok_#{uniq}", "inconnu")
    end
  end

  describe "Msisdn" do
    test "normalisation E.164 camerounaise" do
      alias GameHub.Notifications.Adapters.SmsAdapter
      assert SmsAdapter.normalize_msisdn("690000001") == {:ok, "+237690000001"}
      assert SmsAdapter.normalize_msisdn("237690000001") == {:ok, "+237690000001"}
      assert SmsAdapter.normalize_msisdn("+237690000001") == {:ok, "+237690000001"}
      assert SmsAdapter.normalize_msisdn("+237 6 90 00 00 01") == {:ok, "+237690000001"}
      assert SmsAdapter.normalize_msisdn("123") == {:error, :invalid_msisdn}
    end
  end

  describe "OTP via pipeline" do
    test "repli legacy sans provider actif, n'échoue jamais", %{uniq: uniq} do
      alias GameHub.Notifications.ChannelDispatch
      # Aucun provider actif dans ce test → repli LogAdapter → :ok
      assert :ok = ChannelDispatch.send_otp_sms("+237690000001", "123456")
      assert :ok = ChannelDispatch.send_otp_email("test#{uniq}@exemple.com", "123456")
    end

    test "utilise le provider actif quand configuré", %{uniq: uniq} do
      alias GameHub.Notifications.ChannelDispatch
      stub_overrides(%{"stub_otp_#{uniq}" => StubSmsOk})
      assert {:ok, _} = create_sms_provider("stub_otp_#{uniq}")

      assert :ok = ChannelDispatch.send_otp_sms("+237690000001", "654321")
    end
  end

  describe "rotation de clé" do
    test "anciennes enveloppes lisibles via clés précédentes" do
      old_key = :crypto.strong_rand_bytes(32) |> Base.encode64()
      new_key = :crypto.strong_rand_bytes(32) |> Base.encode64()

      try do
        System.put_env("NOTIFICATION_CONFIG_KEY", old_key)
        encrypted = ConfigCrypto.encrypt_config(%{"api_key" => "rotation-secret"})
        assert ConfigCrypto.primary_decryptable?(encrypted["api_key"])

        # Rotation : nouvelle primaire, ancienne en repli
        System.put_env("NOTIFICATION_CONFIG_KEY", new_key)
        System.put_env("NOTIFICATION_CONFIG_PREVIOUS_KEYS", old_key)
        refute ConfigCrypto.primary_decryptable?(encrypted["api_key"])
        assert ConfigCrypto.decrypt_config(encrypted)["api_key"] == "rotation-secret"

        # Re-chiffrement avec la primaire
        rotated = ConfigCrypto.encrypt_config(ConfigCrypto.decrypt_config(encrypted))
        assert ConfigCrypto.primary_decryptable?(rotated["api_key"])
      after
        System.delete_env("NOTIFICATION_CONFIG_KEY")
        System.delete_env("NOTIFICATION_CONFIG_PREVIOUS_KEYS")
      end
    end
  end

  describe "templates avancés + broadcast v2" do
    test "routage : défaut inbox, surcharge, kill-switch", %{user: user, uniq: uniq} do
      # Sans ligne DB : repli inbox seule
      assert Notifications.routing_for("nope_#{uniq}") == %{channels: ["in_app"], is_active: true}

      # Liste : 11 événements, aucun personnalisé au départ
      rules = Notifications.list_routing()
      assert length(rules) == 11
      assert Enum.all?(rules, fn r -> r.customized == false end)

      # Surcharge canaux via admin
      assert {:ok, rule} = Notifications.upsert_routing("wallet_credit", %{"channels" => ["in_app", "push"], "is_active" => true})
      assert rule.channels == ["in_app", "push"]
      assert Notifications.routing_for("wallet_credit").channels == ["in_app", "push"]

      # dispatch suit le routage : job push enqueued
      assert {:ok, _} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "5", "motif" => "t"},
                 event_id: "rt-#{uniq}"
               )

      assert_enqueued(worker: GameHub.Notifications.Workers.PushWorker)

      # Kill-switch : plus aucun envoi
      assert {:ok, _} = Notifications.upsert_routing("wallet_credit", %{"channels" => ["in_app"], "is_active" => false})
      assert {:error, :disabled} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "5", "motif" => "t"},
                 event_id: "rt-off-#{uniq}"
               )

      # Canaux explicites : bypass interne préservé
      assert {:ok, _} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "5", "motif" => "t"},
                 channels: ["in_app"], event_id: "rt-bypass-#{uniq}"
               )

      # Validation : canal inconnu et liste vide rejetés
      assert {:error, _} = Notifications.upsert_routing("wallet_credit", %{"channels" => ["pigeon"], "is_active" => true})
      assert {:error, _} = Notifications.upsert_routing("wallet_credit", %{"channels" => [], "is_active" => true})
    end

    test "timeseries : 14 jours avec totaux cohérents", %{user: user, uniq: uniq} do
      assert {:ok, _} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "t"},
                 event_id: "ts-#{uniq}"
               )

      series = Notifications.timeseries(14)
      assert length(series) == 14

      today = Date.utc_today() |> Date.to_iso8601()
      today_row = Enum.find(series, fn row -> row.date == today end)
      assert today_row.total >= 1
      assert today_row.sent >= 1
      assert today_row.total == today_row.sent + today_row.failed + today_row.queued

      assert Notifications.timeseries(0) |> length() == 1
      assert Notifications.timeseries(999) |> length() == 90
    end

    test "télémétrie dispatch + delivery émise", %{user: user, uniq: uniq} do
      test_pid = self()
      handler = :"telemetry-test-#{uniq}"

      :ok =
        GameHub.Notifications.Telemetry.attach_many(handler, [[:dispatch], [:delivery]], fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end)

      try do
        assert {:ok, _} =
                 Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "t"},
                   event_id: "tm-#{uniq}"
                 )

        assert_received {:telemetry, [:wiwiga, :notifications, :dispatch], %{count: 1}, %{event_type: "wallet_credit"}}
        assert_received {:telemetry, [:wiwiga, :notifications, :delivery], %{count: 1}, %{channel: "in_app", status: "sent"}}
      after
        GameHub.Notifications.Telemetry.detach(handler)
      end
    end

    test "topics push : mapping, publish, repli per-token", %{user: user, uniq: uniq} do
      alias GameHub.Notifications.PushTopics

      defmodule StubTopicPush do
        @behaviour GameHub.Notifications.Adapters.PushAdapter
        @impl true
        def send_push(_token, _title, _body, _data, _config), do: {:ok, %{provider_message_id: "tok-1"}}
        def publish_topic(topic, _title, _body, _data, _config), do: {:ok, %{provider_message_id: "topic-#{topic}"}}
      end

      assert PushTopics.topic_for_event("admin_broadcast") == "all"
      assert PushTopics.topic_for_event("promo_broadcast") == "promos"
      assert PushTopics.topic_for_event("wallet_credit") == nil

      stub_overrides(%{"stub_topic_#{uniq}" => StubTopicPush})
      assert {:ok, _} = Notifications.create_provider(%{
        "channel" => "push", "name" => "stub_topic_#{uniq}", "display_name" => "topic",
        "is_active" => true, "priority" => 10, "config" => %{}
      })

      # Broadcast → 1 publication topic (pas de token requis)
      assert {:ok, notif} =
               Notifications.dispatch("admin_broadcast", user.id, %{"titre" => "A", "message" => "B"},
                 channels: ["push"], event_id: "topic-#{uniq}"
               )

      assert :ok = perform_job(GameHub.Notifications.Workers.PushWorker, %{"notification_id" => notif.id})

      assert %GameHub.Notifications.Delivery{status: "sent", provider_message_id: "topic-all"} =
               Notifications.get_channel_delivery(notif.id, "push")

      # Enregistrement token sans réseau : toujours OK (best-effort)
      assert {:ok, _} = Notifications.register_device_token(user.id, "android", "fcm-topic-token-#{uniq}")
      assert :ok = PushTopics.subscribe_token("fcm-topic-token-#{uniq}", true)
      assert :ok = PushTopics.unsubscribe_token("fcm-topic-token-#{uniq}")
      assert :ok = PushTopics.sync_promos(user.id, false)
    end

    test "notifications_enabled historique ignoré (matrice seule source)", %{user: user} do
      alias GameHub.Users.Preferences

      assert {:ok, prefs} =
               Preferences.update_preferences(user.id, %{
                 "notifications_enabled" => false,
                 "sound_enabled" => false
               })

      refute Map.has_key?(prefs, "notifications_enabled")
      assert prefs["sound_enabled"] == false

      assert {:ok, fresh} = Preferences.get_preferences(user.id)
      refute Map.has_key?(fresh, "notifications_enabled")
    end

    test "heures creuses : dispatch différé mais tracé", %{user: user, uniq: uniq} do
      alias GameHub.Users.Preferences

      assert {:ok, _} =
               Preferences.update_preferences(user.id, %{
                 "quiet_hours" => %{"enabled" => true, "start" => 0, "end" => 23}
               })

      # Le dispatch réussit, la delivery est tracée queued (job Oban
      # planifié au matin — schedule_in couvert par le calcul user_defer
      # testé ci-dessus + assert_enqueued du job).
      assert {:ok, notif} =
               Notifications.dispatch("promo_broadcast", user.id, %{"titre" => "QH", "message" => "nuit"},
                 channels: ["push"], event_id: "qh-job-#{uniq}"
               )

      assert %GameHub.Notifications.Delivery{status: "queued"} =
               Notifications.get_channel_delivery(notif.id, "push")

      assert_enqueued(worker: GameHub.Notifications.Workers.PushWorker)
    end

    test "heures creuses utilisateur : report marketing/social, jamais sécurité", %{user: user} do
      alias GameHub.Notifications.QuietHours
      alias GameHub.Users.Preferences

      # Nuit Douala : 23h30 UTC = 00h30 locales
      night = DateTime.new!(~D[2026-01-15], ~T[23:30:00], "Etc/UTC")
      noon = DateTime.new!(~D[2026-01-15], ~T[12:00:00], "Etc/UTC")

      # Désactivées par défaut
      assert QuietHours.user_defer(user.id, "marketing", night) == 0

      assert {:ok, _} =
               Preferences.update_preferences(user.id, %{
                 "quiet_hours" => %{"enabled" => true, "start" => 22, "end" => 7}
               })

      # 00h30 locales → report jusqu'à 7h locales (6h UTC) = 6h30
      assert QuietHours.user_defer(user.id, "marketing", night) == 6 * 3600 + 30 * 60
      assert QuietHours.user_defer(user.id, "social", night) > 0
      assert QuietHours.user_defer(user.id, "marketing", noon) == 0
      assert QuietHours.user_defer(user.id, "security", night) == 0
      assert QuietHours.user_defer(user.id, "transactional", night) == 0
      assert QuietHours.user_defer(-1, "marketing", night) == 0

      # Validation : heures hors 0..23 rejetées
      assert {:error, _} =
               Preferences.update_preferences(user.id, %{"quiet_hours" => %{"enabled" => true, "start" => 99, "end" => 7}})
    end

    test "action + priorité héritées du template, surcharge possible", %{user: user, uniq: uniq} do
      assert {:ok, _} =
               Notifications.create_template(%{
                 "key" => "act_test_#{uniq}", "channel" => "in_app", "locale" => "fr",
                 "version" => 1, "subject" => "T", "body_tpl" => "corps",
                 "category" => "transactional", "default_priority" => "high",
                 "action" => "/games", "is_active" => true
               })

      assert {:ok, notif} = Notifications.dispatch("act_test_#{uniq}", user.id, %{}, event_id: "act-#{uniq}")
      assert notif.priority == "high"
      assert notif.action == "/games"

      # Surcharge explicite prioritaire
      assert {:ok, notif2} =
               Notifications.dispatch("act_test_#{uniq}", user.id, %{},
                 event_id: "act2-#{uniq}", priority: "low", action: "/friends"
               )

      assert notif2.priority == "low"
      assert notif2.action == "/friends"
    end

    test "heures creuses : marketing la nuit reporté, sécurité jamais" do
      alias GameHub.Notifications.QuietHours

      night = DateTime.new!(~D[2026-01-15], ~T[23:30:00], "Etc/UTC")
      noon = DateTime.new!(~D[2026-01-15], ~T[12:00:00], "Etc/UTC")

      # 23h30 UTC = 00h30 Douala → report jusqu'à 6h UTC (6h30)
      assert QuietHours.defer_seconds("marketing", "low", night) == 6 * 3600 + 30 * 60
      assert QuietHours.defer_seconds("marketing", "low", noon) == 0
      assert QuietHours.defer_seconds("security", "low", night) == 0
      assert QuietHours.defer_seconds("marketing", "urgent", night) == 0
      assert QuietHours.defer_seconds("transactional", "low", night) == 0
    end

    test "retry-after honoré (snooze plafonné, repli, raise)" do
      alias GameHub.Notifications.WorkerRetry

      assert {:snooze, 45} = WorkerRetry.snooze_or_raise({:prov, {:rate_limited, 45}})
      assert {:snooze, 900} = WorkerRetry.snooze_or_raise({:rate_limited, 9999})
      assert {:snooze, 120} = WorkerRetry.snooze_or_raise({:prov, {:http, 429}})
      assert_raise RuntimeError, fn -> WorkerRetry.snooze_or_raise({:prov, :timeout}, false) end
    end

    test "broadcast bulk : prefs respectées", %{user: user, uniq: uniq} do
      alias GameHub.Notifications.Workers.BroadcastWorker

      # Opt-out in_app transactionnel pour cet utilisateur
      assert {:ok, _} = Notifications.upsert_preference(user.id, "transactional", "in_app", false)

      assert :ok =
               perform_job(BroadcastWorker, %{
                 "title" => "Annonce",
                 "message" => "bonjour",
                 "event_id" => "bulk-#{uniq}",
                 "last_id" => 0,
                 "category" => "transactional"
               })

      # Exclu par opt-out → rien pour lui sur cet event (autres users possibles)
      assert {:ok, items, _} = Notifications.list_for_user(user.id, %{})
      refute Enum.any?(items, fn n -> n.template_key == "admin_broadcast" end)

      # Opt-out retiré → reçu au batch suivant (transactionnel, jamais différé)
      assert {:ok, _} = Notifications.upsert_preference(user.id, "transactional", "in_app", true)

      assert :ok =
               perform_job(BroadcastWorker, %{
                 "title" => "Annonce",
                 "message" => "re-bonjour",
                 "event_id" => "bulk2-#{uniq}",
                 "last_id" => 0,
                 "category" => "transactional"
               })

      assert {:ok, items2, _} = Notifications.list_for_user(user.id, %{})
      assert Enum.any?(items2, fn n -> n.template_key == "admin_broadcast" end)
    end

    test "broadcast_to_all : catégorie + planifié" do
      alias GameHub.Notifications.Workers.BroadcastWorker

      assert {:error, :invalid_category} = Notifications.broadcast_to_all("T", "M", category: "spam")
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:ok, event_id} = Notifications.broadcast_to_all("T", "M", category: "marketing", scheduled_at: future)
      assert is_binary(event_id)
      assert_enqueued(worker: BroadcastWorker)
    end

    test "layout email : brandé, CTA, désinscription marketing" do
      alias GameHub.Notifications.EmailLayout

      html = EmailLayout.wrap("Sujet", "Bonjour.", category: "transactional")
      assert html =~ "WIWIGA"
      assert html =~ "Ouvrir WIWIGA"
      assert html =~ "Bonjour."

      # Headers one-click uniquement marketing
      assert [{"List-Unsubscribe", _}, {"List-Unsubscribe-Post", _}] =
               EmailLayout.unsubscribe_headers("https://x.test/prefs")
    end
  end

  describe "caps anti-spam" do
    test "segments SMS gsm vs unicode" do
      alias GameHub.Notifications.SmsSegments

      assert %{encoding: "gsm-7", segments: 1} = SmsSegments.count("Votre code WIWIGA : 123456")
      long = String.duplicate("a", 200)
      assert %{encoding: "gsm-7", segments: 2} = SmsSegments.count(long)
      assert %{encoding: "unicode", segments: 1} = SmsSegments.count("Bravo 🎉 +500 jetons")
    end

    test "rendu par canal + variables + preview + locale", %{user: user, uniq: uniq} do
      assert {:ok, _} =
               Notifications.create_template(%{
                 "key" => "chan_test_#{uniq}", "channel" => "sms", "locale" => "fr",
                 "version" => 1, "body_tpl" => "SMS:{{montant}}", "category" => "transactional",
                 "required_variables" => ["montant"], "is_active" => true
               })

      assert {:ok, _title, "SMS:500"} =
               Notifications.render_for_channel("chan_test_#{uniq}", "sms", %{"montant" => "500"})

      assert {:error, :no_template} =
               Notifications.render_for_channel("inexistant_#{uniq}", "sms", %{})

      assert "montant" in Notifications.template_variables("chan_test_#{uniq}")

      assert {:ok, %{body: "SMS:42", segments: %{segments: 1}}} =
               Notifications.preview_body("sms", "SMS:{{montant}}", %{"montant" => "42"})

      # Locale : défaut fr, puis préférence utilisateur
      assert Notifications.user_locale(user.id) == "fr"

      user
      |> Ecto.Changeset.change(%{preferences: %{"language" => "en"}})
      |> Repo.update!()

      assert Notifications.user_locale(user.id) == "en"
    end

    test "worker SMS utilise le template du canal", %{user: user, uniq: uniq} do
      test_pid = self()

      defmodule StubCaptureSms do
        @behaviour GameHub.Notifications.Adapters.SmsAdapter
        @impl true
        def send_sms(to, body, _config) do
          send(Application.get_env(:game_hub, :capture_pid), {:sms_sent, to, body})
          {:ok, %{provider_message_id: "cap-1"}}
        end
      end

      Application.put_env(:game_hub, :capture_pid, test_pid)
      stub_overrides(%{"stub_cap_#{uniq}" => StubCaptureSms})
      assert {:ok, _} = create_sms_provider("stub_cap_#{uniq}")

      # Base partagée entre runs : repart d'un template SMS déterministe
      Repo.delete_all(from t in GameHub.Notifications.Template, where: t.key == "wallet_credit" and t.channel == "sms")

      assert {:ok, _} =
               Notifications.create_template(%{
                 "key" => "wallet_credit", "channel" => "sms", "locale" => "fr",
                 "version" => 1, "body_tpl" => "CANAL-SMS:{{montant}}", "category" => "transactional",
                 "required_variables" => ["montant"], "is_active" => true
               })

      assert {:ok, notif} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "777", "motif" => "x"},
                 channels: ["sms"], to: "+237690000001", event_id: "cap-#{uniq}"
               )

      try do
        assert :ok = perform_job(SmsWorker, %{"notification_id" => notif.id, "to" => "+237690000001"})
        assert_received {:sms_sent, "+237690000001", "CANAL-SMS:777"}
      after
        Application.delete_env(:game_hub, :capture_pid)
      end
    end

    test "cron santé planifie + exécute sans envoi", %{uniq: uniq} do
      alias GameHub.Notifications.Workers.{HealthCheckSchedulerWorker, HealthCheckWorker}

      defmodule StubCronHealth do
        @behaviour GameHub.Notifications.Adapters.SmsAdapter
        @impl true
        def send_sms(_to, _body, _config), do: {:ok, %{provider_message_id: "x"}}
        @impl true
        def check_health(_config), do: {:ok, "cron OK"}
      end

      stub_overrides(%{"stub_cron_#{uniq}" => StubCronHealth})
      assert {:ok, provider} = create_sms_provider("stub_cron_#{uniq}")

      assert :ok = perform_job(HealthCheckSchedulerWorker, %{})
      assert_enqueued(worker: HealthCheckWorker)

      assert :ok = perform_job(HealthCheckWorker, %{"provider_id" => provider.id})
      assert %{last_health_status: "healthy"} = Repo.get!(GameHub.Notifications.Provider, provider.id)
      assert {:cancel, :not_found} = perform_job(HealthCheckWorker, %{"provider_id" => -1})
    end

    test "recherche inbox et logs par mot-clé", %{user: user, uniq: uniq} do
      assert {:ok, _} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "10", "motif" => "banane spéciale"},
                 event_id: "q-#{uniq}"
               )

      assert {:ok, items, 1} = Notifications.list_for_user(user.id, %{"q" => "banane"})
      assert length(items) == 1
      assert {:ok, _empty, 0} = Notifications.list_for_user(user.id, %{"q" => "xyz-introuvable-#{uniq}"})
      assert {:ok, _logs, total} = Notifications.list_logs(%{"q" => "banane"})
      assert total >= 1
    end

    test "health-check sans envoi (stub + inconnu + persistance)", %{uniq: uniq} do
      defmodule StubHealthOk do
        @behaviour GameHub.Notifications.Adapters.SmsAdapter
        @impl true
        def send_sms(_to, _body, _config), do: {:ok, %{provider_message_id: "x"}}
        @impl true
        def check_health(_config), do: {:ok, "stub OK"}
      end

      stub_overrides(%{"stub_health_#{uniq}" => StubHealthOk})
      assert {:ok, provider} = create_sms_provider("stub_health_#{uniq}")

      assert {:ok, %{status: "healthy"}} = Notifications.check_provider_health(provider.id)
      assert %{last_health_status: "healthy"} = Repo.get!(GameHub.Notifications.Provider, provider.id)

      # Sans callback check_health → unchecked, sans envoi
      stub_overrides(%{"stub_health_#{uniq}" => StubHealthOk, "stub_plain_#{uniq}" => StubSmsOk})
      assert {:ok, provider2} = create_sms_provider("stub_plain_#{uniq}")
      assert {:ok, %{status: "unchecked", detail: _}} = Notifications.check_provider_health(provider2.id)

      assert {:error, :not_found} = Notifications.check_provider_health(-1)
    end

    test "broadcast_to_all planifie un job, deletes template/provider", %{user: user} do
      alias GameHub.Notifications.Workers.BroadcastWorker

      assert {:ok, event_id} = Notifications.broadcast_to_all("Annonce", "Bonjour à tous")
      assert is_binary(event_id)
      assert_enqueued(worker: BroadcastWorker)

      # Broadcast worker : lot vide → :ok (pas d'envoi fantôme)
      assert :ok = perform_job(BroadcastWorker, %{"title" => "x", "message" => "y", "event_id" => "evt-test", "last_id" => 999_999_999})

      assert {:ok, template} =
               Notifications.create_template(%{
                 "key" => "del_me", "channel" => "in_app", "locale" => "fr",
                 "version" => 1, "body_tpl" => "x", "category" => "transactional"
               })

      assert {:ok, 1} = Notifications.delete_template(template.id)
      assert {:ok, 0} = Notifications.delete_template(-1)

      assert {:ok, provider} =
               Notifications.create_provider(%{
                 "channel" => "sms", "name" => "del_me", "display_name" => "X",
                 "is_active" => false, "priority" => 1, "config" => %{}
               })

      assert {:ok, 1} = Notifications.delete_provider(provider.id)
      assert {:ok, 0} = Notifications.delete_provider(-1)
      assert user.id > 0
    end

    test "quota user épuisé → rate_limited, security exemptée", %{user: user, uniq: uniq} do
      alias GameHub.Notifications.RateLimit
      Application.put_env(:game_hub, :notification_caps, %{sms: 1, email: 20, push: 50})

      try do
        assert {:ok, _} =
                 Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "t"},
                   channels: ["sms"], to: "+237690000001", event_id: "cap-#{uniq}-1"
                 )

        assert {:error, :rate_limited} =
                 Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "t"},
                   channels: ["sms"], to: "+237690000001", event_id: "cap-#{uniq}-2"
                 )

        # Sécurité jamais cappée
        assert {:ok, _} =
                 Notifications.dispatch("security_alert", user.id, %{"message" => "t"},
                   channels: ["sms"], to: "+237690000001", event_id: "cap-sec-#{uniq}"
                 )

        assert :ok = RateLimit.check_user(user.id, "in_app", "marketing")
      after
        Application.delete_env(:game_hub, :notification_caps)
      end
    end

    test "débit provider épuisé → limited", %{uniq: uniq} do
      alias GameHub.Notifications.RateLimit
      provider_id = 900_000 + rem(uniq, 99_999)

      assert :ok = RateLimit.check_provider(provider_id, 1)
      assert {:error, :limited} = RateLimit.check_provider(provider_id, 1)
    end
  end

  describe "config providers admin" do
    test "schéma catalogue : secrets chiffrés même hors heuristique", %{uniq: uniq} do
      import Ecto.Query
      # Isole le nom de catalogue (base partagée entre tests)
      Repo.delete_all(from p in GameHub.Notifications.Provider, where: p.name == "esms_africa" and p.channel == "sms")

      try do
        assert {:ok, provider} =
                 Notifications.create_provider(%{
                   "channel" => "sms",
                   "name" => "esms_africa",
                   "display_name" => "eSMS",
                   "is_active" => false,
                   "priority" => 10,
                   "config" => %{"base_url" => "https://x.test", "auth_header" => "Bearer #{uniq}"}
                 })

        raw = Repo.get!(GameHub.Notifications.Provider, provider.id)
        # auth_header : hors heuristique de nom, mais sensible via schéma
        assert ConfigCrypto.encrypted?(raw.config["auth_header"])
        assert raw.config["base_url"] == "https://x.test"
        assert Notifications.decrypted_config(raw)["auth_header"] == "Bearer #{uniq}"

        # Compteurs non sensibles exposés par list_providers
        listed =
          Notifications.list_providers(%{"channel" => "sms"})
          |> Enum.find(fn p -> p.name == "esms_africa" end)

        assert listed.config_keys >= 2
        assert listed.secrets_set >= 1
      after
        Repo.delete_all(from p in GameHub.Notifications.Provider, where: p.name == "esms_africa" and p.channel == "sms")
      end
    end

    test "schéma, lecture masquée et fusion", %{uniq: uniq} do
      assert {:ok, provider} =
               Notifications.create_provider(%{
                 "channel" => "sms",
                 "name" => "orange_cfg_#{uniq}",
                 "display_name" => "Orange",
                 "is_active" => false,
                 "priority" => 20,
                 "config" => %{"client_secret" => "shh-123", "sender_address" => "tel:+237600000000"}
               })

      # Schéma générique déduit des clés stockées (provider hors catalogue).
      # L'heuristique marque les secrets (secret/token/api_key...), pas les
      # identifiants publics. Les schémas du catalogue restent plus stricts.
      schema = Notifications.provider_config_schema("orange_cfg_#{uniq}", %{"client_secret" => "x", "sender_address" => "y"})
      by_schema_key = Map.new(schema, fn f -> {f.key, f} end)
      assert Map.keys(by_schema_key) |> Enum.sort() == ["client_secret", "sender_address"]
      assert by_schema_key["client_secret"].sensitive == true
      assert by_schema_key["sender_address"].sensitive == false

      # Lecture : secret masqué, clair visible
      assert {:ok, view} = Notifications.get_provider_config(provider.id)
      by_key = Map.new(view.fields, fn f -> {f.key, f} end)
      assert by_key["sender_address"].value == "tel:+237600000000"

      # Fusion : secret vide = conserver, clair mis à jour
      assert {:ok, updated} =
               Notifications.update_provider_config(provider.id, %{
                 "client_secret" => "",
                 "sender_address" => "tel:+237699999999"
               })

      updated_by_key = Map.new(updated.fields, fn f -> {f.key, f} end)
      assert updated_by_key["sender_address"].value == "tel:+237699999999"

      raw = Repo.get!(GameHub.Notifications.Provider, provider.id)
      assert Notifications.decrypted_config(raw)["client_secret"] == "shh-123"

      assert {:error, :not_found} = Notifications.get_provider_config(-1)
      assert {:error, :not_found} = Notifications.update_provider_config(-1, %{})
    end
  end

  describe "FcmV1.check_health/1 — validation offline des credentials" do
    alias GameHub.Notifications.Adapters.FcmV1

    defmodule StubPushFcmRejected do
      @behaviour GameHub.Notifications.Adapters.PushAdapter
      @impl true
      def send_push(_token, _title, _body, _data, _config) do
        {:permanent,
         {:fcm_rejected, 400,
          "{\n  \"error\": {\n    \"code\": 400,\n    \"message\": \"The registration token is not a valid FCM registration token\",\n    \"status\": \"INVALID_ARGUMENT\"}}"}}
      end
    end

    defmodule StubPushTokenInvalid do
      @behaviour GameHub.Notifications.Adapters.PushAdapter
      @impl true
      def send_push(_token, _title, _body, _data, _config), do: {:token_invalid, "tok"}
    end

    # Clé RSA éphémère (jamais persistée) encodée comme Google :
    # PKCS#8 (`BEGIN PRIVATE KEY`) ou PKCS#1 (`BEGIN RSA PRIVATE KEY`).
    defp service_account_json(pem) do
      Jason.encode!(%{
        "type" => "service_account",
        "project_id" => "wiwiga-test",
        "private_key_id" => "test-key",
        "private_key" => pem,
        "client_email" => "test@wiwiga-test.iam.gserviceaccount.com",
        "client_id" => "123",
        "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
        "token_uri" => "https://oauth2.googleapis.com/token"
      })
    end

    defp pem_of(key, entry_type) do
      :public_key.pem_encode([:public_key.pem_entry_encode(entry_type, key)]) |> IO.iodata_to_binary()
    end

    test "accepte une clé PKCS#8 (format Google)" do
      rsa_key = :public_key.generate_key({:rsa, 2048, 65_537})
      json = service_account_json(pem_of(rsa_key, :PrivateKeyInfo))

      assert {:ok, _detail} =
               FcmV1.check_health(%{"project_id" => "wiwiga-test", "service_account_json" => json})
    end

    test "accepte une clé PKCS#1" do
      rsa_key = :public_key.generate_key({:rsa, 2048, 65_537})
      json = service_account_json(pem_of(rsa_key, :RSAPrivateKey))

      assert {:ok, _detail} =
               FcmV1.check_health(%{"project_id" => "wiwiga-test", "service_account_json" => json})
    end

    test "rejette une clé illisible ou un JSON incomplet" do
      bad_key = service_account_json("-----BEGIN PRIVATE KEY-----\nINVALIDE\n-----END PRIVATE KEY-----\n")

      assert {:error, :invalid_private_key} =
               FcmV1.check_health(%{"project_id" => "wiwiga-test", "service_account_json" => bad_key})

      assert {:error, :invalid_service_account} =
               FcmV1.check_health(%{"project_id" => "wiwiga-test", "service_account_json" => "{}"})

      assert {:error, :missing_credentials} = FcmV1.check_health(%{})
    end

    test "test_provider : destinataire rejeté = connexion OK (pas d'erreur)" do
      assert {:ok, provider} =
               Notifications.create_provider(%{
                 "channel" => "push",
                 "name" => "stub_fcm_rej_#{System.unique_integer([:positive])}",
                 "display_name" => "push",
                 "is_active" => true,
                 "priority" => 10,
                 "config" => %{}
               })

      stub_overrides(%{provider.name => StubPushFcmRejected})

      assert {:ok, %{status: "rejected", detail: detail}} =
               Notifications.test_provider(provider.id, %{"recipient" => "mauvais-token"})

      # Message FCM extrait, pas de blob JSON brut
      assert detail =~ "The registration token is not a valid FCM registration token"
      refute detail =~ "@type"
    end

    test "test_provider : token invalide = connexion OK (pas d'erreur)" do
      assert {:ok, provider} =
               Notifications.create_provider(%{
                 "channel" => "push",
                 "name" => "stub_fcm_inv_#{System.unique_integer([:positive])}",
                 "display_name" => "push",
                 "is_active" => true,
                 "priority" => 10,
                 "config" => %{}
               })

      stub_overrides(%{provider.name => StubPushTokenInvalid})

      assert {:ok, %{status: "token_invalid", detail: detail}} =
               Notifications.test_provider(provider.id, %{"recipient" => "vieux-token"})

      assert detail =~ "Connexion"
    end
  end
end
