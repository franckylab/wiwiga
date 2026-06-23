ExUnit.start()

# Configure Ecto Sandbox pour tests concurrents
Ecto.Adapters.SQL.Sandbox.mode(GameHub.Repo, :manual)

# Helper functions pour les tests
defmodule GameHub.TestHelpers do
  @moduledoc """
  Fonctions utilitaires pour les tests.
  """
  
  @doc """
  Génère une clé d'idempotence unique pour les tests.
  """
  def unique_idempotency_key(prefix \\ "test") do
    "#{prefix}_#{System.unique_integer()}_#{:os.system_time(:millisecond)}"
  end
  
  @doc """
  Crée un utilisateur de test avec balance spécifique.
  """
  def create_test_user(attrs \\ []) do
    defaults = %{
      phone: "+237699#{:rand.uniform(999999) |> Integer.to_string() |> String.pad_leading(6, "0")}",
      name: "Test User",
      balance: 100000,
      is_active: true,
      has_verified_kyc: true
    }
    
    final_attrs = Map.merge(defaults, Map.new(attrs))
    
    %GameHub.Users.User{}
    |> GameHub.Users.User.registration_changeset(Map.from_struct(final_attrs))
    |> GameHub.Repo.insert!()
  end
  
  @doc """
  Crée une config de jeu de test.
  """
  def create_game_config(attrs \\ []) do
    defaults = %{
      game_type: "test_game_#{System.unique_integer()}",
      name: "Test Game",
      description: "Test game config",
      min_bet: 1000,
      max_bet: 100000,
      commission_rate: Decimal.new("0.05"),
      commission_mode: "percentage",
      is_active: true,
      config: %{}
    }
    
    final_attrs = Map.merge(defaults, Map.new(attrs))
    
    %GameHub.Games.GameConfig{}
    |> Ecto.Changeset.cast(final_attrs, [:game_type, :name, :description, :min_bet, :max_bet, :commission_rate, :commission_mode, :is_active, :config])
    |> Ecto.Changeset.validate_required([:game_type, :name, :min_bet, :max_bet, :commission_rate])
    |> GameHub.Repo.insert!()
  end
  
  @doc """
  Nettoie toutes les données de test.
  """
  def cleanup_test_data do
    import Ecto.Query
    
    GameHub.Repo.delete_all(GameHub.Wallet.WalletTransaction)
    GameHub.Repo.delete_all(GameHub.Users.User)
    GameHub.Repo.delete_all(GameHub.Games.GameConfig)
  end
end
