# ==================================
# WIWIGA - Interface Plugin Jeu
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GamePlugin
# Description: Interface OTP que chaque jeu doit implémenter

defmodule GameHub.GamePlugin do
  @moduledoc """
  Interface standardisée pour plugins de jeux OTP.
  
  Chaque jeu (DiceGame, CardGame, etc.) DOIT implémenter
  ce behaviour pour être compatible avec le hub central.
  """
  
  @doc """
  Démarre une nouvelle partie.
  
  ## Parameters
    - `config`: Configuration jeu (min_bet, max_bet, commission, etc.)
    - `players`: Liste joueurs
  
  ## Returns
    - `{:ok, game_state}`
    - `{:error, reason}`
  """
  @callback start_game(map(), list(map())) :: {:ok, map()} | {:error, atom()}
  
  @doc """
  Place un pari pour un joueur.
  
  ## Parameters
    - `game_id`: ID partie
    - `player_id`: ID joueur
    - `bet_amount`: Montant pari
    - `bet_details`: Détails du pari (spécifique au jeu)
  
  ## Returns
    - `{:ok, updated_game_state}`
    - `{:error, :invalid_bet}`
    - `{:error, :insufficient_funds}`
  """
  @callback place_bet(String.t(), String.t(), integer(), map()) ::
              {:ok, map()} | {:error, atom()}
  
  @doc """
  Exécute le tour de jeu (lancer dés, distribuer cartes, etc.)
  
  ## Parameters
    - `game_id`: ID partie
  
  ## Returns
    - `{:ok, game_result}`: Résultats avec gagnants
    - `{:error, :game_not_started}`
  """
  @callback execute_turn(String.t()) :: {:ok, map()} | {:error, atom()}
  
  @doc """
  Termine la partie et distribue gains.
  
  ## Parameters
    - `game_id`: ID partie
  
  ## Returns
    - `{:ok, payouts}`: Map des paiements par joueur
    - `{:error, :game_already_ended}`
  """
  @callback end_game(String.t()) :: {:ok, map()} | {:error, atom()}
  
  @doc """
  Récupère état actuel du jeu.
  
  ## Parameters
    - `game_id`: ID partie
  
  ## Returns
    - `{:ok, game_state}`
  """
  @callback get_game_state(String.t()) :: {:ok, map()} | {:error, atom()}
  
  @doc """
  Génère résultat aléatoire sécurisé (dés, cartes, etc.)
  
  ## Parameters
    - `config`: Configuration aléatoire (nombre dés, faces, etc.)
  
  ## Returns
    - `random_result`: Résultat généré avec :crypto.strong_rand_bytes
  """
  @callback generate_random_result(map()) :: map()
end
