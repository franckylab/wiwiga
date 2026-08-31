# ==================================
# WIWIGA - Module RBAC Role
# ==================================
# Module: GameHub.RBAC.Role
# Description: Définition des rôles et leurs permissions

defmodule GameHub.RBAC.Role do
  @moduledoc """
  Définit les rôles RBAC et leurs permissions.
  
  ## Rôles
  
  - `super_admin`: Contrôle total (utilisateurs, rôles, config, modération, audit)
  - `admin`: Gestion utilisateurs (sauf super_admin), config, modération
  - `moderator`: Modération (bannir, mute, signaler), voir audit logs
  - `test`: Accès fonctionnalités de test, bypass limites
  - `user`: Actions standard (jouer, transactions, amis)
  
  ## Hiérarchie
  
  super_admin > admin > moderator > test > user
  
  Un rôle supérieur hérite des permissions du rôle inférieur.
  """
  
  @type t :: :super_admin | :admin | :moderator | :test | :user
  
  @roles [:super_admin, :admin, :moderator, :test, :user]
  
  @role_hierarchy %{
    super_admin: 5,
    admin: 4,
    moderator: 3,
    test: 2,
    user: 1
  }
  
  @role_permissions %{
    # === Permissions utilisateur standard ===
    user: [
      # Jeu
      "games:play",
      "games:create_room",
      "games:join_room",
      
      # Wallet
      "wallet:view_balance",
      "wallet:deposit",
      "wallet:withdraw",
      "wallet:view_transactions",
      
      # Tokens — seuls achat, cadeau ami, promos
      "tokens:view_balance",
      "tokens:purchase",
      "tokens:gift",
      "tokens:redeem_promo",
      
      # Amis
      "friends:add",
      "friends:remove",
      "friends:block",
      "friends:send_message",
      "friends:view_leaderboard",
      
      # Profil
      "profile:view_own",
      "profile:update_own",
      "profile:view_stats",
      
      # Config (lecture seule)
      "config:read_theme",
      "config:read_features"
    ],
    
    # === Permissions test (hérite user) ===
    test: [
      "games:bypass_limits",
      "games:create_test_room",
      "tokens:unlimited",
      "config:bypass_maintenance"
    ],
    
    # === Permissions modérateur (hérite test) ===
    moderator: [
      # Modération
      "moderation:ban_user",
      "moderation:mute_user",
      "moderation:unban_user",
      "moderation:view_reports",
      "moderation:resolve_reports",
      
      # Audit (lecture seule)
      "audit:view_logs",
      
      # Utilisateurs (lecture)
      "users:view_profile",
      "users:view_stats"
    ],
    
    # === Permissions admin (hérite moderator) ===
    admin: [
      # Gestion utilisateurs
      "users:create",
      "users:update",
      "users:deactivate",
      "users:activate",
      "users:reset_password",
      "users:view_all",
      
      # Config (lecture + écriture)
      "config:update_theme",
      "config:update_features",
      "config:update_games",
      "config:update_payments",
      "config:update_tokens",
      
      # Jeux
      "games:manage",
      
      # Promotions
      "promos:create",
      "promos:update",
      
      # Stats
      "stats:view_platform"
    ],
    
    # === Permissions super_admin (hérite admin) ===
    super_admin: [
      # Gestion des rôles
      "users:set_role",
      "users:delete",
      
      # Audit complet
      "audit:manage",
      
      # Système
      "system:reconciliation",
      "system:maintenance",
      "system:backup"
    ]
  }
  
  # ========================================
  # API publique
  # ========================================
  
  @doc "Liste tous les rôles"
  def roles, do: @roles
  
  @doc "Convertit string en atom"
  def from_string(role) when is_binary(role) do
    case String.to_existing_atom(role) do
      atom when atom in @roles -> {:ok, atom}
      _ -> {:error, :unknown_role}
    end
  rescue
    ArgumentError -> {:error, :unknown_role}
  end
  
  def from_string(role) when role in @roles, do: {:ok, role}
  def from_string(_), do: {:error, :unknown_role}
  
  @doc "Convertit atom en string"
  def to_string(role) when role in @roles, do: Atom.to_string(role)
  def to_string(role) when is_binary(role), do: role
  
  @doc "Niveau hiérarchique d'un rôle (plus haut = plus de pouvoir)"
  def level(role) when role in @roles do
    Map.get(@role_hierarchy, role, 0)
  end
  
  def level(role) when is_binary(role) do
    case from_string(role) do
      {:ok, atom} -> level(atom)
      _ -> 0
    end
  end
  
  @doc "Vérifie si un rôle est supérieur ou égal à un autre"
  def at_least?(user_role, required_role) do
    level(user_role) >= level(required_role)
  end
  
  @doc "Liste toutes les permissions d'un rôle (incluant héritage)"
  def permissions(role) do
    role_atom = case from_string(role) do
      {:ok, r} -> r
      _ -> :user
    end
    
    # Collecter les permissions du rôle et de tous les rôles inférieurs
    @roles
    |> Enum.filter(fn r -> level(r) <= level(role_atom) end)
    |> Enum.flat_map(fn r -> Map.get(@role_permissions, r, []) end)
    |> Enum.uniq()
  end
  
  @doc "Vérifie si un rôle a une permission spécifique"
  def has_permission?(role, permission) do
    permissions(role) |> Enum.member?(permission)
  end
  
  @doc "Vérifie si un rôle peut effectuer une action sur un autre rôle"
  def can_manage_role?(manager_role, target_role) do
    manager_level = level(manager_role)
    target_level = level(target_role)
    
    # Un rôle ne peut gérer que des rôles strictement inférieurs
    # Seul super_admin peut gérer d'autres super_admins
    cond do
      manager_role == :super_admin -> true
      manager_role == :admin and target_level < level(:admin) -> true
      manager_level > target_level -> true
      true -> false
    end
  end
  
  @doc "Retourne la description lisible d'un rôle"
  def display_name(:super_admin), do: "Super Administrateur"
  def display_name(:admin), do: "Administrateur"
  def display_name(:moderator), do: "Modérateur"
  def display_name(:test), do: "Compte Test"
  def display_name(:user), do: "Joueur"
  def display_name(role) when is_binary(role) do
    case from_string(role) do
      {:ok, atom} -> display_name(atom)
      _ -> "Inconnu"
    end
  end
  
  @doc "Retourne la couleur associée à un rôle (pour UI)"
  def color(:super_admin), do: "#FF0000"
  def color(:admin), do: "#FF6600"
  def color(:moderator), do: "#0066FF"
  def color(:test), do: "#9900FF"
  def color(:user), do: "#00CC66"
  def color(_), do: "#888888"
end
