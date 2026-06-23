defmodule GameHub.MatchmakingTest do
  @moduledoc """
  Tests pour le module Matchmaking.
  
  Tests:
  - File d'attente Redis
  - Matching joueurs
  - TTL expiration
  - Race conditions
  - Leave queue
  """
  
  use ExUnit.Case, async: false
  
  alias GameHub.Matchmaking
  alias GameHub.Redis
  
  setup do
    # Nettoyer les clés de test dans Redis
    Redix.command(Redis, ["KEYS", "queue:test_*"])
    |> elem(1)
    |> Enum.each(fn key ->
      Redix.command(Redis, ["DEL", key])
    end)
    
    :ok
  end
  
  describe "join_queue/3" do
    test "ajoute un joueur à la file d'attente" do
      result = Matchmaking.join_queue("player1", "test_dice", 5000)
      
      assert result == {:ok, :waiting}
      
      # Vérifier dans Redis
      {:ok, exists} = Redix.command(Redis, ["EXISTS", "queue:test_dice:player1"])
      assert exists == 1
    end
    
    test "rejette un joueur déjà en file" do
      Matchmaking.join_queue("player1", "test_dice", 5000)
      
      result = Matchmaking.join_queue("player1", "test_dice", 5000)
      
      assert result == {:error, :already_queued}
    end
    
    test "crée un match quand 2 joueurs avec même mise" do
      # Premier joueur
      {:ok, :waiting} = Matchmaking.join_queue("player1", "test_dice", 5000)
      
      # Second joueur (déclenche match)
      result = Matchmaking.join_queue("player2", "test_dice", 5000)
      
      assert {:ok, :matched, game_id} = result
      assert is_binary(game_id)
      assert String.starts_with?(game_id, "test_dice_")
    end
    
    test "ne match pas si mises différentes" do
      Matchmaking.join_queue("player1", "test_dice", 5000)
      
      result = Matchmaking.join_queue("player2", "test_dice", 10000)
      
      assert result == {:ok, :waiting}
    end
    
    test "TTL de 5 minutes est défini" do
      Matchmaking.join_queue("player1", "test_dice", 5000)
      
      {:ok, ttl} = Redix.command(Redis, ["TTL", "queue:test_dice:player1"])
      
      # TTL devrait être <= 300 secondes (5 min)
      assert ttl > 0
      assert ttl <= 300
    end
  end
  
  describe "leave_queue/2" do
    test "retire un joueur de la file" do
      Matchmaking.join_queue("player1", "test_dice", 5000)
      
      result = Matchmaking.leave_queue("player1", "test_dice")
      
      assert result == :ok
      
      # Vérifier que le joueur n'est plus dans la file
      {:ok, exists} = Redix.command(Redis, ["EXISTS", "queue:test_dice:player1"])
      assert exists == 0
    end
    
    test "fonctionne même si joueur pas dans file" do
      result = Matchmaking.leave_queue("nonexistent", "test_dice")
      
      # Ne devrait pas lever d'exception
      assert result == :ok
    end
  end
  
  describe "get_queue_status/2" do
    test "retourne position et total" do
      Matchmaking.join_queue("player1", "test_dice", 5000)
      Matchmaking.join_queue("player2", "test_dice", 5000)
      Matchmaking.join_queue("player3", "test_dice", 5000)
      
      # Le match a dû se produire entre player1 et player2
      # player3 devrait être seul
      status = Matchmaking.get_queue_status("player3", "test_dice")
      
      assert Map.has_key?(status, :position)
      assert Map.has_key?(status, :total_players)
    end
  end
  
  describe "scénarios réels" do
    test "multiple joueurs avec mises identiques" do
      # 4 joueurs veulent jouer avec mise 5000
      {:ok, :waiting} = Matchmaking.join_queue("p1", "test_multi", 5000)
      {:ok, :matched, _game1} = Matchmaking.join_queue("p2", "test_multi", 5000)
      {:ok, :waiting} = Matchmaking.join_queue("p3", "test_multi", 5000)
      {:ok, :matched, _game2} = Matchmaking.join_queue("p4", "test_multi", 5000)
      
      # Deux matchs devraient avoir été créés
      # Vérifier que les files sont vides
      {:ok, count} = Redix.command(Redis, ["HLEN", "queue:test_multi"])
      assert count == 0
    end
    
    test "joueurs avec différentes mises restent en file" do
      Matchmaking.join_queue("p1", "test_diff", 5000)
      Matchmaking.join_queue("p2", "test_diff", 10000)
      Matchmaking.join_queue("p3", "test_diff", 15000)
      
      # Aucun match ne devrait se produire
      {:ok, count} = Redix.command(Redis, ["HLEN", "queue:test_diff"])
      assert count == 3
    end
    
    test "simulation concurrence - même joueur rejoint 2 fois" do
      # Première inscription
      result1 = Matchmaking.join_queue("player_concurrent", "test_race", 5000)
      
      # Seconde inscription (devrait échouer)
      result2 = Matchmaking.join_queue("player_concurrent", "test_race", 5000)
      
      assert result1 == {:ok, :waiting}
      assert result2 == {:error, :already_queued}
    end
  end
  
  describe "nettoyage files" do
    test "les joueurs matchés sont retirés de la file" do
      Matchmaking.join_queue("p1", "test_cleanup", 5000)
      Matchmaking.join_queue("p2", "test_cleanup", 5000)
      
      # Après match, la file devrait être vide
      {:ok, count} = Redix.command(Redis, ["HLEN", "queue:test_cleanup"])
      assert count == 0
    end
    
    test "joueur qui quitte réduit le count" do
      Matchmaking.join_queue("p1", "test_leave", 5000)
      Matchmaking.join_queue("p2", "test_leave", 10000)
      
      {:ok, count_before} = Redix.command(Redis, ["HLEN", "queue:test_leave"])
      assert count_before == 2
      
      Matchmaking.leave_queue("p1", "test_leave")
      
      {:ok, count_after} = Redix.command(Redis, ["HLEN", "queue:test_leave"])
      assert count_after == 1
    end
  end
  
  describe "création partie" do
    test "game_id est unique" do
      Matchmaking.join_queue("p1", "test_unique1", 5000)
      {:ok, :matched, game1} = Matchmaking.join_queue("p2", "test_unique1", 5000)
      
      Matchmaking.join_queue("p3", "test_unique2", 5000)
      {:ok, :matched, game2} = Matchmaking.join_queue("p4", "test_unique2", 5000)
      
      refute game1 == game2
    end
    
    test "partie stockée dans Redis avec TTL" do
      Matchmaking.join_queue("p1", "test_ttl", 5000)
      {:ok, :matched, game_id} = Matchmaking.join_queue("p2", "test_ttl", 5000)
      
      game_key = "game:#{game_id}"
      
      # Vérifier que la partie existe
      {:ok, exists} = Redix.command(Redis, ["EXISTS", game_key])
      assert exists == 1
      
      # Vérifier TTL (devrait être 3600s = 1h)
      {:ok, ttl} = Redix.command(Redis, ["TTL", game_key])
      assert ttl > 0
      assert ttl <= 3600
    end
  end
end
