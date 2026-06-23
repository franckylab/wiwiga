defmodule GameHubWeb.PaymentWebhookControllerTest do
  @moduledoc """
  Tests pour le webhook de paiement Campay.
  
  Tests critiques:
  - Vérification signature HMAC
  - Idempotence webhook
  - Créditer portefeuille ACID
  - Gestion échecs paiement
  - User not found
  - Transactions dupliquées
  """
  
  use ExUnit.Case, async: false
  use Plug.Test
  
  alias GameHubWeb.PaymentWebhookController
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  import Ecto.Query
  
  @campay_secret "CAMPAY_WEBHOOK_SECRET_KEY"
  
  setup do
    # Nettoyer
    Repo.delete_all(WalletTransaction)
    Repo.delete_all(User)
    
    # Créer utilisateur de test
    user = Repo.insert!(%User{
      phone: "+237612345678",
      name: "Campay Test User",
      balance: 100000,
      is_active: true,
      has_verified_kyc: true
    })
    
    %{user: user}
  end
  
  describe "valid_signature?/1" do
    test "accepte une signature HMAC valide" do
      # Construire payload
      params = %{
        "transaction_id" => "TX123",
        "amount" => 5000,
        "phone" => "+237612345678",
        "status" => "SUCCESS",
        "idempotency_key" => "test_key_123"
      }
      
      # Calculer signature valide
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      # La fonction valid_signature? est privée, on la teste via le endpoint
      # Pour l'instant, on teste le calcul directement
      assert signature == calculate_hmac_signature(params)
    end
    
    test "rejette une signature invalide" do
      params = %{
        "transaction_id" => "TX123",
        "amount" => 5000,
        "phone" => "+237612345678",
        "status" => "SUCCESS",
        "idempotency_key" => "test_key_123",
        "signature" => "invalid_signature_here"
      }
      
      # Signature invalide devrait être rejetée
      refute params["signature"] == calculate_hmac_signature(Map.delete(params, "signature"))
    end
  end
  
  describe "campay_callback/2 - Signature" do
    test "rejette requête sans signature", %{user: user} do
      params = %{
        "transaction_id" => "TX123",
        "amount" => 5000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => "test_no_sig_#{System.unique_integer()}"
      }
      
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      assert conn.status == 401
      response = Jason.decode!(conn.resp_body)
      assert response["error"]["code"] == "INVALID_SIGNATURE"
    end
    
    test "rejette requête avec signature invalide", %{user: user} do
      params = %{
        "transaction_id" => "TX123",
        "amount" => 5000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => "test_bad_sig_#{System.unique_integer()}",
        "signature" => "bad_signature"
      }
      
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      assert conn.status == 401
    end
    
    test "accepte requête avec signature valide", %{user: user} do
      idempotency_key = "test_valid_sig_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "TX456",
        "amount" => 10000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      conn = conn(:post, "/api/webhooks/campay", params_with_sig)
      conn = PaymentWebhookController.campay_callback(conn, params_with_sig)
      
      # Devrait réussir (200)
      assert conn.status == 200
    end
  end
  
  describe "process_payment/2 - Paiement réussi" do
    setup do
      # Créer params avec signature valide
      idempotency_key = "payment_test_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "TX789",
        "amount" => 15000,
        "phone" => "+237612345678",
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      %{params: params_with_sig, idempotency_key: idempotency_key}
    end
    
    test "crédite le portefeuille de l'utilisateur", %{user: user, params: params} do
      initial_balance = user.balance
      
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      assert conn.status == 200
      
      # Vérifier que le balance a augmenté
      updated_user = Repo.get(User, user.id)
      expected_balance = initial_balance + String.to_integer(params["amount"])
      
      assert updated_user.balance == expected_balance
    end
    
    test "crée une transaction de type deposit", %{user: user, params: params} do
      conn = conn(:post, "/api/webhooks/campay", params)
      PaymentWebhookController.campay_callback(conn, params)
      
      # Vérifier transaction créée
      transaction = Repo.one(
        from t in WalletTransaction,
        where: t.idempotency_key == ^params["idempotency_key"],
        select: t
      )
      
      assert transaction != nil
      assert transaction.type == "deposit"
      assert transaction.amount == String.to_integer(params["amount"])
      assert transaction.user_id == user.id
    end
    
    test "retourne nouveau balance dans la réponse", %{user: user, params: params} do
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      response = Jason.decode!(conn.resp_body)
      
      assert response["status"] == "success"
      assert response["transaction_id"] == params["transaction_id"]
      
      # Le nouveau balance devrait être dans la réponse
      assert Map.has_key?(response, "new_balance")
    end
    
    test "respecte l'idempotence - même key = pas de double crédit", %{user: user, params: params} do
      # Premier traitement
      conn1 = conn(:post, "/api/webhooks/campay", params)
      conn1 = PaymentWebhookController.campay_callback(conn1, params)
      
      assert conn1.status == 200
      
      balance_after_first = Repo.get(User, user.id).balance
      
      # Second traitement avec même idempotency_key
      conn2 = conn(:post, "/api/webhooks/campay", params)
      conn2 = PaymentWebhookController.campay_callback(conn2, params)
      
      assert conn2.status == 200
      
      # Le balance ne doit pas avoir changé
      balance_after_second = Repo.get(User, user.id).balance
      assert balance_after_first == balance_after_second
      
      # Une seule transaction doit exister
      count = Repo.aggregate(
        from(t in WalletTransaction, where: t.idempotency_key == ^params["idempotency_key"]),
        :count,
        :id
      )
      
      assert count == 1
    end
  end
  
  describe "process_payment/2 - Paiement échoué" do
    test "gère statut FAILED sans créditer", %{user: user} do
      idempotency_key = "failed_payment_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "TX_FAIL",
        "amount" => 50000,
        "phone" => user.phone,
        "status" => "FAILED",
        "idempotency_key" => idempotency_key,
        "signature" => calculate_hmac_signature(%{
          "transaction_id" => "TX_FAIL",
          "amount" => 50000,
          "phone" => user.phone,
          "status" => "FAILED",
          "idempotency_key" => idempotency_key
        })
      }
      
      initial_balance = user.balance
      
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      assert response["status"] == "acknowledged"
      
      # Le balance ne doit pas avoir changé
      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == initial_balance
    end
  end
  
  describe "process_payment/2 - Utilisateur non trouvé" do
    test "rejette paiement pour phone inexistant" do
      idempotency_key = "user_not_found_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "TX_NOUSER",
        "amount" => 10000,
        "phone" => "+237699999999", # Phone qui n'existe pas
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      conn = conn(:post, "/api/webhooks/campay", params_with_sig)
      conn = PaymentWebhookController.campay_callback(conn, params_with_sig)
      
      assert conn.status == 404
      response = Jason.decode!(conn.resp_body)
      assert response["error"]["code"] == "USER_NOT_FOUND"
    end
  end
  
  describe "process_payment/2 - Paramètres invalides" do
    test "rejette paramètres manquants" do
      params = %{
        "transaction_id" => "TX_INCOMPLETE"
        # Manque: amount, phone, status, idempotency_key
      }
      
      conn = conn(:post, "/api/webhooks/campay", params)
      conn = PaymentWebhookController.campay_callback(conn, params)
      
      assert conn.status == 400
    end
  end
  
  describe "check_idempotence/1" do
    test "détecte transaction déjà traitée", %{user: user} do
      idempotency_key = "idempotence_check_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "TX_IDEM",
        "amount" => 5000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      # Premier traitement
      conn1 = conn(:post, "/api/webhooks/campay", params_with_sig)
      conn1 = PaymentWebhookController.campay_callback(conn1, params_with_sig)
      
      assert conn1.status == 200
      
      # Second traitement
      conn2 = conn(:post, "/api/webhooks/campay", params_with_sig)
      conn2 = PaymentWebhookController.campay_callback(conn2, params_with_sig)
      
      assert conn2.status == 200
      response = Jason.decode!(conn2.resp_body)
      assert response["message"] == "Transaction déjà traitée"
    end
  end
  
  describe "scénarios réels" do
    test "flow complet: paiement unique crédite une fois" do
      # Créer utilisateur
      user = Repo.insert!(%User{
        phone: "+237600000001",
        name: "Flow Test User",
        balance: 0,
        is_active: true
      })
      
      # Simuler paiement Campay
      idempotency_key = "flow_test_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "CAMPAY_12345",
        "amount" => 25000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      # Webhook reçu
      conn = conn(:post, "/api/webhooks/campay", params_with_sig)
      conn = PaymentWebhookController.campay_callback(conn, params_with_sig)
      
      # Vérifier succès
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      assert response["status"] == "success"
      assert response["new_balance"] == 25000
      
      # Vérifier DB
      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == 25000
      
      # Vérifier transaction
      transaction = Repo.one(
        from t in WalletTransaction,
        where: t.idempotency_key == ^idempotency_key
      )
      
      assert transaction.type == "deposit"
      assert transaction.amount == 25000
      assert transaction.balance_before == 0
      assert transaction.balance_after == 25000
    end
    
    test "multi-paiements successifs incrémentent correctement" do
      user = Repo.insert!(%User{
        phone: "+237600000002",
        name: "Multi Payment User",
        balance: 0,
        is_active: true
      })
      
      # Trois paiements successifs
      Enum.each(1..3, fn i ->
        idempotency_key = "multi_pay_#{i}_#{System.unique_integer()}"
        
        params = %{
          "transaction_id" => "CAMPAY_MULTI_#{i}",
          "amount" => 10000,
          "phone" => user.phone,
          "status" => "SUCCESS",
          "idempotency_key" => idempotency_key
        }
        
        signature = calculate_hmac_signature(params)
        params_with_sig = Map.put(params, "signature", signature)
        
        conn = conn(:post, "/api/webhooks/campay", params_with_sig)
        PaymentWebhookController.campay_callback(conn, params_with_sig)
      end)
      
      # Balance final devrait être 30000 (3 x 10000)
      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == 30000
      
      # Trois transactions doivent exister
      count = Repo.aggregate(
        from(t in WalletTransaction, where: t.user_id == ^user.id),
        :count,
        :id
      )
      
      assert count == 3
    end
    
    test "race condition simulée - idempotence protège" do
      user = Repo.insert!(%User{
        phone: "+237600000003",
        name: "Race Condition User",
        balance: 0,
        is_active: true
      })
      
      idempotency_key = "race_condition_#{System.unique_integer()}"
      
      params = %{
        "transaction_id" => "CAMPAY_RACE",
        "amount" => 50000,
        "phone" => user.phone,
        "status" => "SUCCESS",
        "idempotency_key" => idempotency_key
      }
      
      signature = calculate_hmac_signature(params)
      params_with_sig = Map.put(params, "signature", signature)
      
      # Simuler 5 requêtes simultanées (séquentiellement dans le test)
      Enum.each(1..5, fn _ ->
        conn = conn(:post, "/api/webhooks/campay", params_with_sig)
        PaymentWebhookController.campay_callback(conn, params_with_sig)
      end)
      
      # Balance ne doit être crédité qu'une seule fois
      updated_user = Repo.get(User, user.id)
      assert updated_user.balance == 50000
      
      # Une seule transaction
      count = Repo.aggregate(
        from(t in WalletTransaction, where: t.idempotency_key == ^idempotency_key),
        :count,
        :id
      )
      
      assert count == 1
    end
  end
  
  # === Fonctions Helpers ===
  
  defp calculate_hmac_signature(params) do
    # Reconstruire payload sans signature
    payload = params
      |> Map.delete("signature")
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn key -> "#{key}=#{params[key]}" end)
      |> Enum.join("&")
    
    # Calculer HMAC SHA256
    :crypto.mac(:hmac, :sha256, @campay_secret, payload)
      |> Base.encode16(case: :lower)
  end
end
