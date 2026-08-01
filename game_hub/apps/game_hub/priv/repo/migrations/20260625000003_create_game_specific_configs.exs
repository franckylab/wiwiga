defmodule GameHub.Repo.Migrations.CreateGameSpecificConfigs do
  use Ecto.Migration

  def change do
    create table(:game_specific_configs) do
      add :game_type, :string, null: false  # "dice", "cards", etc.
      add :enabled, :boolean, default: true
      
      # Paramètres de mise
      add :min_bet, :integer, default: 100
      add :max_bet, :integer, default: 500_000
      
      # Paramètres de jeu
      add :max_players, :integer, default: 2
      add :commission_rate, :float, default: 0.05  # 5%
      
      # Configurations spécifiques (JSON pour flexibilité)
      add :game_settings, :map, default: %{}
      # Exemple pour dice_game:
      # %{
      #   "dice_count" => 1,
      #   "dice_type" => 6,
      #   "roll_timeout_ms" => 10000,
      #   "animation_enabled" => true,
      #   "sound_enabled" => true
      # }
      
      # Timeouts
      add :matchmaking_timeout_ms, :integer, default: 30_000
      add :turn_timeout_ms, :integer, default: 15_000
      
      add :updated_by, references(:users, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:game_specific_configs, [:game_type], unique: true)
    create index(:game_specific_configs, [:updated_by])
    
    # Constraint pour montants positifs
    create constraint(:game_specific_configs, :min_bet_positive, check: "min_bet > 0")
    create constraint(:game_specific_configs, :max_bet_positive, check: "max_bet > 0")
    create constraint(:game_specific_configs, :max_bet_gte_min, check: "max_bet >= min_bet")
    create constraint(:game_specific_configs, :commission_valid, check: "commission_rate >= 0 AND commission_rate <= 1")
  end
end
