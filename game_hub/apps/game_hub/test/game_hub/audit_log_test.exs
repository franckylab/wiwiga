# ==================================
# WIWIGA - Tests AuditLog
# ==================================
# Module: GameHub.AuditLogTest
# Description: Tests unitaires pour module audit logs

defmodule GameHub.AuditLogTest do
  use ExUnit.Case, async: false

  alias GameHub.AuditLog

  setup do
    GameHub.TestHelpers.cleanup_test_data()
    user1 = GameHub.TestHelpers.create_test_user()
    user2 = GameHub.TestHelpers.create_test_user()
    %{user1: user1, user2: user2}
  end

  describe "log/6" do
    test "creates audit log entry", %{user1: user1} do
      assert {:ok, log} = AuditLog.log(
        "deposit",
        user1.id,
        "wallet",
        "user_1",
        %{amount: 1000},
        %{ip: "127.0.0.1"}
      )

      assert log.action == "deposit"
      assert log.user_id == user1.id
      assert log.entity_type == "wallet"
      assert log.entity_id == "user_1"
    end

    test "stores changes as map", %{user1: user1} do
      changes = %{
        balance_before: 1000,
        balance_after: 2000,
        amount: 1000
      }

      assert {:ok, log} = AuditLog.log(
        "bet",
        user1.id,
        "game",
        "dice_123",
        changes
      )

      assert log.changes == changes
    end
    
    test "handles nil user_id for system actions" do
      assert {:ok, log} = AuditLog.log(
        "reconciliation",
        nil,
        "system",
        nil,
        %{checked: 100}
      )
      
      assert is_nil(log.user_id)
      assert log.action == "reconciliation"
    end
  end
  
  describe "list_logs/3" do
    test "returns paginated logs", %{user1: user1} do
      # Actions valides de la taxonomie d'audit (voir AuditLog)
      for action <- ["login", "logout", "bet", "winnings", "admin_action"] do
        AuditLog.log(action, user1.id, "type", "id_#{action}", %{})
      end

      assert {:ok, logs, total} = AuditLog.list_logs(%{}, 1, 3)

      assert length(logs) == 3
      assert total >= 5
    end

    test "filters by action", %{user1: user1, user2: user2} do
      AuditLog.log("deposit", user1.id, "wallet", "id_1", %{})
      AuditLog.log("withdraw", user2.id, "wallet", "id_2", %{})

      assert {:ok, logs, _} = AuditLog.list_logs(%{action: "deposit"}, 1, 10)

      assert Enum.all?(logs, fn log -> log.action == "deposit" end)
    end

    test "filters by entity_type", %{user1: user1, user2: user2} do
      AuditLog.log("bet", user1.id, "wallet", "id_1", %{})
      AuditLog.log("winnings", user2.id, "game", "id_2", %{})

      assert {:ok, logs, _} = AuditLog.list_logs(%{entity_type: "wallet"}, 1, 10)

      assert Enum.all?(logs, fn log -> log.entity_type == "wallet" end)
    end
  end

  describe "list_logs/3 filtre user_id" do
    test "returns logs for specific user", %{user1: user1, user2: user2} do
      AuditLog.log("bet", user1.id, "wallet", "id_1", %{})
      AuditLog.log("winnings", user1.id, "game", "id_2", %{})
      AuditLog.log("bet", user2.id, "wallet", "id_3", %{})

      assert {:ok, logs, total} = AuditLog.list_logs(%{user_id: user1.id}, 1, 10)

      assert length(logs) == 2
      assert total == 2
      assert Enum.all?(logs, fn log -> log.user_id == user1.id end)
    end
  end
end
