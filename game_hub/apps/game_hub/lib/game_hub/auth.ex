defmodule GameHub.Auth do
  @moduledoc """
  Module d'authentification par OTP + JWT.
  """
  
  alias GameHub.{Repo, Redis, Guardian}
  alias GameHub.Users.User
  import Ecto.Query
  
  @otp_validity_seconds 300  # 5 minutes
  @otp_length 6
  
  @doc """
  Génère et envoie un code OTP.
  """
  def send_otp(phone) do
    otp = generate_otp()
    
    # Stocker OTP dans Redis
    store_otp(phone, otp)
    
    # TODO: Envoyer via SMS (Twilio, Campay, etc.)
    # Pour le dev, on affiche dans les logs
    IO.puts("OTP pour #{phone}: #{otp}")
    
    {:ok, otp}
  end
  
  @doc """
  Vérifie le code OTP et retourne un JWT token.
  """
  def verify_otp(phone, otp) do
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
            # OTP valide, supprimer et créer/récupérer user
            delete_otp(phone)
            
            case get_or_create_user(phone) do
              {:ok, user} ->
                # Générer JWT token
                case Guardian.encode_and_sign(user) do
                  {:ok, token, _claims} -> {:ok, token, user}
                  {:error, reason} -> {:error, reason}
                end
              
              {:error, reason} ->
                {:error, reason}
            end
        end
    end
  end
  
  @doc """
  Vérifie et décode un token JWT.
  """
  def verify_jwt_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} -> {:ok, %{user_id: user.id, user: user}}
          {:error, reason} -> {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Refresh un token JWT.
  """
  def refresh_jwt_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, _claims} ->
        case Guardian.resource_from_claims(%{"sub" => _claims["sub"]}) do
          {:ok, user} ->
            case Guardian.encode_and_sign(user) do
              {:ok, new_token, _claims} -> {:ok, new_token, user}
              {:error, reason} -> {:error, reason}
            end
          {:error, reason} -> {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Fonctions privées
  
  defp generate_otp do
    100_000..999_999
    |> Enum.random()
    |> to_string()
  end
  
  defp store_otp(phone, otp) do
    expires_at = DateTime.utc_now() |> DateTime.add(@otp_validity_seconds, :second)
    otp_data = %{
      code: otp,
      expires_at: expires_at |> DateTime.to_iso8601()
    }
    
    # Stocker dans Redis avec expiration
    key = "otp:#{phone}"
    json_data = Jason.encode!(otp_data)
    
    result = Redix.command(GameHub.Redis, ["SET", key, json_data, "EX", to_string(@otp_validity_seconds)])
    IO.puts("[Redis] store_otp #{key}: #{inspect(result)}")
    
    case result do
      {:ok, _} -> otp_data
      {:error, error} -> 
        IO.puts("[Redis] Error: #{inspect(error)}")
        otp_data
    end
  end
  
  defp get_stored_otp(phone) do
    key = "otp:#{phone}"
    
    result = Redix.command(GameHub.Redis, ["GET", key])
    IO.puts("[Redis] get_otp #{key}: #{inspect(result)}")
    
    case result do
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
  
  defp get_or_create_user(phone) do
    case Repo.get_by(User, phone: phone) do
      nil ->
        # Créer nouvel utilisateur
        user = %User{
          phone: phone,
          is_active: true
        }
        
        case Repo.insert(user) do
          {:ok, user} -> {:ok, user}
          {:error, changeset} -> {:error, changeset}
        end
      
      user ->
        {:ok, user}
    end
  end
end
