# ==================================
# WIWIGA - Controller Jeu Responsable (utilisateur)
# ==================================
# Module: GameHubWeb.ResponsibleGamingController
# Description: Endpoints utilisateur pour gérer ses propres limites.
#   Toutes les valeurs monétaires sont en jetons (1 jeton = 1 FCFA),
#   les durées en minutes. Hausse différée 24h (voir ResponsibleGaming).

defmodule GameHubWeb.ResponsibleGamingController do
  use GameHubWeb, :controller

  alias GameHub.ResponsibleGaming

  # Champs modifiables via PUT /limits (montants en jetons, durées en minutes).
  @allowed_limit_fields ~w(daily_deposit_limit daily_loss_limit weekly_loss_limit
    monthly_loss_limit daily_wager_limit max_bet_amount daily_matches_limit
    session_time_limit_minutes reality_check_interval_minutes)

  @doc """
  GET /api/responsible-gaming/limits
  Récupère les limites de jeu responsable de l'utilisateur connecté,
  avec hausses en attente et usage du jour (heure de Douala).
  """
  def get_my_limits(conn, _params) do
    user = conn.assigns[:current_user]
    limits = ResponsibleGaming.get_limits(user.id)

    if is_nil(limits) do
      json(conn, %{
        "data" => %{
          "daily_deposit_limit" => nil,
          "daily_loss_limit" => nil,
          "weekly_loss_limit" => nil,
          "monthly_loss_limit" => nil,
          "daily_wager_limit" => nil,
          "max_bet_amount" => nil,
          "daily_matches_limit" => nil,
          "session_time_limit_minutes" => nil,
          "reality_check_interval_minutes" => nil,
          "cooling_off_until" => nil,
          "self_exclusion_until" => nil,
          "self_exclusion_reason" => nil,
          "is_self_excluded" => false,
          "is_cooling_off" => false,
          "pending_config" => %{},
          "pending_effective_at" => nil,
          "usage_today" => empty_usage()
        }
      })
    else
      usage = ResponsibleGaming.daily_usage(user.id, limits)

      json(conn, %{
        "data" => %{
          "daily_deposit_limit" => limits.daily_deposit_limit,
          "daily_loss_limit" => limits.daily_loss_limit,
          "weekly_loss_limit" => limits.weekly_loss_limit,
          "monthly_loss_limit" => limits.monthly_loss_limit,
          "daily_wager_limit" => limits.daily_wager_limit,
          "max_bet_amount" => limits.max_bet_amount,
          "daily_matches_limit" => limits.daily_matches_limit,
          "session_time_limit_minutes" => limits.session_time_limit_minutes,
          "reality_check_interval_minutes" => limits.reality_check_interval_minutes,
          "cooling_off_until" => limits.cooling_off_until,
          "self_exclusion_until" => limits.self_exclusion_until,
          "self_exclusion_reason" => limits.self_exclusion_reason,
          "is_self_excluded" => ResponsibleGaming.excluded?(limits),
          "is_cooling_off" => ResponsibleGaming.cooling_off?(limits),
          "pending_config" => limits.pending_config || %{},
          "pending_effective_at" => limits.pending_effective_at,
          "usage_today" => %{
            "staked" => usage.staked,
            "net_loss" => usage.net_loss,
            "matches" => usage.matches,
            "deposits" => usage.deposits,
            "session_elapsed_seconds" => usage.session_elapsed_seconds
          },
          "updated_at" => limits.updated_at
        }
      })
    end
  end

  @doc """
  PUT /api/responsible-gaming/limits
  Met à jour les limites. Baisses immédiates, hausses effectives après 24h.
  Accepte aussi `cooling_off_days` (1..30) pour démarrer une pause courte.
  """
  def update_my_limits(conn, %{"limits" => limits_data} = params) when is_map(limits_data) do
    user = conn.assigns[:current_user]

    allowed =
      limits_data
      |> Enum.filter(fn {k, _} -> to_string(k) in @allowed_limit_fields end)
      |> Map.new(fn {k, v} -> {k, parse_int(v)} end)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    with :ok <- validate_positive(allowed),
         {:ok, _} <- maybe_start_cooling_off(user.id, params),
         {:ok, updated_limits} <- ResponsibleGaming.set_limits(user.id, allowed) do
      json(conn, %{
        "status" => "success",
        "message" => pending_message(updated_limits),
        "data" => %{
          "pending_config" => updated_limits.pending_config || %{},
          "pending_effective_at" => updated_limits.pending_effective_at
        }
      })
    else
      {:error, :invalid_cooling_off} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Pause invalide : cooling_off_days doit être entre 1 et 30"
        })

      {:error, :non_positive, key} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Limite invalide : #{key} doit être un entier positif"
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Impossible de mettre à jour les limites",
          "errors" => format_errors(changeset)
        })
    end
  end

  def update_my_limits(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      "status" => "error",
      "message" => "Paramètre 'limits' requis (objet)"
    })
  end

  @doc """
  POST /api/responsible-gaming/self-exclude
  Active l'auto-exclusion. `duration_days` : 1..3650, 0 = permanente.
  """
  def self_exclude(conn, params) when is_map(params) do
    user = conn.assigns[:current_user]
    duration_days = parse_int(params["duration_days"])
    reason = params["reason"] || ""

    case ResponsibleGaming.self_exclude(user.id, duration_days, to_string(reason)) do
      {:ok, _limits} ->
        json(conn, %{
          "status" => "success",
          "message" => "Auto-exclusion activée avec succès"
        })

      {:error, :invalid_duration} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Durée invalide : 1 à 3650 jours, ou 0 pour une exclusion permanente"
        })

      {:error, :invalid_reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Motif requis (3 caractères minimum)"
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          "status" => "error",
          "message" => "Impossible d'activer l'auto-exclusion",
          "errors" => format_errors(changeset)
        })
    end
  end

  # === Privé ===

  defp empty_usage do
    %{
      "staked" => 0,
      "net_loss" => 0,
      "matches" => 0,
      "deposits" => 0,
      "session_elapsed_seconds" => nil
    }
  end

  defp pending_message(%{pending_config: pending}) when is_map(pending) and map_size(pending) > 0 do
    "Limites mises à jour : les baisses sont immédiates, les hausses prendront effet dans 24h"
  end

  defp pending_message(_), do: "Limites mises à jour avec succès"

  defp validate_positive(attrs) do
    Enum.reduce_while(attrs, :ok, fn {key, val}, :ok ->
      if is_integer(val) and val > 0 do
        {:cont, :ok}
      else
        {:halt, {:error, :non_positive, key}}
      end
    end)
  end

  defp maybe_start_cooling_off(_user_id, %{"cooling_off_days" => nil}), do: {:ok, :skipped}
  defp maybe_start_cooling_off(_user_id, params) when not is_map_key(params, "cooling_off_days"), do: {:ok, :skipped}

  defp maybe_start_cooling_off(user_id, %{"cooling_off_days" => days}) do
    case parse_int(days) do
      nil -> {:error, :invalid_cooling_off}
      n -> if n >= 1 and n <= 30, do: ResponsibleGaming.start_cooling_off(user_id, n) |> cooling_result(), else: {:error, :invalid_cooling_off}
    end
  end

  defp maybe_start_cooling_off(_user_id, _), do: {:ok, :skipped}

  defp cooling_result({:ok, _}), do: {:ok, :cooling}
  defp cooling_result(err), do: err

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(val) when is_float(val), do: round(val)
  defp parse_int(_), do: nil

  defp format_errors(%{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _}} ->
      %{field: to_string(field), message: msg}
    end)
  end

  defp format_errors(_), do: []
end
