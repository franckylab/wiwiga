# ==================================
# WIWIGA - Schema Token Transaction
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens.TokenTransaction
# Description: Schema transactions de jetons virtuels

defmodule GameHub.Tokens.TokenTransaction do
  @moduledoc """
  Schema transaction jetons.

  ## Types — seuls achat, cadeau ami, jeu et promos
    - `purchase`: Achat jetons (monnaie → jetons)
    - `bet`: Mise de jeu
    - `winnings`: Gains
    - `gift_sent`: Cadeau envoyé (ami uniquement)
    - `gift_received`: Cadeau reçu
    - `promo_credit`: Crédit promotionnel
    - `promo_debit`: Débit promotionnel
    - `commission`: Commission plateforme

  Anciens types `exchange`, `transfer_out`, `transfer_in` supprimés et conservés
  uniquement en historique lecture seule.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  
  schema "token_transactions" do
    field :type, :string
    field :token_amount, :integer
    field :wiga_amount, :integer, virtual: true
    field :balance_before, :integer
    field :balance_after, :integer
    field :wiga_balance_before, :integer, virtual: true
    field :wiga_balance_after, :integer, virtual: true
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
  
  @valid_types ~w(purchase bet winnings gift_sent gift_received promo_credit promo_debit commission)
  
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

  @doc "Alias wiga (1 wiga = 1 jeton)"
  def with_wiga(%__MODULE__{} = tx) do
    %{tx | wiga_amount: tx.token_amount, wiga_balance_before: tx.balance_before, wiga_balance_after: tx.balance_after}
  end
  def with_wiga(txs) when is_list(txs), do: Enum.map(txs, &with_wiga/1)
  def with_wiga(other), do: other
end

defimpl Jason.Encoder, for: GameHub.Tokens.TokenTransaction do
  def encode(tx, opts) do
    map = %{
      id: tx.id,
      user_id: tx.user_id,
      type: tx.type,
      token_amount: tx.token_amount,
      wiga_amount: tx.token_amount,
      balance_before: tx.balance_before,
      balance_after: tx.balance_after,
      wiga_balance_before: tx.balance_before,
      wiga_balance_after: tx.balance_after,
      monetary_value: tx.monetary_value,
      exchange_rate: tx.exchange_rate,
      counterparty_id: tx.counterparty_id,
      metadata: tx.metadata,
      game_id: tx.game_id,
      status: tx.status,
      inserted_at: tx.inserted_at
    }
    Jason.Encode.map(map, opts)
  end
end
