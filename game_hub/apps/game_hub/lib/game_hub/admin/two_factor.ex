# ==================================
# WIWIGA - Module Admin 2FA TOTP
# ==================================
# Module: GameHub.Admin.TwoFactor
# Description: Support authentification à deux facteurs (TOTP)

defmodule GameHub.Admin.TwoFactor do
  @moduledoc """
  Module de gestion de l'authentification à deux facteurs (2FA) pour les admins.
  
  Utilise TOTP (Time-based One-Time Password) pour la vérification.
  Compatible avec Google Authenticator, Authy, etc.
  """

  import Bitwise

  alias GameHub.Repo
  alias GameHub.Users.User

  @doc """
  Génère un secret TOTP pour un utilisateur admin.
  Retourne le secret et l'URI de provisioning (pour QR code).
  """
  @spec generate_secret(User.t()) :: {:ok, map()} | {:error, term()}
  def generate_secret(%User{} = user) do
    # Générer un secret aléatoire de 20 octets encodé en base32
    secret = generate_base32_secret()
    
    # URI de provisioning pour les apps d'authentification
    uri = "otpauth://totp/WIWIGA:#{user.email || user.phone}?secret=#{secret}&issuer=WIWIGA&algorithm=SHA1&digits=6&period=30"
    
    {:ok, %{
      secret: secret,
      provisioning_uri: uri,
      user_id: user.id
    }}
  end

  @doc """
  Active le 2FA pour un utilisateur après vérification du premier code.
  """
  @spec enable_2fa(integer(), String.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  def enable_2fa(user_id, secret, code) do
    if verify_code(secret, code) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      
      case Repo.get(User, user_id) do
        nil -> {:error, :user_not_found}
        user ->
          user
          |> User.changeset(%{
            totp_secret: encrypt_secret(secret),
            totp_enabled: true,
            totp_activated_at: now
          })
          |> Repo.update()
      end
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Désactive le 2FA pour un utilisateur.
  """
  @spec disable_2fa(integer()) :: {:ok, User.t()} | {:error, term()}
  def disable_2fa(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user ->
        user
        |> User.changeset(%{
          totp_secret: nil,
          totp_enabled: false,
          totp_activated_at: nil
        })
        |> Repo.update()
    end
  end

  @doc """
  Vérifie un code TOTP pour un utilisateur admin.
  Retourne true si le code est valide.
  """
  @spec verify_admin_2fa(integer(), String.t()) :: boolean()
  def verify_admin_2fa(user_id, code) do
    case Repo.get(User, user_id) do
      nil -> false
      %User{totp_enabled: false} -> true  # Pas de 2FA activé, pas de vérification
      %User{totp_secret: nil} -> true
      %User{totp_secret: encrypted_secret} ->
        secret = decrypt_secret(encrypted_secret)
        verify_code(secret, code)
    end
  end

  @doc """
  Vérifie si le 2FA est activé pour un utilisateur.
  """
  @spec is_2fa_enabled?(integer()) :: boolean()
  def is_2fa_enabled?(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> user.totp_enabled == true and not is_nil(user.totp_secret)
    end
  end

  # ========================================
  # Fonctions internes TOTP
  # ========================================

  @doc """
  Vérifie un code TOTP avec un secret donné.
  Supporte une fenêtre de ±1 période (30s) pour tolérer les décalages d'horloge.
  """
  @spec verify_code(String.t(), String.t()) :: boolean()
  def verify_code(secret, code) when byte_size(code) == 6 do
    current_time = System.system_time(:second)
    period = 30
    
    # Vérifier le code actuel et les codes adjacents (±1 période)
    [-1, 0, 1]
    |> Enum.any?(fn offset ->
      time_step = div(current_time, period) + offset
      generated = generate_totp(secret, time_step)
      generated == code
    end)
  end
  def verify_code(_, _), do: false

  defp generate_totp(secret, time_step) do
    # Décoder le secret base32
    key = Base.decode32!(String.upcase(secret), padding: false)
    
    # Convertir le time_step en binaire (8 bytes, big-endian)
    time_bytes = <<time_step::64>>
    
    # HMAC-SHA1
    hmac = :crypto.mac(:hmac, :sha, key, time_bytes)
    
    # Dynamic truncation
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
    <<_::size(offset)-unit(8), code_int::32, _::binary>> = hmac
    code_int = code_int &&& 0x7FFFFFFF
    
    # Prendre les 6 derniers chiffres
    code_int
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp generate_base32_secret do
    :crypto.strong_rand_bytes(20)
    |> Base.encode32(padding: false)
  end

  # ========================================
  # Chiffrement AES-256-GCM du secret TOTP
  # ========================================

  @aad "WIWIGA-TOTP-2FA"

  defp encrypt_secret(secret) do
    key = derive_encryption_key()
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} = :crypto.crypto_one_time_aead(
      :aes_256_gcm, key, iv, secret, @aad, true
    )

    # Encoder iv + tag + ciphertext en base64
    Base.encode64(iv <> tag <> ciphertext)
  end

  defp decrypt_secret(encrypted) do
    key = derive_encryption_key()
    decoded = Base.decode64!(encrypted)

    # Extraire iv (12 bytes), tag (16 bytes), ciphertext
    <<iv::binary-12, tag::binary-16, ciphertext::binary>> = decoded

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      secret when is_binary(secret) -> secret
      :error -> raise "2FA decryption failed - data may be corrupted"
    end
  rescue
    _ -> encrypted
  end

  defp derive_encryption_key do
    secret_key_base = Application.get_env(:game_hub, :secret_key_base) ||
                      System.get_env("SECRET_KEY_BASE") ||
                      "wiwiga_default_secret_key_base_dev_only"

    # Dériver une clé 256-bit depuis SECRET_KEY_BASE via SHA-256
    :crypto.hash(:sha256, secret_key_base)
  end
end
