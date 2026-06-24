# ==================================
# WIWIGA - Module Audit Log
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.AuditLog
# Description: Logs d'audit pour traçabilité complète des actions sensibles

defmodule GameHub.AuditLog do
  @moduledoc """
  Module de gestion des logs d'audit.
  
  Obligatoire pour (Règle 9) :
  - Transactions financières
  - Actions admin
  - Changements de sécurité
  - Signaux de fraude
  
  Rétention : 10 ans minimum
  """
  
  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query
  
  @doc """
  Crée une entrée de log d'audit.
  
  ## Parameters
    - `action`: Type d'action (string)
    - `user_id`: ID utilisateur (integer | nil)
    - `entity_type`: Type d'entité (string)
    - `entity_id`: ID entité (string | nil)
    - `changes`: Changements effectués (map)
    - `metadata`: Métadonnées additionnelles (map)
    - `conn`: Plug.Conn pour IP/User-Agent (map | nil)
  
  ## Returns
    - `{:ok, audit_log}`: Log créé
    - `{:error, changeset}`: Erreur de validation
  
  ## Examples
  
      iex> AuditLog.log("deposit", 1, "wallet", "tx_123", %{amount: 5000})
      {:ok, %AuditLog{}}
  """
  @spec log(String.t(), integer() | nil, String.t(), String.t() | nil, map(), map(), map() | nil) :: {:ok, AuditLog.t()} | {:error, Ecto.Changeset.t()}
  def log(action, user_id, entity_type, entity_id \\ nil, changes \\ %{}, metadata \\ %{}, conn \\ nil) do
    audit_data = %{
      user_id: user_id,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      changes: changes,
      metadata: metadata,
      ip_address: extract_ip(conn),
      user_agent: extract_user_agent(conn)
    }
    
    %AuditLog{}
    |> AuditLog.create_changeset(audit_data)
    |> Repo.insert()
  end
  
  @doc """
  Récupère les logs d'audit paginés.
  
  ## Parameters
    - `filters`: Filtres optionnels (map)
    - `page`: Numéro de page (integer)
    - `limit`: Limite par page (integer)
  
  ## Returns
    - `{:ok, logs, total}`: Liste des logs et total
  
  ## Examples
  
      iex> AuditLog.list_logs(%{action: "deposit"}, 1, 20)
      {:ok, [%AuditLog{}], 150}
  """
  @spec list_logs(map(), integer(), integer()) :: {:ok, list(), integer()}
  def list_logs(filters \\ %{}, page \\ 1, limit \\ 20) do
    query = build_query(filters)
    
    logs_query = from l in query,
      order_by: [desc: l.inserted_at],
      limit: ^limit,
      offset: ^((page - 1) * limit)
    
    total_query = from l in query,
      select: count(l.id)
    
    logs = Repo.all(logs_query)
    total = Repo.one(total_query)
    
    {:ok, logs, total}
  end
  
  @doc """
  Récupère les logs pour une entité spécifique.
  
  ## Parameters
    - `entity_type`: Type d'entité
    - `entity_id`: ID entité
  
  ## Returns
    - `{:ok, logs}`: Liste des logs
  
  ## Examples
  
      iex> AuditLog.logs_for_entity("wallet", "tx_123")
      {:ok, [%AuditLog{}]}
  """
  @spec logs_for_entity(String.t(), String.t()) :: {:ok, list()}
  def logs_for_entity(entity_type, entity_id) do
    logs = Repo.all(
      from l in AuditLog,
        where: l.entity_type == ^entity_type and l.entity_id == ^entity_id,
        order_by: [desc: l.inserted_at]
    )
    
    {:ok, logs}
  end
  
  # === Fonctions Privées ===
  
  defp build_query(filters) do
    query = from l in AuditLog
    
    Enum.reduce(filters, query, fn
      {:user_id, user_id}, q ->
        from l in q, where: l.user_id == ^user_id
      
      {:action, action}, q ->
        from l in q, where: l.action == ^action
      
      {:entity_type, entity_type}, q ->
        from l in q, where: l.entity_type == ^entity_type
      
      {:date_from, date_from}, q ->
        from l in q, where: l.inserted_at >= ^date_from
      
      {:date_to, date_to}, q ->
        from l in q, where: l.inserted_at <= ^date_to
      
      _, q -> q
    end)
  end
  
  defp extract_ip(nil), do: nil
  defp extract_ip(%{remote_ip: remote_ip}) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end
  
  defp extract_user_agent(nil), do: nil
  defp extract_user_agent(%{req_headers: headers}) do
    case Enum.find(headers, fn {key, _} -> key == "user-agent" end) do
      {_, value} -> value
      nil -> nil
    end
  end
end
