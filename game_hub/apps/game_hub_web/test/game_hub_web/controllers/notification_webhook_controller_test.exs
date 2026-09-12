defmodule GameHubWeb.NotificationWebhookControllerTest do
  @moduledoc """
  Tests des webhooks notifications : STOP/START SMS et SES/SNS.
  Toujours 200, suppression immédiate, signature SNS vérifiée.
  """

  use ExUnit.Case, async: false
  use Plug.Test

  alias GameHub.Notifications
  alias GameHub.Repo
  alias GameHub.Users.User
  import Ecto.Query

  setup do
    # GameHub.TestHelpers n'est compilé que pour les tests de l'app
    # game_hub : nettoyage local explicite (mêmes tables).
    Repo.delete_all(GameHub.Notifications.Delivery)
    Repo.delete_all(GameHub.Notifications.Notification)
    Repo.delete_all(GameHub.Notifications.DeviceToken)
    Repo.delete_all(GameHub.Notifications.Preference)
    Repo.delete_all(GameHub.Notifications.Suppression)
    Repo.delete_all(User)

    uniq = System.unique_integer([:positive])

    user =
      Repo.insert!(%User{
        phone: "+237690#{String.pad_leading(to_string(rem(uniq, 900000) + 100000), 6, "0")}",
        email: "stop#{uniq}@exemple.com",
        username: "stop_#{uniq}",
        name: "Stop Test",
        balance: 0,
        token_balance: 0,
        is_active: true,
        has_verified_kyc: true
      })

    {:ok, user: user}
  end

  describe "SmsWebhookController.inbound/2" do
    test "STOP supprime + coupe le marketing, 200", %{user: user} do
      conn = conn(:post, "/api/webhooks/sms/orange_cm/inbound")

      conn =
        GameHubWeb.SmsWebhookController.inbound(conn, %{
          "provider" => "orange_cm",
          "from" => user.phone,
          "text" => "STOP PLEASE"
        })

      assert conn.status == 200
      assert conn.resp_body =~ "unsubscribed"
      assert Notifications.suppressed?("sms", user.phone, "marketing")
      # Sécurité exemptée (OTP intact)
      refute Notifications.suppressed?("sms", user.phone, "security")

      prefs = Notifications.list_preferences(user.id) |> Map.new(fn p -> {{p.category, p.channel}, p.enabled} end)
      assert prefs[{"marketing", "sms"}] == false
      assert prefs[{"marketing", "email"}] == false
      assert prefs[{"marketing", "push"}] == false
    end

    test "mots entiers uniquement : NONSTOP ignoré", %{user: user} do
      conn = conn(:post, "/api/webhooks/sms/orange_cm/inbound")

      conn =
        GameHubWeb.SmsWebhookController.inbound(conn, %{
          "provider" => "orange_cm",
          "from" => user.phone,
          "text" => "NONSTOP"
        })

      assert conn.status == 200
      assert conn.resp_body =~ "ignored"
      refute Notifications.suppressed?("sms", user.phone, "marketing")
    end

    test "START réinscrit", %{user: user} do
      assert {:ok, _} = Notifications.suppress("sms", user.phone, "stop_keyword", "test")

      conn = conn(:post, "/api/webhooks/sms/orange_cm/inbound")

      conn =
        GameHubWeb.SmsWebhookController.inbound(conn, %{
          "provider" => "orange_cm",
          "from" => user.phone,
          "text" => "START"
        })

      assert conn.status == 200
      assert conn.resp_body =~ "resubscribed"
      refute Notifications.suppressed?("sms", user.phone, "marketing")
    end

    test "sans expéditeur → 200 sans effet" do
      conn = conn(:post, "/api/webhooks/sms/orange_cm/inbound")
      conn = GameHubWeb.SmsWebhookController.inbound(conn, %{"provider" => "x", "text" => "STOP"})
      assert conn.status == 200
    end
  end

  describe "SesWebhookController.callback/2" do
    test "signature invalide → ignoré, 200 (sans réseau : hôte non SNS)" do
      conn = conn(:post, "/api/webhooks/ses")

      conn =
        GameHubWeb.SesWebhookController.callback(conn, %{
          "Type" => "Notification",
          "Message" => "{}",
          "Signature" => "bogus",
          "SigningCertURL" => "https://evil.test/cert.pem"
        })

      assert conn.status == 200
      assert conn.resp_body =~ "success\":false"
    end

    test "confirmation avec URL non SNS → ignorée, 200" do
      conn = conn(:post, "/api/webhooks/ses")

      conn =
        GameHubWeb.SesWebhookController.callback(conn, %{
          "Type" => "SubscriptionConfirmation",
          "SubscribeURL" => "https://evil.test/confirm"
        })

      assert conn.status == 200
    end

    test "type inconnu → ignoré, 200" do
      conn = conn(:post, "/api/webhooks/ses")
      conn = GameHubWeb.SesWebhookController.callback(conn, %{"Type" => "Ping"})
      assert conn.status == 200
    end
  end

  describe "suppressions au dispatch" do
    test "supprimé → envoi bloqué sauf sécurité", %{user: user} do
      alias GameHub.Notifications.ChannelDispatch

      assert {:ok, _} = Notifications.suppress("sms", user.phone, "stop_keyword", "test")
      assert {:ok, _} = Notifications.suppress("email", user.email, "complaint", "test")

      # Marketing bloqué
      assert {:permanent, :suppressed} = ChannelDispatch.send_sms(user.phone, "promo", "marketing")
      assert {:permanent, :suppressed} = ChannelDispatch.send_email(user.email, "s", "b", category: "marketing")
      # Sécurité intacte (pas de provider actif → autre erreur, jamais :suppressed)
      refute match?({:permanent, :suppressed}, ChannelDispatch.send_sms(user.phone, "code", "security"))

      # Levée → renvoi possible (plus de blocage suppression)
      assert {:ok, 1} = Notifications.unsuppress("sms", user.phone)
      refute Notifications.suppressed?("sms", user.phone, "marketing")
    end
  end

  describe "routes device-token (régression)" do
    # Les routes statiques doivent matcher AVANT "/notifications/:id",
    # sinon "device-token" est capturé comme :id (500 au logout).
    test "DELETE /api/notifications/device-token → unregister_token" do
      assert %{plug: GameHubWeb.NotificationController, plug_opts: :unregister_token} =
               Phoenix.Router.route_info(
                 GameHubWeb.Router,
                 "DELETE",
                 "/api/notifications/device-token",
                 "localhost"
               )
    end

    test "POST /api/notifications/device-token → register_token" do
      assert %{plug: GameHubWeb.NotificationController, plug_opts: :register_token} =
               Phoenix.Router.route_info(
                 GameHubWeb.Router,
                 "POST",
                 "/api/notifications/device-token",
                 "localhost"
               )
    end
  end
end
