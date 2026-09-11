ExUnit.start()

# Les tests utilisent la base dédiée wiwiga_test (config/test.exs)
# avec nettoyage explicite par Repo.delete_all dans les setup.

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
    |> GameHub.Users.User.registration_changeset(final_attrs)
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
  Nettoie toutes les données de test (ordre FK-safe : enfants d'abord).
  À appeler en tête de chaque `setup` — la base wiwiga_test est partagée
  entre fichiers sans sandbox, et les écritures réussissent réellement
  (les inserts partiels d'hier masquaient les nettoyages incomplets).
  """
  def cleanup_test_data do
    import Ecto.Query
    alias GameHub.Repo

    # Notifications (enfants d'abord)
    Repo.delete_all(GameHub.Notifications.Delivery)
    Repo.delete_all(GameHub.Notifications.Notification)
    Repo.delete_all(GameHub.Notifications.DeviceToken)
    Repo.delete_all(GameHub.Notifications.Preference)
    Repo.delete_all(GameHub.Notifications.Suppression)
    Repo.delete_all(GameHub.Notifications.Provider)
    Repo.delete_all(GameHub.Notifications.Template)
    Repo.delete_all(GameHub.Notifications.RoutingRule)
    # Social
    Repo.delete_all(GameHub.Friends.FriendMessage)
    Repo.delete_all(GameHub.Friends.FriendActivity)
    Repo.delete_all(GameHub.Friends.Friendship)
    # Jetons + monétaire
    Repo.delete_all(GameHub.Tokens.UserPromoToken)
    Repo.delete_all(GameHub.Tokens.TokenTransaction)
    Repo.delete_all(GameHub.Wallet.WalletTransaction)
    # Auth / sessions / progression
    Repo.delete_all(GameHub.Auth.RefreshToken)
    Repo.delete_all(GameHub.Users.UserSession)
    Repo.delete_all(GameHub.Users.UserAchievement)
    Repo.delete_all(GameHub.Users.UserStat)
    Repo.delete_all(GameHub.ResponsibleGaming.ResponsibleGamingLimit)
    # Modération + audit (tables brutes, pas de schéma)
    Repo.delete_all("user_bans")
    Repo.delete_all(GameHub.Audit.AuditLog)
    # Jeux (lignes enfants des users)
    Repo.delete_all(GameHub.Games.GameConfig)
    # Utilisateurs en dernier
    Repo.delete_all(GameHub.Users.User)
    :ok
  end
end
