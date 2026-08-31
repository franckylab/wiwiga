# ==================================
# WIWIGA - Controller Jetons
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.TokenController
# Description: Endpoints gestion jetons virtuels

defmodule GameHubWeb.TokenController do
  @moduledoc """
  Controller gestion des jetons virtuels.

  ## Endpoints — seuls achat, cadeau ami, promos
    GET    /api/tokens/balance        - Solde jetons + valeur monétaire
    POST   /api/tokens/purchase       - Achat jetons
    POST   /api/tokens/gift           - Envoi cadeau (amis uniquement)
    GET    /api/tokens/transactions   - Historique
    GET    /api/tokens/summary        - Résumé complet
    GET    /api/tokens/promos         - Promos disponibles
    POST   /api/tokens/promos/:id/redeem - Réclamer promo

  Endpoints supprimés : /tokens/exchange, /tokens/transfer
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
  
  # Échange et transfert supprimés définitivement.
  # POST /api/tokens/exchange et POST /api/tokens/transfer retirés du router.
  # Seuls POST /api/tokens/purchase, /gift (+ promos) restent.
  
  # ========================================
  # CADEAU
  # ========================================
  
  @doc """
  POST /api/tokens/gift — cadeau entre amis uniquement.

  Body: %{recipient_id: 2, token_amount: 100, message: "Joyeux anniversaire!", idempotency_key: "key"}
  Message optionnel trimé ≤140c.
  """
  def gift(conn, %{"recipient_id" => recipient_id, "token_amount" => token_amount, "idempotency_key" => key} = params) do
    user_id = get_current_user_id(conn)
    message = params |> Map.get("message", "") |> to_string() |> String.trim() |> String.slice(0, 140)

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

        {:error, :not_friends} ->
          conn |> put_status(403) |> json(Errors.error("Cadeaux réservés aux amis", 403, "NOT_FRIENDS"))

        {:error, :recipient_not_found} ->
          conn |> put_status(404) |> json(Errors.error("Destinataire non trouvé", 404, "RECIPIENT_NOT_FOUND"))

        {:error, :daily_gift_limit_exceeded} ->
          conn |> put_status(429) |> json(Errors.error("Limite journalière de cadeaux atteinte", 429, "DAILY_GIFT_LIMIT_EXCEEDED"))

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
  
  Liste les promotions actives et valides.
  Retourne [] si la table n'existe pas ou en cas d'erreur DB.
  """
  def promos(conn, _params) do
    try do
      active_promos = Tokens.list_active_promos()
      
      conn |> put_status(200) |> json(%{
        success: true,
        data: active_promos,
        meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
      })
    rescue
      error in [Ecto.QueryError, Ecto.NoResultsError, DBConnection.ConnectionError] ->
        # Table inexistante ou erreur DB → retourne une liste vide (non-bloquant)
        require Logger
        Logger.warning("Promos endpoint error: #{inspect(error)}")
        
        conn |> put_status(200) |> json(%{
          success: true,
          data: [],
          meta: %{
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            warning: "Promotions temporarily unavailable"
          }
        })
      
      error ->
        # Erreur inattendue → 500 avec message
        require Logger
        Logger.error("Promos unexpected error: #{inspect(error)}")
        
        conn |> put_status(500) |> json(
          Errors.error("Erreur chargement promotions", 500, "PROMOS_ERROR")
        )
    end
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
