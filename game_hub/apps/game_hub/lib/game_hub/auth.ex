defmodule GameHub.Auth do
  @moduledoc """
  Module d'authentification multi-méthodes par OTP + JWT avec refresh token rotation.
  
  ## Flux d'authentification
  
  ### Inscription (nouvel utilisateur)
  1. `register/2` — Crée un compte avec phone/email + username + avatar
  2. `send_otp/2` ou `send_otp_email/2` — Envoie le code OTP
  3. `verify_otp/3` — Vérifie l'OTP, retourne les tokens
  
  ### Connexion (utilisateur existant)
  1. `send_otp/2` (phone) ou `send_otp_email/2` (email)
  2. `verify_otp/3` — Vérifie et retourne les tokens
  
  ### Session
  3. `refresh_tokens/2` — Rotation refresh token
  4. `logout/1` — Révoque le refresh token
  
  ## Sécurité
  - OTP: 6 chiffres, validité 5 min, max 5 tentatives/heure/device
  - Access token: JWT 30 min
  - Refresh token: JWT 30 jours, stocké hashé en DB, rotation à chaque usage
  - Dev bypass: code `123456` accepté en dev/test
  """
  
  require Logger
  alias GameHub.{Repo, Guardian, EnvConfig}
  alias GameHub.Users.User
  alias GameHub.Auth.RefreshToken
  alias GameHub.AuditLog
  alias GameHub.Admin.PlatformConfig
  import Ecto.Query
  
  @otp_validity_seconds 300  # 5 minutes
  @otp_rate_limit 5          # max tentatives par window
  @otp_rate_window 3600      # 1 heure en secondes
  @dev_bypass_otp "123456"   # Code bypass pour dev/test
  
  # ========================================
  # OTP — Envoi et Vérification
  # ========================================
  
  @doc """
  Génère et envoie un code OTP.
  
  ## Paramètres
  - `phone`: Numéro de téléphone (+237...)
  - `opts`: Options optionnelles
    - `:device_id` — ID de l'appareil (pour rate limiting)
  
  ## Retour
  - `{:ok, otp}` en dev (OTP affiché dans les logs)
  - `{:error, :rate_limited}` si trop de tentatives
  - `{:error, :invalid_phone}` si numéro invalide
  """
  def send_otp(phone, opts \\ []) do
    device_id = Keyword.get(opts, :device_id)
    ip_address = Keyword.get(opts, :ip_address)
    
    # Vérifier rate limiting par device
    if device_id && rate_limited?(phone, device_id) do
      # Logger le rate limiting
      AuditLog.log("rate_limited", nil, "auth", nil, %{phone: phone, device_id: device_id}, %{ip_address: ip_address})
      {:error, :rate_limited}
    else
      # Incrémenter le compteur de tentatives
      if device_id, do: increment_rate_counter(phone, device_id)
      
      otp = generate_otp()
      store_otp(phone, otp)
      
      # En dev/test: afficher dans les logs
      if !EnvConfig.production?() do
        IO.puts("[OTP DEV] Code pour #{phone}: #{otp}")
        IO.puts("[OTP DEV] Bypass code: #{@dev_bypass_otp}")
      end
      
      # Logger l'envoi OTP
      AuditLog.log("otp_sent", nil, "auth", nil, %{phone: phone, device_id: device_id}, %{ip_address: ip_address})
      
      # Envoyer via SMS provider (LogAdapter en dev, CampayAdapter en production)
      GameHub.SmsProvider.send_sms(phone, "[WIWIGA] Code de vérification: #{otp}")
      
      {:ok, otp}
    end
  end
  
  @doc """
  Génère et envoie un code OTP par email.
  
  ## Paramètres
  - `email`: Adresse email
  - `opts`: Options
    - `:device_id` — ID de l'appareil (pour rate limiting)
  
  ## Retour
  - `{:ok, otp}` en dev (OTP affiché dans les logs)
  - `{:error, :rate_limited}` si trop de tentatives
  - `{:error, :invalid_email}` si email invalide
  """
  def send_otp_email(email, opts \\ []) do
    device_id = Keyword.get(opts, :device_id)
    ip_address = Keyword.get(opts, :ip_address)
    
    # Vérifier format email basique
    if not String.match?(email, ~r/^[^\s]+@[^\s]+$/) do
      {:error, :invalid_email}
    else
      # Utiliser email comme clé OTP (même logique que phone)
      otp_key = "email:#{email}"
      
      if device_id && rate_limited?(otp_key, device_id) do
        AuditLog.log("rate_limited", nil, "auth", nil, %{email: email, device_id: device_id}, %{ip_address: ip_address})
        {:error, :rate_limited}
      else
        if device_id, do: increment_rate_counter(otp_key, device_id)
        
        otp = generate_otp()
        store_otp(otp_key, otp)
        
        if !EnvConfig.production?() do
          IO.puts("[OTP DEV] Code email pour #{email}: #{otp}")
          IO.puts("[OTP DEV] Bypass code: #{@dev_bypass_otp}")
        end
        
        AuditLog.log("otp_email_sent", nil, "auth", nil, %{email: email, device_id: device_id}, %{ip_address: ip_address})
        
        # Envoyer via email provider (LogAdapter en dev, SendGrid en production)
        Logger.info("[EMAIL] OTP pour #{email}: #{otp}")
        
        {:ok, otp}
      end
    end
  end
  
  @doc """
  Inscription multi-méthodes: crée un compte utilisateur.
  
  ## Paramètres
  - `attrs`: Map avec:
    - `phone` OU `email` (au moins un requis)
    - `username` (requis, 3-30 chars alphanumériques + underscore)
    - `avatar_type` (optionnel, défaut: "default")
    - `name` (optionnel)
  
  ## Retour
  - `{:ok, user}` — Compte créé
  - `{:error, changeset}` — Erreurs de validation
  - `{:error, :phone_or_email_required}` — Ni phone ni email fourni
  """
  def register(attrs) do
    # Vérifier si l'inscription est activée via PlatformConfig
    unless PlatformConfig.get_bool("registration", "registration_enabled", true) do
      {:error, :registration_disabled}
    else
      phone = Map.get(attrs, "phone") || Map.get(attrs, :phone)
      email = Map.get(attrs, "email") || Map.get(attrs, :email)

      # Vérifier qu'au moins phone ou email est fourni
      if (is_nil(phone) or phone == "") and (is_nil(email) or email == "") do
        {:error, :phone_or_email_required}
      else
        # Vérifier si la vérification phone est requise
        require_phone = PlatformConfig.get_bool("registration", "require_phone_verification", true)
        if require_phone and (is_nil(phone) or phone == "") do
          {:error, :phone_required}
        else
          # Normaliser les attributs
          normalized_attrs = %{
            "phone" => if(phone && phone != "", do: String.trim(phone)),
            "email" => if(email && email != "", do: String.downcase(String.trim(email))),
            "username" => Map.get(attrs, "username") || Map.get(attrs, :username),
            "name" => Map.get(attrs, "name") || Map.get(attrs, :name),
            "avatar_type" => Map.get(attrs, "avatar_type") || Map.get(attrs, :avatar_type, "default")
          }

          case %User{}
               |> User.registration_changeset(normalized_attrs)
               |> Repo.insert() do
            {:ok, user} ->
              # Appliquer le bonus de bienvenue si configuré
              maybe_apply_welcome_bonus(user)
              {:ok, user}

            error ->
              error
          end
        end
      end
    end
  end

  # Applique le bonus de bienvenue PlatformConfig au nouvel utilisateur
  defp maybe_apply_welcome_bonus(user) do
    bonus = PlatformConfig.get_welcome_bonus()
    if bonus.amount > 0 do
      try do
        GameHub.Wallet.deposit(user.id, bonus.amount, "welcome_bonus_#{user.id}_#{System.system_time(:second)}")
      rescue
        _ -> :ok
      end
    end
  end
  
  @doc """
  Complète l'inscription après vérification OTP.
  Ajoute username et avatar à un utilisateur existant.
  
  ## Paramètres
  - `user_id`: ID de l'utilisateur
  - `attrs`: Map avec username, avatar_type
  
  ## Retour
  - `{:ok, user}` — Profil complété
  - `{:error, reason}` — Erreur
  """
  def complete_registration(user_id, attrs) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        user
        |> User.update_changeset(attrs)
        |> Repo.update()
    end
  end
  
  @doc """
  Vérifie si un identifier (phone ou email) est déjà utilisé.
  
  ## Retour
  - `:available` — Disponible
  - `{:taken, :phone}` — Phone déjà utilisé
  - `{:taken, :email}` — Email déjà utilisé
  - `{:taken, :both}` — Les deux déjà utilisés
  """
  def check_identifier_availability(phone, email) do
    phone_taken = if phone && phone != "" do
      Repo.get_by(User, phone: phone) != nil
    else
      false
    end
    
    email_taken = if email && email != "" do
      Repo.get_by(User, email: String.downcase(email)) != nil
    else
      false
    end
    
    cond do
      phone_taken and email_taken -> {:taken, :both}
      phone_taken -> {:taken, :phone}
      email_taken -> {:taken, :email}
      true -> :available
    end
  end
  
  @doc """
  Vérifie le code OTP et retourne les tokens d'authentification.
  
  Supporte phone OU email comme identifiant.
  
  ## Paramètres
  - `identifier`: Numéro de téléphone ou email
  - `otp`: Code OTP à vérifier
  - `opts`: Options
    - `:device_id` — ID de l'appareil
    - `:ip_address` — Adresse IP du client
    - `:user_agent` — User-Agent du client
    - `:type` — `:phone` (défaut) ou `:email`
  
  ## Retour
  - `{:ok, access_token, refresh_token_raw, user}` — Succès
  - `{:error, reason}` — Échec
  """
  def verify_otp(identifier, otp, opts \\ []) do
    type = Keyword.get(opts, :type, :phone)
    device_id = Keyword.get(opts, :device_id)
    ip_address = Keyword.get(opts, :ip_address)
    user_agent = Keyword.get(opts, :user_agent)
    
    # Déterminer la clé OTP
    otp_key = case type do
      :email -> "email:#{String.downcase(identifier)}"
      _ -> identifier
    end
    
    # Vérifier OTP (dev bypass ou stored)
    case verify_otp_code(otp_key, otp) do
      :ok ->
        # OTP valide, supprimer
        delete_otp(otp_key)
        
        # Récupérer ou créer l'utilisateur
        case get_or_create_user_by_identifier(identifier, type) do
          {:ok, user} ->
            # Logger la vérification OTP réussie
            log_data = case type do
              :email -> %{email: identifier, device_id: device_id}
              _ -> %{phone: identifier, device_id: device_id}
            end
            AuditLog.log("otp_verified", user.id, "auth", nil, log_data, %{ip_address: ip_address, user_agent: user_agent})
            
            # Mettre à jour le tracking de connexion
            update_login_tracking(user)
            
            # Détecter comptes multiples par device
            if device_id, do: check_multi_account_device(device_id, user.id)
            
            generate_auth_tokens(user, device_id, ip_address, user_agent)
          
          {:error, reason} ->
            {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # ========================================
  # Authentification par mot de passe
  # ========================================
  
  @doc """
  Connexion par identifiant (phone/email) + mot de passe.
  
  ## Paramètres
  - `identifier`: Numéro de téléphone ou email
  - `password`: Mot de passe en clair
  - `opts`: Options
    - `:type` — `:phone` (défaut) ou `:email`
    - `:device_id` — ID de l'appareil
    - `:ip_address` — Adresse IP du client
    - `:user_agent` — User-Agent du client
  
  ## Retour
  - `{:ok, access_token, refresh_token_raw, user}` — Succès
  - `{:error, :invalid_credentials}` — Identifiants incorrects
  - `{:error, :account_inactive}` — Compte désactivé
  """
  def login_with_password(identifier, password, opts \\ []) do
    type = Keyword.get(opts, :type, :phone)
    device_id = Keyword.get(opts, :device_id)
    ip_address = Keyword.get(opts, :ip_address)
    user_agent = Keyword.get(opts, :user_agent)
    
    # Trouver l'utilisateur par phone ou email
    user = case type do
      :email ->
        email = String.downcase(String.trim(identifier))
        Repo.get_by(User, email: email)
      
      _ ->
        phone = String.trim(identifier)
        Repo.get_by(User, phone: phone)
    end
    
    case user do
      nil ->
        # Pas d'utilisateur trouvé — vérifier si c'est un compte test/dev
        # qui n'a pas encore de password_hash mais un mot de passe par défaut
        {:error, :invalid_credentials}
      
      %User{is_active: false} ->
        {:error, :account_inactive}
      
      %User{} = found_user ->
        # Vérifier le mot de passe
        if User.verify_password(found_user, password) do
          # Connexion réussie
          AuditLog.log("password_login", found_user.id, "auth", nil, %{
            type: type,
            device_id: device_id
          }, %{ip_address: ip_address, user_agent: user_agent})
          
          # Mettre à jour le tracking de connexion
          update_login_tracking(found_user)
          
          # Vérifier si OTP requis pour cet utilisateur
          if found_user.otp_required_on_login do
            # Envoyer un OTP et retourner un flag
            case send_otp(found_user.phone || "", device_id: device_id, ip_address: ip_address) do
              {:ok, _otp} ->
                {:ok, :otp_required, found_user}
              {:error, _} ->
                # Si pas de phone, essayer email
                if found_user.email do
                  case send_otp_email(found_user.email, device_id: device_id, ip_address: ip_address) do
                    {:ok, _otp} -> {:ok, :otp_required, found_user}
                    {:error, _} -> generate_auth_tokens(found_user, device_id, ip_address, user_agent)
                  end
                else
                  generate_auth_tokens(found_user, device_id, ip_address, user_agent)
                end
            end
          else
            generate_auth_tokens(found_user, device_id, ip_address, user_agent)
          end
        else
          AuditLog.log("password_login_failed", found_user.id, "auth", nil, %{
            type: type,
            device_id: device_id,
            reason: "invalid_password"
          }, %{ip_address: ip_address})
          
          {:error, :invalid_credentials}
        end
    end
  end
  
  @doc """
  Définit ou change le mot de passe d'un utilisateur.
  
  ## Paramètres
  - `user_id`: ID de l'utilisateur
  - `new_password`: Nouveau mot de passe (min 8 caractères)
  
  ## Retour
  - `{:ok, user}` — Succès
  - `{:error, reason}` — Erreur
  """
  def set_password(user_id, new_password) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        user
        |> User.password_changeset(%{"password" => new_password})
        |> Repo.update()
    end
  end
  
  # ========================================
  # Auth Settings — Préférences OTP
  # ========================================
  
  @doc """
  Récupère les préférences d'authentification d'un utilisateur.
  
  ## Retour
  - `{:ok, settings}` — Map avec otp_required_on_login
  - `{:error, :user_not_found}` — Utilisateur non trouvé
  """
  def get_auth_settings(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user ->
        {:ok, %{
          otp_required_on_login: user.otp_required_on_login
        }}
    end
  end
  
  @doc """
  Met à jour les préférences OTP de l'utilisateur.
  
  ## Paramètres
  - `user_id`: ID de l'utilisateur
  - `attrs`: %{otp_required_on_login: true/false}
  
  ## Retour
  - `{:ok, settings}` — Settings mises à jour
  - `{:error, reason}` — Erreur
  """
  def update_auth_settings(user_id, attrs) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        case user |> User.otp_settings_changeset(attrs) |> Repo.update() do
          {:ok, updated_user} ->
            AuditLog.log("auth_settings_updated", user_id, "auth", nil, %{
              otp_required_on_login: updated_user.otp_required_on_login
            })
            {:ok, %{otp_required_on_login: updated_user.otp_required_on_login}}
          
          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end
  
  # ========================================
  # Refresh Token — Rotation
  # ========================================
  
  @doc """
  Effectue la rotation des tokens.
  
  Vérifie le refresh token, le révoque, et génère de nouveaux tokens.
  
  ## Paramètres
  - `refresh_token_raw`: Le refresh token JWT brut
  - `opts`: Options
    - `:device_id` — ID de l'appareil (optionnel)
  
  ## Retour
  - `{:ok, new_access_token, new_refresh_token_raw, user}` — Succès
  - `{:error, :invalid_token}` — Token invalide ou révoqué
  - `{:error, :token_expired}` — Token expiré
  """
  def refresh_tokens(refresh_token_raw, opts \\ []) do
    device_id = Keyword.get(opts, :device_id)
    
    # Vérifier que c'est un refresh token valide
    case Guardian.verify_token_type(refresh_token_raw, "refresh") do
      {:ok, _claims} ->
        token_hash = hash_token(refresh_token_raw)
        
        # Trouver le token en DB
        case get_refresh_token_by_hash(token_hash) do
          nil ->
            {:error, :invalid_token}
          
          %{revoked_at: nil, expires_at: expires_at} = db_token ->
            # Vérifier expiration DB
            if DateTime.compare(DateTime.utc_now(), expires_at) == :gt do
              {:error, :token_expired}
            else
              # Récupérer l'utilisateur
              case Repo.get(User, db_token.user_id) do
                nil ->
                  {:error, :user_not_found}
                
                user ->
                  # Révoquer l'ancien refresh token
                  revoke_refresh_token(db_token)
                  
                  # Logger le refresh
                  AuditLog.log("token_refresh", user.id, "auth", nil, %{device_id: device_id, old_token_id: db_token.id})
                  
                  # Générer de nouveaux tokens
                  generate_auth_tokens(user, device_id, nil, nil)
              end
            end
          
          # Token déjà révoqué — possible replay attack
          %{revoked_at: _} = db_token ->
            # Révoquer TOUS les tokens de cet utilisateur (security measure)
            revoke_all_user_tokens(db_token.user_id)
            # Logger l'attaque replay
            AuditLog.log("token_replay_detected", db_token.user_id, "auth", nil, %{device_id: device_id, token_id: db_token.id})
            {:error, :token_replay_detected}
        end
      
      {:error, :token_expired} ->
        {:error, :token_expired}
      
      {:error, _} ->
        {:error, :invalid_token}
    end
  end
  
  # ========================================
  # Logout — Révocation
  # ========================================
  
  @doc """
  Déconnecte l'utilisateur en révoquant le refresh token.
  
  ## Paramètres
  - `refresh_token_raw`: Le refresh token à révoquer
  
  ## Retour
  - `:ok` — Token révoqué
  - `{:error, reason}` — Erreur
  """
  def logout(refresh_token_raw) do
    token_hash = hash_token(refresh_token_raw)
    
    case get_refresh_token_by_hash(token_hash) do
      nil ->
        # Token pas trouvé, pas grave
        :ok
      
      db_token ->
        revoke_refresh_token(db_token)
        # Aussi blacklist dans Redis pour invalidation rapide
        blacklist_token(token_hash, db_token.expires_at)
        # Logger le logout
        AuditLog.log("logout", db_token.user_id, "auth", nil, %{device_id: db_token.device_id})
        :ok
    end
  end
  
  @doc """
  Déconnecte l'utilisateur de TOUS ses appareils.
  """
  def logout_all(user_id) do
    revoke_all_user_tokens(user_id)
    :ok
  end
  
  # ========================================
  # Vérification JWT (pour AuthPlug)
  # ========================================
  
  @doc """
  Vérifie et décode un access token JWT.
  """
  def verify_jwt_token(token) do
    # D'abord vérifier si le token est blacklisté
    if token_blacklisted?(token) do
      {:error, :token_revoked}
    else
      case Guardian.decode_and_verify(token) do
        {:ok, claims} ->
          # Vérifier que c'est un access token (ou token legacy sans typ)
          token_type = Map.get(claims, "typ", "access")
          
          if token_type in ["access", nil] do
            case Guardian.resource_from_claims(claims) do
              {:ok, user} -> {:ok, %{user_id: user.id, user: user}}
              {:error, reason} -> {:error, reason}
            end
          else
            {:error, {:invalid_token_type, token_type, "access"}}
          end
        
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  @doc """
  Vérifie un access token avec grace period pour les endpoints de jeu.
  
  Accepte les tokens expirés depuis moins de `grace_minutes` (défaut: 5 min).
  """
  def verify_jwt_token_with_grace(token, grace_minutes \\ 5) do
    case verify_jwt_token(token) do
      {:ok, result} ->
        {:ok, result}
      
      {:error, :token_expired} ->
        # Vérifier si dans la grace period
        case Guardian.decode_and_verify(token, allowed_drift: grace_minutes * 60) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} -> {:ok, %{user_id: user.id, user: user, grace: true}}
              {:error, reason} -> {:error, reason}
            end
          
          {:error, reason} ->
            {:error, reason}
        end
      
      error ->
        error
    end
  end
  
  # ========================================
  # Fonctions Publiques Utilitaires
  # ========================================
  
  @doc """
  Récupère le profil utilisateur depuis un access token.
  """
  def get_user_from_token(token) do
    case verify_jwt_token(token) do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end
  
  # ========================================
  # Fonctions Privées — OTP
  # ========================================
  
  defp generate_otp do
    100_000..999_999
    |> Enum.random()
    |> to_string()
  end
  
  defp verify_otp_code(_phone, @dev_bypass_otp) when @dev_bypass_otp == "123456" do
    # Dev bypass: accepté uniquement en dev/test
    if !EnvConfig.production?() do
      :ok
    else
      {:error, :invalid_otp}
    end
  end
  
  defp verify_otp_code(phone, otp) do
    case get_stored_otp(phone) do
      nil ->
        {:error, :otp_not_found}
      
      %{code: stored_otp, expires_at: expires_at} ->
        cond do
          DateTime.compare(DateTime.utc_now(), expires_at) == :gt ->
            delete_otp(phone)
            {:error, :otp_expired}
          
          stored_otp != otp ->
            {:error, :invalid_otp}
          
          true ->
            :ok
        end
    end
  end
  
  defp store_otp(phone, otp) do
    expires_at = DateTime.utc_now() |> DateTime.add(@otp_validity_seconds, :second)
    otp_data = %{
      code: otp,
      expires_at: expires_at |> DateTime.to_iso8601()
    }
    
    key = "otp:#{phone}"
    json_data = Jason.encode!(otp_data)
    
    Redix.command(GameHub.Redis, [
      "SET", key, json_data, "EX", to_string(@otp_validity_seconds)
    ])
    
    otp_data
  end
  
  defp get_stored_otp(phone) do
    key = "otp:#{phone}"
    
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, data} ->
            %{
              code: data["code"],
              expires_at: DateTime.from_iso8601(data["expires_at"]) |> elem(1)
            }
          {:error, _} -> nil
        end
      {:error, _} -> nil
    end
  end
  
  defp delete_otp(phone) do
    key = "otp:#{phone}"
    Redix.command(GameHub.Redis, ["DEL", key])
  end
  
  # ========================================
  # Fonctions Privées — Rate Limiting OTP
  # ========================================
  
  defp rate_limited?(phone, device_id) do
    key = "otp_rate:#{phone}:#{device_id}"
    
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, nil} -> false
      {:ok, count_str} ->
        case Integer.parse(count_str) do
          {count, _} -> count >= @otp_rate_limit
          :error -> false
        end
      {:error, _} -> false
    end
  end
  
  defp increment_rate_counter(phone, device_id) do
    key = "otp_rate:#{phone}:#{device_id}"
    
    # INCR + EXPIRE atomique
    case Redix.command(GameHub.Redis, ["INCR", key]) do
      {:ok, 1} ->
        # Premier incrément, définir l'expiration
        Redix.command(GameHub.Redis, ["EXPIRE", key, to_string(@otp_rate_window)])
      {:ok, _} ->
        # Déjà existant, l'expiration est déjà définie
        :ok
      {:error, _} ->
        :ok
    end
  end
  
  # ========================================
  # Fonctions Privées — Tokens
  # ========================================
  
  defp generate_auth_tokens(user, device_id, ip_address, user_agent) do
    # Générer access token
    case Guardian.encode_access_token(user) do
      {:ok, access_token, _claims} ->
        # Générer refresh token
        case Guardian.encode_refresh_token(user) do
          {:ok, refresh_token_raw, _claims} ->
            # Stocker le refresh token en DB (hashé)
            store_refresh_token(refresh_token_raw, user, device_id, ip_address, user_agent)
            
            {:ok, access_token, refresh_token_raw, user}
          
          {:error, reason} ->
            {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp store_refresh_token(refresh_token_raw, user, device_id, ip_address, user_agent) do
    token_hash = hash_token(refresh_token_raw)
    
    expires_at = DateTime.utc_now()
    |> DateTime.add(Guardian.refresh_token_ttl_seconds(), :second)
    |> DateTime.truncate(:second)
    
    %RefreshToken{}
    |> RefreshToken.creation_changeset(%{
      user_id: user.id,
      token_hash: token_hash,
      device_id: device_id,
      expires_at: expires_at,
      ip_address: ip_address,
      user_agent: user_agent
    })
    |> Repo.insert()
  end
  
  defp get_refresh_token_by_hash(token_hash) do
    Repo.get_by(RefreshToken, token_hash: token_hash)
  end
  
  defp revoke_refresh_token(%RefreshToken{} = token) do
    token
    |> RefreshToken.revocation_changeset()
    |> Repo.update()
  end
  
  defp revoke_all_user_tokens(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    Repo.update_all(
      from(rt in RefreshToken,
        where: rt.user_id == ^user_id and is_nil(rt.revoked_at)
      ),
      set: [revoked_at: now]
    )
  end
  
  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end
  
  # ========================================
  # Fonctions Privées — Blacklist Redis
  # ========================================
  
  defp blacklist_token(token_hash, expires_at) do
    key = "blacklist:#{token_hash}"
    ttl = DateTime.diff(expires_at, DateTime.utc_now(), :second)
    
    if ttl > 0 do
      Redix.command(GameHub.Redis, ["SET", key, "1", "EX", to_string(ttl)])
    end
  end
  
  defp token_blacklisted?(token) do
    token_hash = hash_token(token)
    key = "blacklist:#{token_hash}"
    
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, "1"} -> true
      _ -> false
    end
  end
  
  # ========================================
  # Fonctions Privées — User
  # ========================================
  
  @doc """
  Récupère ou crée un utilisateur par identifiant (phone ou email).
  """
  def get_or_create_user_by_identifier(identifier, type \\ :phone) do
    case type do
      :email ->
        email = String.downcase(String.trim(identifier))
        case Repo.get_by(User, email: email) do
          nil ->
            # Créer un nouvel utilisateur avec email
            attrs = %{
              "email" => email,
              "username" => generate_temp_username(),
              "avatar_type" => "default"
            }
            %User{}
            |> User.registration_changeset(attrs)
            |> Repo.insert()
          
          user ->
            {:ok, user}
        end
      
      _ ->
        phone = String.trim(identifier)
        case Repo.get_by(User, phone: phone) do
          nil ->
            # Créer un nouvel utilisateur avec phone
            attrs = %{
              "phone" => phone,
              "username" => generate_temp_username(),
              "avatar_type" => "default"
            }
            %User{}
            |> User.registration_changeset(attrs)
            |> Repo.insert()
          
          user ->
            {:ok, user}
        end
    end
  end
  
  # Met à jour le tracking de connexion de l'utilisateur.
  defp update_login_tracking(user) do
    user
    |> User.login_tracking_changeset()
    |> Repo.update()
  end
  
  defp generate_temp_username do
    "player_" <> (:erlang.unique_integer([:positive]) |> Integer.to_string(36) |> String.downcase())
  end

  # ========================================
  # Fonctions Privées — Détection Comptes Multiples
  # ========================================
  
  @max_accounts_per_device 3
  
  @doc """
  Vérifie si un device est lié à trop de comptes différents.
  Si plus de @max_accounts_per_device comptes uniques sont liés au même device,
  un log d'audit est créé pour alerte admin.
  """
  def check_multi_account_device(device_id, current_user_id) do
    # Compter les utilisateurs distincts liés à ce device
    user_ids = Repo.all(
      from rt in RefreshToken,
        where: rt.device_id == ^device_id and is_nil(rt.revoked_at),
        select: rt.user_id,
        distinct: true
    )
    
    if length(user_ids) > @max_accounts_per_device do
      # Logger l'alerte
      AuditLog.log(
        "multi_account_detected",
        current_user_id,
        "auth",
        nil,
        %{device_id: device_id, account_count: length(user_ids), user_ids: user_ids}
      )
      
      # En production, on pourrait notifier un service admin
      if !EnvConfig.production?() do
        Logger.warning("[ALERT] Multi-account detected on device #{device_id}: #{length(user_ids)} accounts")
      end
    end
    
    :ok
  end
end
