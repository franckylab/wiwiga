# ==================================
# WIWIGA - Module Portefeuille (ACID)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Wallet
# Description: Gestion ACID des transactions financières avec verrouillage pessimiste

defmodule GameHub.Wallet do
  @moduledoc """
  Gestion du portefeuille utilisateur avec transactions ACID.
  
  ## Règles Critiques
  - TOUJOURS transaction ACID pour modifier balance
  - TOUJOURS verrouillage pessimiste FOR UPDATE
  - TOUJOURS clé idempotence pour webhooks
  - TOUJOURS log d'audit
  """
  
  import Ecto.Query
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  
  @doc """
  Récupère le solde d'un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
  
  ## Returns
    - `{:ok, balance}`: Solde actuel
    - `{:error, :user_not_found}`: Utilisateur inexistant
  """
  @spec get_balance(integer()) :: {:ok, integer()} | {:error, atom()}
  def get_balance(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user.balance}
    end
  end
  
  @doc """
  Récupère les transactions paginées d'un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `page`: Numéro de page (défaut: 1)
    - `limit`: Limite par page (défaut: 20)
  
  ## Returns
    - `{:ok, transactions, total}`: Liste des transactions et total
  """
  @spec list_transactions(integer(), integer(), integer()) :: {:ok, list(), integer()}
  def list_transactions(user_id, page \\ 1, limit \\ 20) do
    offset = (page - 1) * limit
    
    query = from t in WalletTransaction,
      where: t.user_id == ^user_id,
      order_by: [desc: t.inserted_at],
      limit: ^limit,
      offset: ^offset
    
    transactions = Repo.all(query)
    
    total_query = from t in WalletTransaction,
      where: t.user_id == ^user_id,
      select: count(t.id)
    
    total = Repo.one(total_query)
    
    {:ok, transactions, total}
  end
  
  @doc """
  Dépose fonds dans portefeuille.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `amount`: Montant en centimes (entier positif)
    - `idempotency_key`: Clé unique anti-doublon
  
  ## Returns
    - `{:ok, transaction}`: Succès
    - `{:error, :invalid_amount}`: Montant invalide
    - `{:error, :idempotency_key_used}`: Clé déjà utilisée
  """
  @spec deposit(integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def deposit(user_id, amount, idempotency_key) when amount > 0 do
    Repo.transaction(fn ->
      # Vérifier idempotence
      case get_transaction_by_key(idempotency_key) do
        nil ->
          # Verrou pessimiste utilisateur
          user = lock_user_for_update(user_id)
          
          # Calculer nouveau balance
          balance_before = user.balance
          balance_after = balance_before + amount
          
          # Créer transaction
          transaction = create_transaction(%{
            user_id: user_id,
            type: "deposit",
            amount: amount,
            balance_before: balance_before,
            balance_after: balance_after,
            idempotency_key: idempotency_key
          })
          
          # Mettre à jour balance
          update_user_balance(user_id, balance_after)
          
          # Log audit
          log_audit(:deposit, user_id, amount, balance_before, balance_after)
          
          transaction
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def deposit(_, amount, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  @doc """
  Retire fonds du portefeuille.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `amount`: Montant en centimes
    - `idempotency_key`: Clé unique
  
  ## Returns
    - `{:ok, transaction}`: Succès
    - `{:error, :insufficient_funds}`: Solde insuffisant
  """
  @spec withdraw(integer(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def withdraw(user_id, amount, idempotency_key) when amount > 0 do
    Repo.transaction(fn ->
      case get_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          balance_before = user.balance
          
          # Vérifier solde suffisant
          if balance_before >= amount do
            balance_after = balance_before - amount
            
            transaction = create_transaction(%{
              user_id: user_id,
              type: "withdrawal",
              amount: -amount,
              balance_before: balance_before,
              balance_after: balance_after,
              idempotency_key: idempotency_key
            })
            
            update_user_balance(user_id, balance_after)
            log_audit(:withdraw, user_id, amount, balance_before, balance_after)
            
            transaction
          else
            Repo.rollback(:insufficient_funds)
          end
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def withdraw(_, amount, _) when amount <= 0 do
    {:error, :invalid_amount}
  end
  
  @doc """
  Place un pari (débit portefeuille).
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `bet_amount`: Montant du pari
    - `game_id`: ID du jeu
    - `idempotency_key`: Clé unique
  
  ## Returns
    - `{:ok, transaction}`: Pari placé
    - `{:error, :insufficient_funds}`: Solde insuffisant
  """
  @spec place_bet(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def place_bet(user_id, bet_amount, game_id, idempotency_key) when bet_amount > 0 do
    Repo.transaction(fn ->
      case get_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          if user.balance >= bet_amount do
            balance_before = user.balance
            balance_after = balance_before - bet_amount
            
            transaction = create_transaction(%{
              user_id: user_id,
              type: "bet",
              amount: -bet_amount,
              balance_before: balance_before,
              balance_after: balance_after,
              idempotency_key: idempotency_key,
              metadata: %{game_id: game_id}
            })
            
            update_user_balance(user_id, balance_after)
            log_audit(:bet, user_id, bet_amount, balance_before, balance_after)
            
            transaction
          else
            Repo.rollback(:insufficient_funds)
          end
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def place_bet(_, bet_amount, _, _) when bet_amount <= 0 do
    {:error, :invalid_amount}
  end
  
  @doc """
  Crédite gains après victoire.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `win_amount`: Montant gagné
    - `game_id`: ID du jeu
    - `idempotency_key`: Clé unique
  """
  @spec credit_winnings(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def credit_winnings(user_id, win_amount, game_id, idempotency_key) when win_amount > 0 do
    Repo.transaction(fn ->
      case get_transaction_by_key(idempotency_key) do
        nil ->
          user = lock_user_for_update(user_id)
          
          balance_before = user.balance
          balance_after = balance_before + win_amount
          
          transaction = create_transaction(%{
            user_id: user_id,
            type: "winnings",
            amount: win_amount,
            balance_before: balance_before,
            balance_after: balance_after,
            idempotency_key: idempotency_key,
            metadata: %{game_id: game_id}
          })
          
          update_user_balance(user_id, balance_after)
          log_audit(:winnings, user_id, win_amount, balance_before, balance_after)
          
          transaction
          
        _existing ->
          Repo.rollback(:idempotency_key_used)
      end
    end)
  end
  
  def credit_winnings(_, win_amount, _, _) when win_amount <= 0 do
    {:error, :invalid_amount}
  end
  
  # === Fonctions Privées ===
  
  defp lock_user_for_update(user_id) do
    query = from u in User,
      where: u.id == ^user_id,
      select: [:id, :balance],
      lock: "FOR UPDATE"
    
    case Repo.one(query) do
      nil -> Repo.rollback(:user_not_found)
      user -> user
    end
  end
  
  defp get_transaction_by_key(idempotency_key) do
    query = from t in WalletTransaction,
      where: t.idempotency_key == ^idempotency_key,
      select: t
    
    Repo.one(query)
  end
  
  defp create_transaction(attrs) do
    # Insérer transaction dans DB en utilisant le schema
    %WalletTransaction{}
    |> WalletTransaction.create_changeset(%{
      user_id: attrs.user_id,
      type: attrs.type,
      amount: attrs.amount,
      balance_before: attrs.balance_before,
      balance_after: attrs.balance_after,
      idempotency_key: attrs.idempotency_key,
      metadata: attrs[:metadata] || %{},
      game_id: attrs[:game_id],
      payment_provider: attrs[:payment_provider],
      provider_transaction_id: attrs[:provider_transaction_id]
    })
    |> Repo.insert!()
  end
  
  defp update_user_balance(user_id, new_balance) do
    # UPDATE users SET balance = new_balance WHERE id = user_id
    query = from u in GameHub.Users.User,
      where: u.id == ^user_id,
      select: u
    
    case Repo.one(query) do
      nil ->
        Repo.rollback(:user_not_found)
      user ->
        user
        |> Ecto.Changeset.change(balance: new_balance)
        |> Repo.update!()
    end
  end
  
  defp log_audit(action, user_id, amount, balance_before, balance_after) do
    IO.puts("[AUDIT] #{action} | user: #{user_id} | amount: #{amount} | balance: #{balance_before} -> #{balance_after}")
  end
end
