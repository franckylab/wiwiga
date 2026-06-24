# ==================================
# WIWIGA - Tests Validators
# ==================================
# Module: GameHub.ValidatorsTest
# Description: Tests unitaires pour module validation

defmodule GameHub.ValidatorsTest do
  use ExUnit.Case, async: true
  
  alias GameHub.Validators
  
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
      # Mock test - implementation depends on Repo
      assert Validators.validate_resource_ownership(1, "transaction", 100)
    end
    
    test "returns false when user doesn't own resource" do
      refute Validators.validate_resource_ownership(1, "transaction", 100)
    end
  end
end
