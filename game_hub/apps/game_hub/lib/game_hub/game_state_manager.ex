# ==================================
# WIWIGA - Game State Manager (GenServer)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameStateManager
# Description: GenServer qui maintient l'état des parties en cours

defmodule GameHub.GameStateManager do
  @moduledoc """
  GenServer pour gérer l'état des parties de jeu en mémoire.
  
  ## Flow 1v1 Dice
  1. Matchmaking trouve 2 joueurs → `create_game/2`
  2. Chaque joueur place son pari → `place_bet/4`
  3. Quand les 2 paris sont placés → `execute_turn/1` (lancer dés)
  4. Déterminer gagnant → `end_game/1` (crédit wallet)
  
  ## États
  - `:waiting_for_bets` - En attente des paris des 2 joueurs
  - `:bets_placed` - Les 2 paris sont placés, prêt à lancer
  - `:rolling` - Dés en cours de lancement
  - `:ended` - Partie terminée
  """
  
  use GenServer
  require Logger
  
  # === Client API ===
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Crée une nouvelle partie 1v1.
  
  ## Parameters
    - `game_id`: ID unique de la partie
    - `players`: Liste de 2 player_ids [%{id: user_id, ...}]
  
  ## Returns
    - `{:ok, game_state}`
    - `{:error, :game_already_exists}`
  """
  def create_game(game_id, players, opts \\ []) do
    game_type = Keyword.get(opts, :game_type, "dice")
    GenServer.call(__MODULE__, {:create_game, game_id, players, game_type})
  end
  
  @doc """
  Place un pari pour un joueur.
  
  ## Parameters
    - `game_id`: ID de la partie
    - `player_id`: ID du joueur
    - `bet_amount`: Montant du pari
    - `predicted_sum`: Somme prédite (2-12)
  
  ## Returns
    - `{:ok, updated_state}`
    - `{:error, :game_not_found}`
    - `{:error, :bet_already_placed}`
    - `{:error, :game_not_accepting_bets}`
    - `{:error, :invalid_prediction}`
  """
  def place_bet(game_id, player_id, bet_amount, predicted_sum) do
    GenServer.call(__MODULE__, {:place_bet, game_id, player_id, bet_amount, predicted_sum})
  end
  
  @doc """
  Exécute le tour (lance les dés).
  Appelé automatiquement quand les 2 paris sont placés.
  
  ## Returns
    - `{:ok, dice_results}`
    - `{:error, :not_ready_to_roll}`
  """
  def execute_turn(game_id) do
    GenServer.call(__MODULE__, {:execute_turn, game_id})
  end
  
  @doc """
  Termine la partie et retourne le résultat.
  
  ## Returns
    - `{:ok, result}` avec winner, loser, payouts
    - `{:error, :game_not_found}`
  """
  def end_game(game_id) do
    GenServer.call(__MODULE__, {:end_game, game_id})
  end
  
  @doc """
  Récupère l'état actuel d'une partie.
  """
  def get_game_state(game_id) do
    GenServer.call(__MODULE__, {:get_state, game_id})
  end
  
  @doc """
  Liste toutes les parties en cours.
  """
  def list_active_games do
    GenServer.call(__MODULE__, :list_active)
  end

  @doc """
  Marque un joueur comme forfait et notifie les autres.
  """
  def forfeit_player(game_id, player_id) do
    GenServer.call(__MODULE__, {:forfeit_player, game_id, player_id})
  end

  @doc """
  Met une partie en pause (timeout/reconnexion).
  """
  def pause_game(game_id) do
    GenServer.call(__MODULE__, {:pause_game, game_id})
  end
  
  # === Server Callbacks ===
  
  @impl true
  def init(_opts) do
    # Table ETS pour stocker les états de jeu
    games = :ets.new(:game_states, [:named_table, :set, :public])
    
    # Cleanup timer - supprime les parties expirées toutes les 5 minutes
    schedule_cleanup()
    
    {:ok, %{games_table: games}}
  end
  
  @impl true
  def handle_call({:create_game, game_id, players, game_type}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        game_state = %{
          game_id: game_id,
          game_type: game_type,
          players: players,
          bets: %{},
          dice_results: nil,
          total_sum: nil,
          winner: nil,
          status: :waiting_for_bets,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
        
        :ets.insert(state.games_table, {game_id, game_state})
        Logger.info("Game #{game_id} created with #{length(players)} players")
        {:reply, {:ok, game_state}, state}
      
      [_existing] ->
        {:reply, {:error, :game_already_exists}, state}
    end
  end
  
  @impl true
  def handle_call({:place_bet, game_id, player_id, bet_amount, predicted_sum}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        {:reply, {:error, :game_not_found}, state}
      
      [{^game_id, game}] ->
        cond do
          game.status != :waiting_for_bets ->
            {:reply, {:error, :game_not_accepting_bets}, state}
          
          Map.has_key?(game.bets, player_id) ->
            {:reply, {:error, :bet_already_placed}, state}
          
          predicted_sum < 2 or predicted_sum > 12 ->
            {:reply, {:error, :invalid_prediction}, state}
          
          true ->
            bet = %{
              player_id: player_id,
              amount: bet_amount,
              predicted_sum: predicted_sum,
              placed_at: DateTime.utc_now()
            }
            
            updated_bets = Map.put(game.bets, player_id, bet)
            updated_game = %{game | 
              bets: updated_bets, 
              updated_at: DateTime.utc_now()
            }
            
            # Si les 2 joueurs ont placé leurs paris → ready to roll
            updated_game = if map_size(updated_bets) >= 2 do
              %{updated_game | status: :bets_placed}
            else
              updated_game
            end
            
            :ets.insert(state.games_table, {game_id, updated_game})
            Logger.info("Bet placed by player #{player_id} on game #{game_id}")
            {:reply, {:ok, updated_game}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:execute_turn, game_id}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        {:reply, {:error, :game_not_found}, state}
      
      [{^game_id, game}] ->
        if game.status == :bets_placed do
          # Générer les résultats de dés (crypto sécurisé)
          dice_count = 2
          dice_results = Enum.map(1..dice_count, fn _ ->
            :crypto.strong_rand_bytes(1)
            |> :binary.decode_unsigned()
            |> rem(6)
            |> Kernel.+(1)
          end)
          
          total_sum = Enum.sum(dice_results)
          
          updated_game = %{game |
            dice_results: dice_results,
            total_sum: total_sum,
            status: :rolling,
            updated_at: DateTime.utc_now()
          }
          
          :ets.insert(state.games_table, {game_id, updated_game})
          
          Logger.info("Game #{game_id}: dice rolled #{inspect(dice_results)} = #{total_sum}")
          
          {:reply, {:ok, %{dice: dice_results, sum: total_sum}}, state}
        else
          {:reply, {:error, :not_ready_to_roll}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:end_game, game_id}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        {:reply, {:error, :game_not_found}, state}
      
      [{^game_id, game}] ->
        if game.status in [:rolling, :bets_placed] do
          result = determine_winner(game)
          
          updated_game = %{game |
            winner: result.winner,
            status: :ended,
            updated_at: DateTime.utc_now()
          }
          
          :ets.insert(state.games_table, {game_id, updated_game})
          
          Logger.info("Game #{game_id} ended. Winner: #{inspect(result.winner)}")
          
          # Post-game processing (async, non-bloquant)
          # Wallet credits, stats, XP awarding
          Task.start(fn ->
            process_post_game(game_id, game, result)
          end)
          
          {:reply, {:ok, result}, state}
        else
          {:reply, {:error, :game_not_ready_to_end}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:get_state, game_id}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] -> {:reply, {:error, :game_not_found}, state}
      [{^game_id, game}] -> {:reply, {:ok, game}, state}
    end
  end
  
  @impl true
  def handle_call(:list_active, _from, state) do
    games = :ets.tab2list(state.games_table)
    |> Enum.map(fn {_id, game} -> game end)
    |> Enum.filter(fn game -> game.status != :ended end)
    
    {:reply, games, state}
  end

  @impl true
def handle_call({:forfeit_player, game_id, player_id}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        {:reply, {:error, :game_not_found}, state}

      [{^game_id, game}] ->
        remaining = Enum.reject(game.players, &(&1.id == player_id))
        updated_game = %{game |
          players: remaining,
          status: if(length(remaining) <= 1, do: :ended, else: game.status),
          forfeited_by: [player_id | (game[:forfeited_by] || [])]
        }
        :ets.insert(state.games_table, {game_id, updated_game})
        {:reply, {:ok, updated_game}, state}
    end
  end

  @impl true
def handle_call({:pause_game, game_id}, _from, state) do
    case :ets.lookup(state.games_table, game_id) do
      [] ->
        {:reply, {:error, :game_not_found}, state}

      [{^game_id, game}] ->
        updated_game = %{game | status: :paused, paused_at: System.system_time(:millisecond)}
        :ets.insert(state.games_table, {game_id, updated_game})
        {:reply, {:ok, updated_game}, state}
    end
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()
    five_minutes_ago = DateTime.add(now, -300, :second)
    
    # Supprimer les parties terminées ou expirées (> 5 min)
    :ets.tab2list(state.games_table)
    |> Enum.each(fn {game_id, game} ->
      if game.status == :ended or DateTime.compare(game.updated_at, five_minutes_ago) == :lt do
        :ets.delete(state.games_table, game_id)
      end
    end)
    
    schedule_cleanup()
    {:noreply, state}
  end
  
  # === Fonctions Privées ===
  
  # Détermine le gagnant d'une partie 1v1 dice.
  # Règles:
  # - Chaque joueur a prédit une somme (2-12)
  # - Les dés sont lancés (somme réelle)
  # - Joueur avec prédiction exacte → GAGNE
  # - Si les 2 ont prédit juste → celui qui a misé le plus gagne
  # - Si aucun n'a prédit juste → pas de gagnant (mises perdues)
  defp determine_winner(game) do
    bets = game.bets
    actual_sum = game.total_sum
    
    # Trouver les joueurs avec prédiction exacte
    exact_matches = bets
    |> Enum.filter(fn {_player_id, bet} -> bet.predicted_sum == actual_sum end)
    
    case exact_matches do
      [] ->
        # Aucun joueur n'a prédit juste
        %{
          game_id: game.game_id,
          winner: nil,
          loser: nil,
          dice_results: game.dice_results,
          total_sum: actual_sum,
          result: :no_winner,
          message: "Aucun joueur n'a prédit la somme exacte (#{actual_sum})",
          payouts: %{}
        }
      
      [{winner_id, winner_bet}] ->
        # Un seul gagnant exact
        [loser_id] = Map.keys(bets) |> Enum.reject(&(&1 == winner_id))
        
        total_pot = winner_bet.amount + Map.get(bets, loser_id).amount
        commission_rate = 0.05
        commission = trunc(total_pot * commission_rate)
        net_winnings = total_pot - commission
        
        %{
          game_id: game.game_id,
          winner: winner_id,
          loser: loser_id,
          dice_results: game.dice_results,
          total_sum: actual_sum,
          result: :exact_match,
          winner_prediction: winner_bet.predicted_sum,
          total_pot: total_pot,
          commission: commission,
          net_winnings: net_winnings,
          payouts: %{
            winner_id => net_winnings
          }
        }
      
      matches when length(matches) == 2 ->
        # Les deux ont prédit juste → celui qui a misé le plus gagne
        sorted = matches
        |> Enum.sort_by(fn {_id, bet} -> -bet.amount end)
        
        [{winner_id, winner_bet}, {loser_id, _loser_bet}] = sorted
        
        total_pot = winner_bet.amount + Map.get(bets, loser_id).amount
        commission_rate = 0.05
        commission = trunc(total_pot * commission_rate)
        net_winnings = total_pot - commission
        
        %{
          game_id: game.game_id,
          winner: winner_id,
          loser: loser_id,
          dice_results: game.dice_results,
          total_sum: actual_sum,
          result: :both_exact_higher_bet,
          winner_prediction: winner_bet.predicted_sum,
          total_pot: total_pot,
          commission: commission,
          net_winnings: net_winnings,
          payouts: %{
            winner_id => net_winnings
          }
        }
    end
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  # === Post-Game Processing ===

  # Traitement post-partie (async):
  # 1. Créditer le gagnant (wallet)
  # 2. Enregistrer les stats (GameStats)
  # 3. Attribuer l'XP (XPRules + Stats)
  defp process_post_game(game_id, game, result) do
    game_type = game.game_type || "dice"
    player_ids = Enum.map(game.players, & &1.id)
    bets_map = Map.new(game.bets, fn {pid, bet} -> {pid, bet.amount} end)

    # 1. Créditer le gagnant + enregistrer stats
    case result.winner do
      nil ->
        # Pas de gagnant (match nul ou aucune prédiction exacte)
        GameHub.GameStats.record_match_result(%{
          game_type: game_type,
          winner_id: nil,
          player_ids: player_ids,
          bets: bets_map,
          net_winnings: 0
        })

      winner_id ->
        net_winnings = result.net_winnings || 0

        # Créditer le wallet du gagnant
        if net_winnings > 0 do
          idempotency_key = "game_#{game_id}_winnings"
          case GameHub.Wallet.credit_winnings(winner_id, net_winnings, game_id, idempotency_key) do
            {:ok, _} -> Logger.info("Credited #{net_winnings} to player #{winner_id}")
            {:error, :idempotent_duplicate} -> :ok
            {:error, err} -> Logger.error("Wallet credit failed: #{inspect(err)}")
          end
        end

        # Enregistrer stats match
        GameHub.GameStats.record_match_result(%{
          game_type: game_type,
          winner_id: winner_id,
          player_ids: player_ids,
          bets: bets_map,
          net_winnings: net_winnings
        })
    end

    # 2. Attribuer XP à chaque joueur
    award_xp_to_players(game_type, game, result)

    # 3. Recalculer les stats globales des joueurs
    Enum.each(player_ids, fn pid ->
      try do
        GameHub.Users.Stats.recalculate(pid)
      rescue
        err -> Logger.error("Stats recalculate failed for #{pid}: #{inspect(err)}")
      end
    end)
  rescue
    err -> Logger.error("Post-game processing failed for #{game_id}: #{inspect(err)}")
  end

  # Attribue l'XP aux joueurs selon les règles configurées.
  # Le gagnant reçoit win_xp, le perdant loss_xp.
  defp award_xp_to_players(game_type, game, result) do
    Enum.each(game.bets, fn {player_id, _bet} ->
      {player_result, win_streak} = case result.winner do
        nil -> {:draw, 0}
        ^player_id -> {:win, get_current_streak(player_id, game_type)}
        _ -> {:loss, 0}
      end

      xp_gained = GameHub.Admin.XPRules.calculate_xp(game_type, player_result, win_streak)

      if xp_gained > 0 do
        case GameHub.Users.Stats.add_xp(player_id, xp_gained) do
          {:ok, _} -> Logger.info("Player #{player_id} gained #{xp_gained} XP (#{player_result})")
          {:error, err} -> Logger.error("XP award failed for #{player_id}: #{inspect(err)}")
        end
      end
    end)
  rescue
    err -> Logger.error("XP awarding failed: #{inspect(err)}")
  end

  # Récupère la série de victoires actuelle d'un joueur
  defp get_current_streak(player_id, game_type) do
    case GameHub.GameStats.my_stats(player_id, game_type) do
      %{current_streak: streak} when is_integer(streak) -> streak
      _ -> 0
    end
  rescue
    _ -> 0
  end
end
