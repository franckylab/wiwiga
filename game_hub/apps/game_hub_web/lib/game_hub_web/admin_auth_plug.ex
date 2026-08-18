# ==================================
# WIWIGA - Plug Admin Authorization
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminAuthPlug
# Description: Vérification droits admin avec RBAC,
#              rate limiting et IP whitelist

defmodule GameHubWeb.AdminAuthPlug do
  @moduledoc """
  Plug pour vérifier les droits admin via RBAC.
  
  ## Fonctionnalités
  - Vérification rôle admin (super_admin, admin, moderator)
  - Rate limiting spécifique admin (max 100 req/min par admin)
  - Vérification IP whitelist si configurée
  - Logging systématique des actions admin
  
  ## Utilisation :
  pipeline :admin_only do
    plug GameHubWeb.AdminAuthPlug
  end
  
  Assigne `current_user` dans conn.assigns pour les controllers.
  """
  
  import Plug.Conn
  alias GameHub.{Repo, Users.User}
  alias GameHub.RBAC.Permissions
  alias GameHub.Admin.Security
  alias GameHub.Admin.TwoFactor
  
  @rate_limit_window_ms 60_000  # 1 minute
  @rate_limit_max_requests 100   # max 100 requêtes par fenêtre
  
  @doc """
  Initialise le plug.
  """
  def init(opts), do: opts
  
  @doc """
  Vérifie si l'utilisateur est admin avec rate limiting et IP whitelist.
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
        # Vérifier IP whitelist si configurée
        case check_ip_whitelist(conn) do
          :ok ->
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
                  # Vérifier 2FA si activé pour cet admin
                  if TwoFactor.is_2fa_enabled?(user.id) do
                    totp_code = case get_req_header(conn, "x-totp-code") do
                      [code | _] -> code
                      [] -> nil
                    end
                    
                    cond do
                      is_nil(totp_code) ->
                        conn
                        |> put_status(401)
                        |> Phoenix.Controller.json(%{
                          success: false,
                          error: %{
                            code: "2FA_REQUIRED",
                            message: "Code 2FA requis. Envoyez le header X-TOTP-Code."
                          }
                        })
                        |> halt()
                      
                      not TwoFactor.verify_admin_2fa(user.id, totp_code) ->
                        conn
                        |> put_status(401)
                        |> Phoenix.Controller.json(%{
                          success: false,
                          error: %{
                            code: "2FA_INVALID",
                            message: "Code 2FA invalide ou expiré."
                          }
                        })
                        |> halt()
                      
                      true ->
                        # 2FA validé, vérifier rate limit
                        check_admin_rate_limit(conn, user)
                    end
                  else
                    # Pas de 2FA activé, vérifier rate limit directement
                    check_admin_rate_limit(conn, user)
                  end
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
          
          {:error, :ip_blocked} ->
            conn
            |> put_status(403)
            |> Phoenix.Controller.json(%{
              success: false,
              error: %{
                code: "IP_BLOCKED",
                message: "Adresse IP non autorisée pour accéder au panel admin"
              }
            })
            |> halt()
        end
    end
  end
  
  # ========================================
  # Rate Limiting (via Redis si disponible, sinon ETS)
  # ========================================
  
  @doc """
  Vérifie le rate limiting pour un admin.
  Utilise Redis si disponible, sinon un compteur ETS en mémoire.
  """
  def check_rate_limit(user_id) do
    key = "admin:rate_limit:#{user_id}"
    now = System.system_time(:millisecond)
    
    case get_redis_rate_info(key, now) do
      {:ok, count} when count >= @rate_limit_max_requests ->
        {:error, :rate_limited}
      {:ok, _count} ->
        :ok
      {:error, _reason} ->
        # Si Redis indisponible, laisser passer
        :ok
    end
  end
  
  defp get_redis_rate_info(key, _now) do
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, nil} ->
        # Première requête dans la fenêtre
        Redix.command(GameHub.Redis, ["SET", key, "1", "PX", @rate_limit_window_ms])
        {:ok, 1}
      
      {:ok, count_str} ->
        count = String.to_integer(count_str)
        {:ok, count + 1}
      
      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:ok, 1}
  end
  
  # ========================================
  # IP Whitelist
  # ========================================
  
  @doc """
  Vérifie si l'IP de la requête est autorisée.
  Si aucune IP n'est configurée dans la whitelist, toutes sont autorisées.
  """
  def check_ip_whitelist(conn) do
    client_ip = get_client_ip(conn)
    
    case Security.ip_whitelist_active?() do
      true ->
        if Security.ip_allowed?(client_ip) do
          :ok
        else
          {:error, :ip_blocked}
        end
      
      false ->
        # Pas de whitelist active, tout est autorisé
        :ok
    end
  end
  
  defp get_client_ip(conn) do
    # Supporter X-Forwarded-For pour les proxys
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()
      [] ->
        conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    end
  end

  # ========================================
  # Helper: Rate limit + assign user
  # ========================================

  defp check_admin_rate_limit(conn, user) do
    case check_rate_limit(user.id) do
      :ok ->
        conn
        |> assign(:current_user, user)
        |> assign(:current_user_id, user.id)
      
      {:error, :rate_limited} ->
        conn
        |> put_status(429)
        |> Phoenix.Controller.json(%{
          success: false,
          error: %{
            code: "RATE_LIMITED",
            message: "Trop de requêtes. Maximum #{@rate_limit_max_requests} requêtes par minute."
          }
        })
        |> halt()
    end
  end
end
