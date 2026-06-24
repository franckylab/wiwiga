# Skill: Implémentation Frontend Flutter

## Description
Développer l'application Flutter WIWIGA (web + Android) avec gestion d'état Riverpod, sécurité des données, UX conforme aux standards jeux d'argent, support multiplateforme, et design system néon gaming.

## Design System Néon Gaming
⚠️ **OBLIGATOIRE** : Tous les écrans DOIVENT utiliser le design system néon gaming défini dans :
- **Règles** : `.qoder/rules/rl_design-system.md`
- **Composants** : `.qoder/skills/sk_neon-components.md`
- **Thème** : `lib/core/theme/neon_theme.dart`

### Règles Rapides
1. **TOUJOURS** utiliser les 10 composants néon (NeonButton, NeonCard, NeonInput, etc.)
2. **JAMAIS** utiliser les widgets Material natifs directement
3. Palette : Vert #2DD4BF (primaire), Orange #F59E0B (secondaire), Fond #1E293B
4. Typographie : Inter (body) + Orbitron (titres/montants)
5. Animations : 100ms (micro), 200ms (standard), 300ms (transitions)
6. Configuration dynamique : Tous les paramètres sont configurables via dashboard admin

## Quand Utiliser
- Créer un nouvel écran Flutter
- Implémenter un provider Riverpod
- Développer un widget réutilisable
- Gérer la communication WebSocket
- Implémenter l'internationalisation (i18n)
- Appliquer le design system néon

## Étapes d'Implémentation

### 1. Structure Provider Riverpod

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State
class WalletState {
  final int balance;
  final bool isLoading;
  final String? error;
  final List<Transaction> transactions;
  
  const WalletState({
    this.balance = 0,
    this.isLoading = false,
    this.error,
    this.transactions = const [],
  });
  
  WalletState copyWith({
    int? balance,
    bool? isLoading,
    String? error,
    List<Transaction>? transactions,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      transactions: transactions ?? this.transactions,
    );
  }
  
  factory WalletState.initial() => const WalletState();
}

// Notifier
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repository;
  
  WalletNotifier(this._repository) : super(WalletState.initial());
  
  Future<void> loadBalance() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final balance = await _repository.getBalance();
      state = state.copyWith(
        balance: balance,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du chargement du solde',
      );
    }
  }
  
  Future<void> deposit(int amount) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _repository.initiateDeposit(amount);
      state = state.copyWith(
        balance: result.newBalance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _mapDepositError(e),
      );
    }
  }
  
  String _mapDepositError(dynamic error) {
    if (error is NetworkException) {
      return 'Problème de connexion. Vérifiez votre internet.';
    } else if (error is ApiValidationException) {
      return 'Le montant doit être entre 100 et 1 000 000 FCFA';
    } else {
      return 'Une erreur est survenue. Réessayez.';
    }
  }
}

// Provider
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(repository);
});
```

### 2. Écran avec ConsumerWidget

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Portefeuille'),
      ),
      body: wallet.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(walletProvider.notifier).loadBalance(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(balance: wallet.balance),
                  const SizedBox(height: 24),
                  _ActionButtons(onDeposit: () => _showDepositDialog(context, ref)),
                  const SizedBox(height: 24),
                  if (wallet.error != null)
                    _ErrorBanner(message: wallet.error!),
                  const SizedBox(height: 16),
                  _TransactionList(transactions: wallet.transactions),
                ],
              ),
            ),
    );
  }
  
  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => DepositDialog(ref: ref),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int balance;
  
  const _BalanceCard({required this.balance});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solde disponible',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatCurrency(balance)} FCFA',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
  }
}
```

### 3. Dialog avec Gestion d'Erreurs UX

```dart
class DepositDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  
  const DepositDialog({super.key, required this.ref});
  
  @override
  ConsumerState<DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends ConsumerState<DepositDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    
    return AlertDialog(
      title: const Text('Effectuer un dépôt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                helperText: 'Exemple: 5000',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                final amount = int.tryParse(value);
                if (amount == null) {
                  return 'Montant invalide';
                }
                if (amount < 100) {
                  return 'Le montant minimum est 100 FCFA';
                }
                if (amount > 1_000_000) {
                  return 'Le montant maximum est 1 000 000 FCFA';
                }
                return null;
              },
            ),
            if (wallet.error != null) ...[
              const SizedBox(height: 16),
              Text(
                wallet.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: wallet.isLoading ? null : _submit,
          child: wallet.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Déposer'),
        ),
      ],
    );
  }
  
  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = int.parse(_amountController.text);
      widget.ref
          .read(walletProvider.notifier)
          .deposit(amount)
          .then((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dépôt initié avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
```

### 4. Communication WebSocket

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

class GameWebSocket {
  final String gameId;
  WebSocketChannel? _channel;
  
  // Stream controllers
  final _gameStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  Stream<Map<String, dynamic>> get gameStateStream => _gameStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  Future<void> connect(String jwtToken) async {
    final url = Uri.parse('wss://api.wiwiga.com/socket/websocket');
    
    _channel = WebSocketChannel.connect(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
      },
    );
    
    _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDisconnect,
    );
    
    // Join game room
    _sendMessage({
      'event': 'phx_join',
      'topic': 'game:$gameId',
    });
  }
  
  Future<void> placeBet(int amount) async {
    _sendMessage({
      'event': 'place_bet',
      'topic': 'game:$gameId',
      'payload': {
        'amount': amount,
        'idempotency_key': _generateIdempotencyKey(),
      },
    });
  }
  
  void _handleMessage(dynamic message) {
    final data = jsonDecode(message);
    
    switch (data['event']) {
      case 'game_state_update':
        _gameStateController.add(data['payload']);
        break;
      case 'bet_placed':
        _gameStateController.add(data['payload']);
        break;
      case 'game_ended':
        _gameStateController.add(data['payload']);
        break;
      case 'error':
        _errorController.add(data['payload']['message']);
        break;
    }
  }
  
  void _handleError(dynamic error) {
    _errorController.add('Erreur de connexion: ${error.toString()}');
  }
  
  void _handleDisconnect() {
    _errorController.add('Déconnecté du serveur');
  }
  
  void _sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }
  
  String _generateIdempotencyKey() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  void dispose() {
    _channel?.sink.close();
    _gameStateController.close();
    _errorController.close();
  }
}
```

### 5. Écran de Jeu avec Animations

```dart
class DiceGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final GameConfig config;
  
  const DiceGameScreen({
    super.key,
    required this.gameId,
    required this.config,
  });
  
  @override
  ConsumerState<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends ConsumerState<DiceGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<int> _diceResults = [];
  bool _isRolling = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _setupWebSocket();
  }
  
  void _setupWebSocket() {
    final ws = GameWebSocket(gameId: widget.gameId);
    
    ws.gameStateStream.listen((state) {
      if (mounted) {
        setState(() {
          if (state['dice_results'] != null) {
            _diceResults = List<int>.from(state['dice_results']);
          }
          _isRolling = state['is_rolling'] ?? false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jeu de Dés'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DiceDisplay(
              diceResults: _diceResults,
              isRolling: _isRolling,
              animationController: _animationController,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isRolling ? null : _rollDice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: _isRolling
                  ? const Text('Lancement en cours...')
                  : const Text('Lancer les dés'),
            ),
            if (_diceResults.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Total: ${_diceResults.reduce((a, b) => a + b)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _rollDice() {
    _animationController.forward(from: 0);
    
    // Envoyer requête au serveur
    ref.read(gameProvider.notifier).rollDice(widget.gameId);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _DiceDisplay extends StatelessWidget {
  final List<int> diceResults;
  final bool isRolling;
  final AnimationController animationController;
  
  const _DiceDisplay({
    required this.diceResults,
    required this.isRolling,
    required this.animationController,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isRolling) {
      return AnimatedBuilder(
        animation: animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: animationController.value * 20,
            child: child,
          );
        },
        child: const Icon(
          Icons.casino,
          size: 120,
          color: Colors.grey,
        ),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: diceResults.map((value) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: _DiceWidget(value: value),
        );
      }).toList(),
    );
  }
}

class _DiceWidget extends StatelessWidget {
  final int value;
  
  const _DiceWidget({required this.value});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
```

### 6. Internationalisation (i18n)

```dart
// lib/l10n/app_fr.arb
{
  "wallet_title": "Mon Portefeuille",
  "wallet_balance": "Solde disponible",
  "wallet_deposit": "Effectuer un dépôt",
  "wallet_withdraw": "Retrait",
  "wallet_transactions": "Historique des transactions",
  "deposit_amount_label": "Montant (FCFA)",
  "deposit_amount_helper": "Exemple: 5000",
  "deposit_minimum_error": "Le montant minimum est 100 FCFA",
  "deposit_maximum_error": "Le montant maximum est 1 000 000 FCFA",
  "deposit_success": "Dépôt initié avec succès!",
  "deposit_failed": "Votre dépôt n'a pas abouti. Vérifiez votre téléphone et réessayez.",
  "deposit_retry": "Réessayer",
  "deposit_change_method": "Changer de méthode",
  "deposit_contact_support": "Contacter support"
}

// Utilisation
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Text(AppLocalizations.of(context)!.wallet_balance)
```

### 7. Tests Flutter

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('WalletNotifier Tests', () {
    late MockWalletRepository mockRepository;
    late WalletNotifier notifier;
    
    setUp(() {
      mockRepository = MockWalletRepository();
      notifier = WalletNotifier(mockRepository);
    });
    
    test('initial state has zero balance', () {
      expect(notifier.state.balance, 0);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });
    
    test('deposit updates balance on success', () async {
      when(mockRepository.initiateDeposit(1000))
          .thenAnswer((_) async => DepositResult(newBalance: 11000));
      
      notifier = WalletNotifier(mockRepository)
        ..state = notifier.state.copyWith(balance: 10000);
      
      await notifier.deposit(1000);
      
      expect(notifier.state.balance, 11000);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });
    
    test('deposit sets error on failure', () async {
      when(mockRepository.initiateDeposit(1000))
          .thenThrow(NetworkException());
      
      await notifier.deposit(1000);
      
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, contains('Problème de connexion'));
    });
  });
  
  group('WalletScreen Widget Tests', () {
    testWidgets('displays balance correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletProvider.overrideWith((ref) {
              final notifier = WalletNotifier(MockWalletRepository());
              notifier.state = notifier.state.copyWith(balance: 5000);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: WalletScreen(),
          ),
        ),
      );
      
      expect(find.text('5 000 FCFA'), findsOneWidget);
    });
    
    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletProvider.overrideWith((ref) {
              final notifier = WalletNotifier(MockWalletRepository());
              notifier.state = notifier.state.copyWith(isLoading: true);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: WalletScreen(),
          ),
        ),
      );
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

## Checklist Validation
- [ ] Providers Riverpod immutables (`StateNotifier`)
- [ ] Error states gérés dans chaque provider
- [ ] Loading states pour UX réactive
- [ ] Validation formulaires côté frontend
- [ ] Messages d'erreur en français clairs
- [ ] WebSocket avec reconnexion automatique
- [ ] Internationalisation ARB configurée
- [ ] Accessibilité (labels, contraste, cibles tactiles)
- [ ] Tests unitaires et widget >80% couverture
- [ ] Pas de logique métier dans widgets
- [ ] Repository pattern pour isolation données

## Pièges à Éviter
- ❌ JAMAIS de `setState` global pour état partagé
- ❌ JAMAIS de logique métier dans widgets
- ❌ JAMAIS de génération aléatoire côté client pour jeux
- ❌ JAMAIS de stockage de tokens JWT en clair
- ❌ JAMAIS de validation financière côté client uniquement
- ❌ JAMAIS d'ignorer les error states

## Références
- `GAME_HUB_PROMPT_FR.md` - Spécifications complètes
- `.qoder/rules/rl_development-best-practices.md` - Règles de développement
- Documentation Flutter: https://docs.flutter.dev
- Documentation Riverpod: https://riverpod.dev
