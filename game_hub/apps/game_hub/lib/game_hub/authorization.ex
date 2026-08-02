# ==================================
# WIWIGA - Module Authorization
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Authorization
# Description: Vérification des droits d'accès (Règle 6)
#              Intègre le système RBAC

defmodule GameHub.Authorization do
  @moduledoc """
  Module d'autorisation.
  
  Règle 6 : TOUJOURS vérifier la propriété côté backend.
  
  Responsabilités :
  - Vérifier propriété des ressources
  - Vérifier droits admin via RBAC
  - Double vérification (frontend + backend)
  
  ## RBAC
  
  Les permissions sont gérées par `GameHub.RBAC.Permissions`.
  Ce module fournit une interface simplifiée pour les cas courants.
  """
  
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.RBAC.Permissions
  
  @doc """
  Vérifie si un utilisateur peut accéder à une transaction.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `transaction_id`: ID transaction
  
  ## Returns
    - `true`: Accès autorisé
    - `false`: Accès refusé
  """
  @spec can_access_transaction?(integer(), integer()) :: boolean
  def can_access_transaction?(user_id, transaction_id) do
    case Repo.get(WalletTransaction, transaction_id) do
      nil -> false
      transaction -> transaction.user_id == user_id
    end
  end
  
  @doc """
  Vérifie si un utilisateur est propriétaire d'une ressource.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `resource_type`: Type de ressource
    - `resource_id`: ID ressource
  
  ## Returns
    - `true`: Propriétaire
    - `false`: Non propriétaire
  """
  @spec owns_resource?(integer(), String.t(), integer()) :: boolean
  def owns_resource?(user_id, resource_type, resource_id) do
    case resource_type do
      "transaction" -> can_access_transaction?(user_id, resource_id)
      "user" -> user_id == resource_id
      _ -> false
    end
  end
  
  @doc """
  Vérifie si un utilisateur est admin (super_admin ou admin).
  
  ## Parameters
    - `user_id`: ID utilisateur
  
  ## Returns
    - `true`: Admin
    - `false`: Non admin
  """
  @spec is_admin?(integer()) :: boolean
  def is_admin?(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> Permissions.is_admin?(user)
    end
  end
  
  @doc """
  Vérifie si un utilisateur est super_admin.
  """
  @spec is_super_admin?(integer()) :: boolean
  def is_super_admin?(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> Permissions.is_super_admin?(user)
    end
  end
  
  @doc """
  Vérifie si un utilisateur est modérateur ou supérieur.
  """
  @spec is_moderator?(integer()) :: boolean
  def is_moderator?(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> Permissions.is_moderator?(user)
    end
  end
  
  @doc """
  Vérifie si un utilisateur a une permission spécifique.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `permission`: String de permission
  
  ## Returns
    - `true`: Permission accordée
    - `false`: Permission refusée
  """
  @spec has_permission?(integer(), String.t()) :: boolean
  def has_permission?(user_id, permission) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> Permissions.can?(user, permission)
    end
  end
  
  @doc """
  Vérifie si un utilisateur peut effectuer une action.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `action`: Action à vérifier
    - `resource`: Ressource concernée
  
  ## Returns
    - `:ok`: Action autorisée
    - `{:error, :unauthorized}`: Action refusée
  """
  @spec can_perform_action?(integer(), String.t(), map()) :: :ok | {:error, :unauthorized}
  def can_perform_action?(user_id, action, resource \\ %{}) do
    user = Repo.get(User, user_id)
    
    cond do
      is_nil(user) ->
        {:error, :unauthorized}
      
      # Permission explicite
      Permissions.can?(user, action) ->
        :ok
      
      # Propriété de la ressource
      action == "view_transaction" ->
        if can_access_transaction?(user_id, resource[:transaction_id]), do: :ok, else: {:error, :unauthorized}
      
      action == "edit_user" ->
        if owns_resource?(user_id, "user", resource[:user_id]), do: :ok, else: {:error, :unauthorized}
      
      true ->
        {:error, :unauthorized}
    end
  end
  
  @doc """
  Vérifie si un utilisateur peut gérer un autre utilisateur.
  
  ## Parameters
    - `manager_id`: ID du manager
    - `target_id`: ID de la cible
  
  ## Returns
    - `true`: Peut gérer
    - `false`: Ne peut pas gérer
  """
  @spec can_manage_user?(integer(), integer()) :: boolean
  def can_manage_user?(manager_id, target_id) do
    manager = Repo.get(User, manager_id)
    target = Repo.get(User, target_id)
    
    case {manager, target} do
      {%User{} = m, %User{} = t} -> Permissions.can_manage?(m, t)
      _ -> false
    end
  end
  
  @doc """
  Vérifie si un utilisateur peut attribuer un rôle.
  """
  @spec can_assign_role?(integer(), String.t()) :: boolean
  def can_assign_role?(user_id, target_role) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> Permissions.can_assign_role?(user, target_role)
    end
  end
end
