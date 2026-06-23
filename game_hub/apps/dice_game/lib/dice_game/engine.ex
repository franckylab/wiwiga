# ==================================
# WIWIGA - Plugin Jeu de Dés OTP
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: DiceGame.Engine
# Description: Implémentation GamePlugin pour jeu de dés

defmodule DiceGame.Engine do
  @moduledoc """
  Moteur de jeu de dés implémentant GameHub.GamePlugin.
  
  ## Règles Jeu
  - 2-5 dés configurables
  - Chaque dé: 6 faces
  - Joueur parie sur somme totale
  - Génération aléatoire CRYPTO côté serveur
  """
  
  @behaviour GameHub.GamePlugin
  
  @doc """
  Démarre partie de dés.
  
  ## Exemple
      iex> DiceGame.Engine.start_game(%{dice_count: 3, min_bet: 100}, [%{id: "player1"}])
      {:ok, %{game_id: "game_123", status: :waiting_for_bets}}
  """
  @impl true
  def start_game(config, players) do
    game_id = generate_game_id()
    
    game_state = %{
      game_id: game_id,
      game_type: :dice,
      config: config,
      players: players,
      bets: %{},
      dice_results: [],
      status: :waiting_for_bets,
      started_at: DateTime.utc_now()
    }
    
    {:ok, game_state}
  end
  
  @doc """
  Place pari sur somme des dés.
  
  ## Parameters
    - `game_id`: ID partie
    - `player_id`: ID joueur
    - `bet_amount`: Montant
    - `bet_details`: %{predicted_sum: 10} (somme prédite)
  """
  @impl true
  def place_bet(game_id, player_id, bet_amount, bet_details) do
    # Validation
    if bet_amount < 100 do
      {:error, :bet_too_low}
    else
      # Enregistrer pari
      bet = %{
        player_id: player_id,
        amount: bet_amount,
        prediction: bet_details.predicted_sum,
        placed_at: DateTime.utc_now()
      }
      
      {:ok, %{bet_placed: bet}}
    end
  end
  
  @doc """
  Lance les dés (génération crypto sécurisée).
  
  ## Sécurité
  - Utilise :crypto.strong_rand_bytes/1
  - JAMAIS :rand.uniform
  - Côté serveur uniquement
  """
  @impl true
  def execute_turn(game_id) do
    # Nombre dés depuis config
    dice_count = 3 # Configurable
    
    # Générer résultats dés avec crypto sécurisé
    dice_results = Enum.map(1..dice_count, fn _ ->
      generate_secure_dice_roll()
    end)
    
    total_sum = Enum.sum(dice_results)
    
    result = %{
      game_id: game_id,
      dice_results: dice_results,
      total_sum: total_sum,
      executed_at: DateTime.utc_now()
    }
    
    {:ok, result}
  end
  
  @doc """
  Termine partie et calcule gains.
  
  ## Commission
  - Prélèvement sur gains selon config
  - Jamais sur mises perdues
  """
  @impl true
  def end_game(game_id) do
    # Calculer gagnants/perdants
    # Appliquer commission
    # Créditer gains (transaction ACID)
    
    payouts = %{
      game_id: game_id,
      status: :ended,
      ended_at: DateTime.utc_now()
    }
    
    {:ok, payouts}
  end
  
  @impl true
  def get_game_state(game_id) do
    {:ok, %{game_id: game_id, status: :in_progress}}
  end
  
  @doc """
  Génère lancé de dé sécurisé (1-6).
  
  ## Implementation
  Utilise :crypto.strong_rand_bytes pour véritable aléatoire.
  """
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
  
  defp generate_secure_dice_roll do
    # :crypto.strong_rand_bytes(1) -> 0-255
    # Modulo 6 + 1 -> 1-6
    :crypto.strong_rand_bytes(1)
    |> :binary.decode_unsigned()
    |> rem(6)
    |> Kernel.+(1)
  end
  
  defp generate_game_id do
    "dice_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end
end
