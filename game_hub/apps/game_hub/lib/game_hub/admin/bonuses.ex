# ==================================
# WIWIGA - Module Admin Bonuses
# ==================================
# Module: GameHub.Admin.Bonuses
# Description: Gestion des bonus et promotions

defmodule GameHub.Admin.Bonuses do
  @moduledoc """
  Module de gestion des bonus et promotions.

  Types de bonus:
  - `welcome`: Bonus de bienvenue (premier depot)
  - `deposit`: Bonus sur depot (pourcentage)
  - `cashback`: Cashback sur pertes
  - `tournament`: Bonus tournoi

  Fonctionnalites:
  - Creation, activation, expiration
  - Suivi de l'utilisation et du cout
  - Impact sur le NGR (bonus deduct du GGR)
  """

  alias GameHub.Repo
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  # ========================================
  # Liste des bonus
  # ========================================

  @doc """
  Liste tous les bonus avec filtres.
  """
  @spec list_bonuses(map()) :: list(map())
  def list_bonuses(filters \\ %{}) do
    query = from b in "bonuses", order_by: [desc: b.inserted_at]

    query = case Map.get(filters, "is_active") do
      nil -> query
      "true" -> from b in query, where: b.is_active == true
      "false" -> from b in query, where: b.is_active == false
      _ -> query
    end

    query = case Map.get(filters, "type") do
      nil -> query
      type -> from b in query, where: b.type == ^type
    end

    Repo.all(
      from b in query,
        select: %{
          id: b.id,
          name: b.name,
          type: b.type,
          description: b.description,
          value: b.value,
          min_deposit: b.min_deposit,
          max_bonus: b.max_bonus,
          wagering_requirement: b.wagering_requirement,
          starts_at: b.starts_at,
          expires_at: b.expires_at,
          is_active: b.is_active,
          usage_count: b.usage_count,
          total_cost: b.total_cost,
          created_by: b.created_by,
          inserted_at: b.inserted_at,
          updated_at: b.updated_at
        }
    )
  end

  @doc """
  Liste les bonus actifs et valides (non expires).
  """
  @spec list_active_bonuses() :: list(map())
  def list_active_bonuses do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.all(
      from b in "bonuses",
        where: b.is_active == true and
               (is_nil(b.starts_at) or b.starts_at <= ^now) and
               (is_nil(b.expires_at) or b.expires_at >= ^now),
        order_by: [desc: b.inserted_at],
        select: %{
          id: b.id,
          name: b.name,
          type: b.type,
          description: b.description,
          value: b.value,
          min_deposit: b.min_deposit,
          max_bonus: b.max_bonus,
          wagering_requirement: b.wagering_requirement,
          usage_count: b.usage_count,
          total_cost: b.total_cost
        }
    )
  end

  # ========================================
  # Creation / Update
  # ========================================

  @doc """
  Cree un nouveau bonus.
  """
  @spec create_bonus(map(), integer()) :: {:ok, map()} | {:error, term()}
  def create_bonus(attrs, created_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result = Repo.insert_all("bonuses", [
      %{
        name: Map.get(attrs, "name"),
        type: Map.get(attrs, "type", "deposit"),
        description: Map.get(attrs, "description", ""),
        value: Map.get(attrs, "value", 0),
        min_deposit: Map.get(attrs, "min_deposit", 0),
        max_bonus: Map.get(attrs, "max_bonus", 0),
        wagering_requirement: Map.get(attrs, "wagering_requirement", 1),
        starts_at: parse_datetime(Map.get(attrs, "starts_at")),
        expires_at: parse_datetime(Map.get(attrs, "expires_at")),
        is_active: Map.get(attrs, "is_active", true),
        usage_count: 0,
        total_cost: 0,
        created_by: created_by,
        inserted_at: now,
        updated_at: now
      }
    ], returning: true)

    case result do
      {1, [bonus]} ->
        AuditLog.log("admin_action", created_by, "bonuses", to_string(bonus.id), %{
          "action" => "create_bonus",
          "name" => bonus.name,
          "type" => bonus.type
        })
        {:ok, bonus}
      _ -> {:error, "Failed to create bonus"}
    end
  end

  @doc """
  Met a jour un bonus.
  """
  @spec update_bonus(integer(), map(), integer()) :: {:ok, map()} | {:error, term()}
  def update_bonus(bonus_id, attrs, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    updates = Enum.reduce(attrs, [updated_at: now], fn {key, value}, acc ->
      case key do
        "name" -> [{:name, value} | acc]
        "type" -> [{:type, value} | acc]
        "description" -> [{:description, value} | acc]
        "value" -> [{:value, value} | acc]
        "min_deposit" -> [{:min_deposit, value} | acc]
        "max_bonus" -> [{:max_bonus, value} | acc]
        "wagering_requirement" -> [{:wagering_requirement, value} | acc]
        "starts_at" -> [{:starts_at, parse_datetime(value)} | acc]
        "expires_at" -> [{:expires_at, parse_datetime(value)} | acc]
        "is_active" -> [{:is_active, value} | acc]
        _ -> acc
      end
    end)

    query = from b in "bonuses",
      where: b.id == ^bonus_id,
      update: [set: ^updates],
      select: %{id: b.id, name: b.name, type: b.type, value: b.value,
                is_active: b.is_active, usage_count: b.usage_count, total_cost: b.total_cost}

    result = Repo.update_all(query, [])

    result = case result do
      {1, [bonus]} -> {:ok, bonus}
      _ -> {:error, :not_found}
    end

    AuditLog.log("admin_action", updated_by, "bonuses", to_string(bonus_id), %{
      "action" => "update_bonus"
    })

    result
  end

  @doc """
  Active ou desactive un bonus.
  """
  @spec toggle_bonus(integer(), boolean(), integer()) :: {:ok, map()} | {:error, term()}
  def toggle_bonus(bonus_id, active, updated_by) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query = from b in "bonuses",
      where: b.id == ^bonus_id,
      update: [set: [is_active: ^active, updated_at: ^now]],
      select: %{id: b.id, name: b.name, is_active: b.is_active}

    result = Repo.update_all(query, [])

    case result do
      {1, [bonus]} ->
        AuditLog.log("admin_action", updated_by, "bonuses", to_string(bonus_id), %{
          "action" => "toggle_bonus",
          "active" => active
        })
        {:ok, bonus}
      _ -> {:error, :not_found}
    end
  end

  # ========================================
  # Stats d'utilisation
  # ========================================

  @doc """
  Statistiques d'utilisation d'un bonus.
  """
  @spec get_bonus_stats(integer()) :: {:ok, map()} | {:error, term()}
  def get_bonus_stats(bonus_id) do
    bonus = Repo.one(
      from b in "bonuses",
        where: b.id == ^bonus_id,
        select: %{
          id: b.id,
          name: b.name,
          type: b.type,
          value: b.value,
          usage_count: b.usage_count,
          total_cost: b.total_cost,
          is_active: b.is_active
        }
    )

    case bonus do
      nil ->
        {:error, :not_found}

      b ->
        # Claims par statut
        claims_by_status = Repo.all(
          from bc in "bonus_claims",
            where: bc.bonus_id == ^bonus_id,
            group_by: bc.status,
            select: %{status: bc.status, count: count(bc.id)}
        )

        # Total claimé
        total_claims = Repo.one(
          from bc in "bonus_claims",
            where: bc.bonus_id == ^bonus_id,
            select: count(bc.id)
        )

        total_wagered = Repo.one(
          from bc in "bonus_claims",
            where: bc.bonus_id == ^bonus_id,
            select: coalesce(sum(bc.wagered_amount), 0)
        )

        total_won = Repo.one(
          from bc in "bonus_claims",
            where: bc.bonus_id == ^bonus_id,
            select: coalesce(sum(bc.won_amount), 0)
        )

        {:ok, %{
          bonus: b,
          total_claims: total_claims,
          total_wagered: total_wagered,
          total_won: total_won,
          claims_by_status: Map.new(claims_by_status, fn c -> {c.status, c.count} end),
          roi: if(b.total_cost > 0, do: Float.round(total_won / b.total_cost * 100, 1), else: 0.0)
        }}
    end
  end

  @doc """
  Cout total des bonus sur une periode (pour calcul NGR).
  """
  @spec get_total_bonus_cost(String.t()) :: integer()
  def get_total_bonus_cost(period \\ "30d") do
    now = DateTime.utc_now()
    from_dt = case period do
      "7d" -> DateTime.add(now, -7 * 24 * 3600, :second)
      "30d" -> DateTime.add(now, -30 * 24 * 3600, :second)
      "90d" -> DateTime.add(now, -90 * 24 * 3600, :second)
      _ -> DateTime.add(now, -30 * 24 * 3600, :second)
    end

    Repo.one(
      from bc in "bonus_claims",
        where: bc.claimed_at >= ^from_dt,
        select: coalesce(sum(bc.won_amount), 0)
    ) || 0
  end

  # ========================================
  # Helpers
  # ========================================

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
  defp parse_datetime(_), do: nil
end
