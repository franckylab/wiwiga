# ==================================
# WIWIGA - Module Admin Security
# ==================================
# Module: GameHub.Admin.Security
# Description: Gestion sécurité admin (IP whitelist, bans, audit)

defmodule GameHub.Admin.Security do
  @moduledoc """
  Module de gestion de la sécurité pour l'administration.
  
  Fonctionnalités:
  - IP whitelist management
  - User bans (temporaire/permanent)
  - Statistiques de sécurité
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  # ========================================
  # IP Whitelist
  # ========================================

  @doc """
  Liste les IPs en whitelist.
  """
  @spec list_whitelist() :: list()
  def list_whitelist do
    Repo.all(
      from w in "ip_whitelist",
        where: w.is_active == true,
        order_by: [desc: w.inserted_at],
        select: %{
          id: w.id,
          ip_address: w.ip_address,
          description: w.description,
          is_active: w.is_active,
          created_by: w.created_by,
          inserted_at: w.inserted_at
        }
    )
  end

  @doc """
  Ajoute une IP à la whitelist.
  """
  @spec add_to_whitelist(map()) :: {:ok, map()} | {:error, term()}
  def add_to_whitelist(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result = Repo.insert_all("ip_whitelist", [
      %{
        ip_address: attrs["ip_address"],
        description: attrs["description"],
        is_active: true,
        created_by: attrs["created_by"],
        inserted_at: now,
        updated_at: now
      }
    ], returning: true)

    case result do
      {1, [entry]} -> {:ok, entry}
      _ -> {:error, "Failed to add IP to whitelist"}
    end
  rescue
    error in Ecto.ConstraintError ->
      {:error, "IP already in whitelist: #{error.constraint}"}
  end

  @doc """
  Supprime une IP de la whitelist.
  """
  @spec remove_from_whitelist(String.t()) :: :ok | {:error, term()}
  def remove_from_whitelist(ip_address) do
    {count, _} = Repo.delete_all(
      from w in "ip_whitelist",
        where: w.ip_address == ^ip_address
    )

    if count > 0, do: :ok, else: {:error, :not_found}
  end

  @doc """
  Vérifie si une IP est dans la whitelist.
  """
  @spec ip_allowed?(String.t()) :: boolean()
  def ip_allowed?(ip_address) do
    # Si la whitelist est vide, tout est autorisé
    count = Repo.one(
      from w in "ip_whitelist",
        where: w.is_active == true,
        select: count(w.id)
    )

    if count == 0 do
      true
    else
      Repo.exists?(
        from w in "ip_whitelist",
          where: w.ip_address == ^ip_address and w.is_active == true
      )
    end
  end

  @doc """
  Vérifie si la whitelist IP est active (au moins une entrée active).
  """
  @spec ip_whitelist_active?() :: boolean()
  def ip_whitelist_active? do
    Repo.exists?(
      from w in "ip_whitelist",
        where: w.is_active == true
    )
  end

  # ========================================
  # User Bans
  # ========================================

  @doc """
  Bannit un utilisateur.
  Opération atomique : crée le ban + désactive l'utilisateur + log audit.
  """
  @spec ban_user(integer(), integer(), String.t(), boolean(), DateTime.t() | nil) :: {:ok, map()} | {:error, term()}
  def ban_user(user_id, banned_by, reason, is_permanent \\ true, expires_at \\ nil) do
    Repo.transaction(fn ->
      case Repo.get(User, user_id) do
        nil ->
          Repo.rollback(:user_not_found)

        user ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          # Créer le ban
          result = Repo.insert_all("user_bans", [
            %{
              user_id: user_id,
              reason: reason,
              banned_by: banned_by,
              is_permanent: is_permanent,
              is_active: true,
              expires_at: expires_at,
              inserted_at: now,
              updated_at: now
            }
          ], returning: true)

          # Désactiver l'utilisateur
          user
          |> User.changeset(%{is_active: false})
          |> Repo.update!()

          # Logger dans l'audit
          AuditLog.log("admin_action", banned_by, "users", to_string(user_id), %{
            "action" => "ban_user",
            "reason" => reason,
            "is_permanent" => is_permanent
          })

          case result do
            {1, [ban]} -> ban
            _ -> Repo.rollback(:ban_creation_failed)
          end
      end
    end)
  end

  @doc """
  Lève le ban d'un utilisateur.
  Opération atomique : met à jour le ban + réactive l'utilisateur + log audit.
  """
  @spec unban_user(integer(), integer(), String.t()) :: :ok | {:error, term()}
  def unban_user(user_id, lifted_by, reason) do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Mettre à jour le ban
      query = from b in "user_bans",
        where: b.user_id == ^user_id and b.is_active == true,
        select: b.id,
        limit: 1,
        update: [set: [
          is_active: false,
          lifted_by: ^lifted_by,
          lifted_at: ^now,
          lift_reason: ^reason,
          updated_at: ^now
        ]]

      {count, _} = Repo.update_all(query, [])

      if count == 0, do: Repo.rollback(:no_active_ban)

      # Réactiver l'utilisateur
      case Repo.get(User, user_id) do
        nil -> Repo.rollback(:user_not_found)
        user ->
          user
          |> User.changeset(%{is_active: true})
          |> Repo.update!()

          # Logger
          AuditLog.log("admin_action", lifted_by, "users", to_string(user_id), %{
            "action" => "unban_user",
            "reason" => reason
          })

          :ok
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Liste les bans actifs.
  """
  @spec list_active_bans() :: list()
  def list_active_bans do
    Repo.all(
      from b in "user_bans",
        where: b.is_active == true,
        order_by: [desc: b.inserted_at],
        select: %{
          id: b.id,
          user_id: b.user_id,
          reason: b.reason,
          banned_by: b.banned_by,
          is_permanent: b.is_permanent,
          expires_at: b.expires_at,
          inserted_at: b.inserted_at
        }
    )
  end

  # ========================================
  # Vue d'ensemble sécurité
  # ========================================

  @doc """
  Vue d'ensemble de la sécurité.
  """
  @spec get_security_overview() :: map()
  def get_security_overview do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)
    twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)

    failed_auths_1h = Repo.one(
      from a in AuditLog,
        where: a.action == "password_login_failed" and
               a.inserted_at >= ^one_hour_ago,
        select: count(a.id)
    )

    failed_auths_24h = Repo.one(
      from a in AuditLog,
        where: a.action == "password_login_failed" and
               a.inserted_at >= ^twenty_four_hours_ago,
        select: count(a.id)
    )

    rate_limited_24h = Repo.one(
      from a in AuditLog,
        where: a.action == "rate_limited" and
               a.inserted_at >= ^twenty_four_hours_ago,
        select: count(a.id)
    )

    active_bans = Repo.one(
      from b in "user_bans",
        where: b.is_active == true,
        select: count(b.id)
    )

    whitelist_count = Repo.one(
      from w in "ip_whitelist",
        where: w.is_active == true,
        select: count(w.id)
    )

    # Score de sécurité (0-100)
    score = calculate_security_score(failed_auths_24h, rate_limited_24h, active_bans)

    %{
      failed_auths_1h: failed_auths_1h,
      failed_auths_24h: failed_auths_24h,
      rate_limited_24h: rate_limited_24h,
      active_bans: active_bans,
      whitelist_count: whitelist_count,
      security_score: score,
      threat_level: cond do
        score >= 80 -> "low"
        score >= 50 -> "medium"
        true -> "high"
      end
    }
  end

  defp calculate_security_score(failed_auths, rate_limited, bans) do
    score = 100

    # Pénalités
    auth_penalty = min(div(failed_auths, 5), 30)
    rate_penalty = min(div(rate_limited, 3), 20)
    ban_penalty = min(bans * 2, 20)

    max(0, score - auth_penalty - rate_penalty - ban_penalty)
  end
end
