# ==================================
# WIWIGA - Module Configuration Environnement
# ==================================
# Module pour charger et valider les variables d'environnement

defmodule GameHub.EnvConfig do
  @moduledoc """
  Gestion des variables d'environnement.
  
  ## Usage
  Toutes les configurations sensibles sont chargées depuis l'environnement.
  En développement, les valeurs par défaut sont utilisées.
  En production, les variables DOIVENT être définies.
  """
  
  @doc """
  Récupère une variable d'environnement requise.
  Lève une erreur si non définie en production.
  """
  def get!(key) do
    case System.get_env(key) do
      nil ->
        if production?() do
          raise "Environment variable #{key} is required in production"
        else
          default_value(key)
        end
      value -> value
    end
  end
  
  @doc """
  Récupère une variable d'environnement avec valeur par défaut.
  """
  def get(key, default \\ nil) do
    System.get_env(key, default)
  end
  
  @doc """
  Récupère un entier depuis l'environnement.
  """
  def get_integer(key, default \\ nil) do
    case System.get_env(key) do
      nil -> default
      value ->
        case Integer.parse(value) do
          {int, ""} -> int
          _ -> default
        end
    end
  end
  
  @doc """
  Récupère un booléen depuis l'environnement.
  """
  def get_boolean(key, default \\ false) do
    case System.get_env(key) do
      nil -> default
      value -> value in ["true", "1", "yes", "on"]
    end
  end
  
  @doc """
  Vérifie si nous sommes en production.
  """
  def production? do
    Mix.env() == :prod
  end
  
  @doc """
  Vérifie si nous sommes en développement.
  """
  def dev? do
    Mix.env() == :dev
  end
  
  @doc """
  Vérifie si nous sommes en test.
  """
  def test? do
    Mix.env() == :test
  end
  
  @doc """
  Valide que toutes les variables requises sont présentes.
  À appeler au démarrage en production.
  """
  def validate_production! do
    unless production?(), do: :ok
    
    required_vars = [
      "DATABASE_URL",
      "GUARDIAN_SECRET_KEY",
      "SECRET_KEY_BASE",
      "CAMPAY_WEBHOOK_SECRET_KEY"
    ]
    
    missing = Enum.filter(required_vars, fn var ->
      is_nil(System.get_env(var))
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      raise """
      Missing required environment variables for production:
      #{Enum.join(missing, ", ")}
      
      Please set these variables before starting the application.
      See .env.example for reference.
      """
    end
  end
  
  # Valeurs par défaut pour le développement
  defp default_value("DATABASE_URL"), do: "postgresql://postgres:postgres@localhost:5432/game_hub_dev"
  defp default_value("TEST_DATABASE_URL"), do: "postgresql://postgres:postgres@localhost:5432/game_hub_test"
  defp default_value("REDIS_URL"), do: "redis://localhost:6379"
  defp default_value("REDIS_HOST"), do: "localhost"
  defp default_value("REDIS_PORT"), do: "6379"
  defp default_value("GUARDIAN_SECRET_KEY"), do: "dev-secret-key-not-for-production-change-in-prod"
  defp default_value("GUARDIAN_ISSUER"), do: "game_hub"
  defp default_value("GUARDIAN_TTL_SECONDS"), do: "86400"
  defp default_value("CAMPAY_WEBHOOK_SECRET_KEY"), do: "CAMPAY_WEBHOOK_SECRET_KEY"
  defp default_value("CAMPAY_API_URL"), do: "https://demo.campay.net/api"
  defp default_value("PORT"), do: "4000"
  defp default_value("SECRET_KEY_BASE"), do: "dev-secret-key-base-not-for-production"
  defp default_value("DB_POOL_SIZE"), do: "10"
  defp default_value("DB_TIMEOUT"), do: "5000"
  defp default_value("LOG_LEVEL"), do: "debug"
  defp default_value("ALLOWED_ORIGINS"), do: "*"
  defp default_value(_), do: nil
end
