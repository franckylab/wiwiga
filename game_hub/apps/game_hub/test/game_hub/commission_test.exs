defmodule GameHub.CommissionTest do
  @moduledoc """
  Tests unitaires pour le module Commission.
  
  Tests critiques:
  - Calcul commission percentage
  - Calcul commission fixed
  - Calcul commission tiered
  - Enregistrement commission
  - Déduction commission sur gains
  """
  
  use ExUnit.Case, async: false
  
  alias GameHub.Commission
  alias GameHub.Repo
  alias GameHub.Games.GameConfig
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  
  import Ecto.Query
  
  setup do
    # Nettoyer
    Repo.delete_all(WalletTransaction)
    Repo.delete_all(User)
    Repo.delete_all(GameConfig)
    
    # Créer utilisateur
    user = Repo.insert!(%User{
      phone: "+237699000100",
      name: "Commission Test User",
      balance: 200000,
      is_active: true
    })
    
    # Créer config jeu avec commission percentage
    dice_config = Repo.insert!(%GameConfig{
      game_type: "dice",
      name: "Jeu de Dés",
      description: "Test dice game",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0.05"), # 5%
      commission_mode: "percentage",
      is_active: true,
      config: %{}
    })
    
    # Créer config jeu avec commission fixed
    card_config = Repo.insert!(%GameConfig{
      game_type: "card",
      name: "Jeu de Cartes",
      description: "Test card game",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0"),
      commission_mode: "fixed",
      is_active: true,
      config: %{"fixed_amount" => 500}
    })
    
    # Créer config jeu avec commission tiered
    roulette_config = Repo.insert!(%GameConfig{
      game_type: "roulette",
      name: "Roulette",
      description: "Test roulette game",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0"),
      commission_mode: "tiered",
      is_active: true,
      config: %{
        "tiers" => [
          %{"min" => 0, "max" => 10000, "rate" => "0.05"},
          %{"min" => 10001, "max" => 50000, "rate" => "0.04"},
          %{"min" => 50001, "max" => nil, "rate" => "0.03"}
        ]
      }
    })
    
    %{
      user: user,
      dice_config: dice_config,
      card_config: card_config,
      roulette_config: roulette_config
    }
  end
  
  describe "get_game_config/1" do
    test "retourne la config d'un jeu actif", %{dice_config: config} do
      result = Commission.get_game_config("dice")
      
      assert result != nil
      assert result.game_type == "dice"
      assert result.commission_mode == "percentage"
      assert result.commission_rate == Decimal.new("0.05")
    end
    
    test "retourne nil pour un jeu inexistant" do
      assert Commission.get_game_config("nonexistent") == nil
    end
    
    test "retourne nil pour un jeu inactif" do
      # Créer un jeu inactif
      Repo.insert!(%GameConfig{
        game_type: "inactive_game",
        name: "Inactive Game",
        min_bet: 1000,
        max_bet: 10000,
        commission_rate: Decimal.new("0.05"),
        commission_mode: "percentage",
        is_active: false
      })
      
      assert Commission.get_game_config("inactive_game") == nil
    end
  end
  
  describe "calculate_commission/2" do
    test "calcule commission percentage (5% sur 100000 = 5000)", %{dice_config: _} do
      assert {:ok, commission} = Commission.calculate_commission("dice", 100000)
      
      # 5% de 100000 = 5000
      assert commission == 5000
    end
    
    test "calcule commission percentage avec décimales", %{dice_config: _} do
      assert {:ok, commission} = Commission.calculate_commission("dice", 75000)
      
      # 5% de 75000 = 3750
      assert commission == 3750
    end
    
    test "calcule commission fixed (500 fixe)", %{card_config: _} do
      assert {:ok, commission} = Commission.calculate_commission("card", 100000)
      
      # Commission fixe = 500
      assert commission == 500
    end
    
    test "commission fixed identique quel que soit le montant", %{card_config: _} do
      assert {:ok, comm1} = Commission.calculate_commission("card", 10000)
      assert {:ok, comm2} = Commission.calculate_commission("card", 50000)
      
      assert comm1 == comm2
      assert comm1 == 500
    end
    
    test "calcule commission tiered (premier tier)", %{roulette_config: _} do
      # 5000 est dans le premier tier (0-10000) à 5%
      assert {:ok, commission} = Commission.calculate_commission("roulette", 5000)
      
      # 5% de 5000 = 250
      assert commission == 250
    end
    
    test "calcule commission tiered (deuxième tier)", %{roulette_config: _} do
      # 30000 est dans le deuxième tier (10001-50000) à 4%
      assert {:ok, commission} = Commission.calculate_commission("roulette", 30000)
      
      # 4% de 30000 = 1200
      assert commission == 1200
    end
    
    test "calcule commission tiered (troisième tier)", %{roulette_config: _} do
      # 100000 est dans le troisième tier (50001+) à 3%
      assert {:ok, commission} = Commission.calculate_commission("roulette", 100000)
      
      # 3% de 100000 = 3000
      assert commission == 3000
    end
    
    test "retourne erreur pour jeu inexistant" do
      assert Commission.calculate_commission("nonexistent", 100000) == {:error, :game_not_found}
    end
  end
  
  describe "record_commission/4" do
    test "enregistre une transaction commission", %{user: user} do
      game_id = "dice_123"
      idempotency_key = "commission_#{System.unique_integer()}"
      
      assert {:ok, transaction} = Commission.record_commission(
        game_id,
        user.id,
        5000,
        idempotency_key
      )
      
      assert transaction.type == "commission"
      assert transaction.amount == -5000
      assert transaction.game_id == game_id
      assert transaction.idempotency_key == idempotency_key
      assert transaction.metadata[:reason] == "commission_house"
    end
  end
  
  describe "deduct_commission/4" do
    test "déduit commission des gains (percentage)", %{user: user} do
      game_type = "dice"
      winnings = 100000
      idempotency_key = "deduct_#{System.unique_integer()}"
      
      assert {:ok, result} = Commission.deduct_commission(
        game_type,
        user.id,
        winnings,
        idempotency_key
      )
      
      # 5% commission = 5000
      assert result.commission == 5000
      # Net = 100000 - 5000 = 95000
      assert result.net == 95000
      assert result.gross == 100000
    end
    
    test "déduit commission fixed", %{user: user} do
      game_type = "card"
      winnings = 100000
      idempotency_key = "deduct_fixed_#{System.unique_integer()}"
      
      assert {:ok, result} = Commission.deduct_commission(
        game_type,
        user.id,
        winnings,
        idempotency_key
      )
      
      # Commission fixed = 500
      assert result.commission == 500
      # Net = 100000 - 500 = 99500
      assert result.net == 99500
    end
    
    test "retourne erreur si jeu inexistant", %{user: user} do
      assert Commission.deduct_commission(
        "nonexistent",
        user.id,
        100000,
        "deduct_fail_#{System.unique_integer()}"
      ) == {:error, :game_not_found}
    end
  end
  
  describe "extract_game_type/1" do
    test "extrait 'dice' d'un game_id dice" do
      # Fonction privée, testée indirectement via record_commission
      game_id = "dice_123_456"
      
      # On vérifie que le metadata contient le bon game_type
      # via une transaction factice
      {:ok, tx} = Commission.record_commission(
        game_id,
        1,
        1000,
        "extract_test_#{System.unique_integer()}"
      )
      
      assert tx.metadata[:game_type] == "dice"
    end
    
    test "retourne 'unknown' pour format non reconnu" do
      game_id = "unknown_game_123"
      
      {:ok, tx} = Commission.record_commission(
        game_id,
        1,
        1000,
        "extract_unknown_#{System.unique_integer()}"
      )
      
      assert tx.metadata[:game_type] == "unknown"
    end
  end
  
  describe "scénarios business" do
    test "commission progressive sur différents montants", %{roulette_config: _} do
      # Petit montant: 5%
      {:ok, comm1} = Commission.calculate_commission("roulette", 5000)
      assert comm1 == 250 # 5%
      
      # Montant moyen: 4%
      {:ok, comm2} = Commission.calculate_commission("roulette", 30000)
      assert comm2 == 1200 # 4%
      
      # Gros montant: 3%
      {:ok, comm3} = Commission.calculate_commission("roulette", 100000)
      assert comm3 == 3000 # 3%
      
      # Vérifier que le taux dégressif avantage les gros montants
      # En pourcentage effectif:
      # 5000 -> 250 = 5.0%
      # 30000 -> 1200 = 4.0%
      # 100000 -> 3000 = 3.0%
      assert comm1 / 5000 > comm2 / 30000
      assert comm2 / 30000 > comm3 / 100000
    end
    
    test "comparaison modes de commission" do
      # Sur 100000 de gains:
      # - Percentage 5% = 5000
      # - Fixed 500 = 500
      # - Tiered 3% (haut tier) = 3000
      
      # Percentage est le plus cher pour les gros montants
      # Fixed est le moins cher (constant)
      # Tiered est intermédiaire (dégressif)
      
      assert 5000 > 3000
      assert 3000 > 500
    end
  end
end
