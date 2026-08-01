# ==================================
# WIWIGA - Schema User Promo Token
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens.UserPromoToken
# Description: Tracking des promos réclamées par utilisateur

defmodule GameHub.Tokens.UserPromoToken do
  @moduledoc """
  Enregistrement des promos réclamées par un utilisateur.
  
  Permet de tracker:
  - Jetons crédités
  - Jetons restants (si conditions non remplies)
  - Conditions d'utilisation
  - Expiration
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Tokens.PromoToken
  
  @derive {Jason.Encoder, except: [:__meta__]}
  
  schema "user_promo_tokens" do
    field :tokens_credited, :integer
    field :tokens_remaining, :integer
    field :conditions_met, :boolean, default: false
    field :redeemed_at, :utc_datetime
    field :expires_at, :utc_datetime
    
    belongs_to :user, User
    belongs_to :promo_token, PromoToken
    
    timestamps()
  end
  
  @doc """
  Vérifie si l'utilisateur a déjà réclamé cette promo.
  """
  def already_redeemed?(user_id, promo_id) do
    query = from up in __MODULE__,
      where: up.user_id == ^user_id and up.promo_token_id == ^promo_id
    
    Repo.exists?(query)
  end
  
  @doc """
  Récupère les promos actives d'un utilisateur (non expirées, avec solde).
  """
  def get_user_active_promos(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    query = from up in __MODULE__,
      where: up.user_id == ^user_id and
             up.tokens_remaining > 0 and
             (is_nil(up.expires_at) or up.expires_at >= ^now),
      preload: [:promo_token],
      order_by: [desc: up.redeemed_at]
    
    Repo.all(query)
  end
  
  @doc """
  Met à jour les jetons restants (après utilisation partielle).
  """
  def update_remaining(user_promo_id, new_remaining) do
    get!(user_promo_id)
    |> changeset(%{tokens_remaining: new_remaining})
    |> Repo.update()
  end
  
  @doc """
  Marque les conditions comme remplies.
  """
  def mark_conditions_met(user_promo_id) do
    get!(user_promo_id)
    |> changeset(%{conditions_met: true})
    |> Repo.update()
  end
  
  defp get!(id), do: Repo.get!(__MODULE__, id)
  
  defp changeset(user_promo, attrs) do
    user_promo
    |> cast(attrs, [:tokens_credited, :tokens_remaining, :conditions_met, :redeemed_at, :expires_at, :user_id, :promo_token_id])
    |> validate_required([:tokens_credited, :tokens_remaining, :redeemed_at, :user_id, :promo_token_id])
    |> validate_number(:tokens_credited, greater_than: 0)
    |> validate_number(:tokens_remaining, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :promo_token_id])
  end
end
