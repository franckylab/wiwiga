# ==================================
# WIWIGA - Seed Configurations Par Défaut
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Données initiales pour WIWIGA
# Exécuter avec : mix run priv/repo/seeds.exs

defmodule GameHub.Repo.Seeds do
  @moduledoc """
  Seed pour configurations par défaut.
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Games.GameConfig
  alias GameHub.Games.GameTimeoutConfig
  alias GameHub.FeatureFlags.FeatureFlag
  alias GameHub.UI.{ThemeConfig, FeatureConfig, PaymentConfig}

  def run do
    IO.puts("🌱 Running seeds...")

    # 1. Utilisateurs par défaut
    seed_users()

    # 2. Game Timeout Configs
    seed_timeout_configs()

    # 3. Feature Flags
    seed_feature_flags()

    # 4. Configuration Thème UI
    seed_theme_config()

    # 5. Configuration Features
    seed_feature_config()

    # 6. Configuration Jeux
    seed_game_configs()

    # 7. Configuration Paiements
    seed_payment_configs()

    print_summary()
    IO.puts("✅ Seeds complétés avec succès!")
  end

  # === Utilisateurs ===

  defp seed_users do
    IO.puts("\n👤 Création des utilisateurs par défaut...")

    users = [
      %{
        phone: "+237699999999",
        name: "Admin WIWIGA",
        balance: 1_000_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false
      },
      %{
        phone: "+237688888888",
        name: "Utilisateur Test",
        balance: 500_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false
      },
      %{
        phone: "+237677777777",
        name: "Utilisateur Limité",
        balance: 200_000,
        is_active: true,
        has_verified_kyc: false,
        self_excluded: false,
        daily_deposit_limit: 500_000,
        daily_loss_limit: 250_000
      }
    ]

    Enum.each(users, fn user_data ->
      case Repo.get_by(User, phone: user_data.phone) do
        nil ->
          user = Repo.insert!(%User{} |> User.changeset(user_data))
          IO.puts("  ✓ Created user: #{user.name} (#{user.phone})")

        existing ->
          IO.puts("  ⊘ User #{existing.name} (#{existing.phone}) already exists")
      end
    end)
  end

  # === Game Timeout Configs ===

  defp seed_timeout_configs do
    IO.puts("\n⏱️  Seeding timeout configs...")

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
          IO.puts("  ⊘ Timeout config for #{existing.game_type} already exists")
      end
    end)
  end

  # === Feature Flags ===

  defp seed_feature_flags do
    IO.puts("\n🚩 Seeding feature flags...")

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
          IO.puts("  ✓ Created feature flag: #{flag_data.flag_name}")

        existing ->
          IO.puts("  ⊘ Feature flag #{existing.flag_name} already exists")
      end
    end)
  end

  # === Theme Config ===

  defp seed_theme_config do
    IO.puts("\n🎨 Seeding theme configuration...")
    config = ThemeConfig.get_config()
    IO.puts("  ✓ Theme config initialized (id: #{config.id})")
  end

  # === Feature Config ===

  defp seed_feature_config do
    IO.puts("\n⚙️  Seeding feature configuration...")
    config = FeatureConfig.get_config()
    IO.puts("  ✓ Feature config initialized (id: #{config.id})")
  end

  # === Game Configs ===

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
        {:ok, _config} ->
          IO.puts("  ✓ Created game config for #{game_type}")
        {:error, _} ->
          IO.puts("  ⊘ Game config for #{game_type} already exists or error")
      end
    end)
  end

  # === Payment Configs ===

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
        {:ok, _config} ->
          IO.puts("  ✓ Created payment config for #{provider}")
        {:error, _} ->
          IO.puts("  ⊘ Payment config for #{provider} already exists or error")
      end
    end)
  end

  # === Résumé ===

  defp print_summary do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📊 RÉSUMÉ DES DONNÉES CRÉÉES")
    IO.puts(String.duplicate("=", 60))
    IO.puts("👥 Utilisateurs: 3 (Admin, Test, Limité)")
    IO.puts("⏱️  Timeout configs: 1 (dice)")
    IO.puts("🚩 Feature flags: 3 (dice_game_v2, tournament_mode, social_chat)")
    IO.puts("🎨 Theme config: 1 (singleton)")
    IO.puts("⚙️  Feature config: 1 (singleton)")
    IO.puts("🎲 Game configs: 1 (dice)")
    IO.puts("💳 Payment configs: 3 (campay, mtn_momo, orange_money)")
    IO.puts(String.duplicate("=", 60))
  end
end

# Exécuter seeds
GameHub.Repo.Seeds.run()
