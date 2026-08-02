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
  
  alias GameHub.Repo
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :game_type, :name, :description, :min_bet, :max_bet, :min_bet_tokens, :commission_rate, :commission_mode, :is_active, :coming_soon, :tips, :display_order]}
  
  schema "game_configs" do
    field :game_type, :string
    field :name, :string
    field :description, :string
    field :min_bet, :integer
    field :max_bet, :integer
    field :min_bet_tokens, :integer
    field :commission_rate, :decimal
    field :commission_mode, :string, default: "percentage"
    field :is_active, :boolean, default: true
    field :config, :map
    field :coming_soon, :boolean, default: false
    field :tips, :map
    field :display_order, :integer, default: 0
    
    timestamps()
  end
  
  @doc """
  Crée ou met à jour une configuration de jeu par game_type.
  """
  def create_or_update(game_type, attrs) do
    # Ajouter valeurs par défaut pour champs requis
    attrs = attrs
    |> Map.put_new("game_type", game_type)
    |> Map.put_new("name", String.capitalize(game_type))
    |> Map.put_new("commission_mode", "percentage")
    |> Map.put_new("min_bet", 100)
    |> Map.put_new("max_bet", 500_000)
    |> Map.put_new("commission_rate", 0.05)
    
    case Repo.get_by(__MODULE__, game_type: game_type) do
      nil ->
        %__MODULE__{}
        |> create_changeset(attrs)
        |> Repo.insert()
      
      existing ->
        existing
        |> create_changeset(attrs)
        |> Repo.update()
    end
  end
  
  @doc """
  Changeset pour création config jeu.
  """
  def create_changeset(config, attrs) do
    config
    |> cast(attrs, [:game_type, :name, :description, :min_bet, :max_bet, :min_bet_tokens, :commission_rate, :commission_mode, :is_active, :config, :coming_soon, :tips, :display_order])
    |> validate_required([:game_type, :name, :min_bet, :max_bet, :commission_rate, :commission_mode])
    |> validate_inclusion(:game_type, ~w(dice ludo card roulette))
    |> validate_inclusion(:commission_mode, ~w(percentage fixed tiered))
    |> validate_number(:min_bet, greater_than: 0)
    |> validate_number(:max_bet, greater_than: 0)
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
