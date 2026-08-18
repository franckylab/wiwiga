# ==================================
# WIWIGA - Module Admin.Export
# ==================================
# Export CSV/PDF de donnees admin
# Supporte: users, transactions, game_stats, alerts, bonuses

defmodule GameHub.Admin.Export do
  @moduledoc """
  Module d'export de donnees pour l'administration.
  Genere des fichiers CSV et les stocke avec un lien de telechargement.
  """

  alias GameHub.Repo
  import Ecto.Query

  @export_dir "exports/admin"

  # ========================================
  # EXPORT CSV
  # ========================================

  @doc """
  Exporte les utilisateurs en CSV.
  """
  def export_users(opts \\ []) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    query =
      from u in "users",
        select: %{
          id: u.id,
          username: u.username,
          phone: u.phone,
          email: u.email,
          role: u.role,
          balance: u.balance,
          token_balance: u.token_balance,
          is_active: u.is_active,
          has_verified_kyc: u.has_verified_kyc,
          login_count: u.login_count,
          last_login_at: u.last_login_at,
          inserted_at: u.inserted_at
        }

    query = apply_date_filters(query, from_date, to_date, :inserted_at)
    users = Repo.all(query)

    headers = ["id", "username", "phone", "email", "role", "balance", "token_balance", "is_active", "has_verified_kyc", "login_count", "last_login_at", "inserted_at"]

    rows =
      Enum.map(users, fn u ->
        [
          u.id,
          u.username,
          u.phone || "",
          u.email || "",
          u.role,
          u.balance,
          u.token_balance,
          u.is_active,
          u.has_verified_kyc,
          u.login_count || 0,
          format_datetime(u.last_login_at),
          format_datetime(u.inserted_at)
        ]
      end)

    generate_csv("users", headers, rows)
  end

  @doc """
  Exporte les transactions wallet en CSV.
  """
  def export_transactions(opts \\ []) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    query =
      from t in "wallet_transactions",
        select: %{
          id: t.id,
          user_id: t.user_id,
          type: t.type,
          amount: t.amount,
          balance_before: t.balance_before,
          balance_after: t.balance_after,
          description: t.description,
          reference: t.reference,
          payment_provider: t.payment_provider,
          status: t.status,
          inserted_at: t.inserted_at
        }

    query = apply_date_filters(query, from_date, to_date, :inserted_at)
    transactions = Repo.all(query)

    headers = ["id", "user_id", "type", "amount", "balance_before", "balance_after", "description", "reference", "payment_provider", "status", "inserted_at"]

    rows =
      Enum.map(transactions, fn t ->
        [
          t.id,
          t.user_id,
          t.type,
          t.amount,
          t.balance_before,
          t.balance_after,
          t.description || "",
          t.reference || "",
          t.payment_provider || "",
          t.status || "",
          format_datetime(t.inserted_at)
        ]
      end)

    generate_csv("transactions", headers, rows)
  end

  @doc """
  Exporte les statistiques de jeux en CSV.
  """
  def export_game_stats(opts \\ []) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    query =
      from g in "game_stats",
        select: %{
          id: g.id,
          user_id: g.user_id,
          game_type: g.game_type,
          matches_played: g.matches_played,
          wins: g.wins,
          losses: g.losses,
          total_wagered: g.total_wagered,
          total_won_net: g.total_won_net,
          biggest_win: g.biggest_win,
          current_streak: g.current_streak,
          best_streak: g.best_streak,
          inserted_at: g.inserted_at
        }

    query = apply_date_filters(query, from_date, to_date, :inserted_at)
    stats = Repo.all(query)

    headers = ["id", "user_id", "game_type", "matches_played", "wins", "losses", "total_wagered", "total_won_net", "biggest_win", "current_streak", "best_streak", "inserted_at"]

    rows =
      Enum.map(stats, fn g ->
        [
          g.id,
          g.user_id,
          g.game_type,
          g.matches_played,
          g.wins,
          g.losses,
          g.total_wagered,
          g.total_won_net,
          g.biggest_win || 0,
          g.current_streak || 0,
          g.best_streak || 0,
          format_datetime(g.inserted_at)
        ]
      end)

    generate_csv("game_stats", headers, rows)
  end

  @doc """
  Exporte les alertes en CSV.
  """
  def export_alerts(opts \\ []) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    query =
      from a in "admin_alerts",
        select: %{
          id: a.id,
          type: a.type,
          severity: a.severity,
          message: a.message,
          metric_value: a.metric_value,
          threshold_value: a.threshold_value,
          is_resolved: a.is_resolved,
          resolved_at: a.resolved_at,
          inserted_at: a.inserted_at
        }

    query = apply_date_filters(query, from_date, to_date, :inserted_at)
    alerts = Repo.all(query)

    headers = ["id", "type", "severity", "message", "metric_value", "threshold_value", "is_resolved", "resolved_at", "inserted_at"]

    rows =
      Enum.map(alerts, fn a ->
        [
          a.id,
          a.type,
          a.severity,
          a.message || "",
          a.metric_value,
          a.threshold_value,
          a.is_resolved,
          format_datetime(a.resolved_at),
          format_datetime(a.inserted_at)
        ]
      end)

    generate_csv("alerts", headers, rows)
  end

  @doc """
  Exporte les bonus en CSV.
  """
  def export_bonuses(_opts \\ []) do
    query =
      from b in "bonuses",
        select: %{
          id: b.id,
          name: b.name,
          type: b.type,
          value: b.value,
          min_deposit: b.min_deposit,
          max_bonus: b.max_bonus,
          wagering_requirement: b.wagering_requirement,
          is_active: b.is_active,
          usage_count: b.usage_count,
          total_cost: b.total_cost,
          starts_at: b.starts_at,
          expires_at: b.expires_at,
          inserted_at: b.inserted_at
        }

    bonuses = Repo.all(query)

    headers = ["id", "name", "type", "value", "min_deposit", "max_bonus", "wagering_requirement", "is_active", "usage_count", "total_cost", "starts_at", "expires_at", "inserted_at"]

    rows =
      Enum.map(bonuses, fn b ->
        [
          b.id,
          b.name,
          b.type,
          b.value,
          b.min_deposit,
          b.max_bonus,
          b.wagering_requirement,
          b.is_active,
          b.usage_count || 0,
          b.total_cost || 0,
          format_datetime(b.starts_at),
          format_datetime(b.expires_at),
          format_datetime(b.inserted_at)
        ]
      end)

    generate_csv("bonuses", headers, rows)
  end

  # ========================================
  # HELPERS
  # ========================================

  defp apply_date_filters(query, nil, nil, _field), do: query

  defp apply_date_filters(query, from_date, to_date, field) do
    query
    |> maybe_add_from(from_date, field)
    |> maybe_add_to(to_date, field)
  end

  defp maybe_add_from(query, nil, _field), do: query
  defp maybe_add_from(query, from_date, field) do
    from q in query, where: field(q, ^field) >= ^from_date
  end

  defp maybe_add_to(query, nil, _field), do: query
  defp maybe_add_to(query, to_date, field) do
    from q in query, where: field(q, ^field) <= ^to_date
  end

  defp generate_csv(type, headers, rows) do
    # Creer le dossier d'export
    File.mkdir_p!(@export_dir)

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    filename = "#{type}_#{timestamp}.csv"
    filepath = Path.join(@export_dir, filename)

    csv_content =
      [Enum.join(headers, ",")]
      |> Kernel.++(Enum.map(rows, fn row -> Enum.map(row, &escape_csv/1) |> Enum.join(",") end))
      |> Enum.join("\n")

    case File.write(filepath, csv_content) do
      :ok ->
        {:ok, %{
          type: type,
          filename: filename,
          filepath: filepath,
          row_count: length(rows),
          file_size: byte_size(csv_content)
        }}

      {:error, reason} ->
        {:error, "Failed to write CSV: #{reason}"}
    end
  end

  defp escape_csv(value) when is_nil(value), do: ""
  defp escape_csv(value) when is_boolean(value), do: to_string(value)
  defp escape_csv(value) when is_number(value), do: to_string(value)
  defp escape_csv(value) do
    str = to_string(value)
    if String.contains?(str, [",", "\"", "\n"]) do
      "\"#{String.replace(str, "\"", "\"\"")}\""
    else
      str
    end
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime(dt), do: to_string(dt)
end
