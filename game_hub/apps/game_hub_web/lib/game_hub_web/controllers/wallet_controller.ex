# ==================================
# WIWIGA - Controller Compte Utilisateur
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.WalletController
# Description: Endpoints dépôt, retrait, balance, historique

defmodule GameHubWeb.WalletController do
  @moduledoc """
  Controller gestion compte utilisateur.
  
  ## Endpoints
    GET    /api/wallet/balance           - Solde utilisateur
    POST   /api/wallet/deposit           - Dépôt Mobile Money
    POST   /api/wallet/withdraw          - Retrait
    GET    /api/wallet/transactions      - Historique
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Wallet, Errors}
  
  @doc """
  GET /api/wallet/balance
  
  Header: Authorization: Bearer <token>
  
  Response: %{success: true, data: %{balance: 50000}}
  """
  def balance(conn, _params) do
    user_id = get_current_user_id(conn)
    
    case Wallet.get_balance(user_id) do
      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      {:ok, balance} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{balance: balance},
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
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
      |> json(Errors.error("Montant minimum: 1 FCFA (100 centimes)", 400, "AMOUNT_TOO_LOW", %{min: 100}))
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
      |> json(Errors.error("Montant minimum: 1 FCFA (100 centimes)", 400, "AMOUNT_TOO_LOW"))
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
    page = parse_int_param(params["page"], 1, 1, 1000)
    limit = parse_int_param(params["limit"], 20, 1, 100)
    type = Map.get(params, "type")
    search = Map.get(params, "search") || Map.get(params, "q")
    from_dt = parse_date_param(params["from"])
    to_dt = parse_date_param(params["to"])

    case Wallet.list_transactions(user_id, page, limit, type: type, from: from_dt, to: to_dt, search: search) do
      {:ok, transactions, total} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: transactions,
          pagination: %{
            page: page,
            limit: limit,
            total: total,
            total_pages: ceil(total / max(limit, 1)),
            has_next: page * limit < total,
            has_prev: page > 1
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end

  defp parse_int_param(nil, default, _min, _max), do: default
  defp parse_int_param(val, default, min, max) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n |> max(min) |> min(max)
      :error -> default
    end
  end
  defp parse_int_param(val, default, min, max) when is_integer(val), do: val |> max(min) |> min(max)
  defp parse_int_param(_, default, _, _), do: default

  defp parse_date_param(nil), do: nil
  defp parse_date_param(val) when is_binary(val) do
    case DateTime.from_iso8601(val) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  rescue
    _ -> nil
  end
  defp parse_date_param(_), do: nil
  
  # === Fonctions Privées ===
  
  defp get_current_user_id(conn) do
    # Utiliser AuthPlug
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
end
