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
  alias GameHub.Tokens.TokenConfig

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

    # 8. Configuration Jetons
    seed_token_config()

    # 9. Promotions exemples
    seed_promo_tokens()

    # 10. Achievements par défaut
    seed_achievements()

    print_summary()
    IO.puts("✅ Seeds complétés avec succès!")
  end

  # === Utilisateurs avec rôles RBAC ===

  defp seed_users do
    IO.puts("\n👤 Création des utilisateurs par défaut (avec rôles RBAC)...")

    users = [
      # Super Administrateur
      %{
        phone: "+237600000000",
        email: "superadmin@wiwiga.com",
        username: "superadmin",
        name: "Super Admin WIWIGA",
        role: "super_admin",
        avatar_type: "wiwiga_4",
        balance: 10_000_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false,
        password: "Wiwiga@Super2026!"
      },
      # Administrateur
      %{
        phone: "+237699999999",
        email: "admin@wiwiga.com",
        username: "admin_wiwiga",
        name: "Admin WIWIGA",
        role: "admin",
        avatar_type: "wiwiga_1",
        balance: 1_000_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false,
        password: "Wiwiga@Admin2026!"
      },
      # Modérateur
      %{
        phone: "+237688888888",
        email: "moderator@wiwiga.com",
        username: "moderator_wiwiga",
        name: "Modérateur WIWIGA",
        role: "moderator",
        avatar_type: "wiwiga_5",
        balance: 500_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false,
        password: "Wiwiga@Modo2026!"
      },
      # Compte Test
      %{
        phone: "+237677777777",
        email: "test@wiwiga.com",
        username: "test_account",
        name: "Compte Test",
        role: "test",
        avatar_type: "wiwiga_3",
        balance: 5_000_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false,
        password: "Wiwiga@Test2026!"
      },
      # Utilisateur standard 1
      %{
        phone: "+237655555555",
        email: "joueur1@wiwiga.com",
        username: "joueur_pro",
        name: "Joueur Pro",
        role: "user",
        avatar_type: "wiwiga_2",
        balance: 200_000,
        is_active: true,
        has_verified_kyc: true,
        self_excluded: false,
        password: "Wiwiga@Joueur2026!"
      },
      # Utilisateur standard 2
      %{
        phone: "+237644444444",
        email: "joueur2@wiwiga.com",
        username: "gamer_dude",
        name: "Gamer Dude",
        role: "user",
        avatar_type: "wiwiga_6",
        balance: 150_000,
        is_active: true,
        has_verified_kyc: false,
        self_excluded: false,
        daily_deposit_limit: 500_000,
        daily_loss_limit: 250_000,
        password: "Wiwiga@Joueur2026!"
      }
    ]

    Enum.each(users, fn user_data ->
      {password, user_attrs} = Map.pop(user_data, :password)
      
      case Repo.get_by(User, phone: user_attrs.phone) do
        nil ->
          # Créer avec mot de passe hashé
          changeset = if password do
            %User{}
            |> User.admin_registration_with_password_changeset(Map.put(user_attrs, :password, password))
          else
            %User{}
            |> User.changeset(user_attrs)
          end
          
          user = Repo.insert!(changeset)
          IO.puts("  ✓ Created #{user.role}: #{user.name} (#{user.username}) — password: #{password || "N/A"}")

        existing ->
          # Si l'utilisateur existe mais n'a pas de password_hash, le définir
          if password && (existing.password_hash == nil || existing.password_hash == "") do
            hashed = GameHub.Users.User.hash_password_raw(password)
            existing
            |> Ecto.Changeset.change(%{password_hash: hashed})
            |> Repo.update!()
            IO.puts("  ✓ Updated #{existing.name} (#{existing.username}) with password: #{password}")
          else
            IO.puts("  ⊘ User #{existing.name} (#{existing.phone}) already exists")
          end
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
      },
      %{
        flag_name: "otp_registration_required",
        description: "Vérification OTP requise lors de l'inscription (désactivé par défaut)",
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

  # === Token Config ===

  defp seed_token_config do
    IO.puts("\n🪙 Seeding token configuration...")
    config = TokenConfig.get_config()
    IO.puts("  ✓ Token config initialized (id: #{config.id}, rate: #{config.exchange_rate} tokens/FCFA)")
  end

  # === Promo Tokens ===

  defp seed_promo_tokens do
    IO.puts("\n🎁 Seeding promo tokens...")

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    promos = [
      %{
        name: "Bonus Bienvenue",
        description: "500 jetons offerts pour votre inscription!",
        token_amount: 500,
        conditions: %{"expiry_days" => 30, "min_games" => 1},
        is_active: true,
        max_redemptions: 1000,
        valid_from: now,
        valid_until: DateTime.add(now, 365 * 86400, :second)
      },
      %{
        name: "Parrainage",
        description: "200 jetons pour chaque ami invité!",
        token_amount: 200,
        conditions: %{"expiry_days" => 60},
        is_active: true,
        valid_from: now
      },
      %{
        name: "Flash Weekend",
        description: "1000 jetons bonus le weekend!",
        token_amount: 1000,
        conditions: %{"expiry_days" => 7, "wagering_multiplier" => 2},
        is_active: true,
        max_redemptions: 500,
        valid_from: now,
        valid_until: DateTime.add(now, 30 * 86400, :second)
      }
    ]

    Enum.each(promos, fn attrs ->
      case GameHub.Tokens.PromoToken.create_promo(attrs) do
        {:ok, promo} ->
          IO.puts("  ✓ Created promo: #{promo.name} (#{promo.token_amount} tokens)")
        {:error, _} ->
          IO.puts("  ⊘ Promo already exists or error")
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
    IO.puts("🚩 Feature flags: 4 (dice_game_v2, tournament_mode, social_chat, otp_registration)")
    IO.puts("🎨 Theme config: 1 (singleton)")
    IO.puts("⚙️  Feature config: 1 (singleton)")
    IO.puts("🎲 Game configs: 1 (dice)")
    IO.puts("💳 Payment configs: 3 (campay, mtn_momo, orange_money)")
    IO.puts("🪙 Token config: 1 (singleton)")
    IO.puts("🎁 Promo tokens: 3 (bienvenue, parrainage, flash)")
    IO.puts("🏆 Achievements: 14 (badges par défaut)")
    IO.puts(String.duplicate("=", 60))
  end
  
  # === Achievements par défaut ===
  defp seed_achievements do
    IO.puts("🏆 Seeding achievements...")
    
    case GameHub.Users.AchievementManager.seed_default_achievements() do
      {:ok, count} -> IO.puts("   ✅ #{count} achievements créés")
      _ -> IO.puts("   ⚠️  Achievements déjà existants")
    end
  end
end

# Exécuter seeds
GameHub.Repo.Seeds.run()
