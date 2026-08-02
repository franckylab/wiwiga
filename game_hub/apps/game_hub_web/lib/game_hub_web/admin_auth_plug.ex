# ==================================
# WIWIGA - Plug Admin Authorization
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminAuthPlug
# Description: Vérification droits admin avec RBAC

defmodule GameHubWeb.AdminAuthPlug do
  @moduledoc """
  Plug pour vérifier les droits admin via RBAC.
  
  Utilisation :
  pipeline :admin_only do
    plug GameHubWeb.AdminAuthPlug
  end
  
  Assigne `current_user` dans conn.assigns pour les controllers.
  """
  
  import Plug.Conn
  alias GameHub.{Repo, Users.User}
  alias GameHub.RBAC.Permissions
  
  @doc """
  Initialise le plug.
  """
  def init(opts), do: opts
  
  @doc """
  Vérifie si l'utilisateur est admin (super_admin ou admin).
  """
  def call(conn, _opts) do
    # Récupérer user_id depuis AuthPlug (stocké dans private)
    user_id = conn.private[:current_user_id] || conn.assigns[:current_user_id]
    
    cond do
      is_nil(user_id) ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{
          success: false,
          error: %{
            code: "UNAUTHORIZED",
            message: "Authentification requise"
          }
        })
        |> halt()
      
      true ->
        # Charger l'utilisateur complet
        case Repo.get(User, user_id) do
          nil ->
            conn
            |> put_status(401)
            |> Phoenix.Controller.json(%{
              success: false,
              error: %{
                code: "USER_NOT_FOUND",
                message: "Utilisateur non trouvé"
              }
            })
            |> halt()
          
          user ->
            if Permissions.is_admin?(user) do
              # Assigner l'utilisateur complet pour les controllers
              conn
              |> assign(:current_user, user)
              |> assign(:current_user_id, user.id)
            else
              conn
              |> put_status(403)
              |> Phoenix.Controller.json(%{
                success: false,
                error: %{
                  code: "FORBIDDEN",
                  message: "Droits administrateur requis. Votre rôle: #{user.role}"
                }
              })
              |> halt()
            end
        end
    end
  end
end
