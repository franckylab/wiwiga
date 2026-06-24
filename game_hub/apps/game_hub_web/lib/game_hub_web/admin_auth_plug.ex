# ==================================
# WIWIGA - Plug Admin Authorization
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminAuthPlug
# Description: Vérification droits admin

defmodule GameHubWeb.AdminAuthPlug do
  @moduledoc """
  Plug pour vérifier les droits admin.
  
  Utilisation :
  pipeline :admin_only do
    plug GameHubWeb.AdminAuthPlug
  end
  """
  
  import Plug.Conn
  alias GameHub.Authorization
  
  @doc """
  Initialise le plug.
  """
  def init(opts), do: opts
  
  @doc """
  Vérifie si l'utilisateur est admin.
  """
  def call(conn, _opts) do
    user_id = conn.assigns[:current_user_id]
    
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
      
      not Authorization.is_admin?(user_id) ->
        conn
        |> put_status(403)
        |> Phoenix.Controller.json(%{
          success: false,
          error: %{
            code: "FORBIDDEN",
            message: "Droits admin requis"
          }
        })
        |> halt()
      
      true ->
        conn
    end
  end
end
