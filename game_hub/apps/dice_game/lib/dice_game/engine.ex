# ==================================
# WIWIGA - Plugin Jeu de Dés OTP
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: DiceGame.Engine
# Description: Implémentation GamePlugin pour jeu de dés 1v1

defmodule DiceGame.Engine do
  @moduledoc """
  Moteur de jeu de dés 1v1 implémentant GameHub.GamePlugin.
  
  ## Règles du Jeu
  - 2 joueurs s'affrontent via matchmaking
  - Chaque joueur prédit la somme de 2 dés (2-12)
  - Les dés sont lancés (génération crypto sécurisée)
  - Joueur avec prédiction exacte → GAGNE le pot
  - Si les 2 ont prédit juste → celui qui a misé le plus gagne
  - Si aucun n'a prédit juste → pas de gagnant
  - Commission de 5% sur le pot total
  
  ## Flow
  1. Matchmaking → 2 joueurs trouvés
  2. `start_game/2` → crée la partie (en mémoire via GameStateManager)
  3. `place_bet/4` → chaque joueur place sa prédiction (débit wallet)
  4. `execute_turn/1` → lance les dés (crypto sécurisé)
  5. `end_game/1` → détermine gagnant + crédit wallet + persiste DB
  """
  
  @behaviour GameHub.GamePlugin
  
  alias GameHub.GameStateManager
  alias GameHub.Wallet
  alias GameHub.Repo
  alias GameHub.DiceGame.DiceGameResult
  
  @commission_rate 0.05
  @min_bet 100
  @dice_count 2
  @min_sum 2
  @max_sum 12
  
  # === GamePlugin Callbacks ===
  
  @impl true
  def start_game(_config, players) do
    game_id = generate_game_id()
    
    case GameStateManager.create_game(game_id, players) do
      {:ok, game_state} ->
        {:ok, %{
          game_id: game_id,
          status: :waiting_for_bets,
          players: players,
          created_at: game_state.created_at
        }}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @impl true
  def place_bet(game_id, player_id, bet_amount, bet_details) do
    predicted_sum = bet_details[:predicted_sum] || bet_details["predicted_sum"]
    
    cond do
      is_nil(predicted_sum) ->
        {:error, :missing_predicted_sum}
      
      not is_integer(predicted_sum) or predicted_sum < @min_sum or predicted_sum > @max_sum ->
        {:error, :invalid_prediction}
      
      bet_amount < @min_bet ->
        {:error, :bet_too_low}
      
      true ->
        # Débiter le portefeuille du joueur (séquestre)
        idempotency_key = "bet_#{game_id}_#{player_id}"
        
        case Wallet.place_bet(player_id, bet_amount, game_id, idempotency_key) do
          {:ok, _transaction} ->
            # Enregistrer le pari dans le GameState
            case GameStateManager.place_bet(game_id, player_id, bet_amount, predicted_sum) do
              {:ok, updated_state} ->
                {:ok, %{
                  bet_placed: true,
                  player_id: player_id,
                  amount: bet_amount,
                  predicted_sum: predicted_sum,
                  game_status: updated_state.status
                }}
              
              {:error, reason} ->
                # Rollback: créditer le joueur
                Wallet.credit_winnings(
                  player_id, bet_amount, game_id,
                  "rollback_#{game_id}_#{player_id}"
                )
                {:error, reason}
            end
          
          {:error, :insufficient_funds} ->
            {:error, :insufficient_funds}
          
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  @impl true
  def execute_turn(game_id) do
    case GameStateManager.execute_turn(game_id) do
      {:ok, %{dice: dice_results, sum: total_sum}} ->
        {:ok, %{
          game_id: game_id,
          dice_results: dice_results,
          total_sum: total_sum,
          executed_at: DateTime.utc_now()
        }}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @impl true
  def end_game(game_id) do
    with {:ok, game_state} <- GameStateManager.get_game_state(game_id),
         {:ok, turn_result} <- maybe_execute_turn(game_id, game_state),
         {:ok, result} <- GameStateManager.end_game(game_id) do
      # Créditer le gagnant si il y en a un
      payout_result = credit_winner(result, game_id)
      
      # Persister le résultat en DB (traçabilité 10 ans)
      persist_result(game_state, turn_result, result, payout_result)
      
      # Mettre à jour les agrégats statistiques (leaderboards, flux d'activité)
      record_game_stats(game_state, result)
      
      {:ok, %{
        game_id: game_id,
        status: :ended,
        winner: result.winner,
        loser: result.loser,
        result: result.result,
        dice_results: result.dice_results,
        total_sum: result.total_sum,
        total_pot: result[:total_pot] || 0,
        commission: result[:commission] || 0,
        net_winnings: result[:net_winnings] || 0,
        payout_status: payout_result,
        ended_at: DateTime.utc_now()
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @impl true
  def get_game_state(game_id) do
    GameStateManager.get_game_state(game_id)
  end
  
  @impl true
  def generate_random_result(%{dice_count: count}) do
    dice_results = Enum.map(1..count, fn _ ->
      generate_secure_dice_roll()
    end)
    
    %{
      dice: dice_results,
      sum: Enum.sum(dice_results)
    }
  end
  
  # === Fonctions Privées ===
  
  @doc """
  Si le tour n'a pas encore été exécuté, l'exécuter.
  Sinon, retourner les résultats existants.
  """
  defp maybe_execute_turn(game_id, game_state) do
    case game_state.status do
      :bets_placed ->
        execute_turn(game_id)
      
      :rolling ->
        {:ok, %{
          dice: game_state.dice_results,
          sum: game_state.total_sum
        }}
      
      _ ->
        {:error, :game_not_ready}
    end
  end
  
  @doc """
  Crédite les gains au gagnant via le wallet.
  """
  defp credit_winner(result, game_id) do
    case result.winner do
      nil ->
        :no_payout
      
      winner_id ->
        idempotency_key = "win_#{game_id}_#{winner_id}"
        
        case Wallet.credit_winnings(
          winner_id,
          result.net_winnings,
          game_id,
          idempotency_key
        ) do
          {:ok, _transaction} -> :paid
          {:error, reason} -> {:payout_error, reason}
        end
    end
  end
  
  @doc """
  Persiste le résultat complet en DB pour audit (10 ans).
  """
  defp persist_result(game_state, turn_result, end_result, _payout_status) do
    all_player_ids = game_state.players
    |> Enum.map(fn p -> Map.get(p, :id) || Map.get(p, "id") end)
    
    bets_data = game_state.bets
    |> Enum.map(fn {pid, bet} ->
      {"#{pid}", %{
        "amount" => bet.amount,
        "predicted_sum" => bet.predicted_sum
      }}
    end)
    |> Map.new()
    
    payouts_data = case end_result.winner do
      nil -> %{}
      winner_id -> %{"#{winner_id}" => end_result.net_winnings}
    end
    
    timestamp = DateTime.utc_now()
    
    verification_hash = DiceGameResult.generate_verification_hash(
      game_state.game_id,
      turn_result.dice,
      timestamp
    )
    
    %DiceGameResult{}
    |> DiceGameResult.create_changeset(%{
      game_id: game_state.game_id,
      dice_results: turn_result.dice,
      total_sum: turn_result.sum,
      dice_count: @dice_count,
      dice_type: 6,
      player_ids: all_player_ids,
      winner_id: end_result.winner,
      bets: bets_data,
      payouts: payouts_data,
      commission_amount: end_result[:commission] || 0,
      verification_hash: verification_hash
    })
    |> Repo.insert()
    
    :ok
  rescue
    error ->
      require Logger
      Logger.error("Failed to persist dice result: #{inspect(error)}")
      :ok
  end
  
  @doc """
  Enregistre les agrégats statistiques du match (non bloquant).
  """
  defp record_game_stats(game_state, end_result) do
    player_ids = game_state.players
    |> Enum.map(fn p -> Map.get(p, :id) || Map.get(p, "id") end)
    
    GameHub.GameStats.record_match_result(%{
      game_type: "dice",
      winner_id: end_result.winner,
      player_ids: player_ids,
      bets: game_state.bets,
      net_winnings: end_result[:net_winnings] || 0
    })
  rescue
    error ->
      require Logger
      Logger.error("Failed to record game stats: #{inspect(error)}")
      :ok
  end
  
  defp generate_secure_dice_roll do
    :crypto.strong_rand_bytes(1)
    |> :binary.decode_unsigned()
    |> rem(6)
    |> Kernel.+(1)
  end
  
  defp generate_game_id do
    "dice_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end
end
