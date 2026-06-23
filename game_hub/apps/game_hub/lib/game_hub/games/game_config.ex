# ==================================
# WIWIGA - Schema Configuration Jeu
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Games.GameConfig
# Description: Configuration des jeux avec commission configurable

defmodule GameHub.Games.GameConfig do
  @moduledoc """
  Schema configuration jeu.
  
  ## Commission Modes
    - `percentage`: Pourcentage des gains
    - `fixed`: Montant fixe par partie
    - `tiered`: Barème progressif
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :game_type, :name, :min_bet, :max_bet, :commission_rate, :commission_mode, :is_active]}
  
  schema "game_configs" do
    field :game_type, :string
    field :name, :string
    field :description, :string
    field :min_bet, :integer
    field :max_bet, :integer
    field :commission_rate, :decimal
    field :commission_mode, :string, default: "percentage"
    field :is_active, :boolean, default: true
    field :config, :map
    
    timestamps()
  end
  
  @doc """
  Changeset pour création config jeu.
  """
  def create_changeset(config, attrs) do
    config
    |> cast(attrs, [:game_type, :name, :description, :min_bet, :max_bet, :commission_rate, :commission_mode, :is_active, :config])
    |> validate_required([:game_type, :name, :min_bet, :max_bet, :commission_rate, :commission_mode])
    |> validate_inclusion(:game_type, ~w(dice card roulette))
    |> validate_inclusion(:commission_mode, ~w(percentage fixed tiered))
    |> validate_number(:min_bet, greater_than: 0)
    |> validate_number(:max_bet, greater_than: :min_bet)
    |> validate_number(:commission_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint(:game_type)
  end
  
  @doc """
  Changeset pour update commission.
  """
  def commission_changeset(config, attrs) do
    config
    |> cast(attrs, [:commission_rate, :commission_mode])
    |> validate_required([:commission_rate, :commission_mode])
    |> validate_number(:commission_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_inclusion(:commission_mode, ~w(percentage fixed tiered))
  end
  
  @doc """
  Calcule commission sur gains.
  """
  def calculate_commission(%{commission_rate: rate, commission_mode: "percentage"}, winnings) do
    Decimal.mult(winnings, rate)
  end
  
  def calculate_commission(%{commission_mode: "fixed", config: %{"fixed_amount" => amount}}, _winnings) do
    amount
  end
  
  def calculate_commission(_, _), do: Decimal.new(0)
  
  @doc """
  Vérifie si mise est dans limites.
  """
  def valid_bet?(%{min_bet: min, max_bet: max}, bet_amount) do
    bet_amount >= min && bet_amount <= max
  end
end
