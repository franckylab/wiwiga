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
    
    total_online = get_total_online()
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: games,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601(), total_online: total_online}
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
              {message, details} = responsible_gaming_message(reason, user_id, bet_amount)
              conn
              |> put_status(403)
              |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))
            
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
                bet_amount: room.bet_amount,
                sets_count: room.sets_count,
                sets_mode: Map.get(room, :sets_mode, "fixed")
              },
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          _ ->
            case GameMatch.get_match(game_id) do
              {:ok, match} ->
                # Retour complet pour reload page (tout le state, pas juste résumé)
                conn |> put_status(200) |> json(%{
                  success: true,
                  data: sanitize_debug_match(match),
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
          bet_amount: case map["bet_amount"] do nil -> 0; v -> String.to_integer(v) end,
          sets_count: case map["sets_count"] do nil -> nil; v -> String.to_integer(v) end,
          sets_mode: map["sets_mode"] || "fixed"
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
      status: lobby.status,
      # Aperçu sets (mode fixe/aléatoire) — affichage lobby cohérent
      # avec la configuration serveur (jamais deviné côté client).
      sets: Map.get(lobby, :sets)
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
      # Jeu responsable : un joueur exclu/en pause ne confirme pas un départ
      # (la mise débitée au join reste remboursée via leave_queue).
      case GameHub.ResponsibleGaming.check_playable(user_id) do
        {:error, reason} ->
          {message, details} = GameHub.ResponsibleGaming.block_message(reason, user_id, bet_amount)
          conn |> put_status(403) |> json(Errors.error(message, 403, "RESPONSIBLE_GAMING_BLOCK", details))

        :ok ->
          do_toggle_quick_ready(conn, user_id, game_id, rule_type, bet_amount)
      end
    end
  end

  defp do_toggle_quick_ready(conn, user_id, game_id, rule_type, bet_amount) do
    case Matchmaking.toggle_quick_ready(user_id, game_id, rule_type, bet_amount) do
      {:ok, :matched, game_id_matched, lobby} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "matched", game_id: game_id_matched, lobby: serialize_lobby(lobby)}, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
      {:ok, lobby} ->
        conn |> put_status(200) |> json(%{success: true, data: serialize_lobby(lobby), meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})
      {:error, reason} ->
        conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "LOBBY_ERROR"))
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

  def debug_start_set(conn, %{"game_id" => game_id}) do
    case GameMatch.start_set(game_id) do
      {:ok, match} -> conn |> put_status(200) |> json(%{success: true, data: sanitize_debug_match(match)})
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "START_SET_ERROR"))
    end
  end

  # Debug: inspect match (pour test tours) — sanitize pour JSON
  defp sanitize_debug_match(match) do
    css = Map.get(match, :current_set_state)
    sanitized_css = case css do
      nil -> nil
      m when is_map(m) ->
        base = case Map.get(m, :result) do
          {:winner, id} -> Map.put(m, :result, %{winner_id: to_string(id), result: "winner"})
          :tie -> Map.put(m, :result, %{result: "tie"})
          _ -> m
        end
        base =
          try do
            Map.update(base, :rolls, %{}, fn rolls when is_map(rolls) ->
              Map.new(rolls, fn {k, v} -> {to_string(k), sanitize_roll(v)} end)
            end)
          rescue
            _ -> base
          end
        remaining = case Map.get(base, :turn_deadline) do
          %DateTime{} = dl -> try do max(0, DateTime.diff(dl, DateTime.utc_now(), :second)) rescue _ -> nil end
          _ -> nil
        end
        Map.put(base, :turn_remaining_seconds, remaining)
      other -> other
    end
    {last_roller_id, last_roll} = latest_roll(match)
    sets = try do Enum.map(Map.get(match, :sets, []), &sanitize_set/1) rescue _ -> [] end
    %{
      match_id: match.match_id,
      status: to_string(match.status),
      players: Enum.map(match.players, fn p -> %{id: to_string(p.id), name: Map.get(p, :name, "Joueur")} end),
      current_set: match.current_set,
      sets_count: Map.get(match, :sets_count, 1),
      sets_mode: Map.get(match, :sets_mode, "fixed"),
      sets_to_win: Map.get(match, :sets_to_win, div(Map.get(match, :sets_count, 1), 2) + 1),
      dice_count: Map.get(match, :dice_count, 2),
      bet_amount: Map.get(match, :bet_amount, 0),
      rule_type: Map.get(match, :rule_type, "normal"),
      game_type: Map.get(match, :game_type, "dice"),
      max_players: Map.get(match, :max_players, 2),
      current_set_state: sanitized_css,
      set_scores: match.set_scores,
      sets: sets,
      payout: payout_summary(match),
      rematch: rematch_lobby_view(match, Map.get(match, :rematch)),
      left_players: (Map.get(match, :left_players, MapSet.new()) || MapSet.new()) |> MapSet.to_list() |> Enum.map(&to_string/1),
      eliminated_players: match.eliminated_players |> MapSet.to_list() |> Enum.map(&to_string/1),
      winner_id: Map.get(match, :winner_id) |> then(fn nil -> nil; v -> to_string(v) end),
      turn_timeout_ms: GameHub.GameMatch.turn_timeout_seconds(Map.get(match, :game_type, "dice")) * 1000,
      last_roller_id: last_roller_id,
      last_roll: last_roll
    }
  end

  defp sanitize_set(set) when is_map(set) do
    rolls = Map.get(set, :rolls, %{}) || %{}
    {sums, dice} = Enum.reduce(rolls, {%{}, %{}}, fn {pid, roll}, {sums, dice} ->
      {sum, faces} = case roll do
        %{sum: s, dice: d} when is_integer(s) and is_list(d) -> {s, d}
        %{dice: d} when is_list(d) -> {Enum.sum(d), d}
        %{sum: s} when is_integer(s) -> {s, []}
        _ -> {0, []}
      end
      {Map.put(sums, to_string(pid), sum), Map.put(dice, to_string(pid), faces)}
    end)
    {winner_id, result} = case Map.get(set, :winner_id) do
      nil -> case Map.get(set, :result) do
        {:winner, id} -> {to_string(id), "winner"}
        _ -> {nil, "tie"}
      end
      id -> {to_string(id), "winner"}
    end
    %{set_number: Map.get(set, :set_number), winner_id: winner_id, result: result, sums: sums, dice: dice, target_value: Map.get(set, :target_value)}
  end

  defp payout_summary(match) do
    bet = Map.get(match, :bet_amount, 0) || 0
    winner = Map.get(match, :winner_id)
    if match.status == :match_ended and bet > 0 and not is_nil(winner) do
      n = length(Map.get(match, :players, []))
      gross = bet * n
      rate = try do
        rules = GameHub.GameRules.get_rules_or_default(match.game_type, match.rule_type || "normal")
        (rules.config["commission_rate"] || 0.05) |> to_string() |> Decimal.new() |> Decimal.to_float()
      rescue _ -> 0.05 end
      commission = trunc(gross * rate)
      %{gross: gross, commission: commission, net: gross - commission, winner_id: to_string(winner)}
    else
      nil
    end
  rescue _ -> nil
  end

  defp rematch_lobby_view(_match, nil), do: %{status: "none"}
  defp rematch_lobby_view(_match, %{started: true} = lobby) do
    %{status: "started", proposed_by: lobby.proposed_by,
      accepted: lobby.accepted |> MapSet.to_list() |> Enum.map(&to_string/1),
      new_match_id: lobby.new_match_id}
  end
  defp rematch_lobby_view(match, lobby) do
    left = Map.get(match, :left_players, MapSet.new()) || MapSet.new()
    invited = match.players |> Enum.map(fn p -> to_string(p.id) end) |> Enum.reject(fn id -> MapSet.member?(left, id) end)
    %{status: "proposed", proposed_by: lobby.proposed_by,
      accepted: lobby.accepted |> MapSet.to_list() |> Enum.map(&to_string/1),
      declined: lobby.declined |> MapSet.to_list() |> Enum.map(&to_string/1),
      invited: invited,
      left: left |> MapSet.to_list() |> Enum.map(&to_string/1),
      accepted_count: lobby.accepted |> MapSet.to_list() |> Enum.reject(fn id -> MapSet.member?(left, id) end) |> length(),
      proposed_at: lobby.proposed_at |> DateTime.to_iso8601()}
  end

  defp sanitize_roll(%{dice: dice, sum: sum} = roll) do
    %{
      player_id: roll |> Map.get(:player_id) |> to_string(),
      dice: dice,
      sum: sum,
      forfeited: Map.get(roll, :forfeited, false),
      rolled_at: case Map.get(roll, :rolled_at) do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        v when is_binary(v) -> v
        _ -> nil
      end
    }
  end
  defp sanitize_roll(other) when is_map(other) do
    pid = Map.get(other, :player_id) || Map.get(other, "player_id")
    dice = Map.get(other, :dice) || Map.get(other, "dice") || []
    sum = Map.get(other, :sum) || Map.get(other, "sum") || Enum.sum(List.wrap(dice))
    %{player_id: to_string(pid), dice: List.wrap(dice), sum: sum,
      forfeited: Map.get(other, :forfeited) || Map.get(other, "forfeited") || false,
      rolled_at: case Map.get(other, :rolled_at) || Map.get(other, "rolled_at") do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        v when is_binary(v) -> v
        _ -> nil
      end}
  rescue _ -> %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}
  end
  defp sanitize_roll(_), do: %{player_id: nil, dice: [], sum: 0, forfeited: false, rolled_at: nil}

  defp latest_roll(match) do
    rolls = match |> Map.get(:current_set_state, %{}) |> then(fn
      nil -> %{}
      css when is_map(css) -> Map.get(css, :rolls, %{}) || %{}
      _ -> %{}
    end)
    if map_size(rolls) == 0 do
      {nil, nil}
    else
      {pid, roll} = Enum.max_by(rolls, fn {_pid, r} ->
        case r do
          %{rolled_at: %DateTime{} = dt} -> DateTime.to_unix(dt, :microsecond)
          %{"rolled_at" => v} when is_binary(v) -> v
          %{rolled_at: v} when is_binary(v) -> v
          _ -> ""
        end
      end)
      {to_string(pid), sanitize_roll(roll)}
    end
  rescue _ -> {nil, nil}
  end

  def debug_match(conn, %{"game_id" => game_id}) do
    case GameMatch.get_match(game_id) do
      {:ok, match} -> conn |> put_status(200) |> json(%{success: true, data: sanitize_debug_match(match)})
      {:error, _} -> conn |> put_status(404) |> json(Errors.error("Match non trouvé", 404, "MATCH_NOT_FOUND"))
    end
  end

  def debug_roll(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    player_id = to_string(Map.get(params, "player_id", user_id))
    case GameMatch.roll_dice(game_id, player_id) do
      {:ok, %{match: match, roll: roll, set_result: sr}} ->
        conn |> put_status(200) |> json(%{success: true, data: %{roll: sanitize_roll(roll), match: sanitize_debug_match(match), set_result: sanitize_set_result(sr)}})
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "ROLL_ERROR"))
    end
  end

  # === REST fallback pour jeu temps réel (utilisé si WebSocket indisponible) ===

  def roll(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    player_id = to_string(Map.get(params, "player_id", user_id))
    case GameMatch.roll_dice(game_id, player_id) do
      {:ok, %{match: match, roll: roll, set_result: sr}} ->
        conn |> put_status(200) |> json(%{success: true, data: %{roll: sanitize_roll(roll), match: sanitize_debug_match(match), set_result: sanitize_set_result(sr)}})
      {:error, :not_your_turn} -> conn |> put_status(403) |> json(Errors.error("Ce n'est pas votre tour", 403, "NOT_YOUR_TURN"))
      {:error, :already_rolled} -> conn |> put_status(409) |> json(Errors.error("Vous avez déjà lancé", 409, "ALREADY_ROLLED"))
      {:error, :player_eliminated} -> conn |> put_status(403) |> json(Errors.error("Vous êtes éliminé", 403, "PLAYER_ELIMINATED"))
      {:error, :set_not_in_progress} -> conn |> put_status(409) |> json(Errors.error("Set non en cours", 409, "SET_NOT_IN_PROGRESS"))
      {:error, :voting_phase_active} -> conn |> put_status(409) |> json(Errors.error("Phase de vote en cours", 409, "VOTING_PHASE"))
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "ROLL_ERROR"))
    end
  end

  def vote(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    player_id = to_string(Map.get(params, "player_id", user_id))
    target = Map.get(params, "target_value") || Map.get(params, "target")
    target_val = cond do is_integer(target) -> target; is_binary(target) -> String.to_integer(target); true -> nil end
    if is_nil(target_val) do
      conn |> put_status(400) |> json(Errors.error("target_value requis", 400, "VALIDATION_ERROR"))
    else
      case GameMatch.vote_target(game_id, player_id, target_val) do
        {:ok, match} -> conn |> put_status(200) |> json(%{success: true, data: sanitize_debug_match(match)})
        {:error, :already_voted} -> conn |> put_status(409) |> json(Errors.error("Déjà voté", 409, "ALREADY_VOTED"))
        {:error, :not_voting_phase} -> conn |> put_status(409) |> json(Errors.error("Pas en phase de vote", 409, "NOT_VOTING_PHASE"))
        {:error, :invalid_target} -> conn |> put_status(400) |> json(Errors.error("Cible invalide", 400, "INVALID_TARGET"))
        {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "VOTE_ERROR"))
      end
    end
  end

  def start_set_rest(conn, %{"game_id" => game_id}) do
    case GameMatch.start_set(game_id) do
      {:ok, match} -> conn |> put_status(200) |> json(%{success: true, data: sanitize_debug_match(match)})
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "START_SET_ERROR"))
    end
  end

  # === Revanche opt-out (fin de partie) — REST fallback ===

  def propose_rematch(conn, %{"game_id" => game_id}) do
    user_id = get_current_user_id(conn)
    player_id = to_string(user_id)

    case GameMatch.propose_rematch(game_id, player_id) do
      {:ok, lobby} ->
        {:ok, match} = GameMatch.get_match(game_id)
        conn |> put_status(200) |> json(%{success: true, data: %{lobby: lobby, match: sanitize_debug_match(match)}})

      {:error, :match_not_found} -> conn |> put_status(404) |> json(Errors.error("Partie introuvable ou expirée", 404, "MATCH_NOT_FOUND"))
      {:error, :match_not_ended} -> conn |> put_status(409) |> json(Errors.error("La partie n'est pas terminée", 409, "MATCH_NOT_ENDED"))
      {:error, :not_a_player} -> conn |> put_status(403) |> json(Errors.error("Vous ne faites pas partie de cette partie", 403, "NOT_A_PLAYER"))
      {:error, :player_left} -> conn |> put_status(409) |> json(Errors.error("Vous avez quitté cette partie", 409, "PLAYER_LEFT"))
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "REMATCH_ERROR"))
    end
  end

  def respond_rematch(conn, %{"game_id" => game_id} = params) do
    user_id = get_current_user_id(conn)
    player_id = to_string(user_id)
    accept? = Map.get(params, "accept", Map.get(params, "accepted", true))

    case GameMatch.respond_rematch(game_id, player_id, accept?) do
      {:ok, lobby} ->
        {:ok, match} = GameMatch.get_match(game_id)
        conn |> put_status(200) |> json(%{success: true, data: %{lobby: lobby, match: sanitize_debug_match(match)}})

      {:error, :match_not_found} -> conn |> put_status(404) |> json(Errors.error("Partie introuvable ou expirée", 404, "MATCH_NOT_FOUND"))
      {:error, :no_rematch_proposal} -> conn |> put_status(404) |> json(Errors.error("Aucune revanche proposée", 404, "NO_REMATCH_PROPOSAL"))
      {:error, :not_a_player} -> conn |> put_status(403) |> json(Errors.error("Vous ne faites pas partie de cette partie", 403, "NOT_A_PLAYER"))
      {:error, :player_left} -> conn |> put_status(409) |> json(Errors.error("Vous avez quitté cette partie", 409, "PLAYER_LEFT"))
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "REMATCH_ERROR"))
    end
  end

  def start_rematch(conn, %{"game_id" => game_id}) do
    user_id = get_current_user_id(conn)
    player_id = to_string(user_id)

    case GameMatch.start_rematch(game_id, player_id) do
      {:ok, %{new_match_id: new_id, match: match, excluded: excluded}} ->
        conn |> put_status(200) |> json(%{success: true, data: %{new_match_id: new_id, match: sanitize_debug_match(match), excluded: Enum.map(excluded, &to_string/1)}})

      {:error, :match_not_found} -> conn |> put_status(404) |> json(Errors.error("Partie introuvable ou expirée", 404, "MATCH_NOT_FOUND"))
      {:error, :no_rematch_proposal} -> conn |> put_status(404) |> json(Errors.error("Aucune revanche proposée", 404, "NO_REMATCH_PROPOSAL"))
      {:error, :not_proposer} -> conn |> put_status(403) |> json(Errors.error("Seul le proposant peut démarrer la revanche", 403, "NOT_PROPOSER"))
      {:error, :not_enough_players} -> conn |> put_status(409) |> json(Errors.error("Pas assez de joueurs (soldes insuffisants ou départs)", 409, "NOT_ENOUGH_PLAYERS"))
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "REMATCH_ERROR"))
    end
  end

  def cancel_rematch(conn, %{"game_id" => game_id}) do
    user_id = get_current_user_id(conn)
    player_id = to_string(user_id)

    case GameMatch.cancel_rematch(game_id, player_id) do
      {:ok, lobby} ->
        conn |> put_status(200) |> json(%{success: true, data: %{lobby: lobby}})

      {:error, :match_not_found} -> conn |> put_status(404) |> json(Errors.error("Partie introuvable ou expirée", 404, "MATCH_NOT_FOUND"))
      {:error, :no_rematch_proposal} -> conn |> put_status(404) |> json(Errors.error("Aucune revanche proposée", 404, "NO_REMATCH_PROPOSAL"))
      {:error, :not_proposer} -> conn |> put_status(403) |> json(Errors.error("Seul le proposant peut annuler", 403, "NOT_PROPOSER"))
      {:error, reason} -> conn |> put_status(400) |> json(Errors.error("#{reason}", 400, "REMATCH_ERROR"))
    end
  end

  def leave_match(conn, %{"game_id" => game_id}) do
    user_id = get_current_user_id(conn)
    # Idempotent : toujours 200 (chemins dispose)
    GameMatch.leave_match(game_id, to_string(user_id))
    conn |> put_status(200) |> json(%{success: true, data: %{status: "left"}})
  end

  defp sanitize_set_result(:tie), do: %{result: "tie"}
  defp sanitize_set_result({:winner, id}), do: %{winner_id: to_string(id), result: "winner"}
  defp sanitize_set_result(:in_progress), do: %{result: "in_progress"}
  defp sanitize_set_result(other), do: %{result: inspect(other)}

  defp get_players_online(game_type) do
    GameHub.Presence.count_game_online(game_type)
  rescue
    _ -> 0
  catch
    _, _ -> 0
  end

  defp get_total_online do
    GameHub.Presence.count_online()
  rescue
    _ -> 0
  catch
    _, _ -> 0
  end
  
  defp get_tips_items(%{tips: %{"items" => items}}) when is_list(items), do: items
  defp get_tips_items(_config), do: []

  # Messages humains pour jeu responsable — source unique
  # ResponsibleGaming.block_message/3 (le frontend exploite details.reason).
  defp responsible_gaming_message(reason, user_id, bet_amount) do
    GameHub.ResponsibleGaming.block_message(reason, user_id, bet_amount)
  end
end
