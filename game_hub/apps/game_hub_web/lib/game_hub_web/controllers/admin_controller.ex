# ==================================
# WIWIGA - Controller Admin
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminController
# Description: Endpoints d'administration avec RBAC
#              Gestion utilisateurs, rôles, config, audit

defmodule GameHubWeb.AdminController do
  @moduledoc """
  Controller d'administration avec système RBAC.
  
  ## Endpoints Utilisateurs
    GET    /api/admin/users              - Liste utilisateurs (filtrable)
    GET    /api/admin/users/:id          - Détail utilisateur
    POST   /api/admin/users              - Créer utilisateur (avec rôle)
    PUT    /api/admin/users/:id          - Mettre à jour utilisateur
    PUT    /api/admin/users/:id/role     - Changer le rôle
    PUT    /api/admin/users/:id/activate - Activer/Désactiver
  
  ## Endpoints Système
    GET    /api/admin/audit-logs         - Logs d'audit
    POST   /api/admin/feature-flags      - Créer feature flag
    PUT    /api/admin/feature-flags/:id  - Mettre à jour flag
    POST   /api/admin/reconciliation     - Lancer réconciliation
    GET    /api/admin/stats              - Statistiques
    GET    /api/admin/roles              - Liste des rôles et permissions
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Repo, AuditLog, FeatureFlags, WalletReconciliation, Errors}
  alias GameHub.Users.User
  alias GameHub.RBAC.{Role, Permissions}
  import Ecto.Query
  
  # ========================================
  # Gestion Utilisateurs
  # ========================================
  
  @doc """
  GET /api/admin/users
  
  Query: ?page=1&limit=20&role=user&status=active&search=john
  """
  def list_users(conn, params) do
    current_user = conn.assigns[:current_user]
    page = parse_int_param(params["page"], 1, min: 1)
    limit = parse_int_param(params["limit"] || params["page_size"], 20, min: 1, max: 100)
    
    query = from u in User, order_by: [desc: u.inserted_at]
    
    # Filtre par rôle
    query = case Map.get(params, "role") do
      nil -> query
      role -> from u in query, where: u.role == ^role
    end
    
    # Filtre par statut
    query = case Map.get(params, "status") do
      "active" -> from u in query, where: u.is_active == true
      "inactive" -> from u in query, where: u.is_active == false
      _ -> query
    end
    
    # Filtre par recherche (username, phone, email, name)
    query = case Map.get(params, "search") do
      nil -> query
      "" -> query
      search ->
        search_pattern = "%#{search}%"
        from u in query,
          where: ilike(u.username, ^search_pattern)
            or ilike(u.phone, ^search_pattern)
            or ilike(u.email, ^search_pattern)
            or ilike(u.name, ^search_pattern)
    end
    
    # Pagination — total filtré (sans limit/offset) pour cohérence
    filtered_query = query
    paginated_query = from u in query, limit: ^limit, offset: ^((page - 1) * limit)
    
    users = Repo.all(paginated_query)
    total = Repo.aggregate(filtered_query, :count, :id)
    
    # Formater les utilisateurs (sans données sensibles)
    formatted_users = Enum.map(users, &format_user_for_admin(&1, current_user))
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        users: formatted_users,
        total: total,
        page: page,
        page_size: limit,
        total_pages: ceil(total / limit),
        has_next: page * limit < total,
        has_prev: page > 1
      },
      pagination: %{
        page: page,
        limit: limit,
        total: total,
        total_pages: ceil(total / limit),
        has_next: page * limit < total,
        has_prev: page > 1
      }
    })
  end
  
  @doc """
  GET /api/admin/users/:id
  
  Détail d'un utilisateur.
  """
  def get_user(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    
    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      user ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: format_user_detail(user, current_user)
        })
    end
  end
  
  @doc """
  POST /api/admin/users
  
  Body: %{
    phone: "+237..." ou email: "user@example.com",
    username: "pseudo",
    role: "user",
    avatar_type: "wiwiga_1",
    name: "Nom"
  }
  
  Crée un utilisateur avec un rôle spécifique.
  Seul super_admin peut créer des admins.
  """
  def create_user(conn, params) do
    current_user = conn.assigns[:current_user]
    target_role = Map.get(params, "role", "user")
    
    # Vérifier que le current_user peut attribuer ce rôle
    if not Permissions.can_assign_role?(current_user, target_role) do
      conn
      |> put_status(403)
      |> json(Errors.error("Vous n'avez pas les droits pour attribuer ce rôle", 403, "FORBIDDEN"))
    else
      case register_user(params) do
        {:ok, user} ->
          # Logger la création
          AuditLog.log("admin_create_user", current_user.id, "admin", user.id, %{
            role: target_role,
            admin_id: current_user.id
          })
          
          conn
          |> put_status(201)
          |> json(%{
            success: true,
            data: format_user_detail(user, current_user)
          })
        
        {:error, :phone_or_email_required} ->
          conn
          |> put_status(400)
          |> json(Errors.error("Un numéro de téléphone ou un email est requis", 400, "VALIDATION_ERROR"))
        
        {:error, %Ecto.Changeset{} = changeset} ->
          errors = format_changeset_errors(changeset)
          conn
          |> put_status(422)
          |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
        
        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(Errors.error("Erreur: #{inspect(reason)}", 500, "ERROR"))
      end
    end
  end
  
  @doc """
  PUT /api/admin/users/:id/role
  
  Body: %{role: "moderator"}
  
  Change le rôle d'un utilisateur.
  Seul super_admin peut attribuer des rôles admin/super_admin.
  """
  def update_user_role(conn, %{"id" => id, "role" => target_role}) do
    current_user = conn.assigns[:current_user]
    
    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      target_user ->
        # Vérifier permissions
        cond do
          # Ne peut pas se modifier soi-même
          current_user.id == target_user.id ->
            conn
            |> put_status(400)
            |> json(Errors.error("Impossible de modifier votre propre rôle", 400, "INVALID_ACTION"))
          
          # Vérifier que le current_user peut gérer ce target
          not Permissions.can_manage?(current_user, target_user) ->
            conn
            |> put_status(403)
            |> json(Errors.error("Vous ne pouvez pas gérer cet utilisateur", 403, "FORBIDDEN"))
          
          # Vérifier que le current_user peut attribuer ce rôle
          not Permissions.can_assign_role?(current_user, target_role) ->
            conn
            |> put_status(403)
            |> json(Errors.error("Vous n'avez pas les droits pour attribuer ce rôle", 403, "FORBIDDEN"))
          
          true ->
            case target_user |> User.role_changeset(%{role: target_role}) |> Repo.update() do
              {:ok, updated_user} ->
                AuditLog.log("admin_change_role", current_user.id, "admin", target_user.id, %{
                  old_role: target_user.role,
                  new_role: target_role
                })
                
                conn
                |> put_status(200)
                |> json(%{
                  success: true,
                  data: format_user_detail(updated_user, current_user)
                })
              
              {:error, changeset} ->
                errors = format_changeset_errors(changeset)
                conn
                |> put_status(422)
                |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
            end
        end
    end
  end
  
  @doc """
  PUT /api/admin/users/:id/activate
  
  Body: %{is_active: true/false}
  
  Active ou désactive un utilisateur.
  """
  def toggle_user_active(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]
    is_active = Map.get(params, "is_active", true)
    
    case Repo.get(User, id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      target_user ->
        if not Permissions.can_manage?(current_user, target_user) do
          conn
          |> put_status(403)
          |> json(Errors.error("Vous ne pouvez pas gérer cet utilisateur", 403, "FORBIDDEN"))
        else
          case target_user |> Ecto.Changeset.change(%{is_active: is_active}) |> Repo.update() do
            {:ok, updated_user} ->
              action = if is_active, do: "activate_user", else: "deactivate_user"
              AuditLog.log(action, current_user.id, "admin", target_user.id, %{
                is_active: is_active
              })
              
              conn
              |> put_status(200)
              |> json(%{
                success: true,
                data: format_user_detail(updated_user, current_user)
              })
            
            {:error, _} ->
              conn
              |> put_status(500)
              |> json(Errors.error("Erreur lors de la mise à jour", 500, "ERROR"))
          end
        end
    end
  end
  
  # ========================================
  # Rôles et Permissions
  # ========================================
  
  @doc """
  GET /api/admin/roles
  
  Retourne la liste des rôles avec leurs permissions.
  """
  def list_roles(conn, _params) do
    roles_data = Enum.map(Role.roles(), fn role ->
      %{
        role: Atom.to_string(role),
        name: Role.display_name(role),
        color: Role.color(role),
        level: Role.level(role),
        permissions: Role.permissions(role)
      }
    end)
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{roles: roles_data}
    })
  end
  
  # ========================================
  # Audit Logs
  # ========================================
  
  @doc """
  GET /api/admin/audit-logs
  
  Query: ?action=deposit&page=1&limit=50
  """
  def list_audit_logs(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "50") |> String.to_integer() |> min(200) |> max(1)
    
    filters = Map.take(params, ["action", "entity_type", "user_id"])
    
    case AuditLog.list_logs(filters, page, limit) do
      {:ok, logs, total} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            logs: logs,
            total: total,
            page: page,
            limit: limit,
            total_pages: ceil(total / limit)
          }
        })
    end
  end
  
  # ========================================
  # Feature Flags
  # ========================================
  
  def create_feature_flag(conn, params) do
    case FeatureFlags.create_or_update(params) do
      {:ok, flag} ->
        conn |> put_status(201) |> json(%{success: true, data: flag})
      
      {:error, changeset} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Erreur validation", 400, "VALIDATION_ERROR", %{
          errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
        }))
    end
  end
  
  def update_feature_flag(conn, %{"flag_name" => flag_name} = params) do
    case FeatureFlags.create_or_update(Map.put(params, "flag_name", flag_name)) do
      {:ok, flag} ->
        conn |> put_status(200) |> json(%{success: true, data: flag})
      {:error, _} ->
        conn |> put_status(400) |> json(Errors.error("Erreur validation", 400, "VALIDATION_ERROR"))
    end
  end
  
  # ========================================
  # Réconciliation
  # ========================================
  
  def trigger_reconciliation(conn, _params) do
    case WalletReconciliation.run() do
      {:ok, report} ->
        conn |> put_status(200) |> json(%{success: true, data: report})
      {:error, _} ->
        conn |> put_status(500) |> json(Errors.error("Erreur réconciliation", 500, "RECONCILIATION_ERROR"))
    end
  end
  
  # ========================================
  # Statistiques
  # ========================================
  
  @doc """
  GET /api/admin/stats
  
  Statistiques globales enrichies avec métriques détaillées.
  """
  def stats(conn, _params) do
    total_users = Repo.one(from u in User, select: count(u.id))
    active_users = Repo.one(from u in User, where: u.is_active == true, select: count(u.id))
    inactive_users = total_users - active_users
    
    # Utilisateurs par rôle
    users_by_role = Repo.all(
      from u in User,
        group_by: u.role,
        select: %{role: u.role, count: count(u.id)}
    )
    |> Enum.into(%{}, fn %{role: role, count: count} -> {role, count} end)
    
    total_transactions = Repo.one(from t in GameHub.Wallet.WalletTransaction, select: count(t.id))
    total_balance = Repo.one(from u in User, select: coalesce(sum(u.balance), 0))
    
    # Total token balance across all users
    total_token_balance = Repo.one(from u in User, select: coalesce(sum(u.token_balance), 0))
    
    # Utilisateurs récents (7 jours)
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)
    new_users_7d = Repo.one(
      from u in User,
        where: u.inserted_at >= ^seven_days_ago,
        select: count(u.id)
    )
    
    # Utilisateurs connectés récemment (24h)
    twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
    active_24h = Repo.one(
      from u in User,
        where: u.last_login_at >= ^twenty_four_hours_ago,
        select: count(u.id)
    )
    
    # Sessions actives (refresh tokens non révoqués et non expirés)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    active_sessions = Repo.one(
      from rt in GameHub.Auth.RefreshToken,
        where: is_nil(rt.revoked_at) and rt.expires_at > ^now,
        select: count(rt.id)
    )
    
    # Sessions par device unique
    active_devices = Repo.one(
      from rt in GameHub.Auth.RefreshToken,
        where: is_nil(rt.revoked_at) and rt.expires_at > ^now and not is_nil(rt.device_id),
        select: count(fragment("DISTINCT ?", rt.device_id))
    )
    
    # Transactions des 7 derniers jours
    transactions_7d = Repo.all(
      from t in GameHub.Wallet.WalletTransaction,
        where: t.inserted_at >= ^seven_days_ago,
        group_by: fragment("date_trunc('day', ?)", t.inserted_at),
        select: %{
          date: fragment("date_trunc('day', ?)", t.inserted_at),
          count: count(t.id),
          total_amount: coalesce(sum(t.amount), 0)
        }
    )
    
    # KYC stats
    kyc_verified = Repo.one(from u in User, where: u.has_verified_kyc == true, select: count(u.id))
    kyc_pending = total_users - kyc_verified
    
    # Self-excluded users
    self_excluded = Repo.one(from u in User, where: u.self_excluded == true, select: count(u.id))
    
    # Audit logs count (last 24h)
    audit_24h = Repo.one(
      from al in GameHub.Audit.AuditLog,
        where: al.inserted_at >= ^twenty_four_hours_ago,
        select: count(al.id)
    )
    
    stats = %{
      total_users: total_users,
      active_users: active_users,
      inactive_users: inactive_users,
      users_by_role: users_by_role,
      total_transactions: total_transactions,
      total_balance: total_balance,
      total_token_balance: total_token_balance,
      new_users_7d: new_users_7d,
      active_24h: active_24h,
      active_sessions: active_sessions,
      active_devices: active_devices,
      transactions_7d: transactions_7d,
      kyc_verified: kyc_verified,
      kyc_pending: kyc_pending,
      self_excluded: self_excluded,
      audit_events_24h: audit_24h,
      timestamp: DateTime.utc_now()
    }
    
    conn
    |> put_status(200)
    |> json(%{success: true, data: stats})
  end
  
  # ========================================
  # System Health / Monitoring
  # ========================================
  
  @doc """
  GET /api/admin/system-health
  
  État de santé du système pour supervision admin.
  """
  def system_health(conn, _params) do
    # Database health
    db_status = try do
      Repo.query!("SELECT 1")
      %{status: "healthy", latency_ms: measure_latency(fn -> Repo.query!("SELECT 1") end)}
    rescue
      _ -> %{status: "unhealthy", latency_ms: nil}
    end
    
    # Redis health
    redis_status = try do
      {latency, _} = :timer.tc(fn -> Redix.command(GameHub.Redis, ["PING"]) end)
      %{status: "healthy", latency_ms: latency / 1000}
    rescue
      _ -> %{status: "unhealthy", latency_ms: nil}
    end
    
    # Memory usage (BEAM)
    memory = :erlang.memory()
    memory_info = %{
      total_mb: round(memory[:total] / 1_048_576 * 100) / 100,
      processes_mb: round(memory[:processes] / 1_048_576 * 100) / 100,
      system_mb: round(memory[:system] / 1_048_576 * 100) / 100,
      atom_mb: round(memory[:atom] / 1_048_576 * 100) / 100,
      binary_mb: round(memory[:binary] / 1_048_576 * 100) / 100
    }
    
    # Process count
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    
    # Uptime
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_hours = round(uptime_ms / 3_600_000 * 100) / 100
    
    # Active sessions
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    active_sessions = Repo.one(
      from rt in GameHub.Auth.RefreshToken,
        where: is_nil(rt.revoked_at) and rt.expires_at > ^now,
        select: count(rt.id)
    )
    
    # OTP pending (Redis keys with otp: prefix)
    otp_pending = try do
      case Redix.command(GameHub.Redis, ["DBSIZE"]) do
        {:ok, size} -> size
        _ -> nil
      end
    rescue
      _ -> nil
    end
    
    health = %{
      database: db_status,
      redis: redis_status,
      memory: memory_info,
      processes: %{
        count: process_count,
        limit: process_limit,
        usage_percent: round(process_count / process_limit * 10000) / 100
      },
      uptime_hours: uptime_hours,
      active_sessions: active_sessions,
      redis_keys: otp_pending,
      erlang_version: to_string(:erlang.system_info(:otp_release)),
      system_version: to_string(:erlang.system_info(:version)),
      timestamp: DateTime.utc_now()
    }
    
    conn
    |> put_status(200)
    |> json(%{success: true, data: health})
  end
  
  defp measure_latency(fun) do
    {microseconds, _} = :timer.tc(fun)
    round(microseconds / 1000 * 100) / 100
  end
  
  # ========================================
  # Fonctions Privées
  # ========================================
  
  defp register_user(attrs) do
    phone = Map.get(attrs, "phone")
    email = Map.get(attrs, "email")
    
    if (is_nil(phone) or phone == "") and (is_nil(email) or email == "") do
      {:error, :phone_or_email_required}
    else
      normalized_attrs = %{
        "phone" => if(phone && phone != "", do: String.trim(phone)),
        "email" => if(email && email != "", do: String.downcase(String.trim(email))),
        "username" => Map.get(attrs, "username"),
        "name" => Map.get(attrs, "name"),
        "role" => Map.get(attrs, "role", "user"),
        "avatar_type" => Map.get(attrs, "avatar_type", "default")
      }
      
      %User{}
      |> User.admin_registration_changeset(normalized_attrs)
      |> Repo.insert()
    end
  end
  
  defp format_user_for_admin(user, current_user) do
    %{
      id: user.id,
      phone: user.phone,
      email: user.email,
      username: user.username,
      name: user.name,
      role: user.role,
      avatar_type: user.avatar_type,
      is_active: user.is_active,
      has_verified_kyc: user.has_verified_kyc,
      balance: user.balance,
      login_count: user.login_count || 0,
      last_login_at: user.last_login_at,
      created_at: user.inserted_at,
      can_manage: current_user && Permissions.can_manage?(current_user, user)
    }
  end
  
  defp format_user_detail(user, current_user) do
    format_user_for_admin(user, current_user)
    |> Map.put(:permissions, Role.permissions(user.role))
    |> Map.put(:daily_deposit_limit, user.daily_deposit_limit)
    |> Map.put(:daily_loss_limit, user.daily_loss_limit)
    |> Map.put(:self_excluded, user.self_excluded)
    |> Map.put(:token_balance, user.token_balance || 0)
  end
  
  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
  
  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp parse_int_param(nil, default, _opts), do: default
  defp parse_int_param(value, default, opts) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int
        |> then(fn v -> if min = opts[:min], do: max(v, min), else: v end)
        |> then(fn v -> if max_val = opts[:max], do: min(v, max_val), else: v end)
      _ -> default
    end
  rescue
    _ -> default
  end
  defp parse_int_param(value, default, opts) when is_integer(value) do
    value
    |> then(fn v -> if min = opts[:min], do: max(v, min), else: v end)
    |> then(fn v -> if max_val = opts[:max], do: min(v, max_val), else: v end)
  end
  defp parse_int_param(_, default, _opts), do: default
end
