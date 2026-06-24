# ==================================
# WIWIGA - Tests IdempotencyKey
# ==================================
# Module: GameHub.IdempotencyKeyTest
# Description: Tests unitaires pour gestion idempotence

defmodule GameHub.IdempotencyKeyTest do
  use ExUnit.Case, async: true
  
  alias GameHub.IdempotencyKey
  
  describe "store/2" do
    test "stores new key successfully" do
      key = "test_new_#{System.unique_integer()}"
      data = %{amount: 1000, user_id: 1}
      
      assert {:ok, :new, ^data} = IdempotencyKey.store(key, data)
    end
    
    test "returns existing data for duplicate key" do
      key = "test_dup_#{System.unique_integer()}"
      data = %{amount: 1000}
      
      {:ok, :new, _} = IdempotencyKey.store(key, data)
      
      # Second call should return existing
      assert {:ok, :existing, ^data} = IdempotencyKey.store(key, %{amount: 2000})
    end
    
    test "different keys store independently" do
      key1 = "test_ind_1_#{System.unique_integer()}"
      key2 = "test_ind_2_#{System.unique_integer()}"
      
      data1 = %{amount: 1000}
      data2 = %{amount: 2000}
      
      {:ok, :new, _} = IdempotencyKey.store(key1, data1)
      {:ok, :new, _} = IdempotencyKey.store(key2, data2)
      
      assert {:ok, :existing, ^data1} = IdempotencyKey.store(key1, %{amount: 9999})
      assert {:ok, :existing, ^data2} = IdempotencyKey.store(key2, %{amount: 9999})
    end
  end
  
  describe "get/1" do
    test "returns data for existing key" do
      key = "test_get_#{System.unique_integer()}"
      data = %{amount: 5000}
      
      IdempotencyKey.store(key, data)
      
      assert {:ok, ^data} = IdempotencyKey.get(key)
    end
    
    test "returns error for non-existent key" do
      assert {:error, :not_found} = IdempotencyKey.get("nonexistent_key_123")
    end
  end
  
  describe "delete/1" do
    test "deletes existing key" do
      key = "test_del_#{System.unique_integer()}"
      data = %{amount: 100}
      
      IdempotencyKey.store(key, data)
      
      assert :ok = IdempotencyKey.delete(key)
      assert {:error, :not_found} = IdempotencyKey.get(key)
    end
    
    test "deletes non-existent key without error" do
      assert :ok = IdempotencyKey.delete("nonexistent_#{System.unique_integer()}")
    end
  end
end
