# ==================================
# WIWIGA - Admin Effective Config Controller
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminGameEffectiveConfigController
# Description: Vue centralisée en lecture seule de la configuration
#   effective des jeux (`GameHub.Games.EffectiveConfig`). Le paramétrage
#   est dispersé entre `game_rules`, `game_configs`, `game_timeout_configs`
#   et `xp_rules` ; cet endpoint fusionne ces sources en miroir des chaînes
#   de résolution du moteur, chaque valeur étant annotée de sa source.
#   L'écriture reste sur les endpoints spécialisés existants
#   (`/game-rules`, `/game-configs`, `/game-timeouts`, `/xp-rules`).
#
# Endpoints (scope admin, JWT + rôle admin obligatoires) :
#   GET /api/admin/games/effective-config[?game_type=...]
#   GET /api/admin/games/effective-config/:game_type/:rule_type

defmodule GameHubWeb.AdminGameEffectiveConfigController do
  use GameHubWeb, :controller

  alias GameHub.Games.EffectiveConfig
  alias GameHub.Errors

  @doc """
  GET /api/admin/games/effective-config — configurations effectives de
  toutes les règles actives, optionnellement filtrées par `?game_type=`.
  """
  def index(conn, params) do
    game_type = Map.get(params, "game_type")
    configs = EffectiveConfig.list_all(game_type)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: configs,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  GET /api/admin/games/effective-config/:game_type/:rule_type —
  configuration effective d'un couple jeu × règle.
  """
  def show(conn, %{"game_type" => game_type, "rule_type" => rule_type}) do
    case EffectiveConfig.for_game(game_type, rule_type) do
      {:ok, config} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: config,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

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
end
