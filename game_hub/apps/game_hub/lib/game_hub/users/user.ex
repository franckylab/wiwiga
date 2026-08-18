# ==================================
# WIWIGA - Schema Utilisateur
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Users.User
# Description: Schema Ecto utilisateur avec compte
#              Auth multi-méthodes (phone/email) + RBAC + avatars

defmodule GameHub.Users.User do
  @moduledoc """
  Schema utilisateur.
  
  ## Fields
    - `phone`: Numéro téléphone (unique, optionnel si email)
    - `email`: Email (unique, optionnel si phone)
    - `username`: Pseudonyme (unique, requis)
    - `role`: Rôle RBAC (super_admin, admin, moderator, test, user)
    - `avatar_type`: Type d'avatar (default, wiwiga_1..8)
    - `avatar_url`: URL avatar custom (futur)
    - `balance`: Solde en centimes (bigint >= 0)
    - `is_active`: Compte actif
    - `has_verified_kyc`: KYC complété
    - `self_excluded`: Auto-exclusion jeu
    - `last_login_at`: Dernière connexion
    - `login_count`: Nombre de connexions
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Wallet.WalletTransaction
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :phone, :email, :username, :name, :role, :avatar_type, :avatar_url, :balance, :token_balance, :is_active, :has_verified_kyc, :self_excluded, :last_login_at, :login_count, :otp_required_on_login, :preferences]}
  
  # Rôles RBAC
  @roles ~w(super_admin admin moderator test user)
  @default_role "user"
  
  # Types d'avatar
  @avatar_types ~w(default wiwiga_1 wiwiga_2 wiwiga_3 wiwiga_4 wiwiga_5 wiwiga_6 wiwiga_7 wiwiga_8)
  @default_avatar "default"
  
  # Validation mot de passe
  @password_min_length 8
  
  schema "users" do
    # Auth multi-méthodes
    field :phone, :string
    field :email, :string
    field :username, :string, default: ""
    field :password_hash, :string
    field :password, :string, virtual: true
    
    # Rôles et profil
    field :role, :string, default: @default_role
    field :name, :string
    field :avatar_type, :string, default: @default_avatar
    field :avatar_url, :string
    
    # Monétaire
    field :balance, :integer, default: 0
    field :token_balance, :integer, default: 0
    
    # Statut
    field :is_active, :boolean, default: true
    field :has_verified_kyc, :boolean, default: false
    field :self_excluded, :boolean, default: false
    
    # Limites responsible gaming
    field :daily_deposit_limit, :integer, default: 1_000_000
    field :daily_loss_limit, :integer, default: 500_000
    
    # Tracking connexion
    field :last_login_at, :utc_datetime
    field :login_count, :integer, default: 0
    
    # Préférences OTP
    field :otp_required_on_login, :boolean, default: false
    
    # 2FA TOTP (admin)
    field :totp_secret, :string
    field :totp_enabled, :boolean, default: false
    field :totp_activated_at, :utc_datetime
    
    # Préférences utilisateur (JSONB: son, vibration, langue, thème, etc.)
    field :preferences, :map, default: %{}
    
    # Associations
    has_many :transactions, WalletTransaction
    
    timestamps()
  end
  
  # ========================================
  # Accessors
  # ========================================
  
  def roles, do: @roles
  def default_role, do: @default_role
  def avatar_types, do: @avatar_types
  def default_avatar, do: @default_avatar
  
  def is_admin?(%__MODULE__{role: role}), do: role in ["super_admin", "admin"]
  def is_super_admin?(%__MODULE__{role: "super_admin"}), do: true
  def is_super_admin?(_), do: false
  def is_moderator?(%__MODULE__{role: role}), do: role in ["super_admin", "admin", "moderator"]
  
  @doc """
  Changeset standard pour création/mise à jour complète.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :phone, :email, :username, :name, :role, :avatar_type, :avatar_url,
      :balance, :is_active, :has_verified_kyc, :self_excluded,
      :daily_deposit_limit, :daily_loss_limit, :last_login_at, :login_count,
      :totp_secret, :totp_enabled, :totp_activated_at
    ])
    |> validate_phone_or_email()
    |> validate_username()
    |> validate_role()
    |> validate_avatar()
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> validate_number(:daily_deposit_limit, greater_than: 0)
    |> validate_number(:daily_loss_limit, greater_than: 0)
    |> unique_constraint(:phone)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour inscription (auth multi-méthodes).
  Requiert: phone OU email + username
  Optionnel: avatar_type
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone, :email, :username, :name, :avatar_type])
    |> validate_phone_or_email()
    |> validate_username()
    |> validate_avatar()
    |> maybe_generate_username()
    |> unique_constraint(:phone)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour inscription admin (par super_admin).
  Inclut le rôle.
  """
  def admin_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone, :email, :username, :name, :role, :avatar_type])
    |> validate_phone_or_email()
    |> validate_username()
    |> validate_role()
    |> validate_avatar()
    |> maybe_generate_username()
    |> unique_constraint(:phone)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour update profil.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :username, :avatar_type, :daily_deposit_limit, :daily_loss_limit])
    |> validate_username()
    |> validate_avatar()
    |> validate_number(:daily_deposit_limit, greater_than: 0)
    |> validate_number(:daily_loss_limit, greater_than: 0)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour changement de rôle (admin uniquement).
  """
  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_role()
  end
  
  @doc """
  Changeset pour auto-exclusion.
  """
  def self_exclusion_changeset(user, attrs) do
    user
    |> cast(attrs, [:self_excluded])
    |> validate_required([:self_excluded])
  end
  
  @doc """
  Changeset pour tracking de connexion.
  """
  def login_tracking_changeset(user) do
    user
    |> change(%{
      last_login_at: DateTime.utc_now() |> DateTime.truncate(:second),
      login_count: (user.login_count || 0) + 1
    })
  end
  
  @doc """
  Changeset pour mise à jour des préférences OTP.
  """
  def otp_settings_changeset(user, attrs) do
    user
    |> cast(attrs, [:otp_required_on_login])
    |> validate_required([:otp_required_on_login])
  end
  
  @doc """
  Changeset pour mise à jour du profil utilisateur.
  Permet: username, name, avatar_type, avatar_url
  """
  def profile_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :name, :avatar_type, :avatar_url])
    |> validate_username()
    |> validate_avatar()
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour mise à jour des préférences utilisateur (JSONB).
  """
  def preferences_changeset(user, attrs) do
    user
    |> cast(attrs, [:preferences])
  end
  
  @doc """
  Changeset pour définition de mot de passe.
  Hash le mot de passe avec Pbkdf2 avant stockage.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: @password_min_length)
    |> hash_password()
  end
  
  @doc """
  Changeset pour inscription avec mot de passe optionnel.
  Si un mot de passe est fourni, il est hashé.
  """
  def registration_with_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone, :email, :username, :name, :avatar_type, :password])
    |> validate_phone_or_email()
    |> validate_username()
    |> validate_avatar()
    |> maybe_generate_username()
    |> maybe_hash_password()
    |> unique_constraint(:phone)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Changeset pour inscription admin avec mot de passe.
  """
  def admin_registration_with_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone, :email, :username, :name, :role, :avatar_type, :password])
    |> validate_phone_or_email()
    |> validate_username()
    |> validate_role()
    |> validate_avatar()
    |> maybe_generate_username()
    |> maybe_hash_password()
    |> unique_constraint(:phone)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end
  
  @doc """
  Vérifie si le mot de passe fourni correspond au hash stocké.
  """
  def verify_password(%__MODULE__{password_hash: hash}, password) when is_binary(password) and hash != nil do
    Pbkdf2.verify_pass(password, hash)
  end
  
  def verify_password(_, _), do: false
  
  @doc """
  Hash un mot de passe avec Pbkdf2.
  """
  def hash_password_raw(password) do
    Pbkdf2.hash_pwd_salt(password)
  end
  
  # ========================================
  # Validations privées
  # ========================================
  
  defp validate_phone_or_email(changeset) do
    phone = get_change(changeset, :phone)
    email = get_change(changeset, :email)
    
    cond do
      # Création: au moins phone ou email requis
      is_nil(phone) and is_nil(email) and changeset.data.id == nil ->
        changeset
        |> add_error(:phone, "phone ou email requis")
        |> add_error(:email, "phone ou email requis")
      
      # Validation format phone
      phone != nil and phone != "" and not String.match?(phone, ~r/^\+?[0-9]{8,15}$/) ->
        add_error(changeset, :phone, "format de numéro invalide")
      
      # Validation format email
      email != nil and email != "" and not String.match?(email, ~r/^[^\s]+@[^\s]+$/) ->
        add_error(changeset, :email, "format d'email invalide")
      
      true ->
        changeset
    end
  end
  
  defp validate_username(changeset) do
    username = get_field(changeset, :username)
    
    if username && username != "" do
      changeset
      |> validate_length(:username, min: 3, max: 30)
      |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "lettres, chiffres et underscores uniquement")
    else
      changeset
    end
  end
  
  defp validate_role(changeset) do
    changeset
    |> validate_inclusion(:role, @roles)
  end
  
  defp validate_avatar(changeset) do
    changeset
    |> validate_inclusion(:avatar_type, @avatar_types)
  end
  
  defp maybe_generate_username(changeset) do
    username = get_field(changeset, :username)
    
    if username == nil or username == "" do
      # Générer un pseudonyme unique basé sur le timestamp
      generated = "player_" <> (:erlang.unique_integer([:positive]) |> Integer.to_string(36) |> String.downcase())
      put_change(changeset, :username, generated)
    else
      changeset
    end
  end
  
  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset
      
      password ->
        hashed = Pbkdf2.hash_pwd_salt(password)
        put_change(changeset, :password_hash, hashed)
    end
  end
  
  defp maybe_hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset
      
      "" ->
        changeset
      
      password ->
        hashed = Pbkdf2.hash_pwd_salt(password)
        put_change(changeset, :password_hash, hashed)
    end
  end
  
  @doc """
  Vérifie si utilisateur peut jouer.
  """
  def can_play?(%{is_active: true, self_excluded: false, has_verified_kyc: true}), do: true
  def can_play?(_), do: false
end
