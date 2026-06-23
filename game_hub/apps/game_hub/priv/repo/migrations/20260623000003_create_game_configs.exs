# ==================================
# WIWIGA - Migration Game Configs
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260623000003_create_game_configs.exs

defmodule GameHub.Repo.Migrations.CreateGameConfigs do
  use Ecto.Migration
  
  def up do
    create table(:game_configs, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_type, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :min_bet, :bigint, null: false
      add :max_bet, :bigint, null: false
      add :commission_rate, :decimal, precision: 5, scale: 4, null: false
      add :commission_mode, :string, default: "percentage", null: false
      add :is_active, :boolean, default: true, null: false
      add :config, :map
      
      timestamps()
    end
    
    # Index unique par type
    create unique_index(:game_configs, [:game_type])
    
    # Index pour jeux actifs
    create index(:game_configs, [:is_active])
    
    # Insertion configuration jeu de dés
    execute """
      INSERT INTO game_configs (id, game_type, name, description, min_bet, max_bet, commission_rate, commission_mode, is_active, config, inserted_at, updated_at)
      VALUES (
        1,
        'dice',
        'Jeu de Dés',
        'Pariez sur la somme des dés lancés',
        100,
        100000,
        0.05,
        'percentage',
        true,
        '{"dice_count": 3, "dice_faces": 6, "bet_types": ["exact_sum", "over_under", "specific_value"]}',
        NOW(),
        NOW()
      )
    """
  end
  
  def down do
    drop table(:game_configs)
  end
end
