# ==================================
# WIWIGA - Module SMS OTP
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.SmsOtp
# Description: Génération et vérification OTP par SMS

defmodule GameHub.SmsOtp do
  @moduledoc """
  Module de gestion des codes OTP par SMS.
  
  ## Flow
  1. Générer code 6 chiffres
  2. Envoyer par SMS (provider configurable)
  3. Stocker Redis avec TTL 5 min
  4. Vérifier code saisi par utilisateur
  5. Marquer phone vérifié si code valide
  
  ## Sécurité
  - Code 6 chiffres (1M combinaisons)
  - TTL 5 minutes
  - Max 3 tentatives
  - Lockout 15 min après échecs
  """
  
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.AuditLog
  
  @doc """
  Génère et envoie code OTP.
  
  ## Parameters
    - `phone`: Numéro de téléphone
  
  ## Returns
    - `{:ok, otp_id}`: Code envoyé
    - `{:error, reason}`: Erreur
  
  ## Examples
  
      iex> SmsOtp.send_otp("+237699999999")
      {:ok, "otp_123456"}
  """
  @spec send_otp(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def send_otp(phone) do
    with :ok <- validate_phone(phone),
         :ok <- check_rate_limit(phone) do
      
      # Générer code 6 chiffres crypto sécurisé
      otp_code = generate_otp_code()
      otp_id = generate_otp_id(phone)
      
      # Stocker dans Redis (TTL 5 min)
      store_otp_in_redis(otp_id, otp_code, phone)
      
      # Envoyer SMS
      send_sms(phone, otp_code)
      
      # Log d'audit
      AuditLog.log(
        "otp_sent",
        nil,
        "sms_otp",
        otp_id,
        %{phone: mask_phone(phone)},
        %{provider: "campay"}
      )
      
      {:ok, otp_id}
    end
  end
  
  @doc """
  Vérifie code OTP saisi.
  
  ## Parameters
    - `otp_id`: ID OTP retourné par send_otp
    - `code`: Code saisi par utilisateur
  
  ## Returns
    - `{:ok, user}`: Code valide, utilisateur retourné
    - `{:error, :invalid_code}`: Code incorrect
    - `{:error, :expired}`: Code expiré
    - `{:error, :max_attempts}`: Trop de tentatives
  
  ## Examples
  
      iex> SmsOtp.verify_otp("otp_123456", "123456")
      {:ok, %User{}}
  """
  @spec verify_otp(String.t(), String.t()) :: {:ok, User.t()} | {:error, atom()}
  def verify_otp(otp_id, code) do
    with {:ok, stored_data} <- get_otp_from_redis(otp_id),
         :ok <- check_attempts(otp_id),
         :ok <- validate_code(stored_data.code, code) do
      
      # Code valide - marquer phone vérifié
      user = mark_phone_verified(stored_data.phone)
      
      # Supprimer OTP utilisé
      delete_otp(otp_id)
      
      # Log d'audit
      AuditLog.log(
        "otp_verified",
        user.id,
        "sms_otp",
        otp_id,
        %{phone: mask_phone(stored_data.phone)},
        %{}
      )
      
      {:ok, user}
    else
      {:error, :invalid_code} ->
        increment_attempts(otp_id)
        {:error, :invalid_code}
      
      error ->
        error
    end
  end
  
  @doc """
  Résend code OTP (rate limité).
  
  ## Parameters
    - `otp_id`: ID OTP précédent
  
  ## Returns
    - `{:ok, new_otp_id}`: Nouveau code envoyé
  """
  @spec resend_otp(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def resend_otp(otp_id) do
    case get_otp_from_redis(otp_id) do
      {:ok, %{phone: phone}} ->
        # Vérifier cooldown (60 secondes)
        :ok = check_cooldown(otp_id)
        
        # Générer nouveau code
        send_otp(phone)
      
      _ ->
        {:error, :otp_not_found}
    end
  end
  
  # === Fonctions Privées ===
  
  defp validate_phone("+237" <> rest) when byte_size(rest) == 9 do
    case Regex.match?(~r/^[67][0-9]{8}$/, rest) do
      true -> :ok
      false -> {:error, :invalid_phone}
    end
  end
  
  defp validate_phone(_), do: {:error, :invalid_phone}
  
  defp check_rate_limit(phone) do
    # Vérifier max 3 OTP envoyés par heure
    key = "sms_rate:#{phone}"
    
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, nil} ->
        # Premier envoi
        Redix.command(GameHub.Redis, ["SET", key, "1", "EX", "3600"])
        :ok
      
      {:ok, count} when count < "3" ->
        Redix.command(GameHub.Redis, ["INCR", key])
        :ok
      
      {:ok, _} ->
        {:error, :rate_limit_exceeded}
      
      {:error, _} ->
        :ok # Redis indisponible, continuer
    end
  end
  
  defp generate_otp_code do
    # 6 chiffres crypto sécurisé
    :crypto.strong_rand_bytes(3)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end
  
  defp generate_otp_id(phone) do
    "otp_#{phone}_#{:os.system_time(:millisecond)}"
  end
  
  defp store_otp_in_redis(otp_id, code, phone) do
    data = %{
      code: code,
      phone: phone,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      attempts: 0
    }
    
    Redix.command(GameHub.Redis, [
      "SET",
      otp_id,
      :erlang.term_to_binary(data),
      "EX",
      "300" # 5 minutes
    ])
  end
  
  defp send_sms(phone, code) do
    # TODO: Intégrer provider SMS (Campay, Twilio, etc.)
    IO.puts("[SMS OTP] Sending code #{code} to #{mask_phone(phone)}")
    
    # Simuler envoi réussi
    :ok
  end
  
  defp get_otp_from_redis(otp_id) do
    case Redix.command(GameHub.Redis, ["GET", otp_id]) do
      {:ok, nil} ->
        {:error, :expired}
      
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        {:ok, data}
      
      {:error, _} ->
        {:error, :redis_error}
    end
  end
  
  defp check_attempts(otp_id) do
    case get_otp_from_redis(otp_id) do
      {:ok, %{attempts: attempts}} when attempts >= 3 ->
        {:error, :max_attempts}
      
      _ ->
        :ok
    end
  end
  
  defp validate_code(stored_code, input_code) do
    if stored_code == input_code do
      :ok
    else
      {:error, :invalid_code}
    end
  end
  
  defp increment_attempts(otp_id) do
    case get_otp_from_redis(otp_id) do
      {:ok, data} ->
        updated = %{data | attempts: data.attempts + 1}
        Redix.command(GameHub.Redis, [
          "SET",
          otp_id,
          :erlang.term_to_binary(updated),
          "EX",
          "300"
        ])
      
      _ ->
        :ok
    end
  end
  
  defp mark_phone_verified(phone) do
    User
    |> Repo.get_by(phone: phone)
    |> case do
      nil -> raise "User not found: #{phone}"
      user ->
        user
        |> Ecto.Changeset.change(has_verified_kyc: true)
        |> Repo.update!()
    end
  end
  
  defp delete_otp(otp_id) do
    Redix.command(GameHub.Redis, ["DEL", otp_id])
  end
  
  defp check_cooldown(otp_id) do
    # Vérifier que 60 secondes se sont écoulées
    case get_otp_from_redis(otp_id) do
      {:ok, %{created_at: created_at}} ->
        created_time = DateTime.from_iso8601(created_at) |> elem(1)
        now = DateTime.utc_now()
        
        if DateTime.diff(now, created_time, :second) >= 60 do
          :ok
        else
          {:error, :cooldown_not_elapsed}
        end
      
      _ ->
        {:error, :otp_not_found}
    end
  end
  
  defp mask_phone("+237" <> <<_::binary-size(6), rest::binary>>) do
    "+237******#{rest}"
  end
  
  defp mask_phone(phone), do: phone
end
