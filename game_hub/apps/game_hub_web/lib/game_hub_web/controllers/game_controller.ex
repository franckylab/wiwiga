# ==================================
# WIWIGA - Controller Jeux (V3 Partia rapida unifiée)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.GameController
# Description: Endpoints liste jeux, rejoindre partie (hybrid Room + Queue), état jeu

defmodule GameHubWeb.GameController do
  @moduledoc """
  Controller gestion jeux — V3.
  
  ## Endpoints
    GET    /api/games                    - Liste jeux
    GET    /api/games/:game_id           - Détails jeu
    POST   /api/games/:game_id/join      - Partie rapide (mise+rule) hybrid
    DELETE /api/games/:game_id/queue     - Annuler recherche
    GET    /api/games/:game_id/queue/status - Statut file
    GET    /api/games/:game_id/state     - État partie
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{Errors, Repo, Games.GameConfig, Wallet, Commission, AuditLog, GameRoom, GameMatch, Matchmaking}
  import Ecto.Query
  
  @valid_rules ~w(normal cible)

  defp normalize_rule(rule) when is_binary(rule) do
    r = String.downcase(String.trim(rule))
    if r in @valid_rules, do: r, else: "normal"
  end
  defp normalize_rule(_), do: "normal"
  
  @doc """
  GET /api/games
  
  Response: %{success: true, data: [%{id: "dice", name: "Jeu de Dés", ...}]}
  """
  def index(conn, _params) do
    game_configs = Repo.all(
      from g in GameConfig,
      where: g.is_active == true,
      order_by: [asc: g.display_order, asc: g.id]
    )
    
    games = Enum.map(game_configs, fn config ->
      %{
        id: config.game_type,
        name: config.name,
        description: config.description,
        min_bet: config.min_bet,
        max_bet: config.max_bet,
        commission_rate: Decimal.to_float(config.commission_rate),
        status: if(config.is_active, do: "active", else: "inactive"),
        coming_soon: config.coming_soon,
        display_order: config.display_order,
        players_online: if(config.coming_soon, do: 0, else: get_players_online(config.game_type))
      }
    end)
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: games,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end
  
  @doc """
  GET /api/games/:game_id
  
  Response: %{success: true, data: %{id: "dice", name: "...", config: {...}}}
  """
  def show(conn, %{"game_id" => game_id}) do
    game_config = Repo.get_by(GameConfig, game_type: game_id)
    
    case game_config do
      nil ->
        conn
        |> put_status(404)
        |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
      
      config ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            id: config.game_type,
            name: config.name,
            description: config.description,
            min_bet: config.min_bet,
            max_bet: config.max_bet,
            commission_rate: Decimal.to_float(config.commission_rate),
            commission_mode: config.commission_mode,
            coming_soon: config.coming_soon,
            display_order: config.display_order,
            players_online: if(config.coming_soon, do: 0, else: get_players_online(config.game_type)),
            tips: get_tips_items(config),
            config: config.config || %{}
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
    end
  end
  
  @doc """
  POST /api/games/:game_id/join
  
  Body: %{bet_amount: 500, rule_type: "normal"|"cible"}
  
  Hybrid:
    1) Scan salles en attente compatibles (même mise + règle + place libre)
    2) Sinon queue Redis partitionnée (game_type, rule_type)
  """
  def join(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    bet_amount = params["bet_amount"] || params["betAmount"]
    rule_type = normalize_rule(params["rule_type"] || params["ruleType"] || "normal")

    # Support int/float/string
    bet_amount =
      cond do
        is_integer(bet_amount) -> bet_amount
        is_float(bet_amount) -> trunc(bet_amount)
        is_binary(bet_amount) -> String.to_integer(bet_amount)
        true -> nil
      end

    if is_nil(bet_amount) do
      conn
      |> put_status(400)
      |> json(Errors.error("Paramètre 'bet_amount' requis", 400, "VALIDATION_ERROR"))
    else
      game_config = Repo.get_by(GameConfig, game_type: game_id)
      
      cond do
        is_nil(game_config) ->
          conn
          |> put_status(404)
          |> json(Errors.error("Jeu non trouvé", 404, "GAME_NOT_FOUND"))
        
        bet_amount < game_config.min_bet ->
          conn
          |> put_status(400)
          |> json(Errors.error("Mise minimum: #{game_config.min_bet} jetons", 400, "BET_TOO_LOW"))

        bet_amount > game_config.max_bet ->
          conn
          |> put_status(400)
          |> json(Errors.error("Mise maximum: #{game_config.max_bet} jetons", 400, "BET_TOO_HIGH"))
        
        not (rule_type in @valid_rules) ->
          conn
          |> put_status(400)
          |> json(Errors.error("rule_type invalide (normal|cible)", 400, "INVALID_RULE_TYPE"))
        
        true ->
          case GameHub.ResponsibleGaming.check_before_bet(user_id, bet_amount) do
            {:error, reason} ->
              conn
              |> put_status(403)
              |> json(Errors.error("Jeu responsable: #{reason}", 403, "RESPONSIBLE_GAMING_BLOCK"))
            
            :ok ->
              # Vérifier déjà en file / déjà en salle ?
              # 1) Hybrid Room scan AVANT débit (évite débit si salle libre ? non on débite avant join_room)
              # On débite puis on tente hybrid
              idempotency_key = "bet_#{user_id}_#{game_id}_#{rule_type}_#{System.os_time(:millisecond)}"
              
              case Wallet.place_bet(user_id, bet_amount, game_id, idempotency_key) do
                {:error, :insufficient_funds} ->
                  conn
                  |> put_status(400)
                  |> json(Errors.error("Solde insuffisant", 400, "INSUFFICIENT_FUNDS", %{
                    required: bet_amount
                  }))
                
                {:error, reason} ->
                  conn
                  |> put_status(400)
                  |> json(Errors.error("Erreur pari", 400, "BET_ERROR", %{reason: reason}))
                
                {:ok, _transaction} ->
                  # Hybrid V3.1: 1) salle existante 2) lobby synchronisé quick match
                  case find_compatible_room(game_id, rule_type, bet_amount) do
                    {:ok, room} ->
                      case GameRoom.join_room(room.room_id, user_id) do
                        {:ok, updated_room} ->
                          AuditLog.log(
                            "bet_placed_room_joined",
                            user_id,
                            "game",
                            updated_room.room_id,
                            %{bet_amount: bet_amount, rule_type: rule_type, status: "matched_room"},
                            %{idempotency_key: idempotency_key}
                          )
                          conn
                          |> put_status(200)
                          |> json(%{
                            success: true,
                            data: %{
                              status: "matched",
                              game_id: updated_room.room_id,
                              room_id: updated_room.room_id,
                              room_code: updated_room.room_code,
                              match_id: updated_room.match_id,
                              message: "Partie trouvée !",
                              bet_amount: bet_amount,
                              rule_type: rule_type
                            },
                            meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                          })

                        {:error, _reason} ->
                          do_quick_lobby_join(conn, user_id, game_id, rule_type, bet_amount, idempotency_key)
                      end

                    :no_room ->
                      do_quick_lobby_join(conn, user_id, game_id, rule_type, bet_amount, idempotency_key)
                  end
              end
          end
      end
    end
  end

  @doc """
  GET /api/games/:game_id/state
  """
  def game_state(conn, %{"game_id" => game_id}) do
    game_key = "game:#{game_id}"
    
    case Redix.command(GameHub.Redis, ["HGETALL", game_key]) do
      {:ok, []} ->
        # Fallback: chercher dans GameRoom puis GameMatch
        case GameRoom.get_room(game_id) do
          {:ok, room} ->
            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{
                game_id: game_id,
                room_id: room.room_id,
                status: room.status,
                players: Enum.map(room.players, fn p -> p.id end),
                game_type: room.game_type,
                rule_type: room.rule_type,
                bet_amount: room.bet_amount
              },
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          _ ->
            case GameMatch.get_match(game_id) do
              {:ok, match} ->
                conn |> put_status(200) |> json(%{
                  success: true,
                  data: %{
                    game_id: game_id,
                    match_id: match.match_id,
                    status: to_string(match.status),
                    players: Enum.map(match.players, fn p -> p.id end),
                    game_type: match.game_type,
                    rule_type: match.rule_type,
                    bet_amount: match.bet_amount,
                    current_set: match.current_set,
                    sets_count: match.sets_count
                  },
                  meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                })
              _ ->
                conn |> put_status(404) |> json(Errors.error("Partie non trouvée", 404, "GAME_NOT_FOUND"))
            end
        end
      
      {:ok, game_data} when is_list(game_data) ->
        # Redix HGETALL retourne liste plate [k,v,k,v] — convertir en map
        map = game_data |> Enum.chunk_every(2) |> Enum.reduce(%{}, fn
          [k, v], acc when is_binary(k) -> Map.put(acc, k, v)
          _, acc -> acc
        end)
        state = %{
          game_id: game_id,
          status: map["status"] || "unknown",
          players: (map["players"] || "") |> String.split(",", trim: true),
          game_type: map["game_type"] || "dice",
          rule_type: map["rule_type"] || "normal",
          bet_amount: case map["bet_amount"] do nil -> 0; v -> String.to_integer(v) end
        }
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: state,
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, _} ->
        conn
        |> put_status(500)
        |> json(Errors.error("Erreur serveur", 500, "INTERNAL_ERROR"))
    end
  end
  
  # === Privé ===
  
  # Nouveau lobby synchronisé V3.1 — retourne lobby state pour page sobre
  defp do_quick_lobby_join(conn, user_id, game_id, rule_type, bet_amount, idempotency_key) do
    case Matchmaking.join_quick_lobby(user_id, game_id, rule_type, bet_amount) do
      {:ok, :waiting, lobby} ->
        AuditLog.log("bet_placed", user_id, "game", game_id, %{bet_amount: bet_amount, rule_type: rule_type, status: "waiting", lobby: lobby}, %{idempotency_key: idempotency_key})
        conn |> put_status(202) |> json(%{success: true, data: %{status: "waiting", bet_amount: bet_amount, rule_type: rule_type, lobby: serialize_lobby(lobby)}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})

      {:ok, :matched, game_id_matched, lobby} ->
        case Commission.calculate_commission(game_id, bet_amount) do
          {:ok, commission} ->
            AuditLog.log("bet_matched", user_id, "game", game_id_matched, %{bet_amount: bet_amount, rule_type: rule_type, commission: commission, status: "matched"}, %{idempotency_key: idempotency_key})
            conn |> put_status(200) |> json(%{success: true, data: %{status: "matched", game_id: game_id_matched, bet_amount: bet_amount, rule_type: rule_type, lobby: serialize_lobby(lobby), max_commission: commission}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
          _ ->
            conn |> put_status(200) |> json(%{success: true, data: %{status: "matched", game_id: game_id_matched, bet_amount: bet_amount, rule_type: rule_type, lobby: serialize_lobby(lobby)}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
        end

      {:error, reason} ->
        refund_key = "refund_#{user_id}_#{game_id}_#{rule_type}_#{System.os_time(:millisecond)}"
        Wallet.credit_winnings(user_id, bet_amount, game_id, refund_key)
        AuditLog.log("bet_refunded", user_id, "game", game_id, %{bet_amount: bet_amount, rule_type: rule_type, reason: reason, status: "refunded"}, %{idempotency_key: refund_key}
        )

        conn
        |> put_status(400)
        |> json(Errors.error("Erreur matchmaking: #{reason}", 400, "MATCHMAKING_ERROR"))
    end
  end

  defp find_compatible_room(game_type, rule_type, bet_amount) do
    try do
      rooms = GameRoom.list_waiting_rooms(game_type, nil)
      # Filtrer compatible: même règle, même mise, place libre, mode staked
      compatible =
        rooms
        |> Enum.filter(fn r ->
          r.status == :waiting and
            r.rule_type == rule_type and
            r.bet_amount == bet_amount and
            length(r.players) < r.max_players and
            r.mode == :staked
        end)
        |> Enum.sort_by(fn r -> r.created_at end, {:asc, DateTime})

      case compatible do
        [room | _] -> {:ok, room}
        [] -> :no_room
      end
    rescue
      _ -> :no_room
    end
  end
  
  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
  
  # ---- Quick lobby helpers ----
  defp serialize_lobby(lobby) when is_map(lobby) do
    %{
      game_type: lobby.game_type,
      rule_type: lobby.rule_type,
      bet_amount: lobby.bet_amount,
      max_players: lobby.max_players,
      min_players: lobby.min_players,
      players: lobby.players,
      players_count: lobby.players_count,
      empty_slots: lobby.empty_slots,
      ready_count: lobby.ready_count,
      can_start: lobby.can_start,
      is_full: lobby.is_full,
      elapsed_seconds: lobby.elapsed_seconds,
      status: lobby.status
    }
  end

  def quick_lobby(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    rule_type = normalize_rule(params["rule_type"] || params["ruleType"] || "normal")
    bet_amount = params["bet_amount"] || params["betAmount"]
    bet_amount = cond do
      is_integer(bet_amount) -> bet_amount
      is_binary(bet_amount) -> String.to_integer(bet_amount)
      is_float(bet_amount) -> trunc(bet_amount)
      true -> nil
    end
    if is_nil(bet_amount) do
      conn |> put_status(400) |> json(Errors.error("bet_amount requis", 400, "VALIDATION_ERROR"))
    else
      lobby = Matchmaking.get_quick_lobby_state(game_id, rule_type, bet_amount, user_id)
      conn |> put_status(200) |> json(%{success: true, data: serialize_lobby(lobby), meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
    end
  end

  def quick_ready(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    rule_type = normalize_rule(params["rule_type"] || params["ruleType"] || "normal")
    bet_amount = params["bet_amount"] || params["betAmount"]
    bet_amount = cond do
      is_integer(bet_amount) -> bet_amount
      is_binary(bet_amount) -> String.to_integer(bet_amount)
      is_float(bet_amount) -> trunc(bet_amount)
      true -> nil
    end
    if is_nil(bet_amount) do
      conn |> put_status(400) |> json(Errors.error("bet_amount requis", 400, "VALIDATION_ERROR"))
    else
      case Matchmaking.toggle_quick_ready(user_id, game_id, rule_type, bet_amount) do
        {:ok, :matched, game_id_matched, lobby} ->
          conn |> put_status(200) |> json(%{success: true, data: %{status: "matched", game_id: game_id_matched, lobby: serialize_lobby(lobby)}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
        {:ok, lobby} ->
          conn |> put_status(200) |> json(%{success: true, data: serialize_lobby(lobby), meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
        {:error, reason} ->
          conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "LOBBY_ERROR"))
      end
    end
  end

  # Compat ancien queue status — enrichi avec lobby si bet fourni
  def queue_status(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    rule_type = normalize_rule(params["rule_type"] || params["ruleType"] || "normal")
    bet_amount = params["bet_amount"] || params["betAmount"]
    bet_amount = cond do
      is_integer(bet_amount) -> bet_amount
      is_binary(bet_amount) -> String.to_integer(bet_amount)
      is_float(bet_amount) -> trunc(bet_amount)
      true -> nil
    end
    status = Matchmaking.get_queue_status(user_id, game_id, rule_type)
    fallback = Matchmaking.check_fallback_status(user_id, game_id, rule_type)

    lobby = if bet_amount do
      try do Matchmaking.get_quick_lobby_state(game_id, rule_type, bet_amount, user_id) rescue _ -> nil end
    else nil end

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        position: status.position,
        total_players: status.total_players,
        elapsed_seconds: status.elapsed_seconds,
        rule_type: rule_type,
        fallback: case fallback do
          :exact_search -> "exact"
          {:fallback_proposal, alt} -> %{proposal: alt}
        end,
        lobby: lobby && serialize_lobby(lobby)
      },
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  # Annuler recherche — étendu au lobby synchronisé
  def leave_queue(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    rule_type = normalize_rule(params["rule_type"] || params["ruleType"] || "normal")
    bet_amount = params["bet_amount"] || params["betAmount"]
    bet_amount_int = cond do
      is_integer(bet_amount) -> bet_amount
      is_binary(bet_amount) -> String.to_integer(bet_amount)
      is_float(bet_amount) -> trunc(bet_amount)
      true -> nil
    end

    # Quitter lobby sync si bet connu
    if bet_amount_int do
      Matchmaking.leave_quick_lobby(user_id, game_id, rule_type, bet_amount_int)
    end
    Matchmaking.leave_queue(user_id, game_id, rule_type)
    Matchmaking.leave_queue(user_id, game_id)

    if bet_amount_int do
      refund_key = "refund_cancel_#{user_id}_#{game_id}_#{bet_amount_int}_#{System.os_time(:millisecond)}"
      case Wallet.credit_winnings(user_id, bet_amount_int, game_id, refund_key) do
        {:ok, _} -> AuditLog.log("bet_refunded_cancel", user_id, "game", game_id, %{bet_amount: bet_amount_int, rule_type: rule_type}, %{idempotency_key: refund_key})
        _ -> :ok
      end
    end

    conn |> put_status(200) |> json(%{success: true, data: %{status: "cancelled"}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
  end

  @doc """
  GET /api/games/active
  Retourne la partie active de l'utilisateur pour redirection automatique.
  Priorité: match en cours > salle en attente/en cours > quick lobby
  """
  def active(conn, _params) do
    user_id = get_current_user_id(conn)
    uid_str = to_string(user_id)

    # 1) Match en cours (GameMatch)
    case GameMatch.get_active_match_for_player(uid_str) do
      {:ok, match} ->
        conn |> put_status(200) |> json(%{
          success: true,
          data: %{
            has_active: true,
            type: "match",
            game_type: match.game_type,
            match_id: match.match_id,
            rule_type: match.rule_type,
            status: to_string(match.status),
            bet_amount: match.bet_amount,
            players_count: length(match.players),
            max_players: match.max_players
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })

      {:error, _} ->
        # 2) Salle active (GameRoom)
        case GameRoom.get_active_room_for_player(user_id) do
          {:ok, room} ->
            room_type = case room.status do
              :waiting -> "room_waiting"
              _ -> "room_in_progress"
            end
            conn |> put_status(200) |> json(%{
              success: true,
              data: %{
                has_active: true,
                type: room_type,
                game_type: room.game_type,
                room_id: room.room_id,
                room_code: room.room_code,
                rule_type: room.rule_type,
                status: to_string(room.status),
                bet_amount: room.bet_amount,
                players_count: length(room.players),
                max_players: room.max_players,
                match_id: room.match_id
              },
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })

          {:error, _} ->
            # 3) Quick lobby (Matchmaking)
            case Matchmaking.find_active_quick_lobby_for_player(uid_str) do
              {:ok, lobby} ->
                conn |> put_status(200) |> json(%{
                  success: true,
                  data: %{
                    has_active: true,
                    type: "quick_lobby",
                    game_type: lobby.game_type,
                    rule_type: lobby.rule_type,
                    bet_amount: lobby.bet_amount,
                    status: lobby.status,
                    players_count: lobby.players_count,
                    max_players: lobby.max_players,
                    lobby: serialize_lobby(lobby)
                  },
                  meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                })

              {:error, _} ->
                # Fallback: vérifier aussi avec int id si uid_str différent
                case Matchmaking.find_active_quick_lobby_for_player(user_id) do
                  {:ok, lobby} ->
                    conn |> put_status(200) |> json(%{
                      success: true,
                      data: %{
                        has_active: true,
                        type: "quick_lobby",
                        game_type: lobby.game_type,
                        rule_type: lobby.rule_type,
                        bet_amount: lobby.bet_amount,
                        status: lobby.status,
                        players_count: lobby.players_count,
                        max_players: lobby.max_players,
                        lobby: serialize_lobby(lobby)
                      },
                      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                    })
                  _ ->
                    conn |> put_status(200) |> json(%{
                      success: true,
                      data: %{has_active: false, type: "none"},
                      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
                    })
                end
            end
        end
    end
  end

  # Debug: inspect match (pour test tours)
  def debug_match(conn, %{"game_id" => game_id}) do
    case GameMatch.get_match(game_id) do
      {:ok, match} -> conn |> put_status(200) |> json(%{success: true, data: %{match_id: match.match_id, status: to_string(match.status), players: Enum.map(match.players, & &1.id), current_set: match.current_set, current_set_state: match.current_set_state, set_scores: match.set_scores}})
      {:error, _} -> conn |> put_status(404) |> json(Errors.error("Match non trouvé", 404, "MATCH_NOT_FOUND"))
    end
  end

  def debug_roll(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    # Permettre de forcer player_id via param pour test
    player_id = to_string(Map.get(params, "player_id", user_id))
    case GameMatch.roll_dice(game_id, player_id) do
      {:ok, %{match: match, roll: roll}} -> conn |> put_status(200) |> json(%{success: true, data: %{roll: roll, match: %{match_id: match.match_id, status: to_string(match.status), current_set_state: match.current_set_state, set_scores: match.set_scores}}})
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "ROLL_ERROR"))
    end
  end

  defp get_players_online(game_type) do
    {:ok, c1} = Redix.command(GameHub.Redis, ["HLEN", "queue:#{game_type}:normal"])
    {:ok, c2} = Redix.command(GameHub.Redis, ["HLEN", "queue:#{game_type}:cible"])
    c1 + c2
  rescue
    _ -> 0
  end
  
  defp get_tips_items(%{tips: %{"items" => items}}) when is_list(items), do: items
  defp get_tips_items(_config), do: []
end
