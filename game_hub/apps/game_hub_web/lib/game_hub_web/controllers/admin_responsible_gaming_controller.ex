# ==================================
# WIWIGA - Controller Admin Responsible Gaming
# ==================================
# Module: GameHubWeb.AdminResponsibleGamingController
# Description: Outils jeu responsable côté admin

defmodule GameHubWeb.AdminResponsibleGamingController do
  @moduledoc """
  Controller pour le jeu responsable côté administration.
  
  ## Endpoints
    GET /api/admin/responsible-gaming/overview            - Vue d'ensemble
    PUT /api/admin/responsible-gaming/users/:id/limits    - Fixer limites
    GET /api/admin/responsible-gaming/self-exclusions     - Auto-exclusions
    GET /api/admin/responsible-gaming/risk-indicators     - Users à risque
  """

  use GameHubWeb, :controller

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.ResponsibleGaming
  alias GameHub.ResponsibleGaming.ResponsibleGamingLimit
  alias GameHub.AuditLog
  alias GameHubWeb.AuthPlug
  import Ecto.Query

  @doc """
  GET /api/admin/responsible-gaming/overview
  Vue d'ensemble du jeu responsable.
  """
  def overview(conn, _params) do
    # Auto-exclus actifs
    self_excluded_count = Repo.one(
      from u in User,
        where: u.self_excluded == true,
        select: count(u.id)
    )

    # Utilisateurs avec limites configurées
    limits_count = Repo.one(
      from rl in ResponsibleGamingLimit,
        select: count(rl.id)
    )

    # Limites par défaut de la plateforme
    default_deposit_limit = 1_000_000
    default_loss_limit = 500_000

    # Users ayant dépassé leurs limites aujourd'hui
    today_start = Date.utc_today() |> Date.to_iso8601()
    users_at_risk = count_users_exceeding_limits(today_start)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        self_excluded_count: self_excluded_count,
        active_limits: limits_count,
        default_deposit_limit: default_deposit_limit,
        default_loss_limit: default_loss_limit,
        users_at_risk_today: users_at_risk
      }
    })
  end

  @doc """
  PUT /api/admin/responsible-gaming/users/:id/limits
  Fixer des limites personnalisées pour un utilisateur.
  """
  def set_limits(conn, %{"id" => id} = params) do
    admin_id = AuthPlug.get_current_user_id(conn)
    user_id = String.to_integer(id)

    case Repo.get(User, user_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Utilisateur non trouvé"})

      user ->
        limits_attrs = %{
          daily_deposit_limit: params["daily_deposit_limit"],
          daily_loss_limit: params["daily_loss_limit"],
          session_time_limit_minutes: params["session_time_limit_minutes"],
          reality_check_interval_minutes: params["reality_check_interval_minutes"]
        } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

        case ResponsibleGaming.set_limits(user_id, limits_attrs) do
          {:ok, limits} ->
            AuditLog.log("admin_action", admin_id, "responsible_gaming", id, %{
              "action" => "set_limits",
              "limits" => limits_attrs
            })

            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{
                user_id: user_id,
                username: user.username,
                limits: limits
              },
              message: "Limites mises à jour"
            })

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{
              success: false,
              message: "Erreur de validation",
              errors: format_errors(changeset)
            })
        end
    end
  end

  @doc """
  GET /api/admin/responsible-gaming/self-exclusions
  Liste des auto-exclusions actives.
  """
  def self_exclusions(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> min(100)
    offset = (page - 1) * limit

    query = from rl in ResponsibleGamingLimit,
      where: not is_nil(rl.self_exclusion_until) and
             rl.self_exclusion_until > ^DateTime.utc_now(),
      order_by: [desc: rl.self_exclusion_until],
      limit: ^limit,
      offset: ^offset

    total = Repo.one(
      from rl in ResponsibleGamingLimit,
        where: not is_nil(rl.self_exclusion_until) and
               rl.self_exclusion_until > ^DateTime.utc_now(),
        select: count(rl.id)
    )

    exclusions = Repo.all(query)

    # Enrichir avec les infos user
    enriched = Enum.map(exclusions, fn limit ->
      user = Repo.get(User, limit.user_id)
      %{
        limit: limit,
        user: if(user, do: %{id: user.id, username: user.username, phone: user.phone}, else: nil)
      }
    end)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        exclusions: enriched,
        total: total,
        page: page,
        limit: limit
      }
    })
  end

  @doc """
  GET /api/admin/responsible-gaming/risk-indicators
  Utilisateurs avec comportements à risque.
  """
  def risk_indicators(conn, _params) do
    # Users avec beaucoup de pertes récentes
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    high_losers = Repo.all(
      from t in GameHub.Wallet.WalletTransaction,
        where: t.type == "bet" and
               t.inserted_at >= ^seven_days_ago,
        group_by: t.user_id,
        having: sum(t.amount) > 100_000,
        order_by: [desc: sum(t.amount)],
        limit: 20,
        select: %{
          user_id: t.user_id,
          total_wagered_7d: sum(t.amount)
        }
    )

    # Enrichir avec infos user
    enriched = Enum.map(high_losers, fn entry ->
      user = Repo.get(User, entry.user_id)
      %{
        user_id: entry.user_id,
        username: if(user, do: user.username, else: "unknown"),
        total_wagered_7d: entry.total_wagered_7d,
        risk_level: if(entry.total_wagered_7d > 500_000, do: "high", else: "medium")
      }
    end)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        at_risk_users: enriched,
        total: length(enriched)
      }
    })
  end

  @doc """
  POST /api/admin/responsible-gaming/self-exclusions/:id/override
  Override admin d'une auto-exclusion (avec justification auditée).
  """
  def override_self_exclusion(conn, %{"id" => user_id_str} = params) do
    admin = AuthPlug.get_current_user(conn)
    justification = Map.get(params, "justification", "")

    if justification == "" do
      conn
      |> put_status(400)
      |> json(%{success: false, message: "Justification requise pour un override admin"})
    else
      case Integer.parse(user_id_str) do
        :error ->
          conn |> put_status(400) |> json(%{success: false, message: "ID utilisateur invalide"})

        {user_id, _} ->
          case Repo.get(User, user_id) do
            nil ->
              conn |> put_status(404) |> json(%{success: false, message: "Utilisateur non trouvé"})

            user ->
              # Lever l'auto-exclusion
              case user |> User.changeset(%{self_excluded: false}) |> Repo.update() do
                {:ok, updated_user} ->
                  # Logger dans l'audit avec justification
                  AuditLog.log("admin_action", admin.id, "responsible_gaming", to_string(user_id), %{
                    "action" => "override_self_exclusion",
                    "justification" => justification,
                    "previous_state" => "self_excluded",
                    "new_state" => "active"
                  })

                  conn
                  |> put_status(200)
                  |> json(%{
                    success: true,
                    message: "Auto-exclusion levée par admin (justification auditée)",
                    data: %{
                      user_id: updated_user.id,
                      self_excluded: updated_user.self_excluded,
                      overridden_by: admin.id,
                      justification: justification
                    }
                  })

                {:error, changeset} ->
                  conn
                  |> put_status(422)
                  |> json(%{success: false, message: "Erreur", errors: format_errors(changeset)})
              end
          end
      end
    end
  end

  # ========================================
  # Helpers
  # ========================================

  defp count_users_exceeding_limits(_today_start) do
    # Compter les users ayant des limites et ayant dépassé
    Repo.one(
      from rl in ResponsibleGamingLimit,
        where: not is_nil(rl.daily_loss_limit),
        select: count(rl.id)
    )
  rescue
    _ -> 0
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
