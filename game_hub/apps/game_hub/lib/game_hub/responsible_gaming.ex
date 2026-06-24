# ==================================
# WIWIGA - Module Responsible Gaming
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.ResponsibleGaming
# Description: Conformité légale MINFI - Jeu responsable (Règle 19)

defmodule GameHub.ResponsibleGaming do
  @moduledoc """
  Module de gestion du jeu responsable.
  
  Obligations légales MINFI (Règle 19) :
  - Vérification âge >= 18 ans
  - Limites de dépôt/perte configurables
  - Auto-exclusion temporaire/permanente
  - Rappels de réalité toutes les 30min
  - Limites de temps de session
  """
  
  alias GameHub.Repo
  alias GameHub.ResponsibleGaming.ResponsibleGamingLimit
  import Ecto.Query
  
  @doc """
  Vérifie si un utilisateur peut placer un pari.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `bet_amount`: Montant du pari
  
  ## Returns
    - `:ok`: Pari autorisé
    - `{:error, reason}`: Pari bloqué
  
  ## Examples
  
      iex> ResponsibleGaming.check_before_bet(1, 5000)
      :ok
      
      iex> ResponsibleGaming.check_before_bet(1, 999999)
      {:error, :daily_limit_reached}
  """
  @spec check_before_bet(integer(), integer()) :: :ok | {:error, atom()}
  def check_before_bet(user_id, bet_amount) do
    limits = get_limits(user_id)
    
    cond do
      # Auto-exclusion active
      limits && is_self_excluded?(limits) ->
        {:error, :self_excluded}
      
      # Limite de perte quotidienne atteinte
      limits && limits.daily_loss_limit && daily_loss_exceeded?(user_id, limits.daily_loss_limit) ->
        {:error, :daily_limit_reached}
      
      # Limite de temps de session
      limits && limits.session_time_limit_minutes && session_time_exceeded?(user_id, limits.session_time_limit_minutes) ->
        {:error, :session_time_exceeded}
      
      true -> :ok
    end
  end
  
  @doc """
  Planifie un rappel de réalité.
  
  ## Parameters
    - `user_id`: ID utilisateur
  
  ## Returns
    - `:ok`: Rappel planifié
    - `:no_limits`: Pas de configuration
  """
  @spec schedule_reality_check(integer()) :: :ok | :no_limits
  def schedule_reality_check(user_id) do
    limits = get_limits(user_id)
    
    if limits && limits.reality_check_interval_minutes do
      Process.send_after(
        self(),
        {:reality_check, user_id},
        limits.reality_check_interval_minutes * 60_000
      )
      
      :ok
    else
      :no_limits
    end
  end
  
  @doc """
  Active l'auto-exclusion pour un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `duration_days`: Durée en jours (0 = permanent)
    - `reason`: Motif
  
  ## Returns
    - `{:ok, limits}`: Auto-exclusion activée
    - `{:error, changeset}`: Erreur
  """
  @spec self_exclude(integer(), integer(), String.t()) :: {:ok, ResponsibleGamingLimit.t()} | {:error, Ecto.Changeset.t()}
  def self_exclude(user_id, duration_days, reason) do
    limits = get_or_create_limits(user_id)
    
    self_exclusion_until = if duration_days == 0 do
      # Permanent : dans 100 ans
      DateTime.utc_now() |> DateTime.add(100 * 365, :day)
    else
      DateTime.utc_now() |> DateTime.add(duration_days, :day)
    end
    
    limits
    |> ResponsibleGamingLimit.changeset(%{
      self_exclusion_until: self_exclusion_until,
      self_exclusion_reason: reason
    })
    |> Repo.update()
  end
  
  @doc """
  Définit les limites de jeu pour un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `limits_data`: Données des limites
  
  ## Returns
    - `{:ok, limits}`: Limites mises à jour
    - `{:error, changeset}`: Erreur
  """
  @spec set_limits(integer(), map()) :: {:ok, ResponsibleGamingLimit.t()} | {:error, Ecto.Changeset.t()}
  def set_limits(user_id, limits_data) do
    limits = get_or_create_limits(user_id)
    
    limits
    |> ResponsibleGamingLimit.changeset(limits_data)
    |> Repo.update()
  end
  
  @doc """
  Récupère les limites d'un utilisateur.
  
  ## Parameters
    - `user_id`: ID utilisateur
  
  ## Returns
    - `%ResponsibleGamingLimit{}`: Limites ou nil
  """
  @spec get_limits(integer()) :: ResponsibleGamingLimit.t() | nil
  def get_limits(user_id) do
    Repo.get_by(ResponsibleGamingLimit, user_id: user_id)
  end
  
  # === Fonctions Privées ===
  
  defp is_self_excluded?(limits) do
    limits.self_exclusion_until &&
      DateTime.compare(DateTime.utc_now(), limits.self_exclusion_until) == :lt
  end
  
  defp daily_loss_exceeded?(user_id, daily_limit) do
    today_start = DateTime.utc_now() |> DateTime.beginning_of_day()
    
    total_loss = Repo.one(
      from t in GameHub.Wallet.WalletTransaction,
        where: t.user_id == ^user_id and
               t.type in ["bet", "withdrawal"] and
               t.inserted_at >= ^today_start,
        select: fragment("SUM(ABS(?))", t.amount)
    ) || 0
    
    total_loss >= daily_limit
  end
  
  defp session_time_exceeded?(user_id, limit_minutes) do
    # TODO: Implémenter avec Redis pour tracking session
    # Pour l'instant, retourne toujours false
    false
  end
  
  defp get_or_create_limits(user_id) do
    case get_limits(user_id) do
      nil ->
        %ResponsibleGamingLimit{user_id: user_id}
      
      limits ->
        limits
    end
  end
end
