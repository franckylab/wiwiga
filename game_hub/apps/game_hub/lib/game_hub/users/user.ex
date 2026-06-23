# ==================================
# WIWIGA - Schema Utilisateur
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Users.User
# Description: Schema Ecto utilisateur avec portefeuille

defmodule GameHub.Users.User do
  @moduledoc """
  Schema utilisateur.
  
  ## Fields
    - `phone`: Numéro téléphone (unique)
    - `balance`: Solde en centimes (bigint >= 0)
    - `is_active`: Compte actif
    - `has_verified_kyc`: KYC complété
    - `self_excluded`: Auto-exclusion jeu
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Wallet.WalletTransaction
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :phone, :name, :balance, :is_active, :has_verified_kyc, :self_excluded]}
  
  schema "users" do
    field :phone, :string
    field :name, :string
    field :balance, :integer, default: 0
    field :is_active, :boolean, default: true
    field :has_verified_kyc, :boolean, default: false
    field :self_excluded, :boolean, default: false
    field :daily_deposit_limit, :integer, default: 1_000_000
    field :daily_loss_limit, :integer, default: 500_000
    
    has_many :transactions, WalletTransaction
    
    timestamps()
  end
  
  @doc """
  Changeset pour création utilisateur.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone, :name])
    |> validate_required([:phone])
    |> validate_format(:phone, ~r/^\+237\d{8}$/, message: "doit commencer par +237 suivi de 8 chiffres")
    |> unique_constraint(:phone)
  end
  
  @doc """
  Changeset pour update profil.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :daily_deposit_limit, :daily_loss_limit])
    |> validate_number(:daily_deposit_limit, greater_than: 0)
    |> validate_number(:daily_loss_limit, greater_than: 0)
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
  Vérifie si utilisateur peut jouer.
  """
  def can_play?(%{is_active: true, self_excluded: false, has_verified_kyc: true}), do: true
  def can_play?(_), do: false
end
