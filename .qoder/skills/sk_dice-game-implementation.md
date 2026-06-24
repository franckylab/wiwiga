# Skill: Implémentation Jeu de Dés (Dice Game)

## Description
Implémenter le premier jeu de WIWIGA - le jeu de lancé de dés - avec génération aléatoire sécurisée côté serveur, configuration paramétrable, et animations Flutter réalistes.

## Quand Utiliser
- Créer le plugin OTP `GameHub.Games.DiceGame`
- Développer l'interface Flutter du jeu de dés
- Configurer les paramètres de jeu en base de données
- Implémenter la logique de détermination du gagnant

## Architecture du Jeu

### Backend (Elixir/Phoenix OTP)

#### 1. Module Principal du Plugin

```elixir
defmodule GameHub.Games.DiceGame do
  @moduledoc """
  Plugin de jeu de dés pour WIWIGA.
  
  Supporte:
  - 1 à 3 dés par joueur
  - 1 à N lancés par partie
  - 3 méthodes de score (single_roll, sum_of_rolls, best_of_rolls)
  - 3 gestions d'égalité (refund, reroll, shared_pot)
  """
  
  @behaviour GameHub.GamePlugin
  use GenServer
  
  alias GameHub.Repo
  alias GameHub.Games.DiceGameConfig
  alias GameHub.Wallet
  alias GameHub.Commission
  
  # Structure d'état du jeu
  defstruct [
    :id,
    :config,
    :players,
    :current_roll,
    :rolls_history,
    :status, # :waiting, :rolling, :completed
    :winner,
    :pot_amount,
    :commission_amount,
  ]
  
  @impl GameHub.GamePlugin
  def start_game(players, settings) do
    config = load_config(settings.config_id)
    initial_state = build_initial_state(players, config, settings)
    
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(initial_state.id))
  end
  
  @impl GameHub.GamePlugin
  def handle_move(game_id, %{action: :roll_dice}, player_id) do
    GenServer.call(via_tuple(game_id), {:roll_dice, player_id})
  end
  
  @impl GenServer
  def handle_call({:roll_dice, player_id}, _from, state) do
    with :ok <- validate_player_turn(state, player_id),
         dice_results <- roll_dice_secure(state.config),
         new_state <- apply_roll(state, player_id, dice_results),
         winner <- determine_winner(new_state) do
      
      # Sauvegarder résultats en base
      save_roll_results(new_state, player_id, dice_results)
      
      # Broadcast aux joueurs
      broadcast_state_update(new_state)
      
      if winner do
        final_state = handle_game_end(new_state, winner)
        {:reply, {:ok, final_state}, final_state}
      else
        {:reply, {:ok, new_state}, new_state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  # ============================================================================
  # Génération Aléatoire SÉCURISÉE (Côté Serveur Uniquement)
  # ============================================================================
  
  @doc """
  Génère un lancé de dés aléatoire avec seed cryptographique.
  
  ## Parameters
    - `config`: Configuration du jeu
    - `number_of_dice`: Nombre de dés (1-3)
  
  ## Returns
    - Liste des valeurs de dés [3, 5, 2]
  
  ## Security
    Utilise :crypto.strong_rand_bytes pour génération sécurisée
    JAMAIS côté client!
  """
  @spec roll_dice_secure(DiceGameConfig.t()) :: [integer()]
  def roll_dice_secure(%{number_of_dice: num_dice, dice_type: dice_type}) do
    num_dice
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> rem(byte, dice_type) + 1 end)
  end
  
  # ============================================================================
  # Calcul du Score selon Méthode Configurée
  # ============================================================================
  
  @doc """
  Calcule le score selon la méthode configurée.
  
  ## Méthodes
    - `single_roll`: Somme d'un seul lancé
    - `sum_of_rolls`: Somme de tous les lancés
    - `best_of_rolls`: Meilleur lancé individuel
  """
  @spec calculate_score(rolls :: [[integer()]], method :: String.t()) :: integer()
  def calculate_score(rolls, "single_roll") do
    rolls |> List.flatten() |> Enum.sum()
  end
  
  def calculate_score(rolls, "sum_of_rolls") do
    rolls |> List.flatten() |> Enum.sum()
  end
  
  def calculate_score(rolls, "best_of_rolls") do
    rolls |> Enum.map(&Enum.sum/1) |> Enum.max()
  end
  
  # ============================================================================
  # Détermination du Gagnant
  # ============================================================================
  
  @spec determine_winner(GameState.t()) :: {:winner, player_id} | {:tie, atom()} | :ongoing
  def determine_winner(state) do
    if state.current_roll < state.config.number_of_rolls do
      :ongoing
    else
      player_scores = calculate_all_scores(state)
      max_score = player_scores |> Enum.map(& &1.score) |> Enum.max()
      winners = Enum.filter(player_scores, & &1.score == max_score)
      
      case length(winners) do
        1 -> {:winner, hd(winners).player_id}
        _ -> handle_tie(state.config.tie_handling)
      end
    end
  end
  
  defp handle_tie("refund"), do: {:tie, :refund}
  defp handle_tie("shared_pot"), do: {:tie, :share_pot}
  defp handle_tie("reroll"), do: {:tie, :reroll}
  
  # ============================================================================
  # Gestion de Fin de Partie
  # ============================================================================
  
  defp handle_game_end(state, {:winner, winner_id}) do
    # Calculer commission
    commission = Commission.calculate(state.pot_amount, state.config.game_id)
    
    # Payer le gagnant
    Wallet.credit_winner(winner_id, state.pot_amount - commission)
    
    # Sauvegarder résultat final
    save_game_result(state, winner_id, commission)
    
    # Log d'audit
    AuditLog.log(:game_ended, winner_id, %{
      game_id: state.id,
      pot: state.pot_amount,
      commission: commission,
      winner: winner_id,
    })
    
    %{state | status: :completed, winner: winner_id}
  end
  
  defp handle_game_end(state, {:tie, :refund}) do
    # Rembourser tous les joueurs
    Enum.each(state.players, fn player ->
      Wallet.refund_bet(player.id, player.bet_amount)
    end)
    
    AuditLog.log(:game_tied_refund, nil, %{
      game_id: state.id,
      refunded_players: length(state.players),
    })
    
    %{state | status: :completed, winner: nil}
  end
  
  defp handle_game_end(state, {:tie, :share_pot}) do
    commission = Commission.calculate(state.pot_amount, state.config.game_id)
    share_amount = div(state.pot_amount - commission, length(state.players))
    
    Enum.each(state.players, fn player ->
      Wallet.credit_winner(player.id, share_amount)
    end)
    
    %{state | status: :completed, winner: nil}
  end
  
  defp handle_game_end(state, {:tie, :reroll}) do
    # Réinitialiser pour relance
    %{state | current_roll: 0, rolls_history: []}
  end
  
  # ============================================================================
  # Helpers Privés
  # ============================================================================
  
  defp via_tuple(game_id) do
    {:via, Registry, {GameHub.GameRegistry, {:dice_game, game_id}}}
  end
  
  defp load_config(config_id) do
    Repo.get!(DiceGameConfig, config_id)
  end
  
  defp build_initial_state(players, config, settings) do
    %GameState{
      id: settings.game_id,
      config: config,
      players: players,
      current_roll: 0,
      rolls_history: [],
      status: :rolling,
      pot_amount: settings.pot_amount,
      commission_amount: settings.commission,
    }
  end
  
  defp validate_player_turn(state, player_id) do
    if Enum.any?(state.players, & &1.id == player_id) do
      :ok
    else
      {:error, :not_a_player}
    end
  end
  
  defp apply_roll(state, player_id, dice_results) do
    new_roll = %{
      player_id: player_id,
      roll_number: state.current_roll + 1,
      dice_results: dice_results,
      roll_score: Enum.sum(dice_results),
      timestamp: DateTime.utc_now(),
    }
    
    %{
      state
      | current_roll: state.current_roll + 1,
        rolls_history: state.rolls_history ++ [new_roll]
    }
  end
  
  defp calculate_all_scores(state) do
    Enum.map(state.players, fn player ->
      player_rolls = Enum.filter(state.rolls_history, & &1.player_id == player.id)
      |> Enum.map(& &1.dice_results)
      
      score = calculate_score(player_rolls, state.config.scoring_method)
      
      %{player_id: player.id, score: score}
    end)
  end
  
  defp save_roll_results(state, player_id, dice_results) do
    %DiceGameResult{
      game_id: state.id,
      player_id: player_id,
      roll_number: state.current_roll,
      dice_results: dice_results,
      roll_score: Enum.sum(dice_results),
      timestamp: DateTime.utc_now(),
      is_final: state.current_roll == state.config.number_of_rolls,
    }
    |> Repo.insert!()
  end
  
  defp save_game_result(state, winner_id, commission) do
    # Sauvegarder résultat final
    # Pour analytique et audit
  end
  
  defp broadcast_state_update(state) do
    # Via Phoenix Channel
    GameHubWeb.Endpoint.broadcast!(
      "game:#{state.id}",
      "state_update",
      serialize_state(state)
    )
  end
  
  defp serialize_state(state) do
    # Convertir état en JSON pour frontend
    %{
      game_id: state.id,
      status: state.status,
      current_roll: state.current_roll,
      total_rolls: state.config.number_of_rolls,
      players: Enum.map(state.players, fn p ->
        %{
          id: p.id,
          name: p.name,
          current_score: get_player_score(state, p.id),
        }
      end),
      last_rolls: get_last_rolls(state),
    }
  end
end
```

#### 2. Schema Ecto Configuration

```elixir
defmodule GameHub.Games.DiceGameConfig do
  use Ecto.Schema
  import Ecto.Query
  
  alias GameHub.Games.Game
  
  schema "dice_game_config" do
    field :game_id, :integer
    field :number_of_dice, :integer, default: 1
    field :number_of_rolls, :integer, default: 1
    field :dice_type, :integer, default: 6
    field :scoring_method, :string, default: "single_roll"
    field :tie_handling, :string, default: "reroll"
    field :active, :boolean, default: true
    
    timestamps()
  end
  
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:game_id, :number_of_dice, :number_of_rolls, :dice_type, :scoring_method, :tie_handling, :active])
    |> validate_required([:game_id])
    |> validate_inclusion(:number_of_dice, 1..3)
    |> validate_inclusion(:number_of_rolls, 1..10)
    |> validate_inclusion(:dice_type, [6])
    |> validate_inclusion(:scoring_method, ["single_roll", "sum_of_rolls", "best_of_rolls"])
    |> validate_inclusion(:tie_handling, ["refund", "reroll", "shared_pot"])
  end
end
```

#### 3. Migration

```elixir
defmodule GameHub.Repo.Migrations.CreateDiceGameConfig do
  use Ecto.Migration
  
  def up do
    create table(:dice_game_config, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :number_of_dice, :integer, default: 1, null: false
      add :number_of_rolls, :integer, default: 1, null: false
      add :dice_type, :integer, default: 6, null: false
      add :scoring_method, :string, default: "single_roll", null: false
      add :tie_handling, :string, default: "reroll", null: false
      add :active, :boolean, default: true, null: false
      timestamps()
    end
    
    create index(:dice_game_config, [:game_id])
    create unique_index(:dice_game_config, [:game_id])
    
    # Contraintes CHECK
    execute """
      ALTER TABLE dice_game_config
      ADD CONSTRAINT number_of_dice_check CHECK (number_of_dice BETWEEN 1 AND 3)
    """
    
    execute """
      ALTER TABLE dice_game_config
      ADD CONSTRAINT number_of_rolls_check CHECK (number_of_rolls BETWEEN 1 AND 10)
    """
    
    execute """
      ALTER TABLE dice_game_config
      ADD CONSTRAINT scoring_method_check CHECK (scoring_method IN ('single_roll', 'sum_of_rolls', 'best_of_rolls'))
    """
    
    execute """
      ALTER TABLE dice_game_config
      ADD CONSTRAINT tie_handling_check CHECK (tie_handling IN ('refund', 'reroll', 'shared_pot'))
    """
  end
  
  def down do
    drop table(:dice_game_config)
  end
end
```

#### 4. Table Résultats

```elixir
defmodule GameHub.Repo.Migrations.CreateDiceGameResults do
  use Ecto.Migration
  
  def up do
    create table(:dice_game_results, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_id, :bigint, null: false
      add :room_id, :bigint
      add :tournament_id, :bigint
      add :player_id, :bigint, null: false
      add :roll_number, :integer, null: false
      add :dice_results, {:array, :integer}, null: false
      add :roll_score, :integer, null: false
      add :timestamp, :utc_datetime, null: false
      add :is_final, :boolean, default: false
      timestamps()
    end
    
    create index(:dice_game_results, [:game_id])
    create index(:dice_game_results, [:player_id])
    create index(:dice_game_results, [:timestamp])
  end
  
  def down do
    drop table(:dice_game_results)
  end
end
```

### Frontend (Flutter)

#### 1. Provider du Jeu

```dart
class DiceGameState {
  final String gameId;
  final String status; // 'waiting', 'rolling', 'completed'
  final int currentRoll;
  final int totalRolls;
  final List<DicePlayer> players;
  final List<int>? lastRollResults;
  final String? winnerId;
  final bool isRolling;
  
  const DiceGameState({
    required this.gameId,
    this.status = 'waiting',
    this.currentRoll = 0,
    this.totalRolls = 1,
    this.players = const [],
    this.lastRollResults,
    this.winnerId,
    this.isRolling = false,
  });
  
  DiceGameState copyWith({
    String? status,
    int? currentRoll,
    int? totalRolls,
    List<DicePlayer>? players,
    List<int>? lastRollResults,
    String? winnerId,
    bool? isRolling,
  }) {
    return DiceGameState(
      gameId: gameId,
      status: status ?? this.status,
      currentRoll: currentRoll ?? this.currentRoll,
      totalRolls: totalRolls ?? this.totalRolls,
      players: players ?? this.players,
      lastRollResults: lastRollResults ?? this.lastRollResults,
      winnerId: winnerId,
      isRolling: isRolling ?? this.isRolling,
    );
  }
}

class DiceGameNotifier extends StateNotifier<DiceGameState> {
  final String gameId;
  GameWebSocket? _webSocket;
  
  DiceGameNotifier(this.gameId) 
    : super(DiceGameState(gameId: gameId));
  
  void connect(String jwtToken) {
    _webSocket = GameWebSocket(gameId: gameId);
    
    _webSocket!.gameStateStream.listen((state) {
      state = state.copyWith(
        status: state['status'],
        currentRoll: state['current_roll'],
        totalRolls: state['total_rolls'],
        players: (state['players'] as List)
            .map((p) => DicePlayer.fromJson(p))
            .toList(),
        lastRollResults: state['last_rolls'] != null
            ? List<int>.from(state['last_rolls'])
            : null,
        winnerId: state['winner_id'],
        isRolling: state['status'] == 'rolling',
      );
    });
    
    _webSocket!.connect(jwtToken);
  }
  
  Future<void> rollDice() async {
    state = state.copyWith(isRolling: true);
    
    try {
      await _webSocket!.placeBet(1000); // Exemple
    } catch (e) {
      state = state.copyWith(isRolling: false);
    }
  }
  
  @override
  void dispose() {
    _webSocket?.dispose();
    super.dispose();
  }
}

final diceGameProvider = StateNotifierProvider.family<DiceGameNotifier, DiceGameState, String>(
  (ref, gameId) => DiceGameNotifier(gameId),
);
```

#### 2. Écran de Jeu

```dart
class DiceGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  
  const DiceGameScreen({super.key, required this.gameId});
  
  @override
  ConsumerState<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends ConsumerState<DiceGameScreen>
    with TickerProviderStateMixin {
  late AnimationController _rollAnimationController;
  late AnimationController _celebrationController;
  
  @override
  void initState() {
    super.initState();
    
    _rollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    final jwtToken = ref.read(authProvider).token;
    ref.read(diceGameProvider(widget.gameId).notifier).connect(jwtToken);
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(diceGameProvider(widget.gameId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeu de Dés'),
        actions: [
          Text('Lancé ${gameState.currentRoll}/${gameState.totalRolls}'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _DiceArea(
              gameState: gameState,
              animationController: _rollAnimationController,
            ),
          ),
          _PlayerScores(players: gameState.players),
          if (gameState.winnerId != null)
            _WinnerBanner(
              winnerId: gameState.winnerId!,
              animationController: _celebrationController,
            ),
          _RollButton(
            onPressed: gameState.isRolling ? null : () => _rollDice(),
            isRolling: gameState.isRolling,
          ),
        ],
      ),
    );
  }
  
  void _rollDice() {
    _rollAnimationController.forward(from: 0);
    
    ref
        .read(diceGameProvider(widget.gameId).notifier)
        .rollDice();
  }
  
  @override
  void dispose() {
    _rollAnimationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }
}

class _DiceArea extends StatelessWidget {
  final DiceGameState gameState;
  final AnimationController animationController;
  
  const _DiceArea({
    required this.gameState,
    required this.animationController,
  });
  
  @override
  Widget build(BuildContext context) {
    if (gameState.isRolling) {
      return Center(
        child: AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: animationController.value * 20,
              child: child,
            );
          },
          child: Icon(
            Icons.casino,
            size: 150,
            color: Colors.grey[400],
          ),
        ),
      );
    }
    
    if (gameState.lastRollResults != null) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: gameState.lastRollResults!.map((value) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: DiceWidget(value: value),
            );
          }).toList(),
        ),
      );
    }
    
    return const Center(
      child: Text('Appuyez pour lancer les dés'),
    );
  }
}

class DiceWidget extends StatelessWidget {
  final int value;
  
  const DiceWidget({super.key, required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
```

## Checklist Validation
- [ ] Génération aléatoire avec `:crypto.strong_rand_bytes/1`
- [ ] JAMAIS de `:rand.uniform` ou Random côté client
- [ ] Configuration chargée depuis DB `dice_game_config`
- [ ] Résultats sauvegardés dans `dice_game_results`
- [ ] Horodatage de chaque lancé
- [ ] Gestion égalité (refund/reroll/shared_pot)
- [ ] Commission calculée et prélevée
- [ ] Gagnant crédité via transaction ACID
- [ ] Log d'audit créé à fin de partie
- [ ] Animation Flutter réaliste
- [ ] WebSocket broadcast état du jeu
- [ ] Tests unitaires >90%

## Pièges à Éviter
- ❌ JAMAIS de logique de détermination du gagnant côté client
- ❌ JAMAIS de stockage des résultats uniquement en mémoire
- ❌ JAMAIS d'utiliser timestamp comme seed aléatoire
- ❌ JAMAIS de permettre plusieurs lancés simultanés
- ❌ JAMAIS d'ignorer la configuration DB (scoring_method, tie_handling)
- ❌ JAMAIS de créditer le gagnant sans transaction ACID

## Références
- `GAME_HUB_PROMPT_FR.md` - Section 5: Jeu de Dés
- `.qoder/rules/rl_development-best-practices.md` - Règle 3: Génération Aléatoire
- `.qoder/skills/sk_backend-elixir-phoenix.md` - Plugins OTP
