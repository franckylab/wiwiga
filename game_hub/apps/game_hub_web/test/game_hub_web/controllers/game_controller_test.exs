defmodule GameHubWeb.GameControllerTest do
  @moduledoc """
  Tests pour le GameController.
  
  Tests:
  - Liste jeux
  - Détails jeu
  - Rejoindre partie (validation)
  - État partie
  - Authorization
  """
  
  use ExUnit.Case, async: false
  use Plug.Test
  
  alias GameHubWeb.GameController
  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Games.GameConfig
  
  setup do
    # Nettoyer DB
    Repo.delete_all(GameConfig)
    Repo.delete_all(User)
    
    # Créer utilisateur de test
    user = Repo.insert!(%User{
      phone: "+237699000200",
      name: "Game Test User",
      balance: 200000,
      is_active: true,
      has_verified_kyc: true
    })
    
    # Créer configs de jeux
    dice_config = Repo.insert!(%GameConfig{
      game_type: "dice",
      name: "Jeu de Dés",
      description: "Pariez sur la somme des dés",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0.05"),
      commission_mode: "percentage",
      is_active: true,
      config: %{"dice_count" => 3}
    })
    
    inactive_config = Repo.insert!(%GameConfig{
      game_type: "inactive",
      name: "Jeu Inactif",
      description: "Ce jeu est désactivé",
      min_bet: 1000,
      max_bet: 50000,
      commission_rate: Decimal.new("0.05"),
      commission_mode: "percentage",
      is_active: false
    })
    
    %{
      user: user,
      dice_config: dice_config,
      inactive_config: inactive_config
    }
  end
  
  describe "index/2 - Liste jeux" do
    test "retourne uniquement les jeux actifs", %{dice_config: config} do
      conn = conn(:get, "/api/games")
      conn = GameController.index(conn, %{})
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["success"] == true
      assert length(response["data"]) == 1
      assert hd(response["data"])["id"] == "dice"
    end
    
    test "retourne liste vide si aucun jeu actif" do
      # Supprimer tous les jeux actifs
      Repo.delete_all(GameConfig)
      
      conn = conn(:get, "/api/games")
      conn = GameController.index(conn, %{})
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["success"] == true
      assert response["data"] == []
    end
    
    test "structure de réponse correcte", %{dice_config: config} do
      conn = conn(:get, "/api/games")
      conn = GameController.index(conn, %{})
      
      response = Jason.decode!(conn.resp_body)
      game = hd(response["data"])
      
      assert Map.has_key?(game, "id")
      assert Map.has_key?(game, "name")
      assert Map.has_key?(game, "description")
      assert Map.has_key?(game, "min_bet")
      assert Map.has_key?(game, "max_bet")
      assert Map.has_key?(game, "commission_rate")
      assert Map.has_key?(game, "status")
      assert Map.has_key?(game, "players_online")
    end
  end
  
  describe "show/2 - Détails jeu" do
    test "retourne détails d'un jeu existant", %{dice_config: config} do
      conn = conn(:get, "/api/games/dice")
      conn = GameController.show(conn, %{"game_id" => "dice"})
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["success"] == true
      data = response["data"]
      
      assert data["id"] == "dice"
      assert data["name"] == "Jeu de Dés"
      assert data["min_bet"] == 1000
      assert data["max_bet"] == 100000
      assert data["commission_rate"] == 0.05
    end
    
    test "retourne 404 si jeu inexistant" do
      conn = conn(:get, "/api/games/nonexistent")
      conn = GameController.show(conn, %{"game_id" => "nonexistent"})
      
      assert conn.status == 404
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "GAME_NOT_FOUND"
    end
    
    test "retourne détails avec config", %{dice_config: config} do
      conn = conn(:get, "/api/games/dice")
      conn = GameController.show(conn, %{"game_id" => "dice"})
      
      response = Jason.decode!(conn.resp_body)
      data = response["data"]
      
      assert Map.has_key?(data, "config")
      assert data["config"]["dice_count"] == 3
    end
  end
  
  describe "join/2 - Rejoindre partie" do
    test "accepte mise dans les limites", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 5000}
      
      # Simuler utilisateur authentifié
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      # Devrait être 202 (waiting) ou 200 (matched)
      assert conn.status in [200, 202]
    end
    
    test "rejette mise trop basse", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 500}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "BET_TOO_LOW"
    end
    
    test "rejette mise trop haute", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 200000}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "BET_TOO_HIGH"
    end
    
    test "rejette si solde insuffisant", %{user: user, dice_config: config} do
      # Créer utilisateur avec peu de balance
      poor_user = Repo.insert!(%User{
        phone: "+237699000201",
        name: "Poor User",
        balance: 500,
        is_active: true
      })
      
      params = %{"game_id" => "dice", "bet_amount" => 1000}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(poor_user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "INSUFFICIENT_FUNDS"
    end
    
    test "rejette si jeu inexistant", %{user: user} do
      params = %{"game_id" => "nonexistent", "bet_amount" => 5000}
      
      conn =
        conn(:post, "/api/games/nonexistent/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 404
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "GAME_NOT_FOUND"
    end
    
    test "requiert paramètre bet_amount", %{user: user} do
      params = %{"game_id" => "dice"}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"]["code"] == "VALIDATION_ERROR"
    end
  end
  
  describe "game_state/2 - État partie" do
    test "retourne 404 si partie inexistante" do
      conn = conn(:get, "/api/games/nonexistent/state")
      conn = GameController.game_state(conn, %{"game_id" => "nonexistent"})
      
      assert conn.status == 404
    end
    
    test "retourne état si partie existe" do
      # Créer une partie dans Redis pour le test
      game_id = "test_game_state_123"
      game_key = "game:#{game_id}"
      
      Redix.command(GameHub.Redis, ["HSET", game_key, "status", "in_progress"])
      Redix.command(GameHub.Redis, ["HSET", game_key, "players", "player1,player2"])
      Redix.command(GameHub.Redis, ["HSET", game_key, "game_type", "dice"])
      
      conn = conn(:get, "/api/games/#{game_id}/state")
      conn = GameController.game_state(conn, %{"game_id" => game_id})
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["success"] == true
      data = response["data"]
      
      assert data["status"] == "in_progress"
      assert data["players"] == ["player1", "player2"]
      assert data["game_type"] == "dice"
      
      # Nettoyer
      Redix.command(GameHub.Redis, ["DEL", game_key])
    end
  end
  
  describe "validation des limites" do
    test "mise = min_bet est acceptée", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 1000}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      # Devrait passer la validation
      assert conn.status in [200, 202]
    end
    
    test "mise = max_bet est acceptée", %{user: user, dice_config: config} do
      # Créer utilisateur avec beaucoup de balance
      rich_user = Repo.insert!(%User{
        phone: "+237699000202",
        name: "Rich User",
        balance: 200000,
        is_active: true
      })
      
      params = %{"game_id" => "dice", "bet_amount" => 100000}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(rich_user.id))
      
      conn = GameController.join(conn, params)
      
      # Devrait passer la validation
      assert conn.status in [200, 202]
    end
    
    test "mise = min_bet - 1 est rejetée", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 999}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
    end
    
    test "mise = max_bet + 1 est rejetée", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 100001}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status == 400
    end
  end
  
  describe "intégration avec Matchmaking" do
    test "rejoindre file d'attente fonctionne", %{user: user, dice_config: config} do
      params = %{"game_id" => "dice", "bet_amount" => 5000}
      
      conn =
        conn(:post, "/api/games/dice/join", params)
        |> Plug.Conn.put_private(:current_user_id, to_string(user.id))
      
      conn = GameController.join(conn, params)
      
      assert conn.status in [200, 202]
      response = Jason.decode!(conn.resp_body)
      
      # Devrait retourner un statut
      assert Map.has_key?(response["data"], "status")
      assert response["data"]["status"] in ["waiting", "matched"]
    end
  end
end
