# ==================================
# WIWIGA - Schema Promo Token
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens.PromoToken
# Description: Offres de jetons promotionnels avec conditions

defmodule GameHub.Tokens.PromoToken do
  @moduledoc """
  Gestion des offres promotionnelles de jetons.
  
  ## Conditions d'utilisation
  Les conditions sont stockées en JSON:
  - `min_games`: Nombre minimum de parties à jouer
  - `game_type`: Restriction sur type de jeu
  - `expiry_days`: Jours avant expiration
  - `min_bet`: Mise minimum requise
  - `wagering_multiplier`: Multiplicateur de mise (rollover)
  
  ## Exemple
      %{
        "min_games" => 5,
        "game_type" => "dice",
        "expiry_days" => 30,
        "wagering_multiplier" => 3
      }
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @derive {Jason.Encoder, except: [:__meta__]}
  
  schema "promo_tokens" do
    field :name, :string
    field :description, :string
    field :token_amount, :integer
    field :conditions, :map, default: %{}
    field :is_active, :boolean, default: true
    field :max_redemptions, :integer
    field :current_redemptions, :integer, default: 0
    field :valid_from, :utc_datetime
    field :valid_until, :utc_datetime
    
    belongs_to :created_by, User
    
    timestamps()
  end
  
  @doc """
  Liste les promos actives et valides.
  """
  def list_active_promos do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    query = from p in __MODULE__,
      where: p.is_active == true and
             p.valid_from <= ^now and
             (is_nil(p.valid_until) or p.valid_until >= ^now),
      where: is_nil(p.max_redemptions) or p.current_redemptions < p.max_redemptions,
      order_by: [desc: p.inserted_at]
    
    Repo.all(query)
  end
  
  @doc """
  Crée une nouvelle offre promo.
  """
  def create_promo(attrs) do
    %__MODULE__{}
    |> create_changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Met à jour une offre promo.
  """
  def update_promo(%__MODULE__{} = promo, attrs) do
    promo
    |> update_changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Incrémente le compteur de réclamations.
  """
  def increment_redemptions(promo_id) do
    from(p in __MODULE__, where: p.id == ^promo_id)
    |> Repo.update_all(inc: [current_redemptions: 1])
  end
  
  @doc """
  Vérifie si une promo est toujours réclamable.
  """
  def redeemable?(promo) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    promo.is_active and
    DateTime.compare(promo.valid_from, now) in [:lt, :eq] and
    (is_nil(promo.valid_until) or DateTime.compare(promo.valid_until, now) in [:gt, :eq]) and
    (is_nil(promo.max_redemptions) or promo.current_redemptions < promo.max_redemptions)
  end
  
  # === Changesets ===
  
  defp create_changeset(promo, attrs) do
    promo
    |> cast(attrs, [:name, :description, :token_amount, :conditions, :is_active, :max_redemptions, :valid_from, :valid_until, :created_by_id])
    |> validate_required([:name, :token_amount, :valid_from])
    |> validate_number(:token_amount, greater_than: 0)
    |> validate_number(:max_redemptions, greater_than: 0)
  end
  
  defp update_changeset(promo, attrs) do
    promo
    |> cast(attrs, [:name, :description, :token_amount, :conditions, :is_active, :max_redemptions, :valid_until])
    |> validate_number(:token_amount, greater_than: 0)
  end
end
