# Skill Frontend Flutter — WIWIGA

## Quand Utiliser

Toute tâche frontend impliquant :
- Écrans Flutter (pages, vues)
- Widgets personnalisés
- State management Riverpod
- Design system néon
- Responsive design
- Navigation et routing

## Architecture Frontend

```
lib/
├── core/            # Config, thème, constantes
├── data/            # Models, repositories, providers, services
├── presentation/    # Widgets, screens
└── main.dart        # Entry point + ProviderScope
```

## Pattern Écran Standard

```dart
class MyFeatureScreen extends ConsumerStatefulWidget {
  const MyFeatureScreen({Key? key}) : super(key: key);
  
  @override
  ConsumerState<MyFeatureScreen> createState() => _MyFeatureScreenState();
}

class _MyFeatureScreenState extends ConsumerState<MyFeatureScreen> {
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: Text('Titre'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
      ),
      body: _isLoading
          ? const ShimmerLoader()
          : _buildContent(),
    );
  }
}
```

## Pattern Repository

```dart
class FriendRepository {
  final ApiService _api;
  FriendRepository(this._api);
  
  Future<List<FriendModel>> listFriends() async {
    final response = await _api.get(ApiEndpoints.friendsList);
    final data = response['data'] as List;
    return data.map((e) => FriendModel.fromJson(e)).toList();
  }
  
  Future<void> sendRequest(String friendId) async {
    await _api.post(ApiEndpoints.friendsSendRequest, body: {'friend_id': friendId});
  }
}
```

## Pattern Provider Riverpod

```dart
// Repository provider
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final api = ref.watch(apiServiceProvider);
  return FriendRepository(api);
});

// Data provider
final friendsProvider = FutureProvider<List<FriendModel>>((ref) {
  return ref.watch(friendRepositoryProvider).listFriends();
});

// Count provider (dérivé)
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final requests = await ref.watch(pendingRequestsProvider.future);
  return requests.length;
});
```

## Design System — Composants Obligatoires

### Utiliser TOUJOURS les composants néon :

```dart
// ✅ CORRECT
NeonButton(text: 'Jouer', onPressed: _start, variant: NeonButtonVariant.primary)
NeonCard(child: Row(...))
NeonInput(label: 'Montant', onChanged: _onChanged, glowOnFocus: true)

// ❌ INCORRECT
ElevatedButton(onPressed: _start, child: Text('Jouer'))
Card(child: Row(...))
TextField(decoration: InputDecoration(labelText: 'Montant'))
```

### Couleurs :

```dart
// ✅ CORRECT — Toujours depuis NeonColors
Text('Titre', style: TextStyle(color: NeonColors.primary))
Container(decoration: BoxDecoration(color: NeonColors.surface))

// ❌ INCORRECT — Jamais de couleurs hardcodées
Text('Titre', style: TextStyle(color: Color(0xFF2DD4BF)))
Container(color: Colors.blue)
```

## Navigation

```dart
// go_router pour navigation déclarative
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LobbyScreen()),
    GoRoute(path: '/game/:id', builder: (_, go) => GameScreen(gameId: go.pathParameters['id']!)),
  ],
);

// ❌ INCORRECT — Pas de Navigator.push direct
Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen()));
```

## WebSocket avec Fallback REST

```dart
Future<void> joinRoom(String roomId) async {
  if (wsService.isConnected) {
    wsService.joinRoom(roomId);
  } else {
    // Fallback REST
    final response = await _api.post('${ApiEndpoints.roomsJoin}/$roomId');
    _handleJoinResponse(response);
  }
}
```

## Formatage Jetons

```dart
import 'package:intl/intl.dart';

String formatTokens(int amount) {
  final formatted = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0)
      .format(amount)
      .trim();
  return '$formatted jetons';
}
// → "500 jetons" ou "1 000 jetons"
```

## Checklist Frontend

- [ ] Composants néon utilisés (NeonButton, NeonCard, etc.)
- [ ] Couleurs depuis NeonColors (pas de hardcodé)
- [ ] Responsive avec LayoutBuilder
- [ ] Loading states avec ShimmerLoader
- [ ] Erreurs gérées avec messages en français
- [ ] State management via Riverpod
- [ ] Navigation via GoRouter (context.go, jamais Navigator.push)
- [ ] Termes "jetons" utilisés (jamais "FCFA" dans l'UI)
