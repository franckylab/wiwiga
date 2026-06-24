# ==================================
# WIWIGA - Migration Résultats Jeu de Dés
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Table dice_game_results pour traçabilité 10 ans (Règle 3)

defmodule GameHub.Repo.Migrations.CreateDiceGameResults do
  use Ecto.Migration

  def up do
    create table(:dice_game_results, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_id, :string, null: false
      add :dice_results, {:array, :integer}, null: false
      add :total_sum, :integer, null: false
      add :dice_count, :integer, null: false
      add :dice_type, :integer, default: 6, null: false
      
      # Joueurs et résultats
      add :player_ids, {:array, :integer}, default: [], null: false
      add :winner_id, :integer
      add :bets, :map, default: %{}, null: false
      add :payouts, :map, default: %{}, null: false
      add :commission_amount, :integer, default: 0, null: false
      
      # Audit et vérification
      add :rng_seed_hash, :string
      add :verification_hash, :string
      
      timestamps()
    end
    
    # Index pour recherches fréquentes
    create index(:dice_game_results, [:game_id], unique: true)
    create index(:dice_game_results, [:winner_id])
    create index(:dice_game_results, [:inserted_at])
    create index(:dice_game_results, [:player_ids], using: "gin")
    
    # Contraintes CHECK
    execute """
      ALTER TABLE dice_game_results
      ADD CONSTRAINT total_sum_positive CHECK (total_sum > 0)
    """
    
    execute """
      ALTER TABLE dice_game_results
      ADD CONSTRAINT dice_count_valid CHECK (dice_count >= 1 AND dice_count <= 10)
    """
    
    execute """
      ALTER TABLE dice_game_results
      ADD CONSTRAINT dice_type_valid CHECK (dice_type >= 4 AND dice_type <= 20)
    """
    
    execute """
      ALTER TABLE dice_game_results
      ADD CONSTRAINT commission_non_negative CHECK (commission_amount >= 0)
    """
  end

  def down do
    drop table(:dice_game_results)
  end
end
