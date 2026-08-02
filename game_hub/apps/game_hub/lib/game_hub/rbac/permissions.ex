# ==================================
# WIWIGA - Module RBAC Permissions
# ==================================
# Module: GameHub.RBAC.Permissions
# Description: Vérification des permissions RBAC

defmodule GameHub.RBAC.Permissions do
  @moduledoc """
  Module de vérification des permissions RBAC.
  
  Utilisé par les controllers et plugs pour vérifier si un utilisateur
  a le droit d'effectuer une action.
  
  ## Exemples
  
      # Vérifier une permission
      if Permissions.can?(user, "users:create") do
        # créer l'utilisateur
      end
      
      # Vérifier avec resource
      Permissions.can?(user, "users:update", target_user)
  """
  
  alias GameHub.RBAC.Role
  alias GameHub.Users.User
  
  @doc """
  Vérifie si un utilisateur a une permission.
  
  ## Parameters
    - `user`: Struct User ou rôle (string/atom)
    - `permission`: String de permission (ex: "users:create")
  
  ## Returns
    - `true`: Permission accordée
    - `false`: Permission refusée
  """
  def can?(%User{role: role}, permission) do
    Role.has_permission?(role, permission)
  end
  
  def can?(role, permission) when is_binary(role) or is_atom(role) do
    Role.has_permission?(role, permission)
  end
  
  def can?(_, _), do: false
  
  @doc """
  Vérifie si un utilisateur peut gérer un autre utilisateur.
  
  Règles:
  - super_admin peut gérer tout le monde
  - admin peut gérer moderator, test, user
  - moderator peut gérer test, user
  - Personne ne peut se gérer soi-même (nécessite un supérieur)
  """
  def can_manage?(%User{} = manager, %User{} = target) do
    cond do
      # On ne peut pas se gérer soi-même
      manager.id == target.id -> false
      
      # super_admin peut tout gérer
      manager.role == "super_admin" -> true
      
      # admin peut gérer tout sauf super_admin et admin
      manager.role == "admin" and target.role not in ["super_admin", "admin"] -> true
      
      # moderator peut gérer test et user
      manager.role == "moderator" and target.role in ["test", "user"] -> true
      
      true -> false
    end
  end
  
  @doc """
  Vérifie si un utilisateur peut attribuer un rôle.
  
  Seul super_admin peut attribuer des rôles admin ou super_admin.
  """
  def can_assign_role?(%User{role: "super_admin"}, _target_role), do: true
  def can_assign_role?(%User{role: "admin"}, target_role) when target_role in ["moderator", "test", "user"], do: true
  def can_assign_role?(_, _), do: false
  
  @doc """
  Vérifie si un utilisateur est admin (super_admin ou admin).
  """
  def is_admin?(%User{role: role}), do: role in ["super_admin", "admin"]
  def is_admin?(_), do: false
  
  @doc """
  Vérifie si un utilisateur est super_admin.
  """
  def is_super_admin?(%User{role: "super_admin"}), do: true
  def is_super_admin?(_), do: false
  
  @doc """
  Vérifie si un utilisateur est modérateur ou supérieur.
  """
  def is_moderator?(%User{role: role}), do: role in ["super_admin", "admin", "moderator"]
  def is_moderator?(_), do: false
  
  @doc """
  Retourne toutes les permissions d'un utilisateur.
  """
  def list_permissions(%User{role: role}) do
    Role.permissions(role)
  end
  
  @doc """
  Vérifie plusieurs permissions (toutes requises).
  """
  def can_all?(user, permissions) when is_list(permissions) do
    Enum.all?(permissions, &can?(user, &1))
  end
  
  @doc """
  Vérifie plusieurs permissions (au moins une requise).
  """
  def can_any?(user, permissions) when is_list(permissions) do
    Enum.any?(permissions, &can?(user, &1))
  end
  
  @doc """
  Vérifie et retourne :ok ou {:error, :unauthorized}.
  """
  def authorize!(user, permission) do
    if can?(user, permission) do
      :ok
    else
      {:error, :unauthorized}
    end
  end
  
  @doc """
  Vérifie avec contexte de ressource.
  
  Exemples:
  - Un user peut modifier son propre profil
  - Un admin peut modifier n'importe quel user (sauf super_admin)
  """
  def can_on_resource?(%User{} = user, action, %User{} = target) do
    cond do
      # Propre ressource
      user.id == target.id and action in ["profile:update_own", "profile:view_own"] -> true
      
      # Permission admin
      can?(user, "users:#{action}") -> true
      
      true -> false
    end
  end
  
  def can_on_resource?(user, action, _resource) do
    can?(user, action)
  end
end
