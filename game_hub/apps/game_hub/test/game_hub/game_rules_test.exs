# ==================================
# WIWIGA - Tests GameRules
# ==================================
defmodule GameHub.GameRulesTest do
  use ExUnit.Case, async: false

  alias GameHub.GameRules
  alias GameHub.Games.GameRule

  describe "get_rules_or_default/2" do
    test "retourne les règles par défaut pour dice/normal" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      assert %GameRule{} = rules
      assert rules.game_type == "dice"
      assert rules.rule_type == "normal"
      assert rules.config["default_sets"] == 1
      assert rules.config["default_dice"] == 2
      assert rules.config["dice_faces"] == 6
    end

    test "retourne les règles par défaut pour dice/cible" do
      rules = GameRules.get_rules_or_default("dice", "cible")
      assert %GameRule{} = rules
      assert rules.rule_type == "cible"
      assert rules.config["target_vote_mode"] == "average"
    end

    test "retourne fallback pour type inconnu" do
      rules = GameRules.get_rules_or_default("unknown", "unknown")
      assert %GameRule{} = rules
      assert rules.config == %{}
    end
  end

  describe "validate_match_config/2" do
    test "valide une config correcte" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      config = %{sets: 3, dice: 2, bet_amount: 1000, players: 2}
      assert :ok = GameRules.validate_match_config(rules, config)
    end

    test "rejette trop de sets" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      config = %{sets: 100, dice: 2, bet_amount: 0, players: 2}
      assert {:error, errors} = GameRules.validate_match_config(rules, config)
      assert Enum.any?(errors, &String.contains?(&1, "sets"))
    end

    test "rejette trop de dés" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      config = %{sets: 1, dice: 10, bet_amount: 0, players: 2}
      assert {:error, errors} = GameRules.validate_match_config(rules, config)
      assert Enum.any?(errors, &String.contains?(&1, "dés"))
    end

    test "rejette mise hors limites" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      config = %{sets: 1, dice: 2, bet_amount: 999_999_999, players: 2}
      assert {:error, errors} = GameRules.validate_match_config(rules, config)
      assert Enum.any?(errors, &String.contains?(&1, "Mise"))
    end

    test "accepte mode free sans mise" do
      rules = GameRules.get_rules_or_default("dice", "normal")
      config = %{sets: 1, dice: 2, bet_amount: 0, players: 2}
      assert :ok = GameRules.validate_match_config(rules, config)
    end
  end

  describe "calculate_commission/2" do
    test "calcule 5% sur 10000" do
      # Le calcul dépend des rules en DB, sinon fallback 5%
      {:ok, commission} = GameRules.calculate_commission("dice", 10000)
      assert commission == 500
    end

    test "retourne 0 pour montant 0" do
      {:ok, commission} = GameRules.calculate_commission("dice", 0)
      assert commission == 0
    end
  end

  describe "default_config/2" do
    test "retourne config pour dice/normal" do
      config = GameRules.default_config("dice", "normal")
      assert is_map(config)
      assert config["default_sets"] == 1
      assert config["default_dice"] == 2
    end
  end

  describe "cache invalidation" do
    test "invalidate_cache ne crash pas" do
      assert :ok = GameRules.invalidate_cache("dice", "normal")
    end

    test "invalidate_all_cache ne crash pas" do
      assert :ok = GameRules.invalidate_all_cache()
    end
  end
end
