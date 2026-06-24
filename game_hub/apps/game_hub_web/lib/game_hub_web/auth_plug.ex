# ==================================
# WIWIGA - Plug Authentification JWT
# ==================================
# Plug pour vérifier les tokens JWT
# Mode développement désactivé en production

defmodule GameHubWeb.AuthPlug do
  @moduledoc """
  Plug d'authentification JWT.
  
  ## Usage
  Dans le router:
  ```
  pipeline :api_auth do
    plug GameHubWeb.AuthPlug
  end
  ```
  
  ## Sécurité Production
  - En production: JWT OBLIGATOIRE
  - En développement: fallback user autorisé
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias GameHub.{Auth, EnvConfig}
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case extract_and_verify_token(conn) do
      {:ok, user_id} ->
        # Utilisateur authentifié
        conn
        |> Plug.Conn.put_private(:current_user_id, user_id)
      
      {:error, :dev_mode_fallback} ->
        # Mode développement - user par défaut
        if EnvConfig.production?() do
          # EN PRODUCTION: Refuser l'accès
          conn
          |> put_status(401)
          |> json(%{
            error: %{
              message: "Authentification requise",
              code: "UNAUTHORIZED"
            }
          })
          |> halt()
        else
          # EN DÉVELOPPEMENT: Autoriser user par défaut
          IO.puts("[DEV MODE] Using default user ID 100")
          conn
          |> Plug.Conn.put_private(:current_user_id, "100")
        end
      
      {:error, reason} ->
        # Token invalide ou manquant
        conn
        |> put_status(401)
        |> json(%{
          error: %{
            message: authentication_error_message(reason),
            code: "UNAUTHORIZED"
          }
        })
        |> halt()
    end
  end
  
  @doc """
  Récupère l'ID utilisateur depuis le conn.
  """
  def get_current_user_id(conn) do
    conn.private[:current_user_id]
  end
  
  # Fonctions privées
  
  defp extract_and_verify_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Auth.verify_jwt_token(token) do
          {:ok, %{user_id: user_id}} -> {:ok, user_id}
          {:error, _} -> {:error, :invalid_token}
        end
      
      _ ->
        # Pas de token
        if EnvConfig.dev?() do
          {:error, :dev_mode_fallback}
        else
          {:error, :missing_token}
        end
    end
  end
  
  defp authentication_error_message(:invalid_token), do: "Token invalide ou expiré"
  defp authentication_error_message(:missing_token), do: "Token d'authentification requis"
  defp authentication_error_message(_), do: "Authentification échouée"
end
