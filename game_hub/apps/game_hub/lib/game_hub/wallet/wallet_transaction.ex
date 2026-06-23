# ==================================
# WIWIGA - Schema Transaction Portefeuille
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Wallet.WalletTransaction
# Description: Schema transactions financières avec idempotence

defmodule GameHub.Wallet.WalletTransaction do
  @moduledoc """
  Schema transaction portefeuille.
  
  ## Types
    - `deposit`: Dépôt
    - `withdrawal`: Retrait
    - `bet`: Pari
    - `winnings`: Gains
    - `commission`: Commission
    - `refund`: Remboursement
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :user_id, :type, :amount, :balance_before, :balance_after, :idempotency_key, :metadata]}
  
  schema "wallet_transactions" do
    field :type, :string
    field :amount, :integer
    field :balance_before, :integer
    field :balance_after, :integer
    field :idempotency_key, :string
    field :metadata, :map
    field :game_id, :string
    field :payment_provider, :string
    field :provider_transaction_id, :string
    
    belongs_to :user, User
    
    timestamps()
  end
  
  @doc """
  Changeset pour création transaction.
  """
  def create_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:user_id, :type, :amount, :balance_before, :balance_after, :idempotency_key, :metadata, :game_id, :payment_provider, :provider_transaction_id])
    |> validate_required([:user_id, :type, :amount, :balance_before, :balance_after, :idempotency_key])
    |> validate_inclusion(:type, ~w(deposit withdrawal bet winnings commission refund))
    |> validate_number(:amount, not_equal: 0)
    |> validate_format(:idempotency_key, ~r/^.+$/, message: "ne peut pas être vide")
    |> unique_constraint(:idempotency_key)
    |> foreign_key_constraint(:user_id)
  end
  
  @doc """
  Calcule le nouveau balance après transaction.
  """
  def calculate_new_balance(balance_before, amount) do
    balance_before + amount
  end
  
  @doc """
  Vérifie si transaction est un crédit.
  """
  def credit?(%{amount: amount}) when amount > 0, do: true
  def credit?(_), do: false
  
  @doc """
  Vérifie si transaction est un débit.
  """
  def debit?(%{amount: amount}) when amount < 0, do: true
  def debit?(_), do: false
end
