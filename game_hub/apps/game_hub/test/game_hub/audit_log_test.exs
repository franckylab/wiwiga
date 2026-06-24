# ==================================
# WIWIGA - Tests AuditLog
# ==================================
# Module: GameHub.AuditLogTest
# Description: Tests unitaires pour module audit logs

defmodule GameHub.AuditLogTest do
  use GameHub.DataCase
  
  alias GameHub.AuditLog
  
  describe "log/6" do
    test "creates audit log entry" do
      assert {:ok, log} = AuditLog.log(
        "deposit",
        1,
        "wallet",
        "user_1",
        %{amount: 1000},
        %{ip: "127.0.0.1"}
      )
      
      assert log.action == "deposit"
      assert log.user_id == 1
      assert log.entity_type == "wallet"
      assert log.entity_id == "user_1"
    end
    
    test "stores changes as map" do
      changes = %{
        balance_before: 1000,
        balance_after: 2000,
        amount: 1000
      }
      
      assert {:ok, log} = AuditLog.log(
        "bet",
        1,
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
    test "returns paginated logs" do
      # Create some logs
      Enum.each(1..5, fn i ->
        AuditLog.log("action_#{i}", i, "type", "id_#{i}", %{})
      end)
      
      assert {:ok, logs, total} = AuditLog.list_logs(%{}, 1, 3)
      
      assert length(logs) == 3
      assert total >= 5
    end
    
    test "filters by action" do
      AuditLog.log("deposit", 1, "wallet", "id_1", %{})
      AuditLog.log("withdraw", 2, "wallet", "id_2", %{})
      
      assert {:ok, logs, _} = AuditLog.list_logs(%{"action" => "deposit"}, 1, 10)
      
      assert Enum.all?(logs, fn log -> log.action == "deposit" end)
    end
    
    test "filters by entity_type" do
      AuditLog.log("action1", 1, "wallet", "id_1", %{})
      AuditLog.log("action2", 2, "game", "id_2", %{})
      
      assert {:ok, logs, _} = AuditLog.list_logs(%{"entity_type" => "wallet"}, 1, 10)
      
      assert Enum.all?(logs, fn log -> log.entity_type == "wallet" end)
    end
  end
  
  describe "get_logs_by_user/3" do
    test "returns logs for specific user" do
      AuditLog.log("action1", 1, "wallet", "id_1", %{})
      AuditLog.log("action2", 1, "game", "id_2", %{})
      AuditLog.log("action3", 2, "wallet", "id_3", %{})
      
      assert {:ok, logs, total} = AuditLog.get_logs_by_user(1, 1, 10)
      
      assert length(logs) == 2
      assert total == 2
      assert Enum.all?(logs, fn log -> log.user_id == 1 end)
    end
  end
end
