# ==================================
# WIWIGA - Controller Jetons
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.TokenController
# Description: Endpoints gestion jetons virtuels

defmodule GameHubWeb.TokenController do
  @moduledoc """
  Controller gestion des jetons virtuels.
  
  ## Endpoints
    GET    /api/tokens/balance        - Solde jetons + valeur monétaire
    POST   /api/tokens/purchase       - Achat jetons
    POST   /api/tokens/exchange       - Échange jetons → monnaie
    POST   /api/tokens/transfer       - Transfert jetons
    POST   /api/tokens/gift           - Envoi cadeau
    GET    /api/tokens/transactions   - Historique
    GET    /api/tokens/summary        - Résumé complet
    GET    /api/tokens/promos         - Promos disponibles
    POST   /api/tokens/promos/:id/redeem - Réclamer promo
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Tokens, Errors}
  alias GameHub.Tokens.TokenConfig
  
  # ========================================
  # SOLDE
  # ========================================
  
  @doc """
  GET /api/tokens/balance
  
  Response: %{success: true, data: %{token_balance: 5000, monetary_value: 50000}}
  """
  def balance(conn, _params) do
    user_id = get_current_user_id(conn)
    
    case Tokens.get_token_summary(user_id) do
      {:error, :user_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      {:ok, summary} ->
        conn |> put_status(200) |> json(%{
          success: true,
          data: summary,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end
  
  # ========================================
  # ACHAT
  # ========================================
  
  @doc """
  POST /api/tokens/purchase
  
  Body: %{amount: 5000, idempotency_key: "key"}
  amount = montant en centimes à convertir en jetons
  """
  def purchase(conn, %{"amount" => amount, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    
    if amount < 100 do
      conn |> put_status(400) |> json(Errors.error("Montant minimum: 1 FCFA (100 centimes)", 400, "AMOUNT_TOO_LOW", %{min: 100}))
    else
      case Tokens.purchase_tokens(user_id, amount, key) do
        {:ok, transaction} ->
          config = TokenConfig.get_config()
          tokens = TokenConfig.monetary_to_tokens(amount, config)
          
          conn |> put_status(201) |> json(%{
            success: true,
            data: %{
              tokens_credited: tokens,
              monetary_value: amount,
              exchange_rate: config.exchange_rate,
              transaction: %{
                id: transaction.id,
                type: "purchase",
                token_amount: transaction.token_amount,
                balance_after: transaction.balance_after
              }
            },
            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
          })
        
        {:error, :idempotency_key_used} ->
          conn |> put_status(409) |> json(Errors.error("Transaction déjà effectuée", 409, "IDEMPOTENCY_KEY_USED"))
        
        {:error, reason} ->
          conn |> put_status(400) |> json(Errors.error("Erreur achat jetons", 400, "PURCHASE_FAILED", %{reason: reason}))
      end
    end
  end
  
  def purchase(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("'amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  # ========================================
  # ÉCHANGE
  # ========================================
  
  @doc """
  POST /api/tokens/exchange
  
  Body: %{token_amount: 1000, idempotency_key: "key"}
  """
  def exchange(conn, %{"token_amount" => token_amount, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    config = TokenConfig.get_config()
    
    cond do
      token_amount < config.min_exchange_tokens ->
        conn |> put_status(400) |> json(Errors.error(
          "Minimum #{config.min_exchange_tokens} jetons", 400, "BELOW_MIN_EXCHANGE",
          %{min_exchange: config.min_exchange_tokens}
        ))
      
      token_amount > config.max_exchange_tokens ->
        conn |> put_status(400) |> json(Errors.error(
          "Maximum #{config.max_exchange_tokens} jetons", 400, "ABOVE_MAX_EXCHANGE",
          %{max_exchange: config.max_exchange_tokens}
        ))
      
      true ->
        case Tokens.exchange_tokens(user_id, token_amount, key) do
          {:ok, transaction} ->
            monetary_value = TokenConfig.tokens_to_monetary(token_amount, config)
            
            conn |> put_status(201) |> json(%{
              success: true,
              data: %{
                tokens_exchanged: token_amount,
                monetary_value: monetary_value,
                fee: TokenConfig.calculate_exchange_fee(token_amount, config),
                transaction: %{
                  id: transaction.id,
                  type: "exchange",
                  token_amount: transaction.token_amount,
                  balance_after: transaction.balance_after
                }
              },
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          
          {:error, :insufficient_tokens} ->
            conn |> put_status(400) |> json(Errors.error("Solde de jetons insuffisant", 400, "INSUFFICIENT_TOKENS"))
          
          {:error, :idempotency_key_used} ->
            conn |> put_status(409) |> json(Errors.error("Transaction déjà effectuée", 409, "IDEMPOTENCY_KEY_USED"))
          
          {:error, reason} ->
            conn |> put_status(400) |> json(Errors.error("Erreur échange", 400, "EXCHANGE_FAILED", %{reason: reason}))
        end
    end
  end
  
  def exchange(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("'token_amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  # ========================================
  # TRANSFERT
  # ========================================
  
  @doc """
  POST /api/tokens/transfer
  
  Body: %{recipient_id: 2, token_amount: 500, idempotency_key: "key"}
  """
  def transfer(conn, %{"recipient_id" => recipient_id, "token_amount" => token_amount, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    
    if token_amount <= 0 do
      conn |> put_status(400) |> json(Errors.error("Montant invalide", 400, "INVALID_AMOUNT"))
    else
      case Tokens.transfer_tokens(user_id, recipient_id, token_amount, key) do
        {:ok, result} ->
          conn |> put_status(200) |> json(%{
            success: true,
            data: result,
            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
          })
        
        {:error, :insufficient_tokens} ->
          conn |> put_status(400) |> json(Errors.error("Solde de jetons insuffisant", 400, "INSUFFICIENT_TOKENS"))
        
        {:error, :recipient_not_found} ->
          conn |> put_status(404) |> json(Errors.error("Destinataire non trouvé", 404, "RECIPIENT_NOT_FOUND"))
        
        {:error, :transfers_disabled} ->
          conn |> put_status(403) |> json(Errors.error("Transferts désactivés", 403, "TRANSFERS_DISABLED"))
        
        {:error, :cannot_transfer_to_self} ->
          conn |> put_status(400) |> json(Errors.error("Impossible de se transférer des jetons", 400, "SELF_TRANSFER"))
        
        {:error, reason} ->
          conn |> put_status(400) |> json(Errors.error("Erreur transfert", 400, "TRANSFER_FAILED", %{reason: reason}))
      end
    end
  end
  
  def transfer(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("'recipient_id', 'token_amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  # ========================================
  # CADEAU
  # ========================================
  
  @doc """
  POST /api/tokens/gift
  
  Body: %{recipient_id: 2, token_amount: 100, message: "Joyeux anniversaire!", idempotency_key: "key"}
  """
  def gift(conn, %{"recipient_id" => recipient_id, "token_amount" => token_amount, "idempotency_key" => key} = params) do
    user_id = get_current_user_id(conn)
    message = Map.get(params, "message", "")
    
    if token_amount <= 0 do
      conn |> put_status(400) |> json(Errors.error("Montant invalide", 400, "INVALID_AMOUNT"))
    else
      case Tokens.send_gift(user_id, recipient_id, token_amount, key, message) do
        {:ok, result} ->
          conn |> put_status(200) |> json(%{
            success: true,
            data: Map.put(result, :message, message),
            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
          })
        
        {:error, :insufficient_tokens} ->
          conn |> put_status(400) |> json(Errors.error("Solde de jetons insuffisant", 400, "INSUFFICIENT_TOKENS"))
        
        {:error, :gifts_disabled} ->
          conn |> put_status(403) |> json(Errors.error("Cadeaux désactivés", 403, "GIFTS_DISABLED"))
        
        {:error, reason} ->
          conn |> put_status(400) |> json(Errors.error("Erreur cadeau", 400, "GIFT_FAILED", %{reason: reason}))
      end
    end
  end
  
  def gift(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("'recipient_id', 'token_amount' et 'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  # ========================================
  # HISTORIQUE
  # ========================================
  
  @doc """
  GET /api/tokens/transactions?page=1&limit=20
  """
  def transactions(conn, params) do
    user_id = get_current_user_id(conn)
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer() |> min(100)
    
    case Tokens.get_token_transactions(user_id, page, limit) do
      {:ok, transactions, total} ->
        conn |> put_status(200) |> json(%{
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
  end
  
  # ========================================
  # RÉSUMÉ
  # ========================================
  
  @doc """
  GET /api/tokens/summary
  """
  def summary(conn, _params) do
    user_id = get_current_user_id(conn)
    
    case Tokens.get_token_summary(user_id) do
      {:ok, summary} ->
        conn |> put_status(200) |> json(%{
          success: true,
          data: summary,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :user_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
    end
  end
  
  # ========================================
  # PROMOS
  # ========================================
  
  @doc """
  GET /api/tokens/promos
  """
  def promos(conn, _params) do
    active_promos = Tokens.list_active_promos()
    
    conn |> put_status(200) |> json(%{
      success: true,
      data: active_promos,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  @doc """
  POST /api/tokens/promos/:id/redeem
  
  Body: %{idempotency_key: "key"}
  """
  def redeem_promo(conn, %{"id" => promo_id, "idempotency_key" => key}) do
    user_id = get_current_user_id(conn)
    
    case Tokens.credit_promo(user_id, String.to_integer(promo_id), key) do
      {:ok, result} ->
        conn |> put_status(201) |> json(%{
          success: true,
          data: result,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :promo_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Promotion non trouvée", 404, "PROMO_NOT_FOUND"))
      
      {:error, :promo_not_available} ->
        conn |> put_status(400) |> json(Errors.error("Promotion non disponible", 400, "PROMO_NOT_AVAILABLE"))
      
      {:error, :promo_already_redeemed} ->
        conn |> put_status(409) |> json(Errors.error("Promotion déjà réclamée", 409, "PROMO_ALREADY_REDEEMED"))
      
      {:error, reason} ->
        conn |> put_status(400) |> json(Errors.error("Erreur réclamation", 400, "REDEEM_FAILED", %{reason: reason}))
    end
  end
  
  def redeem_promo(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("'idempotency_key' requis", 400, "VALIDATION_ERROR"))
  end
  
  # === Privé ===
  
  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
end
