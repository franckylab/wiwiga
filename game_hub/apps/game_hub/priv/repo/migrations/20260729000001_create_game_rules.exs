# ==================================
# WIWIGA - Migration Game Rules
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Table game_rules - règles configurables par type de jeu
#              Chaque type de jeu (dice) a ses propres règles (normal, cible)

defmodule GameHub.Repo.Migrations.CreateGameRules do
  use Ecto.Migration

  def up do
    create table(:game_rules, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :game_type, :string, null: false
      add :rule_type, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :config, :map, null: false, default: %{}
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    # Index unique : un seul rule_type par game_type
    create unique_index(:game_rules, [:game_type, :rule_type])
    create index(:game_rules, [:game_type, :is_active])

    # === Seeds : 2 règles par défaut pour dice ===

    # Type "Normal" : High Roll séquentiel, ordre tournant
    execute """
    INSERT INTO game_rules (game_type, rule_type, name, description, config, is_active, inserted_at, updated_at)
    VALUES (
      'dice',
      'normal',
      'Normal',
      'Chaque joueur lance les dés tour par tour. Le joueur avec la somme la plus élevée gagne le set. Si égalité, le set est nul et rejoué.',
      '{
        "min_sets": 1,
        "max_sets": 11,
        "default_sets": 1,
        "min_dice": 1,
        "max_dice": 5,
        "default_dice": 2,
        "dice_faces": 6,
        "commission_rate": 0.05,
        "min_bet": 100,
        "max_bet": 500000,
        "min_players": 2,
        "max_players": 5,
        "tie_rule": "replay",
        "turn_order": "rotating",
        "turn_timeout_seconds": 15,
        "set_timeout_seconds": 60
      }',
      true,
      NOW(),
      NOW()
    )
    """

    # Type "Cible" : Vote pour nombre cible, plus proche gagne
    execute """
    INSERT INTO game_rules (game_type, rule_type, name, description, config, is_active, inserted_at, updated_at)
    VALUES (
      'dice',
      'cible',
      'Cible',
      'Les joueurs votent pour un nombre cible. La somme des dés la plus proche de la cible gagne le set. Si distances égales, le set est nul.',
      '{
        "min_sets": 1,
        "max_sets": 11,
        "default_sets": 1,
        "min_dice": 1,
        "max_dice": 5,
        "default_dice": 2,
        "dice_faces": 6,
        "commission_rate": 0.05,
        "min_bet": 100,
        "max_bet": 500000,
        "min_players": 2,
        "max_players": 5,
        "tie_rule": "replay",
        "target_vote_mode": "average",
        "vote_timeout_seconds": 20,
        "turn_timeout_seconds": 15,
        "set_timeout_seconds": 60
      }',
      true,
      NOW(),
      NOW()
    )
    """
  end

  def down do
    drop table(:game_rules)
  end
end
