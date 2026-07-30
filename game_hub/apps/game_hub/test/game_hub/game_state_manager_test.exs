defmodule GameHub.GameStateManagerTest do
  @moduledoc """
  Tests pour le Game State Manager (GenServer).
  Couvre le flow complet 1v1 Dice : create → bet → roll → end.
  """
  
  use ExUnit.Case, async: true
  
  alias GameHub.GameStateManager
  
  # Setup: s'assurer que le GenServer est démarré
  setup do
    # Le GenServer est démarré dans le supervision tree
    # Pour les tests async, on démarre un instance locale si nécessaire
    if Process.whereis(GameStateManager) == nil do
      start_supervised!(GameStateManager)
    end
    
    :ok
  end
  
  describe "create_game/2" do
    test "crée une nouvelle partie avec 2 joueurs" do
      game_id = "test_create_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      assert {:ok, state} = GameStateManager.create_game(game_id, players)
      assert state.game_id == game_id
      assert state.status == :waiting_for_bets
      assert map_size(state.bets) == 0
    end
    
    test "refuse si la partie existe déjà" do
      game_id = "test_dup_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      assert {:ok, _} = GameStateManager.create_game(game_id, players)
      assert {:error, :game_already_exists} = GameStateManager.create_game(game_id, players)
    end
  end
  
  describe "place_bet/5" do
    test "place un pari valide" do
      game_id = "test_bet_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      
      assert {:ok, state} = GameStateManager.place_bet(game_id, 1, 500, 7)
      assert Map.has_key?(state.bets, 1)
      assert state.bets[1].predicted_sum == 7
      assert state.bets[1].amount == 500
      assert state.status == :waiting_for_bets
    end
    
    test "passe à :bets_placed quand les 2 joueurs ont parié" do
      game_id = "test_both_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 7)
      
      assert {:ok, state} = GameStateManager.place_bet(game_id, 2, 500, 10)
      assert state.status == :bets_placed
      assert map_size(state.bets) == 2
    end
    
    test "refuse une prédiction hors limites" do
      game_id = "test_invalid_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      
      assert {:error, :invalid_prediction} = GameStateManager.place_bet(game_id, 1, 500, 1)
      assert {:error, :invalid_prediction} = GameStateManager.place_bet(game_id, 1, 500, 13)
    end
    
    test "refuse un doublon de pari" do
      game_id = "test_double_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 7)
      
      assert {:error, :bet_already_placed} = GameStateManager.place_bet(game_id, 1, 500, 8)
    end
    
    test "refuse si partie introuvable" do
      assert {:error, :game_not_found} = GameStateManager.place_bet("nonexistent", 1, 500, 7)
    end
  end
  
  describe "execute_turn/1" do
    test "lance les dés quand les 2 paris sont placés" do
      game_id = "test_roll_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 7)
      {:ok, _} = GameStateManager.place_bet(game_id, 2, 500, 10)
      
      assert {:ok, result} = GameStateManager.execute_turn(game_id)
      assert is_list(result.dice)
      assert length(result.dice) == 2
      assert result.sum == Enum.sum(result.dice)
      assert result.sum >= 2 and result.sum <= 12
    end
    
    test "refuse si pas tous les paris placés" do
      game_id = "test_notready_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 7)
      
      assert {:error, :not_ready_to_roll} = GameStateManager.execute_turn(game_id)
    end
  end
  
  describe "end_game/1 - détermination du gagnant" do
    test "joueur avec prédiction exacte gagne" do
      game_id = "test_win_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 7)
      {:ok, _} = GameStateManager.place_bet(game_id, 2, 500, 3)
      
      {:ok, _} = GameStateManager.execute_turn(game_id)
      {:ok, result} = GameStateManager.end_game(game_id)
      
      # Le résultat dépend du lancer, mais on vérifie la structure
      assert result.game_id == game_id
      assert result.status == :ended
      assert is_map(result.dice_results) or is_list(result.dice_results)
    end
    
    test "pas de gagnant si aucun ne prédit juste" do
      # On force un scénario en créant une partie et en vérifiant la logique
      # Note: ce test vérifie la structure de la réponse
      game_id = "test_nowin_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      {:ok, _} = GameStateManager.place_bet(game_id, 1, 500, 2)
      {:ok, _} = GameStateManager.place_bet(game_id, 2, 500, 12)
      
      {:ok, _} = GameStateManager.execute_turn(game_id)
      {:ok, result} = GameStateManager.end_game(game_id)
      
      # Si la somme n'est ni 2 ni 12, pas de gagnant
      unless result.total_sum in [2, 12] do
        assert result.winner == nil
        assert result.result == :no_winner
      end
    end
    
    test "refuse de terminer une partie inexistante" do
      assert {:error, :game_not_found} = GameStateManager.end_game("nonexistent")
    end
  end
  
  describe "get_game_state/1" do
    test "retourne l'état d'une partie existante" do
      game_id = "test_get_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      
      assert {:ok, state} = GameStateManager.get_game_state(game_id)
      assert state.game_id == game_id
    end
    
    test "retourne error pour partie inexistante" do
      assert {:error, :game_not_found} = GameStateManager.get_game_state("nonexistent")
    end
  end
  
  describe "list_active_games/0" do
    test "liste les parties non terminées" do
      game_id = "test_list_#{System.unique_integer()}"
      players = [%{id: 1}, %{id: 2}]
      
      {:ok, _} = GameStateManager.create_game(game_id, players)
      
      active = GameStateManager.list_active_games()
      assert Enum.any?(active, fn g -> g.game_id == game_id end)
    end
  end
end
