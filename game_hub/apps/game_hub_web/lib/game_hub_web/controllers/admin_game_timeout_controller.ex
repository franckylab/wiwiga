# ==================================
# WIWIGA - Admin GameTimeout Controller
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminGameTimeoutController
# Description: Administration des timeouts GLOBAUX (`game_timeout_configs`),
#   utilisés comme repli quand une règle (`game_rules`) ne fige pas son
#   propre `turn_timeout_seconds` (champ vide = héritage global).
#   Le `grace_period_seconds` sert aussi de délai de tour par défaut.
#
# Endpoints (scope admin, JWT + rôle admin obligatoires) :
#   GET /api/admin/game-timeouts
#   PUT /api/admin/game-timeouts/:game_type

defmodule GameHubWeb.AdminGameTimeoutController do
  use GameHubWeb, :controller

  alias GameHub.{Repo, Errors, AuditLog}
  alias GameHub.Games.GameTimeoutConfig

  # Bornes miroir de GameMatch (usage comme timeout de tour).
  @grace_min 10
  @grace_max 300
  @valid_actions ~w(forfeit refund pause)
  @valid_distributions ~w(to_winner split pool)

  @doc """
  GET /api/admin/game-timeouts — liste les timeouts globaux par jeu.
  """
  def index(conn, _params) do
    import Ecto.Query

    configs =
      GameTimeoutConfig
      |> order_by([c], asc: c.game_type)
      |> Repo.all()

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: Enum.map(configs, &serialize_config/1),
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  PUT /api/admin/game-timeouts/:game_type — crée ou met à jour le global.

  Body (clés optionnelles) : `%{grace_period_seconds (10..300),
  action_on_timeout ("forfeit"|"refund"|"pause"),
  forfeit_distribution ("to_winner"|"split"|"pool"),
  reconnect_allowed (bool), max_reconnect_attempts (int > 0)}`.
  Prend effet sur les NOUVEAUX matchs (chaque match fige ses valeurs).
  """
  def update(conn, %{"game_type" => game_type} = params) do
    admin_id = get_admin_id(conn)

    with {:ok, patch} <- extract_timeout_patch(params),
         {:ok, updated} <- upsert_config(game_type, patch) do
      try do
        AuditLog.log("game_timeout_updated", admin_id, "game_timeout_config", game_type, %{
          timeout_patch: patch
        })
      rescue
        _ -> :ok
      end

      conn
      |> put_status(200)
      |> json(%{
        success: true,
        data: serialize_config(updated),
        meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
      })
    else
      {:error, :invalid_key, key} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Clé non administrable ici : #{key}", 400, "INVALID_CONFIG_KEY"))

      {:error, :invalid_value, key} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Valeur invalide pour #{key}", 400, "INVALID_CONFIG_VALUE"))

      {:error, :update_failed} ->
        conn
        |> put_status(422)
        |> json(Errors.error("Configuration rejetée par la validation", 422, "INVALID_TIMEOUT_CONFIG"))
    end
  end

  # === Privé ===

  defp serialize_config(%GameTimeoutConfig{} = config) do
    %{
      game_type: config.game_type,
      grace_period_seconds: config.grace_period_seconds,
      action_on_timeout: config.action_on_timeout,
      forfeit_distribution: config.forfeit_distribution,
      reconnect_allowed: config.reconnect_allowed,
      max_reconnect_attempts: config.max_reconnect_attempts,
      is_active: config.is_active
    }
  end

  defp upsert_config(game_type, patch) do
    case Repo.get_by(GameTimeoutConfig, game_type: game_type) do
      nil ->
        %GameTimeoutConfig{game_type: game_type}

      existing ->
        existing
    end
    |> GameTimeoutConfig.changeset(patch)
    |> Repo.insert_or_update()
    |> case do
      {:ok, config} -> {:ok, config}
      {:error, _} -> {:error, :update_failed}
    end
  rescue
    _ -> {:error, :update_failed}
  end

  # N'accepte que les clés connues, valeurs typées et bornées.
  defp extract_timeout_patch(params) do
    body = Map.drop(params, ["game_type", "controller", "action"])

    Enum.reduce_while(body, {:ok, %{}}, fn {key, val}, {:ok, acc} ->
      cond do
        key not in ~w(grace_period_seconds action_on_timeout forfeit_distribution reconnect_allowed max_reconnect_attempts) ->
          {:halt, {:error, :invalid_key, key}}

        key == "grace_period_seconds" ->
          case parse_int(val) do
            n when is_integer(n) and n >= @grace_min and n <= @grace_max ->
              {:cont, {:ok, Map.put(acc, :grace_period_seconds, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "action_on_timeout" and val not in @valid_actions ->
          {:halt, {:error, :invalid_value, key}}

        key == "action_on_timeout" ->
          {:cont, {:ok, Map.put(acc, :action_on_timeout, val)}}

        key == "forfeit_distribution" and val not in @valid_distributions ->
          {:halt, {:error, :invalid_value, key}}

        key == "forfeit_distribution" ->
          {:cont, {:ok, Map.put(acc, :forfeit_distribution, val)}}

        key == "reconnect_allowed" ->
          case parse_bool(val) do
            nil -> {:halt, {:error, :invalid_value, key}}
            b -> {:cont, {:ok, Map.put(acc, :reconnect_allowed, b)}}
          end

        key == "max_reconnect_attempts" ->
          case parse_int(val) do
            n when is_integer(n) and n > 0 ->
              {:cont, {:ok, Map.put(acc, :max_reconnect_attempts, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        true ->
          {:halt, {:error, :invalid_key, key}}
      end
    end)
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_float(val), do: trunc(val)

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(String.trim(val)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_bool(val) when is_boolean(val), do: val
  defp parse_bool(val) when is_binary(val) do
    case String.downcase(String.trim(val)) do
      "true" -> true
      "false" -> false
      "1" -> true
      "0" -> false
      _ -> nil
    end
  end
  defp parse_bool(_), do: nil

  defp get_admin_id(conn) do
    case conn.assigns[:current_user] do
      %{id: id} when is_integer(id) -> id
      _ ->
        case conn.assigns[:current_user_id] do
          id when is_integer(id) -> id
          id when is_binary(id) ->
            case Integer.parse(id) do {n,_} -> n; :error -> 0 end
          _ ->
            case conn.assigns[:current_admin] do %{id: id} -> id; _ -> conn.private[:current_user_id] || 0 end
            |> then(fn v -> if is_binary(v) do case Integer.parse(v) do {n,_} -> n; :error -> 0 end else v end end)
        end
    end
  end
end
