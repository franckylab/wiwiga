# ==================================
# WIWIGA - Controller Admin Impersonation
# ==================================
# Module: GameHubWeb.AdminImpersonationController
# Description: Endpoints impersonation utilisateur

defmodule GameHubWeb.AdminImpersonationController do
  @moduledoc """
  Controller pour l'impersonation admin.
  
  ## Endpoints
    POST /api/admin/impersonate/:user_id/start
    POST /api/admin/impersonate/stop
    GET  /api/admin/impersonate/status
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.Impersonation

  @doc """
  POST /api/admin/impersonate/:user_id/start
  Démarre l'impersonation.
  """
  def start(conn, %{"user_id" => user_id}) do
    admin_id = conn.assigns[:current_user_id]
    target_user_id = String.to_integer(user_id)

    # Empêcher l'auto-impersonation
    if admin_id == target_user_id do
      conn
      |> put_status(400)
      |> json(%{success: false, error: %{code: "SELF_IMPERSONATION", message: "Impossible de s'impersoner soi-même"}})
    else
      case Impersonation.start_impersonation(admin_id, target_user_id) do
        {:ok, data} ->
          conn
          |> put_status(200)
          |> json(%{success: true, data: data})

        {:error, :user_not_found} ->
          conn
          |> put_status(404)
          |> json(%{success: false, error: %{code: "NOT_FOUND", message: "Utilisateur non trouvé"}})
      end
    end
  end

  @doc """
  POST /api/admin/impersonate/stop
  Arrête l'impersonation.
  """
  def stop(conn, _params) do
    admin_id = conn.assigns[:current_user_id]

    Impersonation.stop_impersonation(admin_id)

    conn
    |> put_status(200)
    |> json(%{success: true, message: "Impersonation arrêtée"})
  end

  @doc """
  GET /api/admin/impersonate/status
  Statut de l'impersonation.
  """
  def status(conn, _params) do
    admin_id = conn.assigns[:current_user_id]

    data = Impersonation.status(admin_id)

    conn
    |> put_status(200)
    |> json(%{success: true, data: data})
  end
end
