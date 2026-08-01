# ==================================
# WIWIGA - Schema Token Transaction
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens.TokenTransaction
# Description: Schema transactions de jetons virtuels

defmodule GameHub.Tokens.TokenTransaction do
  @moduledoc """
  Schema transaction jetons.
  
  ## Types
    - `purchase`: Achat jetons (monnaie → jetons)
    - `exchange`: Échange jetons (jetons → monnaie)
    - `bet`: Mise de jeu
    - `winnings`: Gains
    - `transfer_out`: Transfert sortant
    - `transfer_in`: Transfert entrant
    - `gift_sent`: Cadeau envoyé
    - `gift_received`: Cadeau reçu
    - `promo_credit`: Crédit promotionnel
    - `promo_debit`: Débit promotionnel
    - `commission`: Commission plateforme
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :user_id, :type, :token_amount, :balance_before, :balance_after, :monetary_value, :exchange_rate, :counterparty_id, :metadata, :game_id, :status, :inserted_at]}
  
  schema "token_transactions" do
    field :type, :string
    field :token_amount, :integer
    field :balance_before, :integer
    field :balance_after, :integer
    field :monetary_value, :integer
    field :exchange_rate, :float
    field :idempotency_key, :string
    field :metadata, :map
    field :game_id, :string
    field :status, :string, default: "completed"
    field :promo_id, :integer
    
    belongs_to :user, User
    belongs_to :counterparty, User
    
    timestamps()
  end
  
  @valid_types ~w(purchase exchange bet winnings transfer_out transfer_in gift_sent gift_received promo_credit promo_debit commission)
  
  @doc """
  Changeset pour création transaction.
  """
  def create_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :user_id, :type, :token_amount, :balance_before, :balance_after,
      :monetary_value, :exchange_rate, :idempotency_key, :metadata,
      :game_id, :status, :counterparty_id, :promo_id
    ])
    |> validate_required([:user_id, :type, :token_amount, :balance_before, :balance_after, :idempotency_key])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, ~w(pending completed failed cancelled))
    |> unique_constraint(:idempotency_key)
  end
end
