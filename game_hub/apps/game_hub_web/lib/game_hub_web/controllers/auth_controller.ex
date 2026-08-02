# ==================================
# WIWIGA - Controller Authentification
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AuthController
# Description: Endpoints OTP multi-méthodes (phone/email) + JWT
#              avec inscription (username + avatar)

defmodule GameHubWeb.AuthController do
  @moduledoc """
  Controller authentification multi-méthodes.
  
  ## Endpoints publics
    POST /api/auth/send-otp      - Envoie code OTP (phone ou email)
    POST /api/auth/verify-otp    - Vérifie OTP, retourne tokens
    POST /api/auth/register      - Inscription (phone/email + username + avatar)
    POST /api/auth/refresh       - Rotation refresh token
    POST /api/auth/logout        - Révoque le refresh token
    GET  /api/auth/avatars       - Liste des avatars prédéfinis
  
  ## Endpoints authentifiés
    GET  /api/auth/me            - Profil utilisateur
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.Auth
  alias GameHub.Errors
  alias GameHub.Users.User
  
  # ========================================
  # OTP — Envoi
  # ========================================
  
  @doc """
  POST /api/auth/send-otp
  
  Body: %{phone: "+237...", device_id: "uuid"} ou %{email: "user@example.com", device_id: "uuid"}
  
  Response: %{success: true, data: %{message: "OTP envoyé"}}
  """
  def send_otp(conn, params) do
    device_id = Map.get(params, "device_id") || get_device_id_header(conn)
    ip_address = get_client_ip(conn)
    
    opts = [device_id: device_id, ip_address: ip_address]
    
    cond do
      # Envoi par phone
      phone = Map.get(params, "phone") ->
        case Auth.send_otp(String.trim(phone), opts) do
          {:ok, _otp} ->
            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{message: "Code OTP envoyé avec succès"},
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          
          {:error, :rate_limited} ->
            conn
            |> put_status(429)
            |> json(Errors.error("Trop de tentatives. Veuillez réessayer dans quelques minutes.", 429, "RATE_LIMITED"))
          
          {:error, :invalid_phone} ->
            conn
            |> put_status(400)
            |> json(Errors.error("Numéro de téléphone invalide", 400, "VALIDATION_ERROR", %{phone: "format invalide"}))
        end
      
      # Envoi par email
      email = Map.get(params, "email") ->
        case Auth.send_otp_email(String.trim(email), opts) do
          {:ok, _otp} ->
            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{message: "Code OTP envoyé par email"},
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          
          {:error, :rate_limited} ->
            conn
            |> put_status(429)
            |> json(Errors.error("Trop de tentatives. Veuillez réessayer dans quelques minutes.", 429, "RATE_LIMITED"))
          
          {:error, :invalid_email} ->
            conn
            |> put_status(400)
            |> json(Errors.error("Adresse email invalide", 400, "VALIDATION_ERROR", %{email: "format invalide"}))
        end
      
      # Aucun identifiant fourni
      true ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'phone' ou 'email' requis", 400, "VALIDATION_ERROR"))
    end
  end
  
  # ========================================
  # OTP — Vérification
  # ========================================
  
  @doc """
  POST /api/auth/verify-otp
  
  Body: %{phone: "+237...", otp: "123456"} ou %{email: "user@example.com", otp: "123456"}
  
  Response: %{success: true, data: %{access_token, refresh_token, user}}
  """
  def verify_otp(conn, params) do
    otp = Map.get(params, "otp")
    device_id = Map.get(params, "device_id") || get_device_id_header(conn)
    ip_address = get_client_ip(conn)
    user_agent = get_user_agent(conn)
    
    opts = [device_id: device_id, ip_address: ip_address, user_agent: user_agent]
    
    cond do
      is_nil(otp) or otp == "" ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'otp' requis", 400, "VALIDATION_ERROR"))
      
      # Vérification par phone
      phone = Map.get(params, "phone") ->
        do_verify_otp(conn, String.trim(phone), otp, Keyword.put(opts, :type, :phone))
      
      # Vérification par email
      email = Map.get(params, "email") ->
        do_verify_otp(conn, String.trim(email), otp, Keyword.put(opts, :type, :email))
      
      true ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'phone' ou 'email' requis", 400, "VALIDATION_ERROR"))
    end
  end
  
  defp do_verify_otp(conn, identifier, otp, opts) do
    case Auth.verify_otp(identifier, otp, opts) do
      {:ok, access_token, refresh_token, user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: GameHub.Guardian.access_token_ttl_seconds(),
            user: format_user(user)
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :invalid_otp} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Code OTP incorrect", 401, "INVALID_OTP"))
      
      {:error, :otp_expired} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Code OTP expiré. Demandez un nouveau code.", 401, "OTP_EXPIRED"))
      
      {:error, :otp_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Aucun OTP trouvé. Demandez d'abord un code.", 404, "OTP_NOT_FOUND"))
      
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur d'authentification: #{inspect(reason)}", 500, "AUTH_ERROR"))
    end
  end
  
  # ========================================
  # Inscription
  # ========================================
  
  @doc """
  POST /api/auth/login
  
  Body: %{
    phone: "+237..." ou email: "user@example.com",
    password: "motdepasse"
  }
  
  Connexion par mot de passe.
  """
  def login(conn, params) do
    device_id = Map.get(params, "device_id") || get_device_id_header(conn)
    ip_address = get_client_ip(conn)
    user_agent = get_user_agent(conn)
    
    password = Map.get(params, "password")
    
    opts = [device_id: device_id, ip_address: ip_address, user_agent: user_agent]
    
    cond do
      is_nil(password) or password == "" ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'password' requis", 400, "VALIDATION_ERROR"))
      
      # Connexion par phone + password
      phone = Map.get(params, "phone") ->
        do_login(conn, String.trim(phone), password, Keyword.put(opts, :type, :phone))
      
      # Connexion par email + password
      email = Map.get(params, "email") ->
        do_login(conn, String.trim(email), password, Keyword.put(opts, :type, :email))
      
      true ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'phone' ou 'email' requis", 400, "VALIDATION_ERROR"))
    end
  end
  
  defp do_login(conn, identifier, password, opts) do
    case Auth.login_with_password(identifier, password, opts) do
      {:ok, access_token, refresh_token, user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: GameHub.Guardian.access_token_ttl_seconds(),
            user: format_user(user),
            otp_required: false
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:ok, :otp_required, user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            otp_required: true,
            user: format_user(user),
            message: "Code OTP envoyé. Veuillez vérifier votre téléphone ou email."
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :invalid_credentials} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Identifiants incorrects", 401, "INVALID_CREDENTIALS"))
      
      {:error, :account_inactive} ->
        conn
        |> put_status(403)
        |> json(Errors.error("Ce compte est désactivé", 403, "ACCOUNT_INACTIVE"))
      
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur d'authentification: #{inspect(reason)}", 500, "AUTH_ERROR"))
    end
  end
  
  @doc """
  POST /api/auth/set-password
  
  Body: %{password: "nouveau_mot_de_passe"}
  
  Définit ou change le mot de passe (utilisateur authentifié).
  """
  def set_password(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    password = Map.get(params, "password")
    
    cond do
      is_nil(password) or password == "" ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'password' requis", 400, "VALIDATION_ERROR"))
      
      String.length(password) < 8 ->
        conn
        |> put_status(400)
        |> json(Errors.error("Le mot de passe doit contenir au moins 8 caractères", 400, "VALIDATION_ERROR"))
      
      true ->
        case Auth.set_password(user_id, password) do
          {:ok, _user} ->
            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{message: "Mot de passe défini avec succès"}
            })
          
          {:error, %Ecto.Changeset{} = changeset} ->
            errors = format_changeset_errors(changeset)
            conn
            |> put_status(422)
            |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
          
          {:error, :user_not_found} ->
            conn
            |> put_status(404)
            |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
        end
    end
  end
  
  # ========================================
  # Inscription
  # ========================================
  
  @doc """
  POST /api/auth/register
  
  Body: %{
    phone: "+237..." ou email: "user@example.com",
    username: "pseudo",
    avatar_type: "wiwiga_1" (optionnel),
    name: "Nom" (optionnel)
  }
  
  Response: %{success: true, data: %{user, message: "Compte créé"}}
  """
  def register(conn, params) do
    case Auth.register(params) do
      {:ok, user} ->
        conn
        |> put_status(201)
        |> json(%{
          success: true,
          data: %{
            user: format_user(user),
            message: "Compte créé avec succès. Veuillez vérifier votre code OTP."
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
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
        |> json(Errors.error("Erreur lors de l'inscription: #{inspect(reason)}", 500, "REGISTRATION_ERROR"))
    end
  end
  
  @doc """
  POST /api/auth/check-availability
  
  Body: %{phone: "+237...", email: "user@example.com"}
  
  Vérifie si les identifiants sont disponibles.
  """
  def check_availability(conn, params) do
    phone = Map.get(params, "phone")
    email = Map.get(params, "email")
    
    case Auth.check_identifier_availability(phone, email) do
      :available ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: %{available: true}})
      
      {:taken, type} ->
        field = case type do
          :phone -> "phone"
          :email -> "email"
          :both -> "phone et email"
        end
        conn
        |> put_status(409)
        |> json(Errors.error("Ce #{field} est déjà utilisé", 409, "ALREADY_EXISTS"))
    end
  end
  
  @doc """
  POST /api/auth/complete-registration
  
  Body: %{username: "pseudo", avatar_type: "wiwiga_1"}
  
  Complète le profil après OTP (pour les nouveaux utilisateurs).
  """
  def complete_registration(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case Auth.complete_registration(user_id, params) do
      {:ok, user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{user: format_user(user)}
        })
      
      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)
        conn
        |> put_status(422)
        |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
      
      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
    end
  end
  
  # ========================================
  # Avatars
  # ========================================
  
  @doc """
  GET /api/auth/avatars
  
  Retourne la liste des avatars prédéfinis WIWIGA.
  """
  def avatars(conn, _params) do
    avatar_list = Enum.map(User.avatar_types(), fn type ->
      %{
        type: type,
        name: avatar_display_name(type),
        is_default: type == User.default_avatar()
      }
    end)
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{avatars: avatar_list}
    })
  end
  
  # ========================================
  # Refresh / Logout / Me
  # ========================================
  
  @doc """
  POST /api/auth/refresh
  """
  def refresh(conn, %{"refresh_token" => refresh_token} = params) do
    device_id = Map.get(params, "device_id") || get_device_id_header(conn)
    opts = [device_id: device_id]
    
    case Auth.refresh_tokens(refresh_token, opts) do
      {:ok, new_access_token, new_refresh_token, _user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            access_token: new_access_token,
            refresh_token: new_refresh_token,
            token_type: "Bearer",
            expires_in: GameHub.Guardian.access_token_ttl_seconds()
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :token_expired} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Session expirée. Veuillez vous reconnecter.", 401, "SESSION_EXPIRED"))
      
      {:error, :token_replay_detected} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Activité suspecte détectée. Toutes les sessions ont été révoquées.", 401, "SECURITY_ALERT"))
      
      {:error, _} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Refresh token invalide", 401, "INVALID_TOKEN"))
    end
  end
  
  def refresh(conn, _params) do
    case get_bearer_token(conn) do
      nil ->
        conn
        |> put_status(400)
        |> json(Errors.error("Paramètre 'refresh_token' requis", 400, "VALIDATION_ERROR"))
      token ->
        refresh(conn, %{"refresh_token" => token})
    end
  end
  
  @doc """
  POST /api/auth/logout
  """
  def logout(conn, %{"refresh_token" => refresh_token}) do
    case Auth.logout(refresh_token) do
      :ok ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{message: "Déconnecté avec succès"},
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, _} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{message: "Déconnecté"},
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end
  
  def logout(conn, _params) do
    case get_bearer_token(conn) do
      nil ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: %{message: "Déconnecté"}})
      token ->
        logout(conn, %{"refresh_token" => token})
    end
  end
  
  @doc """
  GET /api/auth/me
  """
  def me(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Repo.get(User, user_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      user ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{user: format_user(user)},
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end
  
  # ========================================
  # Auth Settings — Préférences OTP
  # ========================================
  
  @doc """
  GET /api/auth/settings
  
  Récupère les préférences d'authentification de l'utilisateur.
  """
  def get_settings(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case Auth.get_auth_settings(user_id) do
      {:ok, settings} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: settings
        })
      
      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
    end
  end
  
  @doc """
  PUT /api/auth/settings
  
  Met à jour les préférences OTP.
  Body: %{otp_required_on_login: true|false}
  """
  def update_settings(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    otp_required = Map.get(params, "otp_required_on_login")
    
    if is_nil(otp_required) do
      conn
      |> put_status(400)
      |> json(Errors.error("Paramètre 'otp_required_on_login' requis (true/false)", 400, "VALIDATION_ERROR"))
    else
      case Auth.update_auth_settings(user_id, %{"otp_required_on_login" => otp_required}) do
        {:ok, settings} ->
          conn
          |> put_status(200)
          |> json(%{
            success: true,
            data: settings,
            message: "Préférences mises à jour"
          })
        
        {:error, %Ecto.Changeset{} = changeset} ->
          errors = format_changeset_errors(changeset)
          conn
          |> put_status(422)
          |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
        
        {:error, :user_not_found} ->
          conn
          |> put_status(404)
          |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      end
    end
  end
  
  # ========================================
  # Fonctions Privées
  # ========================================
  
  defp format_user(user) do
    %{
      id: user.id,
      phone: user.phone,
      email: user.email,
      username: user.username,
      name: user.name,
      role: user.role,
      avatar_type: user.avatar_type,
      avatar_url: user.avatar_url,
      balance: user.balance,
      token_balance: Map.get(user, :token_balance, 0),
      is_active: user.is_active,
      has_verified_kyc: user.has_verified_kyc,
      login_count: user.login_count || 0,
      last_login_at: user.last_login_at,
      otp_required_on_login: user.otp_required_on_login || false,
      created_at: user.inserted_at
    }
  end
  
  defp avatar_display_name("default"), do: "Avatar par défaut"
  defp avatar_display_name("wiwiga_1"), do: "Casque Gaming"
  defp avatar_display_name("wiwiga_2"), do: "Manette Néon"
  defp avatar_display_name("wiwiga_3"), do: "Dé Chanceux"
  defp avatar_display_name("wiwiga_4"), do: "Champion"
  defp avatar_display_name("wiwiga_5"), do: "Robot"
  defp avatar_display_name("wiwiga_6"), do: "Dragon"
  defp avatar_display_name("wiwiga_7"), do: "Phoenix"
  defp avatar_display_name("wiwiga_8"), do: "Étoile"
  defp avatar_display_name(type), do: type
  
  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
  
  defp get_client_ip(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  rescue
    _ -> "unknown"
  end
  
  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> String.slice(ua, 0, 500)
      _ -> "unknown"
    end
  end
  
  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
  
  defp get_device_id_header(conn) do
    case get_req_header(conn, "x-device-id") do
      [device_id | _] when device_id != "" -> device_id
      _ -> nil
    end
  end
end
