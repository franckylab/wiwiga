# ==================================
# WIWIGA - Controller Webhook Paiement Campay
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.PaymentWebhookController
# Description: Webhook Campay avec idempotence + vérification signature

defmodule GameHubWeb.PaymentWebhookController do
  @moduledoc """
  Webhook pour paiements Mobile Money (Campay).
  
  ## Sécurité
  - Vérification signature HMAC
  - Clé idempotence obligatoire
  - Idempotent: même transaction = même réponse
  - Logs d'audit complets
  
  ## Flow
  1. Campay envoie notification paiement
  2. Vérifier signature
  3. Vérifier idempotence
  4. Créditer portefeuille (ACID)
  5. Retourner statut
  """
  
  use GameHubWeb, :controller

  import Ecto.Query

  alias GameHub.Wallet
  alias GameHub.Repo
  alias GameHub.Errors
  
  @campay_secret "CAMPAY_WEBHOOK_SECRET_KEY"
  
  @doc """
  POST /api/webhooks/campay
  
  Body Campay:
  %{
    "transaction_id": "TX123",
    "amount": 5000,
    "phone": "+237612345678",
    "status": "SUCCESS",
    "idempotency_key": "unique_key_123",
    "signature": "hmac_signature_here"
  }
  
  Response:
  - 200: %{status: "success"}
  - 400: %{status: "failed", reason: "..."}
  """
  def campay_callback(conn, params) do
    # 1. Vérifier signature HMAC
    unless valid_signature?(params) do
      conn
      |> put_status(401)
      |> json(Errors.error("Signature invalide", 401, "INVALID_SIGNATURE"))
    else
      # 2. Traiter paiement
      process_payment(conn, params)
    end
  end
  
  @doc """
  Traite notification paiement.
  """
  defp process_payment(conn, %{
    "transaction_id" => tx_id,
    "amount" => amount,
    "phone" => phone,
    "status" => "SUCCESS",
    "idempotency_key" => idempotency_key
  }) do
    # 3. Vérifier idempotence
    case check_idempotence(idempotency_key) do
      :already_processed ->
        # Retourner succès (déjà traité)
        conn
        |> put_status(200)
        |> json(%{status: "success", message: "Transaction déjà traitée"})
      
      :new ->
        # 4. Créditer portefeuille (ACID)
        process_new_payment(conn, phone, amount, tx_id, idempotency_key)
    end
  end
  
  defp process_payment(conn, %{"status" => "FAILED"}) do
    # Paiement échoué - logger
    IO.puts("[PAYMENT] Failed: #{inspect(conn.params)}")
    
    conn
    |> put_status(200)
    |> json(%{status: "acknowledged", message: "Échec enregistré"})
  end
  
  defp process_payment(conn, params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètres webhook invalides", 400, "INVALID_WEBHOOK", params))
  end
  
  @doc """
  Traite nouveau paiement réussi.
  """
  defp process_new_payment(conn, phone, amount, tx_id, idempotency_key) do
    # Trouver utilisateur par téléphone
    case get_user_by_phone(phone) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND", %{phone: phone}))
      
      user ->
        # Créditer portefeuille (ACID transaction)
        case Wallet.deposit(user.id, amount, idempotency_key) do
          {:ok, transaction} ->
            # Log succès
            IO.puts("[PAYMENT] SUCCESS: User #{user.id} credited #{amount} FCFA (TX: #{tx_id})")
            
            conn
            |> put_status(200)
            |> json(%{
              status: "success",
              transaction_id: tx_id,
              new_balance: transaction.balance_after
            })
          
          {:error, :idempotency_key_used} ->
            # Déjà traité (race condition)
            conn
            |> put_status(200)
            |> json(%{status: "success", message: "Transaction déjà traitée"})
          
          {:error, reason} ->
            # Erreur - log critique
            IO.puts("[PAYMENT] ERROR: #{reason} for TX #{tx_id}")
            
            conn
            |> put_status(500)
            |> json(Errors.error("Erreur traitement paiement", 500, "PAYMENT_PROCESSING_ERROR"))
        end
    end
  end
  
  @doc """
  Vérifie signature HMAC Campay.
  """
  defp valid_signature?(params) do
    signature = params["signature"]
    
    # Reconstruire payload sans signature
    payload = params
      |> Map.delete("signature")
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn key -> "#{key}=#{params[key]}" end)
      |> Enum.join("&")
    
    # Calculer HMAC SHA256
    expected_signature = :crypto.mac(:hmac, :sha256, @campay_secret, payload)
      |> Base.encode16(case: :lower)
    
    signature == expected_signature
  end
  
  @doc """
  Vérifie idempotence transaction.
  """
  defp check_idempotence(idempotency_key) do
    # Chercher transaction existante
    query = from t in "wallet_transactions",
      where: t.idempotency_key == ^idempotency_key,
      select: t.id
    
    case GameHub.Repo.one(query) do
      nil -> :new
      _ -> :already_processed
    end
  end
  
  @doc """
  Trouve utilisateur par téléphone.
  """
  defp get_user_by_phone(phone) do
    query = from u in "users",
      where: u.phone == ^phone,
      select: [:id, :phone, :balance]
    
    GameHub.Repo.one(query)
  end
end
