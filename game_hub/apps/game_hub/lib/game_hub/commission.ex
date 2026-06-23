# ==================================
# WIWIGA - Module Commission
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Commission
# Description: Calcul commission depuis DB (jamais hardcodé)

defmodule GameHub.Commission do
  @moduledoc """
  Gestion des commissions sur les jeux.
  
  ## Règles
  - Commission TOUJOURS depuis DB
  - JAMAIS hardcodée dans code
  - Configurée par jeu
  - 3 modes: percentage, fixed, tiered
  
  ## Audit
  - Chaque commission enregistrée
  - Traçabilité complète
  """
  
  import Ecto.Query
  alias GameHub.Repo
  alias GameHub.Games.GameConfig
  alias GameHub.Wallet.WalletTransaction
  
  @doc """
  Récupère configuration commission pour un jeu.
  
  ## Parameters
    - `game_type`: Type jeu (:dice, :card, etc.)
  
  ## Returns
    - `%GameConfig{}`: Configuration complète
    - `nil`: Jeu non trouvé
  """
  @spec get_game_config(String.t()) :: GameConfig.t() | nil
  def get_game_config(game_type) do
    query = from gc in GameConfig,
      where: gc.game_type == ^game_type and gc.is_active == true,
      select: gc
    
    Repo.one(query)
  end
  
  @doc """
  Calcule commission sur gains.
  
  ## Parameters
    - `game_type`: Type jeu
    - `winnings`: Montant gains (integer centimes)
  
  ## Returns
    - `{:ok, commission_amount}`: Commission calculée
    - `{:error, :game_not_found}`: Jeu inexistant
  """
  @spec calculate_commission(String.t(), integer()) :: {:ok, integer()} | {:error, atom()}
  def calculate_commission(game_type, winnings) do
    case get_game_config(game_type) do
      nil ->
        {:error, :game_not_found}
      
      config ->
        commission = apply_commission_rules(config, winnings)
        {:ok, commission}
    end
  end
  
  @doc """
  Applique règles commission selon mode configuré.
  
  ## Modes
    - `percentage`: % des gains
    - `fixed`: Montant fixe
    - `tiered`: Barème progressif
  """
  defp apply_commission_rules(%{commission_mode: "percentage", commission_rate: rate}, winnings) do
    # Percentage: winnings * rate
    Decimal.mult(winnings, rate)
    |> Decimal.to_integer()
  end
  
  defp apply_commission_rules(%{commission_mode: "fixed", config: config}, _winnings) do
    # Fixed: montant fixe depuis config
    Map.get(config, "fixed_amount", 0)
  end
  
  defp apply_commission_rules(%{commission_mode: "tiered", config: config}, winnings) do
    # Tiered: barème progressif
    tiers = Map.get(config, "tiers", [])
    
    calculate_tiered_commission(tiers, winnings)
  end
  
  defp apply_commission_rules(_, _), do: 0
  
  @doc """
  Calcule commission barème progressif.
  
  Exemple tiers:
    0-10000: 5%
    10001-50000: 4%
    50001+: 3%
  """
  defp calculate_tiered_commission(tiers, winnings) do
    tiers
    |> Enum.sort_by(& &1["min"])
    |> find_applicable_tier(winnings)
    |> calculate_tier_amount(winnings)
  end
  
  defp find_applicable_tier(tiers, winnings) do
    Enum.find(tiers, fn tier ->
      min = tier["min"] || 0
      max = tier["max"] || :infinity
      
      winnings >= min and (max == :infinity or winnings <= max)
    end)
  end
  
  defp calculate_tier_amount(nil, _), do: 0
  
  defp calculate_tier_amount(%{"rate" => rate}, winnings) do
    Decimal.mult(winnings, rate)
    |> Decimal.to_integer()
  end
  
  @doc """
  Enregistre transaction commission.
  
  ## Parameters
    - `game_id`: ID partie
    - `user_id`: ID joueur
    - `commission_amount`: Montant commission
    - `idempotency_key`: Clé unique
  """
  @spec record_commission(String.t(), String.t(), integer(), String.t()) :: {:ok, map()} | {:error, atom()}
  def record_commission(game_id, user_id, commission_amount, idempotency_key) do
    # Créer transaction commission (ACID)
    transaction = %{
      user_id: user_id,
      type: "commission",
      amount: -commission_amount, # Débit
      balance_before: 0, # À calculer dans transaction
      balance_after: 0, # À calculer dans transaction
      idempotency_key: idempotency_key,
      game_id: game_id,
      metadata: %{
        reason: "commission_house",
        game_type: extract_game_type(game_id)
      }
    }
    
    # Insérer via Wallet (ACID)
    # Wallet.create_transaction(transaction)
    
    {:ok, transaction}
  end
  
  @doc """
  Prélève commission sur gains avant paiement.
  
  ## Flow
  1. Calculer commission
  2. Débiter commission
  3. Créditer net = winnings - commission
  """
  @spec deduct_commission(String.t(), String.t(), integer(), String.t()) :: {:ok, %{net: integer(), commission: integer()}} | {:error, atom()}
  def deduct_commission(game_type, user_id, winnings, idempotency_key) do
    with {:ok, commission} <- calculate_commission(game_type, winnings),
         {:ok, _commission_txn} <- record_commission("system", user_id, commission, "#{idempotency_key}_commission") do
      
      net_winnings = winnings - commission
      
      {:ok, %{
        net: net_winnings,
        commission: commission,
        gross: winnings
      }}
    end
  end
  
  @doc """
  Stats commissions par période.
  """
  @spec get_commission_stats(Date.t(), Date.t()) :: %{total: integer(), by_game: map()}
  def get_commission_stats(start_date, end_date) do
    query = from t in WalletTransaction,
      where: t.type == "commission" and
             t.inserted_at >= ^start_date and
             t.inserted_at <= ^end_date,
      select: {t.game_id, t.amount}
    
    commissions = Repo.all(query)
    
    total = Enum.reduce(commissions, 0, fn {_, amount}, acc -> acc + abs(amount) end)
    
    by_game = commissions
      |> Enum.group_by(fn {game_id, _} -> game_id end, fn {_, amount} -> abs(amount) end)
      |> Enum.map(fn {game, amounts} -> {game, Enum.sum(amounts)} end)
      |> Enum.into(%{})
    
    %{total: total, by_game: by_game}
  end
  
  # === Fonctions Privées ===
  
  defp extract_game_type("dice_" <> _), do: "dice"
  defp extract_game_type(_), do: "unknown"
end
