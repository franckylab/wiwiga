# ==================================
# WIWIGA - Controller Admin
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminController
# Description: Endpoints d'administration

defmodule GameHubWeb.AdminController do
  @moduledoc """
  Controller d'administration.
  
  ## Endpoints
    GET    /api/admin/users              - Liste utilisateurs
    GET    /api/admin/audit-logs         - Logs d'audit
    POST   /api/admin/feature-flags      - Créer feature flag
    PUT    /api/admin/feature-flags/:id  - Mettre à jour flag
    POST   /api/admin/reconciliation     - Lancer réconciliation
    GET    /api/admin/stats              - Statistiques
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Repo, AuditLog, FeatureFlags, WalletReconciliation, Errors}
  alias GameHub.Users.User
  import Ecto.Query
  
  @doc """
  GET /api/admin/users
  
  Query: ?page=1&limit=20&status=active
  """
  def list_users(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    
    query = from u in User,
      order_by: [desc: u.inserted_at],
      limit: ^limit,
      offset: ^((page - 1) * limit)
    
    users = Repo.all(query)
    
    total = Repo.one(from u in User, select: count(u.id))
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: users,
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
  GET /api/admin/audit-logs
  
  Query: ?action=deposit&page=1&limit=50
  """
  def list_audit_logs(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "50") |> String.to_integer()
    
    filters = Map.take(params, ["action", "entity_type", "user_id"])
    
    case AuditLog.list_logs(filters, page, limit) do
      {:ok, logs, total} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: logs,
          pagination: %{
            page: page,
            limit: limit,
            total: total,
            total_pages: ceil(total / limit)
          }
        })
    end
  end
  
  @doc """
  POST /api/admin/feature-flags
  
  Body: %{flag_name: "test", enabled: true, percentage_rollout: 50}
  """
  def create_feature_flag(conn, params) do
    case FeatureFlags.create_or_update(params) do
      {:ok, flag} ->
        conn
        |> put_status(201)
        |> json(%{
          success: true,
          data: flag
        })
      
      {:error, changeset} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Erreur validation", 400, "VALIDATION_ERROR", %{
          errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
        }))
    end
  end
  
  @doc """
  PUT /api/admin/feature-flags/:flag_name
  
  Body: %{enabled: true}
  """
  def update_feature_flag(conn, %{"flag_name" => flag_name} = params) do
    case FeatureFlags.create_or_update(Map.put(params, "flag_name", flag_name)) do
      {:ok, flag} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: flag
        })
      
      {:error, changeset} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Erreur validation", 400, "VALIDATION_ERROR"))
    end
  end
  
  @doc """
  POST /api/admin/reconciliation
  
  Lance la réconciliation manuelle
  """
  def trigger_reconciliation(conn, _params) do
    case WalletReconciliation.run() do
      {:ok, report} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: report
        })
      
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur réconciliation", 500, "RECONCILIATION_ERROR"))
    end
  end
  
  @doc """
  GET /api/admin/stats
  
  Statistiques globales
  """
  def stats(conn, _params) do
    total_users = Repo.one(from u in User, select: count(u.id))
    total_transactions = Repo.one(from t in GameHub.Wallet.WalletTransaction, select: count(t.id))
    total_balance = Repo.one(from u in User, select: coalesce(sum(u.balance), 0))
    
    stats = %{
      total_users: total_users,
      total_transactions: total_transactions,
      total_balance: total_balance,
      active_games: 0, # TODO: Implémenter
      timestamp: DateTime.utc_now()
    }
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: stats
    })
  end
  
  # === Fonctions Privées ===
  
  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
