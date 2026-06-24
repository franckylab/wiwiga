# ==================================
# WIWIGA - Controller Health Check
# ==================================
# Endpoints de monitoring et santé du système

defmodule GameHubWeb.HealthController do
  @moduledoc """
  Controller pour les checks de santé du système.
  
  ## Endpoints
  GET /api/health          - Santé générale
  GET /api/health/ready    - Prêt à recevoir du trafic
  GET /api/health/db       - Santé base de données
  GET /api/health/redis    - Santé Redis
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Repo, Redis, EnvConfig}
  import Ecto.Query
  
  @doc """
  GET /api/health
  
  Retourne l'état global du système.
  """
  def health(conn, _params) do
    checks = %{
      database: check_database(),
      redis: check_redis(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    status =
      if Enum.all?([checks.database.status, checks.redis.status], fn s -> s == "healthy" end) do
        "healthy"
      else
        "degraded"
      end
    
    conn
    |> put_status(if status == "healthy", do: 200, else: 503)
    |> json(%{
      status: status,
      version: Application.spec(:game_hub, :vsn) |> to_string(),
      environment: Mix.env() |> to_string(),
      checks: checks
    })
  end
  
  @doc """
  GET /api/health/ready
  
  Vérifie si l'application est prête à recevoir du trafic.
  """
  def ready(conn, _params) do
    db_ready = database_ready?()
    redis_ready = redis_ready?()
    
    if db_ready && redis_ready do
      conn
      |> put_status(200)
      |> json(%{
        status: "ready",
        database: true,
        redis: true
      })
    else
      conn
      |> put_status(503)
      |> json(%{
        status: "not_ready",
        database: db_ready,
        redis: redis_ready
      })
    end
  end
  
  @doc """
  GET /api/health/db
  
  Vérifie la connectivité PostgreSQL.
  """
  def db_health(conn, _params) do
    case check_database() do
      %{status: "healthy", latency_ms: latency} ->
        conn
        |> put_status(200)
        |> json(%{
          status: "healthy",
          latency_ms: latency,
          connections: get_db_connection_count()
        })
      
      %{status: "unhealthy", error: error} ->
        conn
        |> put_status(503)
        |> json(%{
          status: "unhealthy",
          error: error
        })
    end
  end
  
  @doc """
  GET /api/health/redis
  
  Vérifie la connectivité Redis.
  """
  def redis_health(conn, _params) do
    case check_redis() do
      %{status: "healthy", latency_ms: latency} ->
        conn
        |> put_status(200)
        |> json(%{
          status: "healthy",
          latency_ms: latency,
          memory_used: get_redis_memory(),
          connected_clients: get_redis_clients()
        })
      
      %{status: "unhealthy", error: error} ->
        conn
        |> put_status(503)
        |> json(%{
          status: "unhealthy",
          error: error
        })
    end
  end
  
  # Fonctions privées
  
  defp check_database do
    start_time = System.monotonic_time(:millisecond)
    
    result =
      try do
        # Test simple de connexion DB
        %{num_rows: 1} = Repo.query!("SELECT 1")
        :ok
      rescue
        error ->
          IO.puts("DB Health Check Error: #{inspect(error)}")
          :error
      end
    
    latency = System.monotonic_time(:millisecond) - start_time
    
    case result do
      :ok -> %{status: "healthy", latency_ms: latency}
      :error -> %{status: "unhealthy", error: "Database connection failed"}
    end
  end
  
  defp check_redis do
    start_time = System.monotonic_time(:millisecond)
    
    result =
      try do
        Redix.command(Redis, ["PING"])
      rescue
        _ -> {:error, "Redis connection failed"}
      end
    
    latency = System.monotonic_time(:millisecond) - start_time
    
    case result do
      {:ok, "PONG"} -> %{status: "healthy", latency_ms: latency}
      {:ok, _} -> %{status: "healthy", latency_ms: latency}
      {:error, error} -> %{status: "unhealthy", error: inspect(error)}
    end
  end
  
  defp database_ready? do
    match?({:ok, _}, check_database() |> Map.get(:status) |> (&(&1 == "healthy")).())
  rescue
    _ -> false
  end
  
  defp redis_ready? do
    match?({:ok, _}, check_redis() |> Map.get(:status) |> (&(&1 == "healthy")).())
  rescue
    _ -> false
  end
  
  defp get_db_connection_count do
    query = """
    SELECT count(*) 
    FROM pg_stat_activity 
    WHERE datname = current_database()
    """
    
    case Repo.one(query) do
      count when is_integer(count) -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp get_redis_memory do
    case Redix.command(Redis, ["INFO", "memory"]) do
      {:ok, info} ->
        # Parser la réponse pour trouver used_memory
        info
        |> String.split("\n")
        |> Enum.find(fn line -> String.starts_with?(line, "used_memory:") end)
        |> case do
          nil -> 0
          line ->
            line
            |> String.split(":")
            |> tl()
            |> hd()
            |> String.trim()
            |> Integer.parse()
            |> elem(0)
        end
      
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp get_redis_clients do
    case Redix.command(Redis, ["INFO", "clients"]) do
      {:ok, info} ->
        info
        |> String.split("\n")
        |> Enum.find(fn line -> String.starts_with?(line, "connected_clients:") end)
        |> case do
          nil -> 0
          line ->
            line
            |> String.split(":")
            |> tl()
            |> hd()
            |> String.trim()
            |> Integer.parse()
            |> elem(0)
        end
      
      _ -> 0
    end
  rescue
    _ -> 0
  end
end
