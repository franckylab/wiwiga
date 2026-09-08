# ==================================
# WIWIGA - Configuration Effective des Jeux
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Games.EffectiveConfig
# Description: Vue centralisée et en lecture seule de la configuration
#   effective d'un type de jeu. Le paramétrage est dispersé entre
#   `game_rules` (moteur : sets, dés, vote, timings), `game_configs`
#   (catalogue monétaire : mises, commission, affichage),
#   `game_timeout_configs` (repli global) et `xp_rules`.
#   Ce module fusionne ces sources en miroir EXACT des chaînes de
#   résolution du moteur (mêmes priorités que GameMatch/GameRules) et
#   annote chaque valeur de sa source, pour que l'administration voie
#   d'un seul écran ce qui s'applique réellement en partie.

defmodule GameHub.Games.EffectiveConfig do
  @moduledoc """
  Configuration effective d'un jeu (lecture seule, usage admin).

  ## Sources fusionnées (par ordre de priorité moteur)
  - `game_rules` : sets, dés, mises règle, vote, timings par règle
  - `game_configs` : catalogue (mises affichées/validées au join, commission, affichage)
  - `game_timeout_configs` : repli global des délais
  - `xp_rules` : gains d'expérience par jeu
  - Constantes moteur en dernier recours (documentées comme telles)

  Chaque valeur est retournée sous la forme `%{value: v, source: s}` où
  `source` vaut par exemple `"game_rules.dice/normal.config.turn_timeout_seconds"`,
  `"game_timeout_configs.dice.grace_period_seconds"`, `"game_configs.dice"`,
  `"xp_rules.dice"`, `"game_rules_default"` ou `"engine_default"`.
  """

  alias GameHub.{GameRules, Repo}
  alias GameHub.Games.GameTimeoutConfig
  alias GameHub.Admin.{GameConfig, XPRules}

  @valid_rules ~w(normal cible)
  @turn_timeout_default 30

  @doc """
  Configuration effective d'un couple `(game_type, rule_type)`.

  ## Returns
    - `{:ok, config}` | `{:error, :invalid_rule_type}` | `{:error, :rules_not_found}`
  """
  @spec for_game(String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def for_game(game_type, rule_type) do
    with :ok <- validate_rule_type(rule_type),
         {:ok, rule} <- GameRules.get_rules(game_type, rule_type) do
      {:ok, build(rule)}
    end
  end

  @doc """
  Configurations effectives de toutes les règles actives, optionnellement
  filtrées par `game_type`. Les règles introuvables sont ignorées.
  """
  @spec list_all(String.t() | nil) :: [map()]
  def list_all(game_type \\ nil) do
    GameRules.list_all()
    |> Enum.filter(fn rule -> is_nil(game_type) or rule.game_type == game_type end)
    |> Enum.map(&build/1)
  end

  # === Construction ===

  defp build(rule) do
    game_type = rule.game_type
    rule_type = rule.rule_type
    rc = rule.config || %{}
    rule_source = "game_rules.#{game_type}/#{rule_type}.config"
    catalog = catalog_config(game_type)
    timeout_row = timeout_config(game_type)

    %{
      game_type: game_type,
      rule_type: rule_type,
      rule_name: rule.name,
      rule_active: rule.is_active,
      sets: sets_block(game_type, rule_type),
      dice: %{
        min: rul(rc, rule_source, "min_dice", 1),
        max: rul(rc, rule_source, "max_dice", 5),
        default: rul(rc, rule_source, "default_dice", 2),
        faces: rul(rc, rule_source, "dice_faces", 6)
      },
      bets: %{
        # Bornes utilisées à la création (salles, matchmaking)
        rule_min: rul(rc, rule_source, "min_bet", 100),
        rule_max: rul(rc, rule_source, "max_bet", 500_000),
        # Bornes validées à l'inscription (join) + affichage catalogue
        catalog_min: cat(catalog, game_type, :min_bet),
        catalog_max: cat(catalog, game_type, :max_bet),
        catalog_min_tokens: cat(catalog, game_type, :min_bet_tokens)
      },
      commission: %{
        # Taux gelé par match à la création (source appliquée en partie)
        rule_rate: rul(rc, rule_source, "commission_rate", 0.05),
        catalog_rate: cat(catalog, game_type, :commission_rate),
        catalog_mode: cat(catalog, game_type, :commission_mode)
      },
      timeouts: timeouts_block(game_type, rc, rule_source, timeout_row),
      vote: vote_block(rule_type, rc, rule_source),
      players: %{
        min: rul(rc, rule_source, "min_players", 2),
        max: rul(rc, rule_source, "max_players", 5)
      },
      display: %{
        name: cat(catalog, game_type, :name),
        enabled: cat(catalog, game_type, :is_enabled),
        coming_soon: cat(catalog, game_type, :coming_soon),
        display_order: cat(catalog, game_type, :display_order)
      },
      xp: xp_block(game_type)
    }
  end

  # Aperçu sets (même source que le lobby : GameRules.sets_preview/2).
  defp sets_block(game_type, rule_type) do
    preview = GameRules.sets_preview(game_type, rule_type)
    source = "game_rules.#{game_type}/#{rule_type}.config"

    %{
      mode: %{value: preview.mode, source: source <> ".sets_mode"},
      min: %{value: preview.min_sets, source: source <> ".min_sets"},
      max: %{value: preview.max_sets, source: source <> ".max_sets"},
      default: %{value: preview.default_sets, source: source <> ".default_sets"},
      random_min: %{value: preview.random_min, source: source <> ".sets_random_min"},
      random_max: %{value: preview.random_max, source: source <> ".sets_random_max"}
    }
  rescue
    _ ->
      %{mode: %{value: "fixed", source: "game_rules_default"}, min: %{value: 1, source: "game_rules_default"},
        max: %{value: 11, source: "game_rules_default"}, default: %{value: 3, source: "game_rules_default"},
        random_min: %{value: 1, source: "game_rules_default"}, random_max: %{value: 5, source: "game_rules_default"}}
  end

  # Délais : miroir exact de GameMatch (règle → global → constante).
  defp timeouts_block(game_type, rc, rule_source, timeout_row) do
    {turn_value, turn_source} =
      case Map.get(rc, "turn_timeout_seconds") do
        nil ->
          case timeout_row do
            %{grace_period_seconds: secs} when is_integer(secs) and secs > 0 ->
              {secs, "game_timeout_configs.#{game_type}.grace_period_seconds"}

            _ ->
              {@turn_timeout_default, "engine_default"}
          end

        secs ->
          {secs, rule_source <> ".turn_timeout_seconds"}
      end

    %{
      turn_seconds: %{value: turn_value, source: turn_source},
      auto_next_set_seconds: rul(rc, rule_source, "auto_next_set_delay_seconds", 4),
      leave_grace_seconds: rul(rc, rule_source, "leave_grace_seconds", 20),
      global: %{
        grace_seconds: trow(timeout_row, game_type, :grace_period_seconds),
        action_on_timeout: trow(timeout_row, game_type, :action_on_timeout),
        forfeit_distribution: trow(timeout_row, game_type, :forfeit_distribution),
        reconnect_allowed: trow(timeout_row, game_type, :reconnect_allowed),
        max_reconnect_attempts: trow(timeout_row, game_type, :max_reconnect_attempts)
      }
    }
  end

  # Vote cible uniquement (règle "cible").
  defp vote_block("cible", rc, rule_source) do
    %{
      target_vote_mode: rul(rc, rule_source, "target_vote_mode", "average"),
      vote_timeout_seconds: rul(rc, rule_source, "vote_timeout_seconds", 20),
      vote_result_delay_seconds: rul(rc, rule_source, "vote_result_delay_seconds", 5)
    }
  end

  defp vote_block(_rule_type, _rc, _rule_source), do: nil

  # XP par jeu (compact, lecture seule).
  defp xp_block(game_type) do
    case XPRules.get_xp_rules(game_type) do
      rules when is_map(rules) ->
        %{
          win: %{value: Map.get(rules, :win_xp), source: "xp_rules.#{game_type}"},
          loss: %{value: Map.get(rules, :loss_xp), source: "xp_rules.#{game_type}"},
          participation: %{value: Map.get(rules, :participation_xp), source: "xp_rules.#{game_type}"},
          active: %{value: Map.get(rules, :is_active, true), source: "xp_rules.#{game_type}"}
        }

      _ ->
        %{win: %{value: nil, source: "absent"}, loss: %{value: nil, source: "absent"},
          participation: %{value: nil, source: "absent"}, active: %{value: nil, source: "absent"}}
    end
  rescue
    _ ->
      %{win: %{value: nil, source: "absent"}, loss: %{value: nil, source: "absent"},
        participation: %{value: nil, source: "absent"}, active: %{value: nil, source: "absent"}}
  end

  # === Accès sources (nil-safe) ===

  # Valeur de règle avec fallback et source annotée.
  defp rul(rc, rule_source, key, default) do
    case Map.get(rc, key) do
      nil -> %{value: num(default), source: "game_rules_default"}
      value -> %{value: num(value), source: "#{rule_source}.#{key}"}
    end
  end

  # Valeur catalogue (`game_configs`) ou absence explicite.
  defp cat(nil, _game_type, _key), do: %{value: nil, source: "absent"}

  defp cat(catalog, game_type, key) do
    %{value: num(Map.get(catalog, key)), source: "game_configs.#{game_type}"}
  end

  # Ligne de timeouts globaux (même requête que GameMatch).
  defp timeout_config(game_type) do
    Repo.get_by(GameTimeoutConfig, game_type: game_type, is_active: true)
  rescue
    _ -> nil
  end

  defp trow(nil, _game_type, _key), do: %{value: nil, source: "absent"}

  defp trow(row, game_type, key) do
    %{value: num(Map.get(row, key)), source: "game_timeout_configs.#{game_type}.#{key}"}
  end

  defp catalog_config(game_type) do
    GameConfig.get_config(game_type)
  rescue
    _ -> nil
  end

  # Normalise les nombres pour JSON (Decimal → float).
  defp num(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp num(value), do: value

  defp validate_rule_type(rule_type) when rule_type in @valid_rules, do: :ok
  defp validate_rule_type(_), do: {:error, :invalid_rule_type}
end
