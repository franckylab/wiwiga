# ==================================
# WIWIGA - Schema Refresh Token
# ==================================
# Module: GameHub.Auth.RefreshToken
# Description: Schema pour les refresh tokens avec rotation

defmodule GameHub.Auth.RefreshToken do
  @moduledoc """
  Schema des refresh tokens.
  
  Chaque refresh token est stocké en base avec un hash SHA256.
  Supporte la rotation (replaced_by_id) et la révocation (revoked_at).
  
  ## Sécurité
  - Seul le hash du token est stocké (jamais le token en clair)
  - Usage unique: chaque utilisation crée un nouveau token et invalide l'ancien
  - Révocation en cascade: quand un token est remplacé, l'ancien est marqué révoqué
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  
  schema "refresh_tokens" do
    field :token_hash, :string
    field :device_id, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :replaced_by_id, :integer
    field :ip_address, :string
    field :user_agent, :string
    
    belongs_to :user, User
    
    timestamps()
  end
  
  @doc """
  Changeset pour création d'un refresh token.
  """
  def creation_changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [:user_id, :token_hash, :device_id, :expires_at, :ip_address, :user_agent])
    |> validate_required([:user_id, :token_hash, :expires_at])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:token_hash)
  end
  
  @doc """
  Changeset pour révoquer un token.
  """
  def revocation_changeset(refresh_token) do
    refresh_token
    |> change(%{revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end
  
  @doc """
  Changeset pour marquer un token comme remplacé.
  """
  def replacement_changeset(refresh_token, new_token_id) do
    refresh_token
    |> change(%{
      replaced_by_id: new_token_id,
      revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end
  
  @doc """
  Vérifie si un token est actif (non révoqué et non expiré).
  """
  def active?(%__MODULE__{} = token) do
    is_nil(token.revoked_at) && DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt
  end
end
