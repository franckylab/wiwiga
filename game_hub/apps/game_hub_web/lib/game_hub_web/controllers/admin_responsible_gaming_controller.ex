# ==================================
# WIWIGA - Controller Admin Responsible Gaming
# ==================================
# Module: GameHubWeb.AdminResponsibleGamingController
# Description: Outils jeu responsable côté admin — compteurs réels
#   (exclusions actives, limites, dépassements du jour en heure de Douala),
#   auto-exclusions, indicateurs de risque (jetons, pertes nettes),
#   fixation de limites par joueur et levée d'exclusion auditée.

defmodule GameHubWeb.AdminResponsibleGamingController do
  @moduledoc """
  Controller pour le jeu responsable côté administration.

  ## Endpoints
    GET /api/admin/responsible-gaming/overview            - Vue d'ensemble
    PUT /api/admin/responsible-gaming/users/:id/limits    - Fixer limites
    GET /api/admin/responsible-gaming/self-exclusions     - Auto-exclusions
    GET /api/admin/responsible-gaming/risk-indicators     - Users à risque
    POST /api/admin/responsible-gaming/self-exclusions/:id/override - Levée auditée
  """

  use GameHubWeb, :controller

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.ResponsibleGaming
  alias GameHub.ResponsibleGaming.ResponsibleGamingLimit
  alias GameHub.Admin.PlatformConfig
  alias GameHub.AuditLog
  alias GameHubWeb.AuthPlug
  import Ecto.Query

  # Seuil "à risque" = 80% de la limite de perte journalière effective.
  @risk_ratio 0.8
  # Seuils indicateurs de risque 7j (perte nette, jetons).
  @risk_high_threshold 500_000
  @risk_medium_threshold 100_000

  @doc """
  GET /api/admin/responsible-gaming/overview
  Vue d'ensemble du jeu responsable (compteurs réels).
  """
  def overview(conn, _params) do
    now = DateTime.utc_now()

    # Auto-exclus actifs — source limits (l'enforcement lit cette table).
    self_excluded_count =
      Repo.one(
        from rl in ResponsibleGamingLimit,
          where: not is_nil(rl.self_exclusion_until) and rl.self_exclusion_until > ^now,
          select: count(rl.id)
      ) || 0

    # Utilisateurs avec limites configurées
    limits_count =
      Repo.one(from rl in ResponsibleGamingLimit, select: count(rl.id)) || 0

    # Dépassements du jour (heure de Douala) : perte nette >= limite effective.
    {users_at_risk_today, limit_breaches_today} = daily_breach_stats()

    # Limites par défaut de la plateforme (clés canoniques, jamais en dur).
    defaults = %{
      default_daily_loss_limit:
        PlatformConfig.get_int("gaming", "default_daily_loss_limit", 500_000),
      default_daily_deposit_limit:
        PlatformConfig.get_int("gaming", "default_daily_deposit_limit", 1_000_000),
      default_daily_wager_limit:
        PlatformConfig.get_int("gaming", "default_daily_wager_limit", 25_000),
      default_daily_matches_limit:
        PlatformConfig.get_int("gaming", "default_daily_matches_limit", 20),
      default_session_time_minutes:
        PlatformConfig.get_int("gaming", "default_session_time_minutes", 120),
      max_bet_per_round:
        PlatformConfig.get_int("gaming", "max_bet_per_round", 10_000),
      reality_check_interval_minutes:
        PlatformConfig.get_int("gaming", "reality_check_interval_minutes", 30)
    }

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        self_excluded_count: self_excluded_count,
        active_limits: limits_count,
        users_at_risk_today: users_at_risk_today,
        limit_breaches_today: limit_breaches_today,
        # Alias conservé pour compatibilité d'affichage existante.
        users_at_risk: users_at_risk_today,
        limit_breaches: limit_breaches_today
      }
      |> Map.merge(defaults)
    })
  end

  @doc """
  PUT /api/admin/responsible-gaming/users/:id/limits
  Fixer des limites personnalisées pour un utilisateur (appliquées
  immédiatement, y compris les hausses — acte admin audité).
  """
  def set_limits(conn, %{"id" => id} = params) do
    admin_id = AuthPlug.get_current_user_id(conn)

    with {user_id, ""} <- parse_id(id),
         %User{} = user <- Repo.get(User, user_id),
         {:ok, attrs} <- extract_admin_limits(params) do
      # L'admin applique directement (pas de différé 24h : acte encadré + audité).
      changeset = ResponsibleGamingLimit.changeset(
        ResponsibleGaming.get_limits(user_id) || %ResponsibleGamingLimit{user_id: user_id},
        attrs
      )

      case Repo.update(changeset) do
        {:ok, limits} ->
          AuditLog.log("admin_action", admin_id, "responsible_gaming", id, %{
            "action" => "set_limits",
            "limits" => attrs
          })

          conn
          |> put_status(200)
          |> json(%{
            success: true,
            data: %{
              user_id: user_id,
              username: user.username,
              limits: serialize_limits(limits)
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
    else
      :error ->
        conn
        |> put_status(400)
        |> json(%{success: false, message: "ID utilisateur invalide"})

      nil ->
        conn
        |> put_status(404)
        |> json(%{success: false, message: "Utilisateur non trouvé"})

      {:error, :invalid_value, key} ->
        conn
        |> put_status(400)
        |> json(%{success: false, message: "Valeur invalide pour #{key}"})
    end
  end

  @doc """
  GET /api/admin/responsible-gaming/self-exclusions
  Liste des auto-exclusions actives (aplatie, paginée).
  """
  def self_exclusions(conn, params) do
    page = parse_positive_int(params["page"], 1)
    limit = parse_positive_int(params["limit"], 20) |> min(100)
    offset = (page - 1) * limit
    now = DateTime.utc_now()

    base_query =
      from rl in ResponsibleGamingLimit,
        where:
          not is_nil(rl.self_exclusion_until) and rl.self_exclusion_until > ^now

    total = Repo.one(from rl in subquery(base_query), select: count(rl.id)) || 0

    exclusions =
      from(rl in subquery(base_query),
        order_by: [desc: rl.self_exclusion_until],
        limit: ^limit,
        offset: ^offset
      )
      |> Repo.all()
      |> Enum.map(fn limit ->
        user = Repo.get(User, limit.user_id)

        %{
          user_id: limit.user_id,
          username: user && user.username,
          phone: user && user.phone,
          reason: limit.self_exclusion_reason,
          excluded_until: limit.self_exclusion_until
        }
      end)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        exclusions: exclusions,
        # Alias conservé pour compatibilité.
        self_exclusions: exclusions,
        total: total,
        page: page,
        limit: limit
      }
    })
  end

  @doc """
  GET /api/admin/responsible-gaming/risk-indicators
  Utilisateurs à risque sur 7j (perte NETTE, jetons — pas mises brutes).
  """
  def risk_indicators(conn, _params) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)
    now = DateTime.utc_now()

    at_risk =
      ResponsibleGaming.net_pnl_by_user(["bet", "winnings"], seven_days_ago, now)
      |> Enum.map(fn %{user_id: uid, pnl: pnl} -> {uid, -(pnl || 0)} end)
      |> Enum.filter(fn {_, net_loss} -> net_loss > @risk_medium_threshold end)
      |> Enum.sort_by(fn {_, net_loss} -> -net_loss end)
      |> Enum.take(20)
      |> Enum.map(fn {uid, net_loss} ->
        user = Repo.get(User, uid)

        %{
          user_id: uid,
          username: if(user, do: user.username, else: "unknown"),
          total_losses_7d: net_loss,
          # Alias conservé pour compatibilité d'affichage.
          total_wagered_7d: net_loss,
          risk_level: if(net_loss > @risk_high_threshold, do: "high", else: "medium")
        }
      end)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        at_risk_users: at_risk,
        # Alias conservé pour compatibilité.
        risk_indicators: at_risk,
        total: length(at_risk)
      }
    })
  end

  @doc """
  POST /api/admin/responsible-gaming/self-exclusions/:id/override
  Levée admin d'une auto-exclusion (justification obligatoire, auditée).
  Efface les DEUX sources (limits + users) pour débloquer réellement.
  """
  def override_self_exclusion(conn, %{"id" => user_id_str} = params) do
    admin = AuthPlug.get_current_user(conn)
    justification = params |> Map.get("justification", "") |> to_string() |> String.trim()

    cond do
      justification == "" ->
        conn
        |> put_status(400)
        |> json(%{success: false, message: "Justification requise pour un override admin"})

      parse_id(user_id_str) == :error ->
        conn |> put_status(400) |> json(%{success: false, message: "ID utilisateur invalide"})

      true ->
        {user_id, ""} = parse_id(user_id_str)

        case Repo.get(User, user_id) do
          nil ->
            conn |> put_status(404) |> json(%{success: false, message: "Utilisateur non trouvé"})

          _user ->
            case ResponsibleGaming.lift_exclusion(user_id) do
              {:ok, _} ->
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
                    user_id: user_id,
                    self_excluded: false,
                    overridden_by: admin.id,
                    justification: justification
                  }
                })

              {:error, reason} ->
                conn
                |> put_status(422)
                |> json(%{success: false, message: "Levée impossible : #{inspect(reason)}"})
            end
        end
    end
  end

  # === Privé ===

  # Dépassements du jour : 1 agrégat (pas de N+1), comparaison en Elixir.
  # Retourne {joueurs à risque (>=80% limite), dépassements (>=100%)}.
  defp daily_breach_stats do
    {start_utc, end_utc} = ResponsibleGaming.douala_day_range(Date.utc_today())

    pnls = ResponsibleGaming.net_pnl_by_user(["bet", "winnings"], start_utc, end_utc)

    user_ids = Enum.map(pnls, & &1.user_id)

    limits_by_user =
      if user_ids == [] do
        %{}
      else
        ResponsibleGamingLimit
        |> where([rl], rl.user_id in ^user_ids)
        |> Repo.all()
        |> Map.new(fn rl -> {rl.user_id, rl} end)
      end

    Enum.reduce(pnls, {0, 0}, fn %{user_id: uid, pnl: pnl}, {at_risk, breached} ->
      net_loss = max(0, -(pnl || 0))
      limit = ResponsibleGaming.effective_daily_loss(Map.get(limits_by_user, uid))

      cond do
        net_loss >= limit -> {at_risk + 1, breached + 1}
        net_loss >= trunc(limit * @risk_ratio) -> {at_risk + 1, breached}
        true -> {at_risk, breached}
      end
    end)
  rescue
    _ -> {0, 0}
  end

  defp serialize_limits(limits) do
    %{
      daily_deposit_limit: limits.daily_deposit_limit,
      daily_loss_limit: limits.daily_loss_limit,
      weekly_loss_limit: limits.weekly_loss_limit,
      monthly_loss_limit: limits.monthly_loss_limit,
      daily_wager_limit: limits.daily_wager_limit,
      max_bet_amount: limits.max_bet_amount,
      daily_matches_limit: limits.daily_matches_limit,
      session_time_limit_minutes: limits.session_time_limit_minutes,
      reality_check_interval_minutes: limits.reality_check_interval_minutes,
      cooling_off_until: limits.cooling_off_until,
      self_exclusion_until: limits.self_exclusion_until,
      pending_config: limits.pending_config || %{},
      pending_effective_at: limits.pending_effective_at
    }
  end

  @admin_limit_fields ~w(daily_deposit_limit daily_loss_limit weekly_loss_limit
    monthly_loss_limit daily_wager_limit max_bet_amount daily_matches_limit
    session_time_limit_minutes reality_check_interval_minutes)

  defp extract_admin_limits(params) do
    Enum.reduce_while(@admin_limit_fields, {:ok, %{}}, fn key, {:ok, acc} ->
      case Map.get(params, key) do
        nil ->
          {:cont, {:ok, acc}}

        val ->
          case parse_limit_value(val) do
            nil -> {:halt, {:error, :invalid_value, key}}
            n -> {:cont, {:ok, Map.put(acc, String.to_atom(key), n)}}
          end
      end
    end)
  end

  defp parse_limit_value(val) when is_integer(val) and val > 0, do: val
  defp parse_limit_value(val) when is_float(val) and val > 0, do: trunc(val)

  defp parse_limit_value(val) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp parse_limit_value(_), do: nil

  defp parse_id(id) when is_integer(id) and id > 0, do: {id, ""}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {n, ""} when n > 0 -> {n, ""}
      _ -> :error
    end
  end

  defp parse_id(_), do: :error

  defp parse_positive_int(nil, default), do: default
  defp parse_positive_int(val, _default) when is_integer(val) and val > 0, do: val
  defp parse_positive_int(val, _default) when is_integer(val), do: 1

  defp parse_positive_int(val, default) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
