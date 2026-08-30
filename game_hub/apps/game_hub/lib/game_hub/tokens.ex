# ==================================
# WIWIGA - Module Tokens (ACID)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens
# Description: Gestion ACID des jetons virtuels avec transactions

defmodule GameHub.Tokens do
  @moduledoc """
  Gestion complète du système de jetons virtuels.
  
  ## Opérations
  - **Achat** : Monnaie → Jetons (via paiement Mobile Money)
  - **Échange** : Jetons → Monnaie (retrait)
  - **Mise** : Débit jetons pour jouer
  - **Gains** : Crédit jetons après victoire
  - **Transfert** : Jetons entre joueurs
  - **Cadeau** : Envoi gratuit de jetons
  - **Promo** : Jetons promotionnels avec conditions
  - **Commission** : Prélèvement commission en jetons
  
  ## Règles Critiques
  - TOUJOURS transaction ACID
  - TOUJOURS verrouillage pessimiste FOR UPDATE
  - TOUJOURS clé idempotence
  - TOUJOURS log d'audit
  """
  
  import Ecto.Query
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Tokens.{TokenTransaction, TokenConfig, PromoToken, UserPromoToken}
  alias GameHub.AuditLog
  
  # ========================================
  # SOLDE
  # ========================================
  
  @doc """
  Récupère le solde en jetons d'un utilisateur.
  """
  @spec get_token_balance(integer()) :: {:ok, integer()} | {:error, atom()}
  def get_token_balance(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user.token_balance}
    end
  end
  
  @doc """
  Récupère un résumé complet (jetons + valeur monétaire).
  """
  @spec get_token_summary(integer()) :: {:ok, map()} | {:error, atom()}
  def get_token_summary(user_id) do
    case get_token_balance(user_id) do
      {:error, reason} -> {:error, reason}
      {:ok, balance} ->
        config = TokenConfig.get_config()
        monetary_centimes = TokenConfig.tokens_to_monetary(balance, config)
        
        {:ok, %{
          token_balance: balance,
          wiga_balance: balance,
          monetary_value_centimes: monetary_centimes,
          monetary_value_fcfa: monetary_centimes / 100,
          exchange_rate: config.exchange_rate,
          min_exchange: config.min_exchange_tokens,
          max_exchange: config.max_exchange_tokens,
          transfer_enabled: config.transfer_enabled,
          gift_enabled: config.gift_enabled
        }}
    end
  end
  
  # ========================================
  # ACHAT DE JETONS
  # ========================================
  
  @doc """
  Achat de jetons après paiement Mobile Money confirmé.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `monetary_amount`: Montant payé en centimes
    - `idempotency_key`: Clé unique
    
  ## Flow
    1. Calcul jetons reçus (taux config)
    2. Crédit jetons
    3. Transaction traçabilité
  """
  @spec purchase_tokens(integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def purchase_tokens(user_id, monetary_amount, idempotency_key) when monetary_amount > 0 do
    Repo.transaction(fn ->
      case get_token_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          config = TokenConfig.get_config()
          
          # Calcul jetons
          tokens = TokenConfig.monetary_to_tokens(monetary_amount, config)
          
          if tokens <= 0 do
            Repo.rollback(:amount_too_low)
          else
            balance_before = user.token_balance
            balance_after = balance_before + tokens
            
            transaction = create_token_transaction(%{
              user_id: user_id,
              type: "purchase",
              token_amount: tokens,
              balance_before: balance_before,
              balance_after: balance_after,
              monetary_value: monetary_amount,
              exchange_rate: config.exchange_rate,
              idempotency_key: idempotency_key
            })
            
            update_user_token_balance(user_id, balance_after)
            
            AuditLog.log(
              "token_purchase",
              user_id,
              "tokens",
              "user_#{user_id}",
              %{tokens: tokens, monetary_value: monetary_amount, balance_after: balance_after}
            )
            
            transaction
          end
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def purchase_tokens(_, amount, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # ========================================
  # ÉCHANGE JETONS → MONNAIE
  # ========================================
  
  @doc """
  Échange jetons contre monnaie (retrait).
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `token_amount`: Nombre de jetons à échanger
    - `idempotency_key`: Clé unique
    
  ## Validations
    - Min/Max échange
    - Solde suffisant
    - Frais d'échange
  """
  @spec exchange_tokens(integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def exchange_tokens(user_id, token_amount, idempotency_key) when token_amount > 0 do
    Repo.transaction(fn ->
      case get_token_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          config = TokenConfig.get_config()
          
          # Vérifier limites
          cond do
            token_amount < config.min_exchange_tokens ->
              Repo.rollback(:below_min_exchange)
            
            token_amount > config.max_exchange_tokens ->
              Repo.rollback(:above_max_exchange)
            
            user.token_balance < token_amount ->
              Repo.rollback(:insufficient_tokens)
            
            true ->
              # Calcul frais
              fee = TokenConfig.calculate_exchange_fee(token_amount, config)
              net_tokens = token_amount - fee
              monetary_value = TokenConfig.tokens_to_monetary(net_tokens, config)
              
              balance_before = user.token_balance
              balance_after = balance_before - token_amount
              
              transaction = create_token_transaction(%{
                user_id: user_id,
                type: "exchange",
                token_amount: -token_amount,
                balance_before: balance_before,
                balance_after: balance_after,
                monetary_value: monetary_value,
                exchange_rate: config.exchange_rate,
                idempotency_key: idempotency_key,
                metadata: %{fee: fee, net_tokens: net_tokens}
              })
              
              update_user_token_balance(user_id, balance_after)
              
              # Débiter aussi le solde monétaire
              deduct_monetary_balance(user_id, monetary_value)
              
              AuditLog.log(
                "token_exchange",
                user_id,
                "tokens",
                "user_#{user_id}",
                %{tokens_exchanged: token_amount, monetary_value: monetary_value, fee: fee}
              )
              
              transaction
          end
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def exchange_tokens(_, amount, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # ========================================
  # MISE DE JEU
  # ========================================
  
  @doc """
  Déduit des jetons pour une mise de jeu.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `bet_tokens`: Nombre de jetons misés
    - `game_id`: ID du jeu
    - `idempotency_key`: Clé unique
  """
  @spec deduct_for_bet(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def deduct_for_bet(user_id, bet_tokens, game_id, idempotency_key) when bet_tokens > 0 do
    Repo.transaction(fn ->
      case get_token_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          # Vérifier mise min
          game_type = extract_game_type(game_id)
          min_tokens = TokenConfig.get_min_bet_tokens(game_type)
          
          cond do
            bet_tokens < min_tokens ->
              Repo.rollback(:below_min_bet)
            
            user.token_balance < bet_tokens ->
              Repo.rollback(:insufficient_tokens)
            
            true ->
              balance_before = user.token_balance
              balance_after = balance_before - bet_tokens
              
              transaction = create_token_transaction(%{
                user_id: user_id,
                type: "bet",
                token_amount: -bet_tokens,
                balance_before: balance_before,
                balance_after: balance_after,
                idempotency_key: idempotency_key,
                game_id: game_id,
                metadata: %{game_type: game_type}
              })
              
              update_user_token_balance(user_id, balance_after)
              
              AuditLog.log(
                "token_bet",
                user_id,
                "tokens",
                "user_#{user_id}",
                %{bet_tokens: bet_tokens, game_id: game_id, balance_after: balance_after}
              )
              
              transaction
          end
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def deduct_for_bet(_, amount, _, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # ========================================
  # GAINS
  # ========================================
  
  @doc """
  Crédite les gains en jetons après victoire.
  """
  @spec credit_winnings(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def credit_winnings(user_id, win_tokens, game_id, idempotency_key) when win_tokens > 0 do
    Repo.transaction(fn ->
      case get_token_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          balance_before = user.token_balance
          balance_after = balance_before + win_tokens
          
          transaction = create_token_transaction(%{
            user_id: user_id,
            type: "winnings",
            token_amount: win_tokens,
            balance_before: balance_before,
            balance_after: balance_after,
            idempotency_key: idempotency_key,
            game_id: game_id
          })
          
          update_user_token_balance(user_id, balance_after)
          
          AuditLog.log(
            "token_winnings",
            user_id,
            "tokens",
            "user_#{user_id}",
            %{win_tokens: win_tokens, game_id: game_id, balance_after: balance_after}
          )
          
          transaction
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def credit_winnings(_, amount, _, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # ========================================
  # TRANSFERT ENTRE JOUEURS
  # ========================================
  
  @doc """
  Transfère des jetons entre joueurs.
  
  ## Parameters
    - `from_user_id`: ID expéditeur
    - `to_user_id`: ID destinataire
    - `token_amount`: Nombre de jetons
    - `idempotency_key`: Clé unique
  """
  @spec transfer_tokens(integer(), integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def transfer_tokens(from_user_id, to_user_id, token_amount, idempotency_key)
      when token_amount > 0 and from_user_id != to_user_id do
    config = TokenConfig.get_config()
    
    unless config.transfer_enabled do
      {:error, :transfers_disabled}
    else
      Repo.transaction(fn ->
        case get_token_transaction_by_key(idempotency_key) do
          nil ->
            # Vérifier destinataire existe
            unless Repo.get(User, to_user_id) do
              Repo.rollback(:recipient_not_found)
            end
            
            # Verrouiller les deux users
            from_user = lock_user_for_update(from_user_id)
            _to_user = lock_user_for_update(to_user_id)
            
            if from_user.token_balance < token_amount do
              Repo.rollback(:insufficient_tokens)
            else
              # Débit expéditeur
              from_balance_before = from_user.token_balance
              from_balance_after = from_balance_before - token_amount
              
              # Crédit destinataire
              to_user = Repo.get!(User, to_user_id)
              to_balance_before = to_user.token_balance
              to_balance_after = to_balance_before + token_amount
              
              # Transaction sortante
              create_token_transaction(%{
                user_id: from_user_id,
                type: "transfer_out",
                token_amount: -token_amount,
                balance_before: from_balance_before,
                balance_after: from_balance_after,
                idempotency_key: idempotency_key,
                counterparty_id: to_user_id,
                metadata: %{recipient_id: to_user_id}
              })
              
              # Transaction entrante (copie pour destinataire)
              create_token_transaction(%{
                user_id: to_user_id,
                type: "transfer_in",
                token_amount: token_amount,
                balance_before: to_balance_before,
                balance_after: to_balance_after,
                idempotency_key: "#{idempotency_key}_recv",
                counterparty_id: from_user_id,
                metadata: %{sender_id: from_user_id}
              })
              
              update_user_token_balance(from_user_id, from_balance_after)
              update_user_token_balance(to_user_id, to_balance_after)
              
              AuditLog.log(
                "token_transfer",
                from_user_id,
                "tokens",
                "user_#{from_user_id}",
                %{amount: token_amount, to: to_user_id}
              )
              
              %{from_balance: from_balance_after, to_balance: to_balance_after, amount: token_amount}
            end
            
          _existing ->
            Repo.rollback(:idempotency_key_used)
        end
      end)
    end
  end
  
  def transfer_tokens(_, _, amount, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  def transfer_tokens(same, same, _, _) do
    {:error, :cannot_transfer_to_self}
  end
  
  # ========================================
  # CADEAU
  # ========================================
  
  @doc """
  Envoie des jetons en cadeau (transfert gratuit).
  Même logique que transfer mais avec type gift.
  """
  @spec send_gift(integer(), integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def send_gift(from_user_id, to_user_id, token_amount, idempotency_key, message \\ "")
  
  def send_gift(from_user_id, to_user_id, token_amount, idempotency_key, message)
      when token_amount > 0 and from_user_id != to_user_id do
    config = TokenConfig.get_config()
    
    unless config.gift_enabled do
      {:error, :gifts_disabled}
    else
      Repo.transaction(fn ->
        case get_token_transaction_by_key(idempotency_key) do
          nil ->
            unless Repo.get(User, to_user_id) do
              Repo.rollback(:recipient_not_found)
            end
            
            from_user = lock_user_for_update(from_user_id)
            _to_user = lock_user_for_update(to_user_id)
            
            if from_user.token_balance < token_amount do
              Repo.rollback(:insufficient_tokens)
            else
              from_balance_before = from_user.token_balance
              from_balance_after = from_balance_before - token_amount
              
              to_user = Repo.get!(User, to_user_id)
              to_balance_before = to_user.token_balance
              to_balance_after = to_balance_before + token_amount
              
              # Cadeau envoyé
              create_token_transaction(%{
                user_id: from_user_id,
                type: "gift_sent",
                token_amount: -token_amount,
                balance_before: from_balance_before,
                balance_after: from_balance_after,
                idempotency_key: idempotency_key,
                counterparty_id: to_user_id,
                metadata: %{recipient_id: to_user_id, message: message}
              })
              
              # Cadeau reçu
              create_token_transaction(%{
                user_id: to_user_id,
                type: "gift_received",
                token_amount: token_amount,
                balance_before: to_balance_before,
                balance_after: to_balance_after,
                idempotency_key: "#{idempotency_key}_recv",
                counterparty_id: from_user_id,
                metadata: %{sender_id: from_user_id, message: message}
              })
              
              update_user_token_balance(from_user_id, from_balance_after)
              update_user_token_balance(to_user_id, to_balance_after)
              
              AuditLog.log(
                "token_gift",
                from_user_id,
                "tokens",
                "user_#{from_user_id}",
                %{amount: token_amount, to: to_user_id, message: message}
              )
              
              %{from_balance: from_balance_after, to_balance: to_balance_after, amount: token_amount}
            end
            
          _existing ->
            Repo.rollback(:idempotency_key_used)
        end
      end)
    end
  end
  
  def send_gift(_, _, amount, _, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # ========================================
  # JETONS PROMOTIONNELS
  # ========================================
  
  @doc """
  Crédite des jetons promotionnels à un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `promo_id`: ID de l'offre promo
    - `idempotency_key`: Clé unique
  """
  @spec credit_promo(integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def credit_promo(user_id, promo_id, idempotency_key) do
    Repo.transaction(fn ->
      # Vérifier si déjà réclamé
      if UserPromoToken.already_redeemed?(user_id, promo_id) do
        Repo.rollback(:promo_already_redeemed)
      end
      
      # Récupérer la promo
      promo = case Repo.get(PromoToken, promo_id) do
        nil -> Repo.rollback(:promo_not_found)
        promo -> promo
      end
      
      # Vérifier validité
      unless PromoToken.redeemable?(promo) do
        Repo.rollback(:promo_not_available)
      end
      
      user = lock_user_for_update(user_id)
      
      # Calcul expiration
      expiry_days = Map.get(promo.conditions || %{}, "expiry_days", 30)
      expires_at = DateTime.utc_now() |> DateTime.add(expiry_days * 86400, :second) |> DateTime.truncate(:second)
      
      # Créditer jetons
      balance_before = user.token_balance
      balance_after = balance_before + promo.token_amount
      
      # Transaction promo
      create_token_transaction(%{
        user_id: user_id,
        type: "promo_credit",
        token_amount: promo.token_amount,
        balance_before: balance_before,
        balance_after: balance_after,
        idempotency_key: idempotency_key,
        promo_id: promo_id,
        metadata: %{promo_name: promo.name, conditions: promo.conditions}
      })
      
      update_user_token_balance(user_id, balance_after)
      
      # Enregistrer user_promo_token
      {:ok, _user_promo} = %UserPromoToken{}
      |> Ecto.Changeset.change(%{
        user_id: user_id,
        promo_token_id: promo_id,
        tokens_credited: promo.token_amount,
        tokens_remaining: promo.token_amount,
        conditions_met: false,
        redeemed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        expires_at: expires_at
      })
      |> Repo.insert()
      
      # Incrémenter compteur promo
      PromoToken.increment_redemptions(promo_id)
      
      AuditLog.log(
        "promo_credit",
        user_id,
        "tokens",
        "user_#{user_id}",
        %{promo_id: promo_id, tokens: promo.token_amount}
      )
      
      %{
        tokens_credited: promo.token_amount,
        new_balance: balance_after,
        expires_at: expires_at,
        conditions: promo.conditions
      }
    end)
  end
  
  @doc """
  Liste les promos disponibles.
  """
  def list_active_promos do
    PromoToken.list_active_promos()
  end
  
  # ========================================
  # COMMISSION EN JETONS
  # ========================================
  
  @doc """
  Prélève une commission en jetons (maison).
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `commission_tokens`: Nombre de jetons de commission
    - `game_id`: ID du jeu
    - `idempotency_key`: Clé unique
  """
  @spec deduct_commission_tokens(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def deduct_commission_tokens(user_id, commission_tokens, game_id, idempotency_key)
      when commission_tokens > 0 do
    Repo.transaction(fn ->
      case get_token_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          if user.token_balance < commission_tokens do
            Repo.rollback(:insufficient_tokens)
          else
            balance_before = user.token_balance
            balance_after = balance_before - commission_tokens
            
            transaction = create_token_transaction(%{
              user_id: user_id,
              type: "commission",
              token_amount: -commission_tokens,
              balance_before: balance_before,
              balance_after: balance_after,
              idempotency_key: idempotency_key,
              game_id: game_id,
              metadata: %{reason: "commission_house"}
            })
            
            update_user_token_balance(user_id, balance_after)
            
            AuditLog.log(
              "token_commission",
              user_id,
              "tokens",
              "user_#{user_id}",
              %{commission_tokens: commission_tokens, game_id: game_id}
            )
            
            transaction
          end
        
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def deduct_commission_tokens(_, amount, _, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  @doc """
  Récupère les promos actives d'un utilisateur.
  """
  def get_user_promos(user_id) do
    UserPromoToken.get_user_active_promos(user_id)
  end
  
  # ========================================
  # HISTORIQUE
  # ========================================
  
  @doc """
  Historique des transactions jetons (paginé).
  """
  @spec get_token_transactions(integer(), integer(), integer()) :: {:ok, list(), integer()}
  def get_token_transactions(user_id, page \\ 1, limit \\ 20) do
    offset = (page - 1) * limit
    
    query = from t in TokenTransaction,
      where: t.user_id == ^user_id,
      order_by: [desc: t.inserted_at],
      limit: ^limit,
      offset: ^offset
    
    transactions = Repo.all(query) |> Enum.map(&TokenTransaction.with_wiga/1)
    
    total_query = from t in TokenTransaction,
      where: t.user_id == ^user_id,
      select: count(t.id)
    
    total = Repo.one(total_query)
    
    {:ok, transactions, total}
  end
  
  # ========================================
  # FONCTIONS PRIVÉES
  # ========================================
  
  defp lock_user_for_update(user_id) do
    query = from u in User,
      where: u.id == ^user_id,
      select: [:id, :balance, :token_balance],
      lock: "FOR UPDATE"
    
    case Repo.one(query) do
      nil -> Repo.rollback(:user_not_found)
      user -> user
    end
  end
  
  defp get_token_transaction_by_key(idempotency_key) do
    query = from t in TokenTransaction,
      where: t.idempotency_key == ^idempotency_key
    
    Repo.one(query)
  end
  
  defp create_token_transaction(attrs) do
    %TokenTransaction{}
    |> TokenTransaction.create_changeset(attrs)
    |> Repo.insert!()
  end
  
  defp update_user_token_balance(user_id, new_balance) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(set: [token_balance: new_balance])
  end
  
  defp deduct_monetary_balance(user_id, amount_centimes) do
    user = Repo.get!(User, user_id)
    new_balance = max(0, user.balance - amount_centimes)
    
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(set: [balance: new_balance])
  end
  
  defp extract_game_type(game_id) do
    case game_id do
      "dice_" <> _ -> "dice"
      "card_" <> _ -> "card"
      _ -> "unknown"
    end
  end
end
