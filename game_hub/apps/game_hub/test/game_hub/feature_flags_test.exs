# ==================================
# WIWIGA - Tests FeatureFlags
# ==================================
# Module: GameHub.FeatureFlagsTest
# Description: Tests unitaires pour module feature flags

defmodule GameHub.FeatureFlagsTest do
  use GameHub.DataCase
  
  alias GameHub.FeatureFlags
  
  describe "enabled?/1" do
    test "returns false for non-existent flag" do
      refute FeatureFlags.enabled?("non_existent_flag")
    end
    
    test "returns true when flag is fully enabled" do
      FeatureFlags.create_or_update(%{
        flag_name: "test_full_enabled",
        enabled: true,
        percentage_rollout: 100
      })
      
      assert FeatureFlags.enabled?("test_full_enabled")
    end
    
    test "returns false when flag is disabled" do
      FeatureFlags.create_or_update(%{
        flag_name: "test_disabled",
        enabled: false,
        percentage_rollout: 0
      })
      
      refute FeatureFlags.enabled?("test_disabled")
    end
    
    test "returns true for whitelisted user" do
      FeatureFlags.create_or_update(%{
        flag_name: "test_whitelist",
        enabled: true,
        percentage_rollout: 0,
        user_ids_whitelist: [1, 2, 3]
      })
      
      assert FeatureFlags.enabled?("test_whitelist", 1)
      refute FeatureFlags.enabled?("test_whitelist", 99)
    end
    
    test "returns false for blacklisted user" do
      FeatureFlags.create_or_update(%{
        flag_name: "test_blacklist",
        enabled: true,
        percentage_rollout: 100,
        user_ids_blacklist: [5, 6, 7]
      })
      
      refute FeatureFlags.enabled?("test_blacklist", 5)
      assert FeatureFlags.enabled?("test_blacklist", 99)
    end
  end
  
  describe "create_or_update/1" do
    test "creates new flag" do
      assert {:ok, flag} = FeatureFlags.create_or_update(%{
        flag_name: "new_flag",
        enabled: true,
        percentage_rollout: 50
      })
      
      assert flag.flag_name == "new_flag"
      assert flag.enabled == true
      assert flag.percentage_rollout == 50
    end
    
    test "updates existing flag" do
      FeatureFlags.create_or_update(%{
        flag_name: "update_flag",
        enabled: false,
        percentage_rollout: 10
      })
      
      assert {:ok, updated} = FeatureFlags.create_or_update(%{
        flag_name: "update_flag",
        enabled: true,
        percentage_rollout: 75
      })
      
      assert updated.enabled == true
      assert updated.percentage_rollout == 75
    end
    
    test "validates percentage_rollout range" do
      assert {:error, changeset} = FeatureFlags.create_or_update(%{
        flag_name: "invalid_flag",
        enabled: true,
        percentage_rollout: 150
      })
      
      assert errors_on(changeset)[:percentage_rollout]
    end
  end
  
  describe "kill_switch/1" do
    test "disables flag immediately" do
      FeatureFlags.create_or_update(%{
        flag_name: "kill_test",
        enabled: true,
        percentage_rollout: 100
      })
      
      assert FeatureFlags.enabled?("kill_test")
      
      assert {:ok, _} = FeatureFlags.kill_switch("kill_test")
      
      refute FeatureFlags.enabled?("kill_test")
    end
  end
end
