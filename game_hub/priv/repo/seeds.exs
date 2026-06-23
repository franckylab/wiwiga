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
