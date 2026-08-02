defmodule GameHub.Guardian do
  @moduledoc """
  Module Guardian pour la gestion des tokens JWT.
  
  Supporte deux types de tokens :
  - `"access"` : Access token, durée 30 minutes, utilisé pour les requêtes API
  - `"refresh"` : Refresh token, durée 30 jours, utilisé pour le renouvellement
  
  ## Configuration
  ```
  config :game_hub, GameHub.Guardian,
    issuer: "wiwiga",
    secret_key: "...",
    access_token_ttl_minutes: 30,
    refresh_token_ttl_days: 30
  ```
  """
  
  use Guardian, otp_app: :game_hub
  
  alias GameHub.Users.User
  alias GameHub.Repo
  
  @access_token_ttl_minutes 30
  @refresh_token_ttl_days 30
  
  @doc """
  Construit les claims pour le token JWT.
  """
  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end
  
  @doc """
  Récupère l'utilisateur depuis le token.
  """
  def resource_from_claims(%{"sub" => user_id}) do
    case Repo.get(User, user_id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
  
  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
  
  @doc """
  Ajoute des claims personnalisées au token.
  
  Définit le type de token (access/refresh) et le TTL.
  """
  def build_claims(claims, _resource, opts) do
    token_type = Keyword.get(opts, :token_type, "access")
    
    ttl_seconds = case token_type do
      "refresh" -> @refresh_token_ttl_days * 24 * 60 * 60
      _access -> @access_token_ttl_minutes * 60
    end
    
    claims =
      claims
      |> Map.put("typ", token_type)
      |> Map.put("iat", System.system_time(:second))
      |> Map.put("exp", System.system_time(:second) + ttl_seconds)
    
    {:ok, claims}
  end
  
  @doc """
  Génère un access token pour un utilisateur.
  """
  def encode_access_token(user) do
    encode_and_sign(user, %{}, token_type: "access")
  end
  
  @doc """
  Génère un refresh token pour un utilisateur.
  """
  def encode_refresh_token(user) do
    encode_and_sign(user, %{}, token_type: "refresh")
  end
  
  @doc """
  Vérifie qu'un token est du type attendu.
  """
  def verify_token_type(token, expected_type) do
    case decode_and_verify(token) do
      {:ok, %{"typ" => ^expected_type} = claims} ->
        {:ok, claims}
      
      {:ok, %{"typ" => actual_type}} ->
        {:error, {:invalid_token_type, actual_type, expected_type}}
      
      {:ok, claims} when expected_type == "access" ->
        # Rétrocompatibilité: tokens sans "typ" sont traités comme access
        {:ok, claims}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  TTL access token en secondes.
  """
  def access_token_ttl_seconds, do: @access_token_ttl_minutes * 60
  
  @doc """
  TTL refresh token en secondes.
  """
  def refresh_token_ttl_seconds, do: @refresh_token_ttl_days * 24 * 60 * 60
  
  @doc """
  TTL refresh token en jours.
  """
  def refresh_token_ttl_days, do: @refresh_token_ttl_days
end
