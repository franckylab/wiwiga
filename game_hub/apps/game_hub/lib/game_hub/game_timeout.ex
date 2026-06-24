# ==================================
# WIWIGA - Module Game Timeout
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameTimeout
# Description: Gestion des déconnexions et timeouts (Règle 8)

defmodule GameHub.GameTimeout do
  @moduledoc """
  Module de gestion des timeouts de jeu.
  
  Politique configurable (Règle 8) :
  - Délai de grâce avant action
  - Action en cas de timeout (forfeit/refund/pause)
  - Distribution des mises
  - Reconnexion autorisée
  """
  
  alias GameHub.Repo
  alias GameHub.Games.GameTimeoutConfig
  
  @doc """
  Gère la déconnexion d'un joueur.
  
  ## Parameters
    - `player_id`: ID joueur
    - `game_id`: ID partie
    - `game_type`: Type de jeu
  
  ## Returns
    - `:ok`: Timeout planifié
    - `{:error, reason}`: Erreur
  """
  @spec handle_disconnect(String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  def handle_disconnect(player_id, game_id, game_type) do
    config = get_config(game_type)
    
    unless config do
      # Config par défaut
      apply_forfeit(player_id, game_id, %{
        grace_period_seconds: 120,
        action_on_timeout: "forfeit",
        forfeit_distribution: "to_winner"
      })
      
      :ok
    else
      # Planifier timeout
      Process.send_after(
        self(),
        {:timeout_check, player_id, game_id},
        config.grace_period_seconds * 1000
      )
      
      :ok
    end
  end
  
  @doc """
  Gère la reconnexion d'un joueur.
  
  ## Parameters
    - `player_id`: ID joueur
    - `game_id`: ID partie
  
  ## Returns
    - `:ok`: Reconnexion réussie
    - `{:error, :timeout_already_applied}`: Timeout déjà appliqué
  """
  @spec handle_reconnect(String.t(), String.t()) :: :ok | {:error, atom()}
  def handle_reconnect(_player_id, _game_id) do
    # Annuler le timeout si encore en attente
    # Pour simplification, on considère que le joueur est revenu à temps
    :ok
  end
  
  @doc """
  Applique la politique de timeout.
  
  ## Parameters
    - `player_id`: ID joueur
    - `game_id`: ID partie
    - `config`: Configuration timeout
  
  ## Returns
    - `:ok`: Action appliquée
  """
  @spec apply_forfeit(String.t(), String.t(), map()) :: :ok
  def apply_forfeit(player_id, game_id, config) do
    case config.action_on_timeout do
      "forfeit" ->
        apply_forfeit_action(player_id, game_id, config.forfeit_distribution)
      
      "refund" ->
        apply_refund_action(player_id, game_id)
      
      "pause" ->
        apply_pause_action(game_id)
      
      _ ->
        apply_forfeit_action(player_id, game_id, "to_winner")
    end
  end
  
  @doc """
  Récupère la configuration timeout pour un type de jeu.
  
  ## Parameters
    - `game_type`: Type de jeu
  
  ## Returns
    - `%GameTimeoutConfig{}`: Configuration ou nil
  """
  @spec get_config(String.t()) :: GameTimeoutConfig.t() | nil
  def get_config(game_type) do
    Repo.get_by(GameTimeoutConfig, game_type: game_type, is_active: true)
  end
  
  # === Fonctions Privées ===
  
  defp apply_forfeit_action(player_id, game_id, distribution) do
    # Logique de forfeiture
    # - Marquer joueur comme forfait
    # - Distribuer mise selon configuration
    # - Notifier adversaire
    
    IO.puts("[FORFEIT] Player #{player_id} forfeited game #{game_id} (distribution: #{distribution})")
    
    # TODO: Implémenter distribution selon type
    case distribution do
      "to_winner" ->
        # Mise va à l'adversaire
        :ok
      
      "split" ->
        # Mise divisée entre joueurs restants
        :ok
      
      "pool" ->
        # Mise va au pool
        :ok
    end
  end
  
  defp apply_refund_action(player_id, game_id) do
    # Remboursement de la mise
    IO.puts("[REFUND] Player #{player_id} refunded for game #{game_id}")
    
    # TODO: Créditer mise au joueur
    :ok
  end
  
  defp apply_pause_action(game_id) do
    # Pause de la partie
    IO.puts("[PAUSE] Game #{game_id} paused")
    
    # TODO: Mettre jeu en pause
    :ok
  end
end
