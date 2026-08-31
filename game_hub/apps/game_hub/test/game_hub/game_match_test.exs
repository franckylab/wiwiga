# ==================================
# WIWIGA - Tests GameMatch
# ==================================
defmodule GameHub.GameMatchTest do
  use ExUnit.Case, async: false

  alias GameHub.GameMatch

  setup do
    # S'assurer que le GenServer est démarré
    start_supervised!(GameMatch)
    :ok
  end

  describe "create_match/1" do
    test "crée un match avec config par défaut" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: :free,
        creator_id: "player_1"
      }

      assert {:ok, match} = GameMatch.create_match(config)
      assert match.game_type == "dice"
      assert match.rule_type == "normal"
      assert match.status == :waiting_players
      assert match.sets_count == 1
      assert match.dice_count == 2
    end

    test "crée un match avec config custom (Partie avec mise)" do
      config = %{
        game_type: "dice",
        rule_type: "cible",
        mode: :staked,
        sets_count: 5,
        dice_count: 3,
        bet_amount: 1000,
        max_players: 4,
        creator_id: "player_1"
      }

      assert {:ok, match} = GameMatch.create_match(config)
      assert match.mode == :staked
      assert match.sets_count == 5
      assert match.dice_count == 3
      assert match.bet_amount == 1000
      assert match.max_players == 4
    end

    test "mode betting supprimé — erreur" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: :betting,
        bet_amount: 500,
        creator_id: "player_1"
      }

      assert {:error, :invalid_mode} = GameMatch.create_match(config)
    end

    test "mode string betting supprimé — erreur" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: "betting",
        bet_amount: 500,
        creator_id: "player_1"
      }

      assert {:error, :invalid_mode} = GameMatch.create_match(config)
    end
  end

  describe "add_player/3" do
    test "ajoute un joueur au match" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:ok, updated} = GameMatch.add_player(match.match_id, "p2", "Joueur 2")
      assert length(updated.players) == 2
    end

    test "refuse si match plein" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", max_players: 2, creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2")
      assert {:error, :match_full} = GameMatch.add_player(match.match_id, "p3")
    end

    test "refuse doublon" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:error, :already_joined} = GameMatch.add_player(match.match_id, "p1")
    end

    test "refuse si match déjà démarré" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2")
      GameMatch.start_match(match.match_id)
      assert {:error, :match_already_started} = GameMatch.add_player(match.match_id, "p3")
    end
  end

  describe "start_match/1" do
    test "démarre un match avec 2 joueurs" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2")
      assert {:ok, started} = GameMatch.start_match(match.match_id)
      assert started.status == :ready
    end

    test "refuse avec 1 seul joueur" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:error, :not_enough_players} = GameMatch.start_match(match.match_id)
    end
  end

  describe "start_set/1 et roll_dice/2 (Normal)" do
    test "démarre un set et lance les dés" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set_started} = GameMatch.start_set(match.match_id)
      assert set_started.status == :set_in_progress
      assert set_started.current_set == 1

      # Lancer pour le premier joueur (selon turn order)
      first_player_id = List.first(set_started.current_set_state.turn_order)
      {:ok, result} = GameMatch.roll_dice(match.match_id, first_player_id)
      assert result.roll.player_id == first_player_id
      assert length(result.roll.dice) == 2
      assert result.roll.sum >= 2 and result.roll.sum <= 12
    end

    test "refuse lancer hors tour" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      GameMatch.start_set(match.match_id)

      # Le deuxième joueur ne devrait pas pouvoir lancer en premier
      {:ok, current} = GameMatch.get_match(match.match_id)
      second_player_id = Enum.at(current.current_set_state.turn_order, 1)
      assert {:error, :not_your_turn} = GameMatch.roll_dice(match.match_id, second_player_id)
    end
  end

  describe "vote_target/3 (Cible)" do
    test "vote pour la cible" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)
      assert set.current_set_state.vote_phase == true

      # Voter
      first_player = List.first(set.current_set_state.turn_order)
      {:ok, updated} = GameMatch.vote_target(match.match_id, first_player, 7)
      assert map_size(updated.current_set_state.votes) == 1
    end

    test "refuse double vote" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      first_player = List.first(set.current_set_state.turn_order)
      GameMatch.vote_target(match.match_id, first_player, 7)
      assert {:error, :already_voted} = GameMatch.vote_target(match.match_id, first_player, 8)
    end
  end

  describe "evaluate_set - Normal" do
    test "détermine le gagnant d'un set normal" do
      {:ok, match} = GameMatch.create_match(%{
        game_type: "dice", rule_type: "normal", sets_count: 1, creator_id: "p1"
      })
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      # Simuler les lancers des 2 joueurs
      [p1_id, p2_id] = set.current_set_state.turn_order

      {:ok, _} = GameMatch.roll_dice(match.match_id, p1_id)
      {:ok, result} = GameMatch.roll_dice(match.match_id, p2_id)

      # Le set devrait être évalué
      assert result.set_result in [:winner, :tie] or match?({:winner, _}, result.set_result)
    end
  end

  describe "get_match/1" do
    test "récupère un match existant" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:ok, retrieved} = GameMatch.get_match(match.match_id)
      assert retrieved.match_id == match.match_id
    end

    test "retourne erreur pour match inexistant" do
      assert {:error, :match_not_found} = GameMatch.get_match("nonexistent")
    end
  end

  describe "list_active_matches/0" do
    test "liste les matchs actifs" do
      GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      matches = GameMatch.list_active_matches()
      assert length(matches) >= 1
    end
  end
end
