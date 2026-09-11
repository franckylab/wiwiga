defmodule GameHub.NotificationsTest do
  @moduledoc """
  Tests unitaires pour le système de notifications multi-canal (Phase 0 : in_app).
  """

  use ExUnit.Case, async: false

  alias GameHub.Notifications
  alias GameHub.Notifications.{Delivery, DeviceToken, Preference, Template, TemplateRenderer}
  alias GameHub.Repo
  alias GameHub.Users.User

  import Ecto.Query

  setup do
    GameHub.TestHelpers.cleanup_test_data()
    GameHub.Notifications.ProviderCache.invalidate_all()

    uniq = System.unique_integer([:positive])

    user =
      Repo.insert!(%User{
        phone: "+237699#{String.pad_leading(to_string(rem(uniq, 900000) + 100000), 6, "0")}",
        username: "notif_#{uniq}",
        name: "Notif Test User",
        balance: 10_000,
        token_balance: 1000,
        is_active: true,
        has_verified_kyc: true
      })

    {:ok, user: user, uniq: uniq}
  end

  describe "TemplateRenderer" do
    test "rend les variables {{nom}}" do
      assert TemplateRenderer.render("Bonjour {{pseudo}}, +{{montant}} jetons", %{"pseudo" => "Ali", "montant" => "500"}) ==
               {:ok, "Bonjour Ali, +500 jetons"}
    end

    test "signale les variables requises manquantes" do
      assert TemplateRenderer.render("Code : {{code}}", %{}, ["code"]) ==
               {:error, {:missing_variables, ["code"]}}
    end

    test "extrait les variables d'un template" do
      assert TemplateRenderer.extract_variables("{{a}} et {{b}} et {{a}}") == ["a", "b"]
    end
  end

  describe "dispatch/4 (in_app)" do
    test "crée une notification avec rendu du template", %{user: user, uniq: uniq} do
      assert {:ok, notif} =
               Notifications.dispatch("wallet_credit", user.id, %{"montant" => "500", "motif" => "gain test"},
                 event_id: "evt-#{uniq}"
               )

      assert notif.title == "Jetons reçus"
      assert notif.body == "+500 jetons : gain test"
      assert notif.status == "sent"
      assert notif.is_read == false
    end

    test "est idempotent sur event_id", %{user: user, uniq: uniq} do
      assert {:ok, first} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "100", "motif" => "x"}, event_id: "dup-#{uniq}")
      assert {:ok, second} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "100", "motif" => "x"}, event_id: "dup-#{uniq}")
      assert first.id == second.id
    end

    test "respecte l'opt-out marketing mais jamais la sécurité", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.upsert_preference(user.id, "marketing", "push", false)

      assert {:error, :opted_out} =
               Notifications.dispatch("promo_broadcast", user.id, %{"message" => "promo"},
                 channels: ["push"],
                 category: "marketing",
                 event_id: "opt-#{uniq}"
               )

      # La sécurité reste toujours envoyée
      assert {:ok, _} =
               Notifications.dispatch("security_alert", user.id, %{"message" => "alerte"},
                 channels: ["push"],
                 event_id: "sec-#{uniq}"
               )
    end

    test "trace une delivery in_app envoyée", %{user: user, uniq: uniq} do
      assert {:ok, notif} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "10", "motif" => "t"}, event_id: "dlv-#{uniq}")
      assert [%Delivery{channel: "in_app", status: "sent"}] = Repo.all(from d in Delivery, where: d.notification_id == ^notif.id)
    end
  end

  describe "inbox joueur" do
    test "liste, compteur et marquage lu", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "a"}, event_id: "ib-#{uniq}-1")
      assert {:ok, _} = Notifications.dispatch("wallet_debit", user.id, %{"montant" => "2", "motif" => "b"}, event_id: "ib-#{uniq}-2")

      assert Notifications.unread_count(user.id) == 2
      assert {:ok, items, 2} = Notifications.list_for_user(user.id, %{})

      [first | _] = items
      assert {:ok, _} = Notifications.mark_read(user.id, first.id)
      assert Notifications.unread_count(user.id) == 1

      assert {:ok, 1} = Notifications.mark_all_read(user.id)
      assert Notifications.unread_count(user.id) == 0
    end

    test "ne marque pas la notification d'un autre utilisateur", %{user: user, uniq: uniq} do
      assert {:ok, notif} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "a"}, event_id: "other-#{uniq}")
      assert {:error, :not_found} = Notifications.mark_read(user.id + 999_999, notif.id)
    end

    test "suppression avec propriété vérifiée", %{user: user, uniq: uniq} do
      assert {:ok, notif} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "1", "motif" => "a"}, event_id: "del-#{uniq}")
      assert {:ok, 0} = Notifications.delete_notification(user.id + 999_999, notif.id)
      assert {:ok, 1} = Notifications.delete_notification(user.id, notif.id)
      assert {:ok, _items, 0} = Notifications.list_for_user(user.id, %{})
    end
  end

  describe "admin providers" do
    test "CRUD + test de connexion", %{uniq: uniq} do
      assert {:ok, provider} =
               Notifications.create_provider(%{
                 channel: "sms",
                 name: "test_sms_#{uniq}",
                 display_name: "SMS Test",
                 is_active: true,
                 priority: 5,
                 config: %{}
               })

      assert provider.channel == "sms"

      assert {:ok, updated} = Notifications.update_provider(provider.id, %{"is_active" => false})
      assert updated.is_active == false

      # Provider inactif → erreur explicite
      assert {:error, :provider_inactive} = Notifications.test_provider(provider.id, %{"recipient" => "+237600000000"})

      assert {:ok, active} = Notifications.update_provider(provider.id, %{"is_active" => true})
      assert active.is_active == true
      # Nom sans adapter → erreur explicite (pas d'envoi deviné)
      assert {:error, :unknown_adapter} = Notifications.test_provider(provider.id, %{"recipient" => "+237600000001"})
      # Sans destinataire → erreur explicite
      assert {:error, :recipient_required} = Notifications.test_provider(provider.id, %{})
    end
  end

  describe "admin templates" do
    test "CRUD + preview + variables manquantes", %{uniq: uniq} do
      key = "test_tpl_#{uniq}"

      assert {:ok, template} =
               Notifications.create_template(%{
                 key: key,
                 channel: "in_app",
                 locale: "fr",
                 version: 1,
                 subject: "Sujet test",
                 body_tpl: "Bonjour {{pseudo}}",
                 required_variables: ["pseudo"],
                 category: "transactional"
               })

      assert {:ok, %{body: "Bonjour Ali"}} = Notifications.preview_template(template.id, %{"pseudo" => "Ali"})

      assert {:error, {:missing_variables, ["pseudo"]}} =
               Notifications.preview_template(template.id, %{})

      assert {:ok, updated} = Notifications.update_template(template.id, %{"subject" => "Nouveau sujet"})
      assert updated.subject == "Nouveau sujet"

      assert [%Template{} | _] = Notifications.list_templates(%{"key" => key})
    end
  end

  describe "device tokens" do
    test "enregistrement, upsert et invalidation", %{user: user, uniq: uniq} do
      token = "fcm-test-token-#{uniq}"

      assert {:ok, device} = Notifications.register_device_token(user.id, "android", token, "1.0.0")
      assert device.is_valid == true

      # Ré-enregistrement (même token) → mise à jour, pas de doublon
      assert {:ok, same} = Notifications.register_device_token(user.id, "android", token, "1.0.1")
      assert same.id == device.id

      assert {:ok, invalid} = Notifications.invalidate_device_token(token)
      assert invalid.is_valid == false

      assert {:ok, 1} = Notifications.unregister_device_token(token)
      assert Repo.get_by(DeviceToken, token: token) == nil
    end
  end

  describe "logs admin + replay + stats" do
    test "logs paginés, détail et replay", %{user: user, uniq: uniq} do
      assert {:ok, notif} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "50", "motif" => "log"}, event_id: "log-#{uniq}")

      assert {:ok, _items, total} = Notifications.list_logs(%{"event_type" => "wallet_credit"})
      assert total >= 1

      assert {:ok, %{notification: found, deliveries: [_ | _]}} = Notifications.get_log(notif.id)
      assert found.id == notif.id

      assert {:ok, replayed} = Notifications.replay(notif.id)
      assert replayed.id != notif.id
      assert replayed.event_type == "wallet_credit"
    end

    test "stats par statut et canal", %{user: user, uniq: uniq} do
      assert {:ok, _} = Notifications.dispatch("wallet_credit", user.id, %{"montant" => "5", "motif" => "s"}, event_id: "stat-#{uniq}")

      stats = Notifications.stats()
      assert is_map(stats.by_status)
      assert is_map(stats.by_channel)
      assert Map.get(stats.by_status, "sent", 0) >= 1
    end
  end

  describe "préférences" do
    test "la sécurité est forcée à true", %{user: user} do
      assert {:ok, pref} = Notifications.upsert_preference(user.id, "security", "sms", false)
      assert pref.enabled == true

      assert [%Preference{} | _] = Notifications.list_preferences(user.id)
    end
  end

  describe "seed_defaults/0" do
    test "est idempotent" do
      assert {:ok, %{providers: 11, templates: 44, routing: 11}} = Notifications.seed_defaults()
      assert {:ok, %{providers: 11, templates: 44, routing: 11}} = Notifications.seed_defaults()
      assert length(Notifications.list_providers()) >= 11
      assert length(Notifications.list_routing()) == 11
    end
  end
end
