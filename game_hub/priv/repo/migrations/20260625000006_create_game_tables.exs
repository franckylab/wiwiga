defmodule GameHub.Repo.Migrations.CreateGameTables do
  use Ecto.Migration

  def change do
    # ========================================
    # Table: game_configs
    # ========================================
    create table(:game_configs) do
      add :game_type, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :min_bet, :integer, default: 100
      add :max_bet, :integer, default: 500_000
      add :min_bet_tokens, :integer, default: 0
      add :commission_rate, :decimal, default: 0.05
      add :commission_mode, :string, default: "percentage"
      add :is_active, :boolean, default: true
      add :config, :map, default: %{}
      add :coming_soon, :boolean, default: false
      add :tips, :map
      add :display_order, :integer, default: 0

      timestamps()
    end

    create unique_index(:game_configs, [:game_type])

    # ========================================
    # Table: game_rules
    # ========================================
    create table(:game_rules) do
      add :game_type, :string, null: false
      add :rule_type, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :config, :map, default: %{}
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:game_rules, [:game_type, :rule_type])
    create index(:game_rules, [:is_active])

    # ========================================
    # Table: player_level_configs
    # ========================================
    create table(:player_level_configs) do
      add :tier, :string, null: false
      add :name, :string, null: false
      add :min_xp, :integer, default: 0
      add :max_xp, :integer
      add :icon, :string, default: "shield"
      add :color, :string, default: "#808080"
      add :benefits, :map, default: %{}
      add :display_order, :integer, default: 0
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:player_level_configs, [:tier])
    create index(:player_level_configs, [:display_order])

    # ========================================
    # Seed data: game_configs
    # ========================================
    execute """
    INSERT INTO game_configs (game_type, name, description, min_bet, max_bet, commission_rate, commission_mode, is_active, display_order, inserted_at, updated_at)
    VALUES
      ('dice', 'Dés', 'Jeu de dés classique - High roll séquentiel', 100, 500000, 0.05, 'percentage', true, 1, NOW(), NOW()),
      ('ludo', 'Ludo', 'Jeu de petits chevaux - Course stratégique', 100, 500000, 0.05, 'percentage', true, 2, NOW(), NOW()),
      ('cards', 'Cartes', 'Jeu de cartes - Variantes multiples', 100, 500000, 0.05, 'percentage', false, 3, NOW(), NOW())
    ON CONFLICT (game_type) DO NOTHING
    """, """
    DELETE FROM game_configs WHERE game_type IN ('dice', 'ludo', 'cards')
    """

    # ========================================
    # Seed data: game_rules
    # ========================================
    execute """
    INSERT INTO game_rules (game_type, rule_type, name, description, config, is_active, inserted_at, updated_at)
    VALUES
      ('dice', 'normal', 'Normal', 'High roll séquentiel, ordre tournant',
       '{"min_sets": 1, "max_sets": 11, "default_sets": 1, "min_dice": 1, "max_dice": 5, "default_dice": 2, "dice_faces": 6, "commission_rate": 0.05, "min_bet": 100, "max_bet": 500000, "min_players": 2, "max_players": 5, "tie_rule": "replay", "turn_order": "rotating"}',
       true, NOW(), NOW()),
      ('dice', 'cible', 'Cible', 'Vote pour nombre cible, plus proche gagne',
       '{"min_sets": 1, "max_sets": 11, "default_sets": 1, "min_dice": 1, "max_dice": 5, "default_dice": 2, "dice_faces": 6, "commission_rate": 0.05, "min_bet": 100, "max_bet": 500000, "min_players": 2, "max_players": 5, "tie_rule": "replay", "target_vote_mode": "average"}',
       true, NOW(), NOW())
    ON CONFLICT (game_type, rule_type) DO NOTHING
    """, """
    DELETE FROM game_rules WHERE game_type = 'dice' AND rule_type IN ('normal', 'cible')
    """

    # ========================================
    # Seed data: player_level_configs
    # ========================================
    execute """
    INSERT INTO player_level_configs (tier, name, min_xp, max_xp, icon, color, benefits, display_order, is_active, inserted_at, updated_at)
    VALUES
      ('bronze', 'Bronze', 0, 499, 'shield', '#CD7F32',
       '{"cashback_rate": 0.0, "withdrawal_bonus": 0.0, "bet_discount": 0.0, "daily_bonus_multiplier": 1.0, "label": "Débutant"}',
       1, true, NOW(), NOW()),
      ('silver', 'Silver', 500, 1999, 'workspace_premium', '#C0C0C0',
       '{"cashback_rate": 0.02, "withdrawal_bonus": 0.01, "bet_discount": 0.02, "daily_bonus_multiplier": 1.1, "label": "Apprenti"}',
       2, true, NOW(), NOW()),
      ('gold', 'Gold', 2000, 4999, 'emoji_events', '#FFD700',
       '{"cashback_rate": 0.04, "withdrawal_bonus": 0.02, "bet_discount": 0.05, "daily_bonus_multiplier": 1.25, "label": "Confirmé"}',
       3, true, NOW(), NOW()),
      ('platinum', 'Platinum', 5000, 9999, 'star', '#E5E4E2',
       '{"cashback_rate": 0.06, "withdrawal_bonus": 0.03, "bet_discount": 0.08, "daily_bonus_multiplier": 1.5, "label": "Expert"}',
       4, true, NOW(), NOW()),
      ('diamond', 'Diamond', 10000, 24999, 'diamond', '#B9F2FF',
       '{"cashback_rate": 0.08, "withdrawal_bonus": 0.05, "bet_discount": 0.12, "daily_bonus_multiplier": 2.0, "label": "Maître"}',
       5, true, NOW(), NOW()),
      ('legend', 'Legend', 25000, nil, 'military_tech', '#FF6B6B',
       '{"cashback_rate": 0.10, "withdrawal_bonus": 0.08, "bet_discount": 0.15, "daily_bonus_multiplier": 3.0, "label": "Légende"}',
       6, true, NOW(), NOW())
    ON CONFLICT (tier) DO NOTHING
    """, """
    DELETE FROM player_level_configs WHERE tier IN ('bronze', 'silver', 'gold', 'platinum', 'diamond', 'legend')
    """
  end
end
