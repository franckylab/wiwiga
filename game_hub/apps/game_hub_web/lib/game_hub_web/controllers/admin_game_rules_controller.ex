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
  # Clés administrables ici : nombre de sets, timings de jeu (tour, vote,
  # enchaînement, grâce) et mode de vote cible. Dés, joueurs, mises et
  # commission règle : mêmes bornes que le changeset GameRule.
  @allowed_sets_keys ~w(min_sets max_sets default_sets sets_mode sets_random_min sets_random_max)
  @allowed_timing_keys ~w(turn_timeout_seconds auto_next_set_delay_seconds leave_grace_seconds)
  @allowed_vote_keys ~w(target_vote_mode vote_timeout_seconds vote_result_delay_seconds)
  @allowed_dice_keys ~w(min_dice max_dice default_dice dice_faces)
  @allowed_players_keys ~w(min_players max_players)
  @allowed_bets_keys ~w(min_bet max_bet)
  @allowed_finance_keys ~w(commission_rate tie_rule)
  @allowed_keys @allowed_sets_keys ++ @allowed_timing_keys ++ @allowed_vote_keys ++ @allowed_dice_keys ++ @allowed_players_keys ++ @allowed_bets_keys ++ @allowed_finance_keys
  # Bornes miroir du changeset GameRule (rejetées aussi côté validation).
  @turn_timeout_min 10
  @turn_timeout_max 300
  @auto_next_set_min 2
  @auto_next_set_max 15
  @leave_grace_min 5
  @leave_grace_max 120
  @vote_timeout_min 5
  @vote_timeout_max 120
  @vote_result_delay_min 2
  @vote_result_delay_max 30
  @valid_vote_modes ~w(average mode)
  @dice_min 1
  @dice_max 10
  @dice_faces_min 4
  @dice_faces_max 20
  @players_min 2
  @players_max 10
  @bet_min 0
  @bet_max 10_000_000
  @valid_tie_rules ~w(replay no_winner)

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
  PUT /api/admin/game-rules/:game_type/:rule_type — met à jour sets + timings.

  Body (clés optionnelles) : `%{min_sets, max_sets, default_sets,
  sets_mode ("fixed"|"random"), sets_random_min, sets_random_max,
  turn_timeout_seconds (10..300),
  auto_next_set_delay_seconds (2..15), leave_grace_seconds (5..120),
  target_vote_mode ("average"|"mode", cible uniquement),
  vote_timeout_seconds (5..120, cible uniquement),
  vote_result_delay_seconds (2..30, cible uniquement)}`.
  Fusionné avec la config existante, validé (changeset), cache ETS invalidé.
  Les matchs en cours gardent leurs valeurs gelées ; les nouveaux matchs
  appliquent la nouvelle config.
  """
  def update(conn, %{"game_type" => game_type, "rule_type" => rule_type} = params) do
    admin_id = get_admin_id(conn)

    with :ok <- validate_rule_type(rule_type),
         {:ok, rule} <- GameRules.get_rules(game_type, rule_type),
         {:ok, sets_patch} <- extract_sets_patch(params),
         # `nil` explicite (ex : retour à l'héritage global du tour) :
         # la clé est SUPPRIMÉE de la config au lieu d'être mise à jour.
         {deletes, updates} = Enum.split_with(sets_patch, fn {_k, v} -> v == :__delete__ end),
         merged =
           Map.merge(rule.config || %{}, Map.new(updates))
           |> Map.drop(Enum.map(deletes, &elem(&1, 0))),
         :ok <- check_range_coherence(merged),
         {:ok, updated} <- GameRules.update_config(game_type, rule_type, merged) do
      try do
        AuditLog.log("game_rules_updated", admin_id, "game_rule", "#{game_type}/#{rule_type}", %{
          sets_patch: Map.new(updates),
          deleted_keys: Enum.map(deletes, &elem(&1, 0)),
          sets_mode: merged["sets_mode"],
          default_sets: merged["default_sets"],
          timing_patch: Map.take(Map.new(updates), @allowed_timing_keys),
          vote_patch: Map.take(Map.new(updates), @allowed_vote_keys)
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

  # N'accepte que les clés sets + timings + vote cible, valeurs typées
  # (normalisation stricte). Les clés de vote ne s'appliquent qu'au
  # rule_type "cible" (rejetées ailleurs : vote inexistant en normal).
  defp extract_sets_patch(params) do
    rule_type = Map.get(params, "rule_type")
    body = Map.drop(params, ["game_type", "rule_type", "controller", "action"])

    Enum.reduce_while(body, {:ok, %{}}, fn {key, val}, {:ok, acc} ->
      cond do
        key in @allowed_vote_keys and rule_type != "cible" ->
          {:halt, {:error, :invalid_key, key}}

        key not in @allowed_keys ->
          {:halt, {:error, :invalid_key, key}}

        key == "sets_mode" and val not in ["fixed", "random"] ->
          {:halt, {:error, :invalid_value, key}}

        key == "sets_mode" ->
          {:cont, {:ok, Map.put(acc, key, val)}}

        key == "target_vote_mode" and val not in @valid_vote_modes ->
          {:halt, {:error, :invalid_value, key}}

        key == "target_vote_mode" ->
          {:cont, {:ok, Map.put(acc, key, val)}}

        key == "turn_timeout_seconds" ->
          # `null` explicite = retour à l'héritage global (clé supprimée).
          if is_nil(val) do
            {:cont, {:ok, Map.put(acc, key, :__delete__)}}
          else
            case parse_int(val) do
              n when is_integer(n) and n >= @turn_timeout_min and n <= @turn_timeout_max ->
                {:cont, {:ok, Map.put(acc, key, n)}}
              _ ->
                {:halt, {:error, :invalid_value, key}}
            end
          end

        key == "auto_next_set_delay_seconds" ->
          case parse_int(val) do
            n when is_integer(n) and n >= @auto_next_set_min and n <= @auto_next_set_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "leave_grace_seconds" ->
          case parse_int(val) do
            n when is_integer(n) and n >= @leave_grace_min and n <= @leave_grace_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "vote_timeout_seconds" ->
          case parse_int(val) do
            n when is_integer(n) and n >= @vote_timeout_min and n <= @vote_timeout_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "vote_result_delay_seconds" ->
          case parse_int(val) do
            n when is_integer(n) and n >= @vote_result_delay_min and n <= @vote_result_delay_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key in @allowed_dice_keys ->
          {dmin, dmax} = if key == "dice_faces", do: {@dice_faces_min, @dice_faces_max}, else: {@dice_min, @dice_max}

          case parse_int(val) do
            n when is_integer(n) and n >= dmin and n <= dmax ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key in @allowed_players_keys ->
          case parse_int(val) do
            n when is_integer(n) and n >= @players_min and n <= @players_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key in @allowed_bets_keys ->
          case parse_int(val) do
            n when is_integer(n) and n >= @bet_min and n <= @bet_max ->
              {:cont, {:ok, Map.put(acc, key, n)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "commission_rate" ->
          case parse_float(val) do
            f when is_float(f) and f >= 0.0 and f <= 1.0 ->
              {:cont, {:ok, Map.put(acc, key, f)}}
            _ ->
              {:halt, {:error, :invalid_value, key}}
          end

        key == "tie_rule" and val in @valid_tie_rules ->
          {:cont, {:ok, Map.put(acc, key, val)}}

        key == "tie_rule" ->
          {:halt, {:error, :invalid_value, key}}

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

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val / 1

  defp parse_float(val) when is_binary(val) do
    case Float.parse(String.trim(val)) do
      {f, ""} -> f
      _ -> nil
    end
  end

  defp parse_float(_), do: nil

  # Cohérence min <= max (+ default_dice dans [min, max]) sur la config
  # fusionnée (les valeurs existantes complètent le patch partiel).
  defp check_range_coherence(merged) do
    pairs = [
      {"min_dice", "max_dice"},
      {"min_players", "max_players"},
      {"min_bet", "max_bet"}
    ]

    coherent? =
      Enum.all?(pairs, fn {lo_key, hi_key} ->
        case {to_number_or_nil(merged[lo_key]), to_number_or_nil(merged[hi_key])} do
          {nil, _} -> true
          {_, nil} -> true
          {lo, hi} -> lo <= hi
        end
      end)

    default_ok? =
      case {to_number_or_nil(merged["default_dice"]), to_number_or_nil(merged["min_dice"]), to_number_or_nil(merged["max_dice"])} do
        {nil, _, _} -> true
        {_, nil, nil} -> true
        {d, lo, hi} -> (is_nil(lo) or d >= lo) and (is_nil(hi) or d <= hi)
      end

    if coherent? and default_ok?, do: :ok, else: {:error, :invalid_value, "range"}
  end

  defp to_number_or_nil(nil), do: nil
  defp to_number_or_nil(n) when is_number(n), do: n

  defp to_number_or_nil(s) when is_binary(s) do
    case Float.parse(String.trim(s)) do
      {f, ""} -> f
      _ -> nil
    end
  end

  defp to_number_or_nil(_), do: nil

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
