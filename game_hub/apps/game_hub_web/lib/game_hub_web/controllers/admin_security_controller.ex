# ==================================
# WIWIGA - Controller Admin Security
# ==================================
# Module: GameHubWeb.AdminSecurityController
# Description: Gestion sécurité admin (IP whitelist, bans, overview)

defmodule GameHubWeb.AdminSecurityController do
  @moduledoc """
  Controller pour la gestion de la sécurité admin.
  
  ## Endpoints
    GET    /api/admin/security/overview        - Vue d'ensemble
    GET    /api/admin/security/failed-auths    - Logs auth échouées
    GET    /api/admin/security/rate-limits     - Stats rate limiting
    GET    /api/admin/security/ip-whitelist    - Liste whitelist
    POST   /api/admin/security/ip-whitelist    - Ajouter IP
    DELETE /api/admin/security/ip-whitelist/:ip - Supprimer IP
    POST   /api/admin/security/ban-user/:id    - Bannir user
    DELETE /api/admin/security/ban-user/:id     - Débannir user
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Security
  alias GameHub.AuditLog
  alias GameHubWeb.AuthPlug

  @doc """
  GET /api/admin/security/overview
  Vue d'ensemble de la sécurité.
  """
  def overview(conn, _params) do
    overview = Security.get_security_overview()

    conn
    |> put_status(200)
    |> json(%{success: true, data: overview})
  end

  @doc """
  GET /api/admin/security/failed-auths
  Logs d'authentification échouées.
  """
  def failed_auths(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer() |> min(100)

    filters = %{"action" => "password_login_failed"}

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

  @doc """
  GET /api/admin/security/rate-limits
  Statistiques de rate limiting.
  """
  def rate_limits(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer() |> min(100)

    filters = %{"action" => "rate_limited"}

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
            limit: limit
          }
        })
    end
  end

  @doc """
  GET /api/admin/security/ip-whitelist
  Liste des IPs autorisées.
  """
  def list_whitelist(conn, _params) do
    ips = Security.list_whitelist()

    conn
    |> put_status(200)
    |> json(%{success: true, data: %{whitelist: ips}})
  end

  @doc """
  POST /api/admin/security/ip-whitelist
  Ajouter une IP à la whitelist.
  """
  def add_to_whitelist(conn, params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    attrs = %{
      "ip_address" => params["ip_address"],
      "description" => params["description"],
      "created_by" => admin_id
    }

    case Security.add_to_whitelist(attrs) do
      {:ok, entry} ->
        AuditLog.log("admin_action", admin_id, "security", entry.ip_address, %{
          "action" => "ip_whitelist_add",
          "ip_address" => entry.ip_address
        })

        conn
        |> put_status(201)
        |> json(%{success: true, data: entry, message: "IP ajoutée à la whitelist"})

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{success: false, message: to_string(reason)})
    end
  end

  @doc """
  DELETE /api/admin/security/ip-whitelist/:ip
  Supprimer une IP de la whitelist.
  """
  def remove_from_whitelist(conn, %{"ip" => ip}) do
    admin_id = AuthPlug.get_current_user_id(conn)

    case Security.remove_from_whitelist(ip) do
      :ok ->
        AuditLog.log("admin_action", admin_id, "security", ip, %{
          "action" => "ip_whitelist_remove",
          "ip_address" => ip
        })

        conn
        |> put_status(200)
        |> json(%{success: true, message: "IP retirée de la whitelist"})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "IP non trouvée"})
    end
  end

  @doc """
  POST /api/admin/security/ban-user/:id
  Bannir un utilisateur.
  """
  def ban_user(conn, %{"id" => id} = params) do
    admin_id = AuthPlug.get_current_user_id(conn)
    user_id = String.to_integer(id)
    reason = Map.get(params, "reason", "Banni par administrateur")
    is_permanent = Map.get(params, "is_permanent", true)

    case Security.ban_user(user_id, admin_id, reason, is_permanent) do
      {:ok, ban} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: ban, message: "Utilisateur banni"})

      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Utilisateur non trouvé"})

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{success: false, message: to_string(reason)})
    end
  end

  @doc """
  DELETE /api/admin/security/ban-user/:id
  Lever le ban d'un utilisateur.
  """
  def unban_user(conn, %{"id" => id} = params) do
    admin_id = AuthPlug.get_current_user_id(conn)
    user_id = String.to_integer(id)
    reason = Map.get(params, "reason", "Ban levé par administrateur")

    case Security.unban_user(user_id, admin_id, reason) do
      :ok ->
        conn
        |> put_status(200)
        |> json(%{success: true, message: "Ban levé"})

      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Utilisateur non trouvé"})
    end
  end
end
