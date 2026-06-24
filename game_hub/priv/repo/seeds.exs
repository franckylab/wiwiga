# ==================================
# WIWIGA - Seed Configurations Par Défaut
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Repo.Seeds do
  @moduledoc """
  Seed pour configurations par défaut.
  
  Exécuter avec : mix run priv/repo/seeds.exs
  """
  
  alias GameHub.Repo
  alias GameHub.Games.GameTimeoutConfig
  alias GameHub.FeatureFlags.FeatureFlag
  alias GameHub.UI.{ThemeConfig, FeatureConfig, GameConfig, PaymentConfig}
  
  def run do
    IO.puts("🌱 Running seeds...")
    
    # 1. Game Timeout Configs par défaut
    seed_timeout_configs()
    
    # 2. Feature Flags par défaut
    seed_feature_flags()
    
    # 3. Configuration Dynamique - Thème UI
    seed_theme_config()
    
    # 4. Configuration Dynamique - Features
    seed_feature_config()
    
    # 5. Configuration Dynamique - Jeux
    seed_game_configs()
    
    # 6. Configuration Dynamique - Paiements
    seed_payment_configs()
    
    IO.puts("✅ Seeds completed!")
  end
  
  defp seed_timeout_configs do
    configs = [
      %{
        game_type: "dice",
        grace_period_seconds: 120,
        action_on_timeout: "forfeit",
        forfeit_distribution: "to_winner",
        reconnect_allowed: true,
        max_reconnect_attempts: 3,
        is_active: true
      }
    ]
    
    Enum.each(configs, fn config_data ->
      case Repo.get_by(GameTimeoutConfig, game_type: config_data.game_type) do
        nil ->
          %GameTimeoutConfig{}
          |> GameTimeoutConfig.changeset(config_data)
          |> Repo.insert!()
          IO.puts("  ✓ Created timeout config for #{config_data.game_type}")
        
        existing ->
          IO.puts("  ⊘ Timeout config for #{config_data.game_type} already exists")
      end
    end)
  end
  
  defp seed_feature_flags do
    flags = [
      %{
        flag_name: "dice_game_v2",
        description: "Nouvelle version du jeu de dés avec animations",
        enabled: false,
        percentage_rollout: 0,
        environment: "all"
      },
      %{
        flag_name: "tournament_mode",
        description: "Mode tournoi pour les jeux",
        enabled: false,
        percentage_rollout: 0,
        environment: "all"
      },
      %{
        flag_name: "social_chat",
        description: "Chat social entre joueurs",
        enabled: false,
        percentage_rollout: 0,
        environment: "all"
      }
    ]
    
    Enum.each(flags, fn flag_data ->
      case Repo.get_by(FeatureFlag, flag_name: flag_data.flag_name) do
        nil ->
          %FeatureFlag{}
          |> FeatureFlag.changeset(flag_data)
          |> Repo.insert!()
          IO.puts("  ✓ Created feature flag #{flag_data.flag_name}")
        
        existing ->
          IO.puts("  ⊘ Feature flag #{flag_data.flag_name} already exists")
      end
    end)
  end
  
  defp seed_theme_config do
    IO.puts("\n🎨 Seeding theme configuration...")
    
    # Crée ou récupère la config singleton
    config = ThemeConfig.get_config()
    IO.puts("  ✓ Theme config initialized (id: #{config.id})")
  end
  
  defp seed_feature_config do
    IO.puts("\n⚙️ Seeding feature configuration...")
    
    config = FeatureConfig.get_config()
    IO.puts("  ✓ Feature config initialized (id: #{config.id})")
  end
  
  defp seed_game_configs do
    IO.puts("\n🎲 Seeding game configurations...")
    
    games = [
      {"dice", %{
        "enabled" => true,
        "min_bet" => 100,
        "max_bet" => 500_000,
        "max_players" => 2,
        "commission_rate" => 0.05,
        "game_settings" => %{
          "dice_count" => 1,
          "dice_type" => 6,
          "roll_timeout_ms" => 10_000,
          "animation_enabled" => true,
          "sound_enabled" => true
        },
        "matchmaking_timeout_ms" => 30_000,
        "turn_timeout_ms" => 15_000
      }}
    ]
    
    Enum.each(games, fn {game_type, attrs} ->
      case GameConfig.create_or_update(game_type, attrs) do
        {:ok, config} ->
          IO.puts("  ✓ Created game config for #{game_type}")
        {:error, _} ->
          IO.puts("  ⊘ Game config for #{game_type} already exists or error")
      end
    end)
  end
  
  defp seed_payment_configs do
    IO.puts("\n💳 Seeding payment configurations...")
    
    payments = [
      {"campay", %{
        "enabled" => true,
        "min_amount" => 500,
        "max_amount" => 1_000_000,
        "api_url" => "https://demo.campay.net/api",
        "provider_settings" => %{
          "timeout_ms" => 30_000,
          "retry_attempts" => 3
        },
        "transaction_fee_percentage" => 0.0,
        "transaction_fee_fixed" => 0
      }},
      {"mtn_momo", %{
        "enabled" => true,
        "min_amount" => 500,
        "max_amount" => 1_000_000,
        "provider_settings" => %{
          "timeout_ms" => 30_000
        },
        "transaction_fee_percentage" => 0.0,
        "transaction_fee_fixed" => 0
      }},
      {"orange_money", %{
        "enabled" => true,
        "min_amount" => 500,
        "max_amount" => 1_000_000,
        "provider_settings" => %{
          "timeout_ms" => 30_000
        },
        "transaction_fee_percentage" => 0.0,
        "transaction_fee_fixed" => 0
      }}
    ]
    
    Enum.each(payments, fn {provider, attrs} ->
      case PaymentConfig.create_or_update(provider, attrs) do
        {:ok, config} ->
          IO.puts("  ✓ Created payment config for #{provider}")
        {:error, _} ->
          IO.puts("  ⊘ Payment config for #{provider} already exists or error")
      end
    end)
  end
end

# Exécuter seeds
GameHub.Repo.Seeds.run()
# ============================================================
# Fichier: seeds.exs
# Description: Données initiales pour WIWIGA
# Auteur: WIWIGA Team
# Date: 2026-06-23
# ============================================================

alias GameHub.Repo
alias GameHub.Users.User
alias GameHub.Games.GameConfig

# ============================================================
# UTILISATEURS PAR DÉFAUT
# ============================================================

IO.puts("👤 Création des utilisateurs par défaut...")

# Super Admin
admin = Repo.insert!(%User{
  phone: "+237699999999",
  name: "Admin WIWIGA",
  balance: 1000000,
  is_active: true,
  has_verified_kyc: true,
  self_excluded: false
})

IO.puts("✅ Super Admin créé: #{admin.phone} (balance: #{admin.balance} centimes)")

# Utilisateur test
test_user = Repo.insert!(%User{
  phone: "+237688888888",
  name: "Utilisateur Test",
  balance: 500000,
  is_active: true,
  has_verified_kyc: true,
  self_excluded: false
})

IO.puts("✅ Utilisateur test créé: #{test_user.phone} (balance: #{test_user.balance} centimes)")

# Utilisateur avec limites
limited_user = Repo.insert!(%User{
  phone: "+237677777777",
  name: "Utilisateur Limité",
  balance: 200000,
  is_active: true,
  has_verified_kyc: false,
  self_excluded: false,
  daily_deposit_limit: 500000,
  daily_loss_limit: 250000
})

IO.puts("✅ Utilisateur limité créé: #{limited_user.phone}")

# ============================================================
# CONFIGURATIONS DES JEUX
# ============================================================

IO.puts("\n🎲 Création des configurations de jeux...")

# Jeu de Dés
dice_config = Repo.insert!(%GameConfig{
  game_type: "dice",
  name: "Jeu de Dés",
  description: "Pariez sur la somme des dés",
  is_active: true,
  commission_rate: Decimal.new("0.05"),
  commission_mode: "percentage",
  min_bet: 10000,
  max_bet: 10000000,
  config: %{
    "min_dice" => 1,
    "max_dice" => 6,
    "number_of_dice" => 2,
    "bet_types" => ["sum", "exact", "over_under"]
  }
})

IO.puts("✅ Jeu de Dés configuré: #{dice_config.game_id}")

# ============================================================
# RÉSUMÉ
# ============================================================

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("📊 RÉSUMÉ DES DONNÉES CRÉÉES")
IO.puts(String.duplicate("=", 60))
IO.puts("👥 Utilisateurs: 3")
IO.puts("   - Admin: #{admin.phone}")
IO.puts("   - Test: #{test_user.phone}")
IO.puts("   - Limité: #{limited_user.phone}")
IO.puts("🎮 Jeux configurés: 1 (Dice)")
IO.puts(String.duplicate("=", 60))
IO.puts("✅ Seeds complétés avec succès!")
IO.puts(String.duplicate("=", 60))
