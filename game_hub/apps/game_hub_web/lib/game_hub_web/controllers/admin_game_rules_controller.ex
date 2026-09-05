# ==================================
# WIWIGA - Admin GameRules Controller
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminGameRulesController
# Description: Administration des règles moteur (`game_rules.config`),
#   dont le nombre de sets (mode fixe / aléatoire).
#   Contrairement à `/game-configs` (monétaire), ces valeurs sont lues
#   en temps réel par GameMatch, GameRoom et Matchmaking.
#
# Endpoints (scope admin, JWT + rôle admin obligatoires) :
#   GET /api/admin/game-rules
#   GET /api/admin/game-rules/:game_type/:rule_type
#   PUT /api/admin/game-rules/:game_type/:rule_type

defmodule GameHubWeb.AdminGameRulesController do
  use GameHubWeb, :controller

  alias GameHub.{GameRules, Errors, AuditLog}

  @valid_rules ~w(normal cible)
  # Clés administrables ici (nombre de sets). Le reste de la config
  # (dés, mises, timeouts) reste géré par les endpoints existants.
  @allowed_sets_keys ~w(min_sets max_sets default_sets sets_mode sets_random_min sets_random_max)

  @doc """
  GET /api/admin/game-rules — liste les règles moteur actives.
  """
  def index(conn, _params) do
    rules = GameRules.list_all()

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: Enum.map(rules, &serialize_rule/1),
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  GET /api/admin/game-rules/:game_type/:rule_type — détail + aperçu sets.
  """
  def show(conn, %{"game_type" => game_type, "rule_type" => rule_type}) do
    with :ok <- validate_rule_type(rule_type),
         {:ok, rule} <- GameRules.get_rules(game_type, rule_type) do
      conn
      |> put_status(200)
      |> json(%{
        success: true,
        data: serialize_rule(rule),
        meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
      })
    else
      {:error, :invalid_rule_type} ->
        conn
        |> put_status(400)
        |> json(Errors.error("rule_type invalide (normal|cible)", 400, "INVALID_RULE_TYPE"))

      {:error, :rules_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Règle introuvable", 404, "RULE_NOT_FOUND"))
    end
  end

  @doc """
  PUT /api/admin/game-rules/:game_type/:rule_type — met à jour les sets.

  Body (clés optionnelles) : `%{min_sets, max_sets, default_sets,
  sets_mode ("fixed"|"random"), sets_random_min, sets_random_max}`.
  Fusionné avec la config existante, validé (changeset), cache ETS invalidé.
  """
  def update(conn, %{"game_type" => game_type, "rule_type" => rule_type} = params) do
    admin_id = get_admin_id(conn)

    with :ok <- validate_rule_type(rule_type),
         {:ok, rule} <- GameRules.get_rules(game_type, rule_type),
         {:ok, sets_patch} <- extract_sets_patch(params),
         merged = Map.merge(rule.config || %{}, sets_patch),
         {:ok, updated} <- GameRules.update_config(game_type, rule_type, merged) do
      try do
        AuditLog.log("game_rules_updated", admin_id, "game_rule", "#{game_type}/#{rule_type}", %{
          sets_patch: sets_patch,
          sets_mode: merged["sets_mode"],
          default_sets: merged["default_sets"]
        })
      rescue
        _ -> :ok
      end

      conn
      |> put_status(200)
      |> json(%{
        success: true,
        data: serialize_rule(updated),
        meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
      })
    else
      {:error, :invalid_rule_type} ->
        conn
        |> put_status(400)
        |> json(Errors.error("rule_type invalide (normal|cible)", 400, "INVALID_RULE_TYPE"))

      {:error, :rules_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Règle introuvable", 404, "RULE_NOT_FOUND"))

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
        |> json(Errors.error("Configuration rejetée : incohérence des sets (min <= défaut/aléatoire <= max)", 422, "INVALID_SETS_CONFIG"))
    end
  end

  # === Privé ===

  defp serialize_rule(rule) do
    %{
      game_type: rule.game_type,
      rule_type: rule.rule_type,
      name: rule.name,
      description: rule.description,
      config: rule.config || %{},
      sets: GameRules.sets_preview(rule.game_type, rule.rule_type),
      is_active: rule.is_active
    }
  end

  defp validate_rule_type(rule_type) when rule_type in @valid_rules, do: :ok
  defp validate_rule_type(_), do: {:error, :invalid_rule_type}

  # N'accepte que les clés sets + valeurs typées (normalisation stricte).
  defp extract_sets_patch(params) do
    body = Map.drop(params, ["game_type", "rule_type", "controller", "action"])

    Enum.reduce_while(body, {:ok, %{}}, fn {key, val}, {:ok, acc} ->
      cond do
        key not in @allowed_sets_keys ->
          {:halt, {:error, :invalid_key, key}}

        key == "sets_mode" and val not in ["fixed", "random"] ->
          {:halt, {:error, :invalid_value, key}}

        key == "sets_mode" ->
          {:cont, {:ok, Map.put(acc, key, val)}}

        true ->
          case parse_int(val) do
            nil -> {:halt, {:error, :invalid_value, key}}
            n -> {:cont, {:ok, Map.put(acc, key, n)}}
          end
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
