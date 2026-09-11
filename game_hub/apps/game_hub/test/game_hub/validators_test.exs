# ==================================
# WIWIGA - Tests Validators
# ==================================
# Module: GameHub.ValidatorsTest
# Description: Tests unitaires pour module validation

defmodule GameHub.ValidatorsTest do
  use ExUnit.Case, async: false

  alias GameHub.Validators

  setup do
    GameHub.TestHelpers.cleanup_test_data()
    :ok
  end
  
  describe "validate_bet_amount/1" do
    test "accepts valid positive integer" do
      assert :ok = Validators.validate_bet_amount(100)
      assert :ok = Validators.validate_bet_amount(1_000_000)
      assert :ok = Validators.validate_bet_amount(1_000_000_000)
    end
    
    test "rejects zero" do
      assert {:error, _} = Validators.validate_bet_amount(0)
    end
    
    test "rejects negative amounts" do
      assert {:error, _} = Validators.validate_bet_amount(-100)
      assert {:error, _} = Validators.validate_bet_amount(-1)
    end
    
    test "rejects non-integer" do
      assert {:error, _} = Validators.validate_bet_amount(100.5)
      assert {:error, _} = Validators.validate_bet_amount("100")
    end
    
    test "rejects amounts exceeding maximum" do
      assert {:error, _} = Validators.validate_bet_amount(1_000_000_001)
    end
  end
  
  describe "validate_phone/1" do
    test "accepts valid Cameroonian phone numbers" do
      assert :ok = Validators.validate_phone("+237699999999")
      assert :ok = Validators.validate_phone("+237677777777")
      assert :ok = Validators.validate_phone("+237688888888")
    end
    
    test "rejects invalid format" do
      assert {:error, _} = Validators.validate_phone("+23769999999") # 8 digits
      assert {:error, _} = Validators.validate_phone("+2376999999999") # 10 digits
      assert {:error, _} = Validators.validate_phone("699999999") # Missing country code
      assert {:error, _} = Validators.validate_phone("+237899999999") # Invalid prefix
    end
  end
  
  describe "sanitize_chat_message/1" do
    test "removes HTML tags" do
      message = "<script>alert('xss')</script>Hello"
      sanitized = Validators.sanitize_chat_message(message)
      
      refute String.contains?(sanitized, "<script>")
      assert String.contains?(sanitized, "Hello")
    end
    
    test "truncates to max length" do
      long_message = String.duplicate("a", 600)
      sanitized = Validators.sanitize_chat_message(long_message)
      
      assert String.length(sanitized) <= 500
    end
    
    test "preserves plain text" do
      message = "Hello, world!"
      assert sanitized = Validators.sanitize_chat_message(message)
      assert sanitized == message
    end
  end
  
  describe "validate_resource_ownership/3" do
    test "returns true when user owns resource" do
      user = GameHub.TestHelpers.create_test_user()
      {:ok, tx} = GameHub.Wallet.deposit(user.id, 100_000, "own_#{System.unique_integer()}")

      assert Validators.validate_resource_ownership(user.id, "transaction", tx.id)
      assert Validators.validate_resource_ownership(user.id, "user", user.id)
    end

    test "returns false when user doesn't own resource" do
      owner = GameHub.TestHelpers.create_test_user()
      stranger = GameHub.TestHelpers.create_test_user()
      {:ok, tx} = GameHub.Wallet.deposit(owner.id, 100_000, "str_#{System.unique_integer()}")

      refute Validators.validate_resource_ownership(stranger.id, "transaction", tx.id)
      refute Validators.validate_resource_ownership(owner.id, "transaction", -1)
      refute Validators.validate_resource_ownership(owner.id, "unknown_type", tx.id)
    end
  end
end
