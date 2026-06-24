# ==================================
# WIWIGA - Module Authorization
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Authorization
# Description: Vérification des droits d'accès (Règle 6)

defmodule GameHub.Authorization do
  @moduledoc """
  Module d'autorisation.
  
  Règle 6 : TOUJOURS vérifier la propriété côté backend.
  
  Responsabilités :
  - Vérifier propriété des ressources
  - Vérifier droits admin
  - Double vérification (frontend + backend)
  """
  
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  
  @doc """
  Vérifie si un utilisateur peut accéder à une transaction.
  
  ## Parameters
    - `user_id`: ID utilisateur
    - `transaction_id`: ID transaction
  
  ## Returns
    - `true`: Accès autorisé
    - `false`: Accès refusé
  
  ## Examples
  
      iex> Authorization.can_access_transaction?(1, 123)
      true
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
  Vérifie si un utilisateur est admin.
  
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
      user -> user.is_admin || false
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
    cond do
      # Admin peut tout faire
      is_admin?(user_id) -> :ok
      
      # Vérifications spécifiques selon action
      action == "view_transaction" ->
        if can_access_transaction?(user_id, resource[:transaction_id]), do: :ok, else: {:error, :unauthorized}
      
      action == "edit_user" ->
        if owns_resource?(user_id, "user", resource[:user_id]), do: :ok, else: {:error, :unauthorized}
      
      true -> {:error, :unauthorized}
    end
  end
end
