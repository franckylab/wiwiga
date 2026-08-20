# ==================================
# WIWIGA - Controller Jeu Responsable (utilisateur)
# ==================================
# Module: GameHubWeb.ResponsibleGamingController
# Description: Endpoints utilisateur pour gérer ses propres limites

defmodule GameHubWeb.ResponsibleGamingController do
  use GameHubWeb, :controller

  alias GameHub.ResponsibleGaming

  @doc """
  GET /api/responsible-gaming/limits
  Récupère les limites de jeu responsable de l'utilisateur connecté.
  """
  def get_my_limits(conn, _params) do
    user = conn.assigns[:current_user]

    case ResponsibleGaming.get_limits(user.id) do
      nil ->
        json(conn, %{
          "data" => %{
            "daily_deposit_limit" => nil,
            "daily_loss_limit" => nil,
            "daily_wager_limit" => nil,
            "session_time_limit_minutes" => nil,
            "reality_check_interval_minutes" => nil,
            "self_exclusion_until" => nil,
            "self_exclusion_reason" => nil,
            "is_self_excluded" => false
          }
        })

      limits ->
        json(conn, %{
          "data" => %{
            "daily_deposit_limit" => limits.daily_deposit_limit,
            "daily_loss_limit" => limits.daily_loss_limit,
            "daily_wager_limit" => limits.daily_wager_limit,
            "session_time_limit_minutes" => limits.session_time_limit_minutes,
            "reality_check_interval_minutes" => limits.reality_check_interval_minutes,
            "self_exclusion_until" => limits.self_exclusion_until,
            "self_exclusion_reason" => limits.self_exclusion_reason,
            "is_self_excluded" => is_self_excluded?(limits),
            "updated_at" => limits.updated_at
          }
        })
    end
  end

  @doc """
  PUT /api/responsible-gaming/limits
  Met à jour les limites de jeu responsable de l'utilisateur.
  """
  def update_my_limits(conn, %{"limits" => limits_data}) do
    user = conn.assigns[:current_user]

    # Filtrer uniquement les champs autorisés
    allowed_fields = %{
      "daily_deposit_limit" => parse_int(limits_data["daily_deposit_limit"]),
      "daily_loss_limit" => parse_int(limits_data["daily_loss_limit"]),
      "daily_wager_limit" => parse_int(limits_data["daily_wager_limit"]),
      "session_time_limit_minutes" => parse_int(limits_data["session_time_limit_minutes"]),
      "reality_check_interval_minutes" => parse_int(limits_data["reality_check_interval_minutes"])
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case ResponsibleGaming.set_limits(user.id, allowed_fields) do
      {:ok, updated_limits} ->
        json(conn, %{
          "status" => "success",
          "message" => "Limites mises à jour avec succès",
          "data" => %{
            "daily_deposit_limit" => updated_limits.daily_deposit_limit,
            "daily_loss_limit" => updated_limits.daily_loss_limit,
            "daily_wager_limit" => updated_limits.daily_wager_limit,
            "session_time_limit_minutes" => updated_limits.session_time_limit_minutes,
            "reality_check_interval_minutes" => updated_limits.reality_check_interval_minutes
          }
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

  @doc """
  POST /api/responsible-gaming/self-exclude
  Active l'auto-exclusion.
  """
  def self_exclude(conn, %{"duration_days" => duration_days, "reason" => reason}) do
    user = conn.assigns[:current_user]

    case ResponsibleGaming.self_exclude(user.id, duration_days, reason) do
      {:ok, _limits} ->
        json(conn, %{
          "status" => "success",
          "message" => "Auto-exclusion activée avec succès"
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

  defp is_self_excluded?(limits) do
    limits.self_exclusion_until &&
      DateTime.compare(DateTime.utc_now(), limits.self_exclusion_until) == :lt
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_int(val) when is_float(val), do: round(val)

  defp format_errors(%{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _}} ->
      %{field: to_string(field), message: msg}
    end)
  end
  defp format_errors(_), do: []
end
