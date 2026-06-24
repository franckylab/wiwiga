# ==================================
# WIWIGA - Module Wallet Reconciliation
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.WalletReconciliation
# Description: Job cron de réconciliation portefeuille (Règle 11)

defmodule GameHub.WalletReconciliation do
  @moduledoc """
  Module de réconciliation automatisée du portefeuille.
  
  Règle 11 : Vérifier horairement que :
  balance = SUM(transactions)
  
  En cas d'incohérence :
  1. Alerte admin
  2. Pause retraits
  3. Investigation requise
  """
  
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.AuditLog
  import Ecto.Query
  
  @doc """
  Exécute la réconciliation complète.
  
  ## Returns
    - `{:ok, report}`: Rapport de réconciliation
    - `{:error, reason}`: Erreur
  
  ## Examples
  
      iex> WalletReconciliation.run()
      {:ok, %{checked: 150, mismatched: 0, alerts: []}}
  """
  @spec run() :: {:ok, map()} | {:error, atom()}
  def run do
    IO.puts("[RECONCILIATION] Starting wallet reconciliation...")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Récupérer tous les utilisateurs avec balance
    users = Repo.all(
      from u in User,
        select: [:id, :phone, :balance]
    )
    
    # Vérifier chaque utilisateur
    results = Enum.map(users, fn user ->
      check_user_balance(user)
    end)
    
    # Filtrer incohérences
    mismatched = Enum.filter(results, fn r -> r.status == :mismatch end)
    checked = length(results)
    
    # Si incohérences détectées
    if length(mismatched) > 0 do
      handle_mismatches(mismatched)
    end
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    report = %{
      status: :completed,
      checked: checked,
      mismatched: length(mismatched),
      alerts: mismatched,
      duration_ms: duration,
      executed_at: DateTime.utc_now()
    }
    
    IO.puts("[RECONCILIATION] Completed: #{checked} users checked, #{length(mismatched)} mismatches found")
    
    # Log d'audit
    AuditLog.log(
      "reconciliation",
      nil,
      "wallet_reconciliation",
      nil,
      %{checked: checked, mismatched: length(mismatched)},
      %{duration_ms: duration}
    )
    
    {:ok, report}
  end
  
  @doc """
  Vérifie la balance d'un utilisateur spécifique.
  
  ## Parameters
    - `user`: Utilisateur à vérifier
  
  ## Returns
    - `%{status, user_id, expected, actual, difference}`
  """
  @spec check_user_balance(map()) :: map()
  def check_user_balance(%{id: user_id, balance: current_balance}) do
    # Calculer balance depuis transactions
    calculated_balance = Repo.one(
      from t in WalletTransaction,
        where: t.user_id == ^user_id,
        select: coalesce(sum(t.amount), 0)
    ) || 0
    
    difference = current_balance - calculated_balance
    
    if difference == 0 do
      %{
        status: :ok,
        user_id: user_id,
        current_balance: current_balance,
        calculated_balance: calculated_balance,
        difference: 0
      }
    else
      %{
        status: :mismatch,
        user_id: user_id,
        current_balance: current_balance,
        calculated_balance: calculated_balance,
        difference: difference
      }
    end
  end
  
  @doc """
  Gère les incohérences détectées.
  
  ## Parameters
    - `mismatches`: Liste des incohérences
  """
  @spec handle_mismatches(list()) :: :ok
  def handle_mismatches(mismatches) do
    IO.puts("[RECONCILIATION] ⚠️  MISMATCHES DETECTED: #{length(mismatches)}")
    
    Enum.each(mismatches, fn mismatch ->
      # Log critique
      IO.puts("[RECONCILIATION] User #{mismatch.user_id}: expected #{mismatch.current_balance}, calculated #{mismatch.calculated_balance}, diff #{mismatch.difference}")
      
      # Log d'audit
      AuditLog.log(
        "reconciliation_mismatch",
        mismatch.user_id,
        "wallet",
        "user_#{mismatch.user_id}",
        %{
          current_balance: mismatch.current_balance,
          calculated_balance: mismatch.calculated_balance,
          difference: mismatch.difference
        },
        %{severity: "critical"}
      )
      
      # TODO: Envoyer alerte admin (email, Slack, etc.)
      # TODO: Optionnel - Pause retraits pour utilisateurs affectés
    end)
    
    :ok
  end
  
  @doc """
  Réconciliation pour un utilisateur spécifique.
  
  ## Parameters
    - `user_id`: ID utilisateur
  
  ## Returns
    - `{:ok, report}`: Rapport utilisateur
  """
  @spec reconcile_user(integer()) :: {:ok, map()} | {:error, atom()}
  def reconcile_user(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        result = check_user_balance(user)
        
        # Log d'audit
        AuditLog.log(
          "reconciliation_user",
          user_id,
          "wallet",
          "user_#{user_id}",
          result
        )
        
        {:ok, result}
    end
  end
end
