# ==================================
# WIWIGA - Module Admin Impersonation
# ==================================
# Module: GameHub.Admin.Impersonation
# Description: Impersonation utilisateur (vue admin)

defmodule GameHub.Admin.Impersonation do
  @moduledoc """
  Module de gestion de l'impersonation admin.
  
  Permet à un admin de se faire passer pour un utilisateur
  pour debugging/support. Tout est loggé dans l'audit.
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Audit.AuditLog

  @impersonation_prefix "admin_impersonation:"

  @doc """
  Démarre une session d'impersonation.
  """
  @spec start_impersonation(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def start_impersonation(admin_id, target_user_id) do
    # Vérifier que l'utilisateur cible existe
    case Repo.get(User, target_user_id) do
      nil ->
        {:error, :user_not_found}

      target_user ->
        # Stocker en Redis avec TTL 1h
        key = "#{@impersonation_prefix}#{admin_id}"
        ttl_seconds = 3600

        store_impersonation(key, admin_id, target_user_id, ttl_seconds)

        # Logger dans l'audit
        AuditLog.log("admin_action", admin_id, "users", to_string(target_user_id), %{
          "action" => "start_impersonation",
          "target_user_id" => target_user_id,
          "target_user_phone" => target_user.phone
        })

        {:ok, %{
          admin_id: admin_id,
          target_user_id: target_user_id,
          target_user_phone: target_user.phone,
          started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          expires_at: DateTime.add(DateTime.utc_now(), ttl_seconds, :second) |> DateTime.to_iso8601()
        }}
    end
  end

  @doc """
  Arrête l'impersonation.
  """
  @spec stop_impersonation(integer()) :: :ok | {:error, term()}
  def stop_impersonation(admin_id) do
    key = "#{@impersonation_prefix}#{admin_id}"

    # Récupérer les infos avant suppression pour l'audit
    target_user_id = get_impersonation_target(admin_id)

    remove_impersonation(key)

    if target_user_id do
      AuditLog.log("admin_action", admin_id, "users", to_string(target_user_id), %{
        "action" => "stop_impersonation"
      })
    end

    :ok
  end

  @doc """
  Vérifie si un admin est en session d'impersonation.
  """
  @spec is_impersonating?(integer()) :: boolean()
  def is_impersonating?(admin_id) do
    key = "#{@impersonation_prefix}#{admin_id}"
    get_impersonation_data(key) != nil
  end

  @doc """
  Retourne l'ID de l'utilisateur impersoné, ou nil.
  """
  @spec get_impersonation_target(integer()) :: integer() | nil
  def get_impersonation_target(admin_id) do
    key = "#{@impersonation_prefix}#{admin_id}"

    case get_impersonation_data(key) do
      nil -> nil
      data -> Map.get(data, "target_user_id")
    end
  end

  @doc """
  Statut de l'impersonation.
  """
  @spec status(integer()) :: map()
  def status(admin_id) do
    if is_impersonating?(admin_id) do
      target_id = get_impersonation_target(admin_id)
      target_user = Repo.get(User, target_id)

      %{
        impersonating: true,
        target_user_id: target_id,
        target_user_phone: target_user && target_user.phone,
        target_user_name: target_user && target_user.name
      }
    else
      %{impersonating: false}
    end
  end

  # ========================================
  # Redis helpers
  # ========================================

  defp store_impersonation(key, admin_id, target_user_id, ttl) do
    data = Jason.encode!(%{
      "admin_id" => admin_id,
      "target_user_id" => target_user_id,
      "started_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    })

    Redix.command(GameHub.Redis, ["SET", key, data, "EX", ttl])
  rescue
    _ -> :ok
  end

  defp get_impersonation_data(key) do
    case Redix.command(GameHub.Redis, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, data} -> Jason.decode!(data)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp remove_impersonation(key) do
    Redix.command(GameHub.Redis, ["DEL", key])
  rescue
    _ -> :ok
  end
end
