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
        # Créer une session tracking (section 2.4)
        device_id = Keyword.get(opts, :device_id)
        user_agent = Keyword.get(opts, :user_agent, "unknown")
        ip_address = Keyword.get(opts, :ip_address, "unknown")
        try do
          GameHub.Users.Sessions.create_session(user.id,
            device_id: device_id,
            user_agent: user_agent,
            ip_address: ip_address
          )
        rescue
          e -> require Logger; Logger.warning("Failed to create session: #{inspect(e)}")
        end
        
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
    # Debug logging pour diagnostiquer les échecs de connexion
    if Mix.env() == :dev do
      IO.puts("[LOGIN DEBUG] identifier=#{identifier}, password_length=#{String.length(password)}")
    end
    
    case Auth.login_with_password(identifier, password, opts) do
      {:ok, access_token, refresh_token, user} ->
        # Créer une session tracking (section 2.4)
        device_id = Keyword.get(opts, :device_id)
        user_agent = Keyword.get(opts, :user_agent, "unknown")
        ip_address = Keyword.get(opts, :ip_address, "unknown")
        try do
          GameHub.Users.Sessions.create_session(user.id,
            device_id: device_id,
            user_agent: user_agent,
            ip_address: ip_address
          )
        rescue
          e -> require Logger; Logger.warning("Failed to create session: #{inspect(e)}")
        end
        
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
  # Profil utilisateur
  # ========================================
  
  @doc """
  PUT /api/auth/profile
  
  Met à jour le profil utilisateur (username, name, avatar_type).
  """
  def update_profile(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Repo.get(GameHub.Users.User, user_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      user ->
        case user |> GameHub.Users.User.profile_update_changeset(params) |> GameHub.Repo.update() do
          {:ok, updated_user} ->
            conn
            |> put_status(200)
            |> json(%{success: true, data: %{user: format_user(updated_user)}, message: "Profil mis à jour"})
          
          {:error, changeset} ->
            errors = format_changeset_errors(changeset)
            conn
            |> put_status(422)
            |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
        end
    end
  end
  
  @doc """
  GET /api/auth/profile/stats
  
  Récupère les statistiques du profil utilisateur.
  """
  def get_profile_stats(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Users.Stats.get_stats(user_id) do
      {:ok, stats} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            games_played: stats.games_played,
            wins: stats.wins,
            losses: stats.losses,
            draws: stats.draws,
            total_winnings: stats.total_winnings,
            total_bets: stats.total_bets,
            current_streak: stats.current_streak,
            best_streak: stats.best_streak,
            xp_points: stats.xp_points,
            rank_tier: stats.rank_tier,
            last_game_at: stats.last_game_at
          }
        })
      
      {:error, _} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur chargement stats", 500, "STATS_ERROR"))
    end
  end
  
  @doc """
  GET /api/auth/profile/achievements
  
  Récupère les achievements avec statut unlock.
  """
  def get_achievements(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    achievements = GameHub.Users.AchievementManager.list_with_status(user_id)
    
    conn
    |> put_status(200)
    |> json(%{success: true, data: %{achievements: achievements}})
  end
  
  # ========================================
  # Préférences utilisateur
  # ========================================
  
  @doc """
  GET /api/auth/preferences
  
  Récupère les préférences utilisateur.
  """
  def get_preferences(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Users.Preferences.get_preferences(user_id) do
      {:ok, prefs} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: prefs})
      
      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
    end
  end
  
  @doc """
  PUT /api/auth/preferences
  
  Met à jour les préférences utilisateur.
  """
  def update_preferences(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    # Extraire uniquement les clés de préférences
    pref_keys = ~w(sound_enabled vibration_enabled notifications_enabled language theme font_size)
    prefs = Map.take(params, pref_keys)
    
    case GameHub.Users.Preferences.update_preferences(user_id, prefs) do
      {:ok, updated_prefs} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: updated_prefs, message: "Préférences mises à jour"})
      
      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))
      
      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(Errors.error(to_string(reason), 422, "VALIDATION_ERROR"))
    end
  end
  
  # ========================================
  # Sessions utilisateur
  # ========================================
  
  @doc """
  GET /api/auth/sessions
  
  Liste les sessions actives.
  """
  def get_sessions(conn, _params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Users.Sessions.get_active_sessions(user_id) do
      {:ok, sessions} ->
        formatted = Enum.map(sessions, fn s ->
          %{
            id: s.id,
            device_name: GameHub.Users.Sessions.detect_device_name(s.user_agent),
            device_id: s.device_id,
            ip_address: s.ip_address,
            last_active_at: s.last_active_at,
            is_current: s.is_current,
            created_at: s.inserted_at
          }
        end)
        
        conn
        |> put_status(200)
        |> json(%{success: true, data: %{sessions: formatted}})
    end
  end
  
  @doc """
  DELETE /api/auth/sessions/:id
  
  Révoque une session.
  """
  def revoke_session(conn, %{"id" => session_id}) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    case GameHub.Users.Sessions.revoke_session(user_id, session_id) do
      {:ok, _} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: %{message: "Session révoquée"}})
      
      {:error, :session_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Session non trouvée", 404, "NOT_FOUND"))
    end
  end
  
  # ========================================
  # Changement de mot de passe
  # ========================================
  
  @doc """
  POST /api/auth/change-password
  
  Change le mot de passe (ancien + nouveau).
  """
  def change_password(conn, params) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    old_password = Map.get(params, "old_password", "")
    new_password = Map.get(params, "new_password", "")
    
    cond do
      old_password == "" or new_password == "" ->
        conn
        |> put_status(400)
        |> json(Errors.error("Ancien et nouveau mot de passe requis", 400, "VALIDATION_ERROR"))
      
      String.length(new_password) < 8 ->
        conn
        |> put_status(422)
        |> json(Errors.error("Le mot de passe doit contenir au moins 8 caractères", 422, "VALIDATION_ERROR"))
      
      true ->
        user = GameHub.Repo.get(GameHub.Users.User, user_id)
        
        if user && user.password_hash && GameHub.Users.User.verify_password(user, old_password) do
          case user |> GameHub.Users.User.password_changeset(%{"password" => new_password}) |> GameHub.Repo.update() do
            {:ok, _} ->
              conn
              |> put_status(200)
              |> json(%{success: true, data: %{message: "Mot de passe changé"}})
            
            {:error, changeset} ->
              errors = format_changeset_errors(changeset)
              conn
              |> put_status(422)
              |> json(Errors.error("Erreur de validation", 422, "VALIDATION_ERROR", errors))
          end
        else
          conn
          |> put_status(401)
          |> json(Errors.error("Ancien mot de passe incorrect", 401, "INVALID_PASSWORD"))
        end
    end
  end
  
  # ========================================
  # Upload Avatar
  # ========================================
  
  @allowed_image_types ~w(image/jpeg image/png image/webp)
  @max_file_size 2 * 1024 * 1024  # 2MB
  
  @doc """
  POST /api/auth/avatar/upload
  
  Upload d'une photo de profil personnelle.
  Multipart form: avatar (file)
  """
  def upload_avatar(conn, %{"avatar" => %Plug.Upload{} = upload}) do
    user_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    
    cond do
      # Vérifier le type MIME
      upload.content_type not in @allowed_image_types ->
        conn
        |> put_status(422)
        |> json(Errors.error("Format non supporté. Accepté: JPEG, PNG, WebP", 422, "INVALID_FORMAT"))
      
      # Vérifier la taille
      File.stat!(upload.path).size > @max_file_size ->
        conn
        |> put_status(422)
        |> json(Errors.error("Fichier trop volumineux (max 2MB)", 422, "FILE_TOO_LARGE"))
      
      true ->
        # Créer le dossier si nécessaire
        upload_dir = Path.join([:code.priv_dir(:game_hub), "static", "uploads", "avatars"])
        File.mkdir_p!(upload_dir)
        
        # Générer le nom de fichier
        ext = case upload.content_type do
          "image/jpeg" -> ".jpg"
          "image/png" -> ".png"
          "image/webp" -> ".webp"
          _ -> ".jpg"
        end
        
        filename = "#{user_id}_#{System.system_time(:second)}#{ext}"
        filepath = Path.join(upload_dir, filename)
        
        # Copier le fichier
        case File.cp(upload.path, filepath) do
          :ok ->
            avatar_url = "/uploads/avatars/#{filename}"
            
            # Mettre à jour l'utilisateur
            user = GameHub.Repo.get(GameHub.Users.User, user_id)
            
            case user |> GameHub.Users.User.profile_update_changeset(%{"avatar_url" => avatar_url}) |> GameHub.Repo.update() do
              {:ok, updated_user} ->
                conn
                |> put_status(200)
                |> json(%{success: true, data: %{avatar_url: avatar_url, user: format_user(updated_user)}, message: "Avatar mis à jour"})
              
              {:error, _} ->
                conn
                |> put_status(500)
                |> json(Errors.error("Erreur mise à jour avatar", 500, "UPDATE_ERROR"))
            end
          
          {:error, _} ->
            conn
            |> put_status(500)
            |> json(Errors.error("Erreur sauvegarde fichier", 500, "UPLOAD_ERROR"))
        end
    end
  end
  
  def upload_avatar(conn, _params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Fichier avatar requis (multipart form)", 400, "MISSING_FILE"))
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
      preferences: user.preferences || %{},
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

  # ========================================
  # DEBUG — Reset passwords (DEV ONLY)
  # ========================================
  
  @doc """
  POST /api/auth/debug-reset-passwords
  
  Réinitialise les mots de passe des utilisateurs seed.
  DEV ONLY — à supprimer en production.
  """
  def debug_reset_passwords(conn, _params) do
    unless Mix.env() == :dev do
      conn |> put_status(404) |> json(%{error: "Not found"})
    else
      passwords = [
        {"+237600000000", "Wiwiga@Super2026!", "super_admin"},
        {"+237699999999", "Wiwiga@Admin2026!", "admin"},
        {"+237688888888", "Wiwiga@Modo2026!", "moderator"},
        {"+237677777777", "Wiwiga@Test2026!", "test"},
        {"+237666666666", "Wiwiga@Joueur2026!", "user"}
      ]
      
      results = Enum.map(passwords, fn {phone, pw, _role} ->
        case GameHub.Repo.get_by(User, phone: phone) do
          nil -> %{phone: phone, status: "not_found"}
          user ->
            new_hash = Pbkdf2.hash_pwd_salt(pw)
            user |> Ecto.Changeset.change(%{password_hash: new_hash}) |> GameHub.Repo.update!()
            verify = Pbkdf2.verify_pass(pw, new_hash)
            %{phone: phone, username: user.username, status: "reset", verify: verify}
        end
      end)
      
      conn |> put_status(200) |> json(%{success: true, data: %{results: results}})
    end
  end
  
  @doc """
  POST /api/auth/debug-inspect-login
  
  Inspecte une tentative de login sans la traiter.
  Affiche le mot de passe reçu, le hash stocké, et le résultat de la vérification.
  """
  def debug_inspect_login(conn, params) do
    unless Mix.env() == :dev do
      conn |> put_status(404) |> json(%{error: "Not found"})
    else
      identifier = Map.get(params, "phone") || Map.get(params, "email")
      password = Map.get(params, "password", "")
      type = if Map.has_key?(params, "email"), do: :email, else: :phone
      
      user = case type do
        :email -> GameHub.Repo.get_by(User, email: String.downcase(String.trim(identifier)))
        _ -> GameHub.Repo.get_by(User, phone: String.trim(identifier))
      end
      
      result = case user do
        nil -> %{found: false, identifier: identifier}
        u ->
          verify = if u.password_hash do
            Pbkdf2.verify_pass(password, u.password_hash)
          else
            :no_hash
          end
          %{
            found: true,
            identifier: identifier,
            user_id: u.id,
            username: u.username,
            password_received: password,
            password_length: String.length(password),
            password_bytes: :erlang.binary_to_list(password),
            hash_prefix: if(u.password_hash, do: String.slice(u.password_hash, 0, 40)),
            hash_length: if(u.password_hash, do: String.length(u.password_hash)),
            verify_result: verify
          }
      end
      
      conn |> put_status(200) |> json(%{success: true, data: result})
    end
  end
end
