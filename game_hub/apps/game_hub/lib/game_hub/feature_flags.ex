# ==================================
# WIWIGA - Module Feature Flags
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.FeatureFlags
# Description: Déploiement progressif avec kill switch (Règle 10)

defmodule GameHub.FeatureFlags do
  @moduledoc """
  Module de gestion des feature flags.
  
  Stratégie de rollout (Règle 10) :
  1. Désactivé par défaut
  2. Activer pour 10%
  3. Monitorer métriques
  4. Augmenter 50% → 100%
  5. Kill switch instantané
  """
  
  alias GameHub.Repo
  alias GameHub.FeatureFlags.FeatureFlag
  import Ecto.Query
  
  @doc """
  Vérifie si un feature flag est activé pour un utilisateur.
  
  ## Parameters
    - `flag_name`: Nom du flag (string)
    - `user_id`: ID utilisateur (integer | nil)
  
  ## Returns
    - `true`: Flag activé
    - `false`: Flag désactivé
  
  ## Examples
  
      iex> FeatureFlags.enabled?("new_dice_animation", 123)
      true
      
      iex> FeatureFlags.enabled?("beta_feature")
      false
  """
  @spec enabled?(String.t(), integer() | nil) :: boolean
  def enabled?(flag_name, user_id \\ nil) do
    case get_flag(flag_name) do
      nil -> false
      flag -> evaluate_flag(flag, user_id)
    end
  end
  
  @doc """
  Crée ou met à jour un feature flag.
  
  ## Parameters
    - `attrs`: Attributs du flag (map)
  
  ## Returns
    - `{:ok, flag}`: Flag créé/modifié
    - `{:error, changeset}`: Erreur
  
  ## Examples
  
      iex> FeatureFlags.create_or_update(%{flag_name: "test", enabled: true})
      {:ok, %FeatureFlag{}}
  """
  @spec create_or_update(map()) :: {:ok, FeatureFlag.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update(attrs) do
    flag_name = attrs[:flag_name] || attrs["flag_name"]
    
    case Repo.get_by(FeatureFlag, flag_name: flag_name) do
      nil ->
        %FeatureFlag{}
        |> FeatureFlag.changeset(attrs)
        |> Repo.insert()
      
      existing ->
        existing
        |> FeatureFlag.changeset(attrs)
        |> Repo.update()
    end
  end
  
  @doc """
  Récupère tous les flags actifs.
  
  ## Returns
    - `{:ok, flags}`: Liste des flags
  """
  @spec list_flags() :: {:ok, list()}
  def list_flags do
    flags = Repo.all(
      from f in FeatureFlag,
        order_by: [asc: f.flag_name]
    )
    
    {:ok, flags}
  end
  
  @doc """
  Active instantanément un flag (kill switch ON).
  
  ## Parameters
    - `flag_name`: Nom du flag
  
  ## Returns
    - `{:ok, flag}`: Flag activé
    - `{:error, :not_found}`: Flag inexistant
  """
  @spec enable_flag(String.t()) :: {:ok, FeatureFlag.t()} | {:error, atom()}
  def enable_flag(flag_name) do
    case Repo.get_by(FeatureFlag, flag_name: flag_name) do
      nil -> {:error, :not_found}
      flag ->
        flag
        |> FeatureFlag.changeset(%{enabled: true, percentage_rollout: 100})
        |> Repo.update()
    end
  end
  
  @doc """
  Désactive instantanément un flag (kill switch OFF).
  
  ## Parameters
    - `flag_name`: Nom du flag
  
  ## Returns
    - `{:ok, flag}`: Flag désactivé
    - `{:error, :not_found}`: Flag inexistant
  """
  @spec disable_flag(String.t()) :: {:ok, FeatureFlag.t()} | {:error, atom()}
  def disable_flag(flag_name) do
    case Repo.get_by(FeatureFlag, flag_name: flag_name) do
      nil -> {:error, :not_found}
      flag ->
        flag
        |> FeatureFlag.changeset(%{enabled: false, percentage_rollout: 0})
        |> Repo.update()
    end
  end
  
  # === Fonctions Privées ===
  
  defp get_flag(flag_name) do
    Repo.get_by(FeatureFlag, flag_name: flag_name)
  end
  
  defp evaluate_flag(flag, user_id) do
    cond do
      # Flag globalement désactivé
      flag.enabled == false -> false
      
      # Utilisateur en blacklist
      user_id && user_id in (flag.user_ids_blacklist || []) -> false
      
      # Utilisateur en whitelist
      user_id && user_id in (flag.user_ids_whitelist || []) -> true
      
      # Rollout à 100%
      flag.enabled && flag.percentage_rollout == 100 -> true
      
      # Rollout à 0%
      flag.enabled && flag.percentage_rollout == 0 -> false
      
      # Rollout partiel - décision aléatoire
      flag.enabled -> random_rollout?(flag.percentage_rollout)
      
      true -> false
    end
  end
  
  defp random_rollout?(percentage) do
    random_value = :crypto.strong_rand_bytes(1)
      |> :binary.decode_unsigned()
      |> rem(100)
    
    random_value < percentage
  end
end
