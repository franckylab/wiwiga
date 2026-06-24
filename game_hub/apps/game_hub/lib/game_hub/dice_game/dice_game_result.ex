# ==================================
# WIWIGA - Schéma Résultat Jeu de Dés
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.DiceGame.DiceGameResult
# Description: Traçabilité obligatoire résultats dés (Règle 3 - 10 ans)

defmodule GameHub.DiceGame.DiceGameResult do
  @moduledoc """
  Schéma pour stocker TOUS les résultats de jeu de dés.
  
  Règle 3 : Conservation 10 ans pour audit MINFI
  - Horodatage précis de chaque lancé
  - Résultats individuels de chaque dé
  - Somme totale
  - Association avec partie et joueurs
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  schema "dice_game_results" do
    field :game_id, :string
    field :dice_results, {:array, :integer}
    field :total_sum, :integer
    field :dice_count, :integer
    field :dice_type, :integer, default: 6
    
    # Association avec joueurs
    field :player_ids, {:array, :integer}, default: []
    field :winner_id, :integer
    
    # Résultats paris
    field :bets, :map, default: %{}
    field :payouts, :map, default: %{}
    field :commission_amount, :integer, default: 0
    
    # Métadonnées audit
    field :rng_seed_hash, :string
    field :verification_hash, :string
    
    timestamps()
  end
  
  @doc """
  Changeset pour création de résultat de jeu.
  """
  def create_changeset(result \\ %__MODULE__{}, attrs) do
    result
    |> cast(attrs, [
      :game_id, :dice_results, :total_sum, :dice_count, :dice_type,
      :player_ids, :winner_id, :bets, :payouts, :commission_amount,
      :rng_seed_hash, :verification_hash
    ])
    |> validate_required([:game_id, :dice_results, :total_sum, :dice_count])
    |> validate_number(:total_sum, greater_than_or_equal_to: 1)
    |> validate_number(:dice_count, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:dice_type, greater_than_or_equal_to: 4, less_than_or_equal_to: 20)
    |> validate_dice_results()
  end
  
  @doc """
  Génère hash de vérification pour audit.
  """
  @spec generate_verification_hash(String.t(), list(), DateTime.t()) :: String.t()
  def generate_verification_hash(game_id, dice_results, timestamp) do
    data = "#{game_id}:#{Enum.join(dice_results, ",")}:#{DateTime.to_iso8601(timestamp)}"
    
    :sha256
    |> :crypto.hash(data)
    |> Base.encode16(case: :lower)
  end
  
  # === Validations Privées ===
  
  defp validate_dice_results(changeset) do
    case get_field(changeset, :dice_results) do
      nil ->
        changeset
      
      results when is_list(results) ->
        if Enum.all?(results, fn r -> is_integer(r) and r >= 1 and r <= 6 end) do
          changeset
        else
          add_error(changeset, :dice_results, "must be between 1 and 6")
        end
      
      _ ->
        add_error(changeset, :dice_results, "must be a list of integers")
    end
  end
end
