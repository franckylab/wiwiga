# ==================================
# WIWIGA - Schema Token Config
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Tokens.TokenConfig
# Description: Configuration du système de jetons (singleton)

defmodule GameHub.Tokens.TokenConfig do
  @moduledoc """
  Configuration globale du système de jetons.
  
  ## Règles
  - Une seule ligne en DB (singleton)
  - Taux configurable: 1 jeton = 1 FCFA par défaut (spec WIWIGA)
  - Limites échange configurables
  - Mises min par jeu configurables
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @derive {Jason.Encoder, except: [:__meta__, :updated_by]}
  
  schema "token_configs" do
    # Taux de conversion (1 jeton = 1 FCFA)
    field :exchange_rate, :float, default: 1.0
    
    # Limites échange
    field :min_exchange_tokens, :integer, default: 100
    field :max_exchange_tokens, :integer, default: 100_000
    
    # Mises min par jeu
    field :min_bet_tokens_dice, :integer, default: 10
    field :min_bet_tokens_card, :integer, default: 10
    
    # Fonctionnalités
    field :transfer_enabled, :boolean, default: true
    field :gift_enabled, :boolean, default: true
    
    # Frais
    field :exchange_fee_percentage, :float, default: 0.0
    field :exchange_fee_fixed, :integer, default: 0
    
    # Settings flexibles
    field :settings, :map, default: %{}
    
    belongs_to :updated_by, User
    
    timestamps()
  end
  
  @doc """
  Récupère la configuration (singleton).
  Crée la config par défaut si inexistante.
  """
  def get_config do
    case Repo.one(__MODULE__) do
      nil -> create_default_config()
      config -> config
    end
  end
  
  @doc """
  Met à jour la configuration.
  """
  def update_config(attrs) do
    config = get_config()
    
    config
    |> changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Convertit jetons → valeur monétaire (centimes).
  
  ## Exemple
      tokens_to_monetary(100) → 10000 (100 FCFA en centimes) avec taux 1.0
  """
  def tokens_to_monetary(tokens, config \\ nil) do
    config = config || get_config()
    monetary = tokens / config.exchange_rate
    # Retourne en centimes (1 FCFA = 100 centimes)
    round(monetary * 100)
  end
  
  @doc """
  Convertit valeur monétaire (centimes) → jetons.
  
  ## Exemple
      monetary_to_tokens(10000) → 100 (jetons) avec taux 1.0
  """
  def monetary_to_tokens(monetary_centimes, config \\ nil) do
    config = config || get_config()
    monetary_fcfa = monetary_centimes / 100
    floor(monetary_fcfa * config.exchange_rate)
  end
  
  @doc """
  Calcule les frais d'échange pour un montant de jetons.
  """
  def calculate_exchange_fee(token_amount, config \\ nil) do
    config = config || get_config()
    
    fee_percentage = round(token_amount * config.exchange_fee_percentage)
    fee_fixed = config.exchange_fee_fixed
    
    fee_percentage + fee_fixed
  end
  
  @doc """
  Récupère la mise minimum en jetons pour un type de jeu.
  """
  def get_min_bet_tokens(game_type, config \\ nil) do
    config = config || get_config()
    
    case game_type do
      "dice" -> config.min_bet_tokens_dice
      "card" -> config.min_bet_tokens_card
      _ -> 10 # Défaut
    end
  end
  
  # === Privé ===
  
  defp create_default_config do
    %__MODULE__{}
    |> changeset(%{
      exchange_rate: 1.0,
      min_exchange_tokens: 100,
      max_exchange_tokens: 100_000,
      min_bet_tokens_dice: 10,
      min_bet_tokens_card: 10,
      transfer_enabled: true,
      gift_enabled: true,
      exchange_fee_percentage: 0.0,
      exchange_fee_fixed: 0
    })
    |> Repo.insert!()
  end
  
  defp changeset(config, attrs) do
    config
    |> cast(attrs, [
      :exchange_rate, :min_exchange_tokens, :max_exchange_tokens,
      :min_bet_tokens_dice, :min_bet_tokens_card,
      :transfer_enabled, :gift_enabled,
      :exchange_fee_percentage, :exchange_fee_fixed,
      :settings, :updated_by_id
    ])
    |> validate_number(:exchange_rate, greater_than: 0)
    |> validate_number(:min_exchange_tokens, greater_than: 0)
    |> validate_number(:max_exchange_tokens, greater_than: 0)
    |> validate_number(:exchange_fee_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:min_bet_tokens_dice, greater_than: 0)
    |> validate_number(:min_bet_tokens_card, greater_than: 0)
  end
end
