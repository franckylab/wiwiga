# ==================================
# WIWIGA - Controller Admin Export
# ==================================
# Module: GameHubWeb.AdminExportController
# Description: Export de données admin (CSV)

defmodule GameHubWeb.AdminExportController do
  @moduledoc """
  Controller pour l'export de données au format CSV.
  
  ## Endpoints
    GET /api/admin/export/users          - Export utilisateurs
    GET /api/admin/export/transactions   - Export transactions
    GET /api/admin/export/games          - Export statistiques jeux
  """

  use GameHubWeb, :controller

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.GameStats.GameStat
  alias GameHub.AuditLog
  alias GameHubWeb.AuthPlug
  import Ecto.Query

  @doc """
  GET /api/admin/export/users
  Export des utilisateurs en CSV.
  """
  def export_users(conn, _params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    users = Repo.all(
      from u in User,
        order_by: [asc: u.inserted_at],
        select: %{
          id: u.id,
          phone: u.phone,
          email: u.email,
          username: u.username,
          name: u.name,
          role: u.role,
          balance: u.balance,
          token_balance: u.token_balance,
          is_active: u.is_active,
          has_verified_kyc: u.has_verified_kyc,
          self_excluded: u.self_excluded,
          login_count: u.login_count,
          last_login_at: u.last_login_at,
          created_at: u.inserted_at
        }
    )

    csv_content = generate_csv(users, [
      "id", "phone", "email", "username", "name", "role",
      "balance", "token_balance", "is_active", "has_verified_kyc",
      "self_excluded", "login_count", "last_login_at", "created_at"
    ])

    AuditLog.log("admin_action", admin_id, "export", "users", %{
      "action" => "export_users",
      "count" => length(users)
    })

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"wiwiga_users_#{Date.utc_today()}.csv\"")
    |> send_resp(200, csv_content)
  end

  @doc """
  GET /api/admin/export/transactions
  Export des transactions en CSV.
  """
  def export_transactions(conn, params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    from_date = parse_date(params["from"], DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second))
    to_date = parse_date(params["to"], DateTime.utc_now())

    transactions = Repo.all(
      from t in WalletTransaction,
        where: t.inserted_at >= ^from_date and t.inserted_at <= ^to_date,
        order_by: [desc: t.inserted_at],
        select: %{
          id: t.id,
          user_id: t.user_id,
          type: t.type,
          amount: t.amount,
          status: t.status,
          reference: t.reference,
          created_at: t.inserted_at
        }
    )

    csv_content = generate_csv(transactions, [
      "id", "user_id", "type", "amount", "status", "reference", "created_at"
    ])

    AuditLog.log("admin_action", admin_id, "export", "transactions", %{
      "action" => "export_transactions",
      "count" => length(transactions),
      "from" => from_date,
      "to" => to_date
    })

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"wiwiga_transactions_#{Date.utc_today()}.csv\"")
    |> send_resp(200, csv_content)
  end

    @doc """
  GET /api/admin/export/games
  Export des statistiques de jeux en CSV.
  """
  def export_games(conn, _params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    stats = Repo.all(
      from gs in GameStat,
        order_by: [desc: gs.last_played_at],
        select: %{
          user_id: gs.user_id,
          game_type: gs.game_type,
          matches_played: gs.matches_played,
          wins: gs.wins,
          losses: gs.losses,
          total_wagered: gs.total_wagered,
          total_won_net: gs.total_won_net,
          biggest_win: gs.biggest_win,
          best_streak: gs.best_streak,
          last_played_at: gs.last_played_at
        }
    )

    csv_content = generate_csv(stats, [
      "user_id", "game_type", "matches_played", "wins", "losses",
      "total_wagered", "total_won_net", "biggest_win", "best_streak", "last_played_at"
    ])

    AuditLog.log("admin_action", admin_id, "export", "games", %{
      "action" => "export_games",
      "count" => length(stats)
    })

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"wiwiga_games_#{Date.utc_today()}.csv\"")
    |> send_resp(200, csv_content)
  end

  @doc """
  GET /api/admin/export/notifications
  Export des notifications + dernière tentative par canal (CSV).
  Filtres optionnels : status, event_type. Plafond 5000 lignes.
  """
  def export_notifications(conn, params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    base =
      from n in GameHub.Notifications.Notification,
        left_join: d in GameHub.Notifications.Delivery,
        on: d.notification_id == n.id,
        order_by: [desc: n.inserted_at],
        limit: 5000,
        select: %{
          id: n.id,
          event_type: n.event_type,
          user_id: n.user_id,
          title: n.title,
          category: n.category,
          priority: n.priority,
          status: n.status,
          is_read: n.is_read,
          channel: d.channel,
          provider_name: d.provider_name,
          delivery_status: d.status,
          provider_message_id: d.provider_message_id,
          error_message: d.error_message,
          sent_at: d.sent_at,
          inserted_at: n.inserted_at
        }

    base =
      case Map.get(params, "status") do
        nil -> base
        status -> from [n, d] in base, where: n.status == ^status
      end

    base =
      case Map.get(params, "event_type") do
        nil -> base
        event_type -> from [n, d] in base, where: n.event_type == ^event_type
      end

    rows = Repo.all(base)

    csv_content =
      generate_csv(rows, [
        "id", "event_type", "user_id", "title", "category", "priority",
        "status", "is_read", "channel", "provider_name", "delivery_status",
        "provider_message_id", "error_message", "sent_at", "inserted_at"
      ])

    AuditLog.log("admin_action", admin_id, "export", "notifications", %{
      "action" => "export_notifications",
      "count" => length(rows)
    })

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"wiwiga_notifications_#{Date.utc_today()}.csv\"")
    |> send_resp(200, csv_content)
  end

  # ========================================
  # Helpers
  # ========================================

  defp generate_csv(data, headers) when is_list(data) do
    header_line = Enum.join(headers, ",")

    lines = Enum.map(data, fn row ->
      headers
      |> Enum.map(fn header ->
        value = Map.get(row, String.to_existing_atom(header), "")
        csv_escape(value)
      end)
      |> Enum.join(",")
    end)

    [header_line | lines]
    |> Enum.join("\n")
  end

  defp csv_escape(nil), do: ""
  defp csv_escape(value) when is_boolean(value), do: to_string(value)
  defp csv_escape(value) when is_number(value), do: to_string(value)
  defp csv_escape(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
  defp csv_escape(value), do: to_string(value)

  defp parse_date(nil, default), do: default
  defp parse_date(date_str, _default) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ ->
        DateTime.utc_now()
    end
  end
end
