# ==================================
# WIWIGA - Controller Portefeuille
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.WalletController
# Description: Endpoints dépôt, retrait, balance, historique

defmodule GameHubWeb.WalletController do
  @moduledoc """
  Controller gestion portefeuille.
  
  ## Endpoints
    GET    /api/wallet/balance           - Solde utilisateur
    POST   /api/wallet/deposit           - Dépôt Mobile Money
    POST   /api/wallet/withdraw          - Retrait
    GET    /api/wallet/transactions      - Historique
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.Wallet
  alias GameHub.Errors
  
  @doc """
  GET /api/wallet/balance
  
  Header: Authorization: Bearer <token>
  
  Response: %{success: true, data: %{balance: 50000}}
  """
  def balance(conn, _params) do
    user_id = get_current_user_id(conn)
    
    # Récupérer balance depuis DB
    user_balance = 50000 # Placeholder
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{balance: user_balance},
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  @doc """
  POST /api/wallet/deposit
  
  Body: %{amount: 5000, idempotency_key: "unique_key_123"}
  
  Response: %{success: true, data: %{new_balance: 55000}}
  """
  def deposit(conn, %{"amount" => amount, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    
    # Validation montant
    if amount < 100 do
      conn
      |> put_status(400)
      |> json(Errors.error("Montant minimum: 100 FCFA", 400, "AMOUNT_TOO_LOW", %{min: 100}))
    else
      case Wallet.deposit(user_id, amount, key) do
        {:ok, transaction} ->
          conn
          |> put_status(201)
          |> json(%{
            success: true,
            data: %{
              new_balance: transaction.balance_after,
              transaction: %{
                id: transaction.id,
                type: "deposit",
                amount: transaction.amount
              }
            },
            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
          })
        
        {:error, :idempotency_key_used} ->
          conn
          |> put_status(409)
          |> json(Errors.error("Cette transaction a déjà été effectuée", 409, "IDEMPOTENCY_KEY_USED"))
        
        {:error, reason} ->
          conn
          |> put_status(400)
          |> json(Errors.error("Erreur lors du dépôt", 400, "DEPOSIT_FAILED", %{reason: reason}))
      end
    end
  end
  
  def deposit(conn, _params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètres 'amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  @doc """
  POST /api/wallet/withdraw
  
  Body: %{amount: 2000, idempotency_key: "unique_key_456"}
  
  Response: %{success: true, data: %{new_balance: 48000}}
  """
  def withdraw(conn, %{"amount" => amount, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    
    if amount < 100 do
      conn
      |> put_status(400)
      |> json(Errors.error("Montant minimum: 100 FCFA", 400, "AMOUNT_TOO_LOW"))
    else
      case Wallet.withdraw(user_id, amount, key) do
        {:ok, transaction} ->
          conn
          |> put_status(201)
          |> json(%{
            success: true,
            data: %{
              new_balance: transaction.balance_after,
              transaction: %{
                id: transaction.id,
                type: "withdrawal",
                amount: transaction.amount
              }
            },
            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
          })
        
        {:error, :insufficient_funds} ->
          conn
          |> put_status(400)
          |> json(Errors.error("Solde insuffisant", 400, "INSUFFICIENT_FUNDS"))
        
        {:error, :idempotency_key_used} ->
          conn
          |> put_status(409)
          |> json(Errors.error("Cette transaction a déjà été effectuée", 409, "IDEMPOTENCY_KEY_USED"))
        
        {:error, reason} ->
          conn
          |> put_status(400)
          |> json(Errors.error("Erreur lors du retrait", 400, "WITHDRAWAL_FAILED", %{reason: reason}))
      end
    end
  end
  
  def withdraw(conn, _params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètres 'amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  @doc """
  GET /api/wallet/transactions
  
  Query: ?page=1&limit=20
  
  Response: %{success: true, data: [...], pagination: %{...}}
  """
  def list_transactions(conn, params) do
    user_id = get_current_user_id(conn)
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    
    # Récupérer transactions paginées
    transactions = [] # Placeholder
    total = 0
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: transactions,
      pagination: %{
        page: page,
        limit: limit,
        total: total,
        total_pages: ceil(total / limit),
        has_next: page * limit < total,
        has_prev: page > 1
      },
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  # === Fonctions Privées ===
  
  defp get_current_user_id(conn) do
    # Extraire user_id depuis JWT token
    # Guardian.Plug.current_resource(conn)
    "user_id_from_jwt"
  end
end
