# ==================================
# WIWIGA - Module IdempotencyKey
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.IdempotencyKey
# Description: Gestion clés d'idempotence pour webhooks et transactions (Règle 2)

defmodule GameHub.IdempotencyKey do
  @moduledoc """
  Module de gestion des clés d'idempotence.
  
  Règle 2 : Prévenir les doublons de transactions
  - Stockage Redis avec TTL 24h
  - Vérification atomique
  - Retourne résultat existant si clé déjà utilisée
  
  ## Use Cases
  - Webhooks de paiement (Campay)
  - Dépôts/rtraits
  - Paris et gains
  """
  
  alias GameHub.AuditLog
  
  @doc """
  Vérifie et stocke une clé d'idempotence.
  
  ## Parameters
    - `key`: Clé unique (string)
    - `data`: Données à stocker si première utilisation
  
  ## Returns
    - `{:ok, :new, data}`: Première utilisation, données stockées
    - `{:ok, :existing, cached_data}`: Clé déjà utilisée, données existantes retournées
    - `{:error, reason}`: Erreur
  
  ## Examples
  
      iex> IdempotencyKey.store("webhook_123", %{amount: 1000})
      {:ok, :new, %{amount: 1000}}
      
      iex> IdempotencyKey.store("webhook_123", %{amount: 2000})
      {:ok, :existing, %{amount: 1000}}
  """
  @spec store(String.t(), any()) :: {:ok, :new | :existing, any()} | {:error, atom()}
  def store(key, data) do
    case check_and_set(key, data) do
      :new ->
        AuditLog.log(
          "idempotency_key_created",
          nil,
          "idempotency",
          key,
          %{status: "new"},
          %{ttl_seconds: 86400}
        )
        
        {:ok, :new, data}
      
      :existing ->
        cached_data = get(key)
        
        AuditLog.log(
          "idempotency_key_duplicate",
          nil,
          "idempotency",
          key,
          %{status: "duplicate"},
          %{}
        )
        
        {:ok, :existing, cached_data}
      
      :error ->
        {:error, :redis_error}
    end
  end
  
  @doc """
  Récupère données associées à une clé.
  
  ## Parameters
    - `key`: Clé d'idempotence
  
  ## Returns
    - `{:ok, data}`: Données trouvées
    - `{:error, :not_found}`: Clé inexistante ou expirée
  """
  @spec get(String.t()) :: {:ok, any()} | {:error, atom()}
  def get(key) do
    redis_key = "idempotency:#{key}"
    
    case Redix.command(GameHub.Redis, ["GET", redis_key]) do
      {:ok, nil} ->
        {:error, :not_found}
      
      {:ok, binary} ->
        data = :erlang.binary_to_term(binary)
        {:ok, data}
      
      {:error, _} ->
        {:error, :redis_error}
    end
  end
  
  @doc """
  Supprime une clé d'idempotence (cleanup manuel).
  
  ## Parameters
    - `key`: Clé à supprimer
  """
  @spec delete(String.t()) :: :ok | {:error, atom()}
  def delete(key) do
    redis_key = "idempotency:#{key}"
    
    case Redix.command(GameHub.Redis, ["DEL", redis_key]) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :redis_error}
    end
  end
  
  # === Fonctions Privées ===
  
  defp check_and_set(key, data) do
    redis_key = "idempotency:#{key}"
    ttl = 86400 # 24 heures
    
    # Script Lua atomique pour check-and-set
    lua_script = """
    if redis.call('EXISTS', KEYS[1]) == 1 then
      return 0
    else
      redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2])
      return 1
    end
    """
    
    binary_data = :erlang.term_to_binary(data)
    
    case Redix.command(GameHub.Redis, ["EVAL", lua_script, "1", redis_key, binary_data, to_string(ttl)]) do
      {:ok, 1} -> :new
      {:ok, 0} -> :existing
      {:error, _} -> :error
    end
  end
end
