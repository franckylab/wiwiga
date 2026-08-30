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
  alias GameHub.Admin.PlatformConfig
  alias GameHub.Tokens.TokenTransaction
  import Ecto.Query

  # Table ETS pour le tracking de session en mémoire
  @session_table :rg_session_tracker
  
  @doc """
  Initialise le tracker de session ETS.
  Appeler au démarrage de l'application.
  """
  def init_session_tracker do
    if :ets.info(@session_table) == :undefined do
      :ets.new(@session_table, [:set, :named_table, :public, read_concurrency: true])
    end
    :ok
  end

  @doc """
  Démarre une session de jeu pour un utilisateur.
  """
  @spec start_session(integer()) :: :ok
  def start_session(user_id) do
    init_session_tracker()
    :ets.insert(@session_table, {user_id, System.monotonic_time(:second)})
    :ok
  end

  @doc """
  Arrête une session de jeu.
  """
  @spec end_session(integer()) :: :ok
  def end_session(user_id) do
    init_session_tracker()
    :ets.delete(@session_table, user_id)
    :ok
  end

  @doc """
  Vérifie si un utilisateur peut placer un pari.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `bet_amount`: Montant du pari
  
  ## Returns
    - `:ok`: Pari autorisé
    - `{:error, reason}`: Pari bloqué
  """
  @spec check_before_bet(integer(), integer()) :: :ok | {:error, atom()}
  def check_before_bet(user_id, bet_amount) do
    limits = get_limits(user_id)
    
    # Limites par défaut depuis PlatformConfig si pas de limites perso
    max_daily_loss = if limits && limits.daily_loss_limit do
      limits.daily_loss_limit
    else
      PlatformConfig.get_int("gaming", "default_daily_loss_limit", 500_000)
    end

    max_session_minutes = if limits && limits.session_time_limit_minutes do
      limits.session_time_limit_minutes
    else
      PlatformConfig.get_int("gaming", "default_session_time_minutes", 120)
    end

    # max_bet désormais stocké en jetons (pure jetons, migration 20260830000003)
    max_bet = PlatformConfig.get_int("gaming", "max_bet_per_round", 10_000)

    cond do
      # Auto-exclusion active
      limits && is_self_excluded?(limits) ->
        {:error, :self_excluded}

      # Mise max par round (bet_amount en jetons)
      bet_amount > max_bet ->
        {:error, :max_bet_exceeded}
      
      # Limite de perte quotidienne atteinte
      daily_loss_exceeded?(user_id, max_daily_loss) ->
        {:error, :daily_limit_reached}
      
      # Limite de temps de session
      session_time_exceeded?(user_id, max_session_minutes) ->
        {:error, :session_time_exceeded}
      
      true -> :ok
    end
  end
  
  @doc """
  Planifie un rappel de réalité.
  Utilise l'intervalle PlatformConfig si pas de config perso.
  """
  @spec schedule_reality_check(integer()) :: :ok | :no_limits
  def schedule_reality_check(user_id) do
    limits = get_limits(user_id)

    interval = if limits && limits.reality_check_interval_minutes do
      limits.reality_check_interval_minutes
    else
      PlatformConfig.get_int("gaming", "reality_check_interval_minutes", 30)
    end

    if interval > 0 do
      Process.send_after(
        self(),
        {:reality_check, user_id},
        interval * 60_000
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
    {:ok, today_start, _} = DateTime.from_iso8601(
      Date.to_iso8601(Date.utc_today()) <> "T00:00:00Z"
    )

    # Limite désormais en jetons (pure jetons)
    daily_limit_jetons = daily_limit

    total_loss = Repo.one(
      from t in TokenTransaction,
        where: t.user_id == ^user_id and
               t.type in ["bet", "exchange"] and
               t.inserted_at >= ^today_start,
        select: fragment("SUM(ABS(?))", t.token_amount)
    ) || 0

    total_loss >= daily_limit_jetons
  end
  
  defp session_time_exceeded?(user_id, limit_minutes) do
    init_session_tracker()
    case :ets.lookup(@session_table, user_id) do
      [{^user_id, start_time}] ->
        elapsed_seconds = System.monotonic_time(:second) - start_time
        elapsed_seconds > limit_minutes * 60
      _ ->
        false
    end
  rescue
    _ -> false
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
