# Correction de l'erreur GoException: no routes for location: /

## Problème identifié

Lorsqu'un utilisateur se déconnecte, n'est pas connecté, ou que son token est expiré, l'erreur `GoException: no routes for location: /` s'affichait lors du rechargement des pages.

### Causes racines

1. **Route racine `/` non définie** : Le routeur n'avait pas de route pour `/`, ce qui causait une erreur quand l'application essayait d'y naviguer.

2. **Déconnexion admin incorrecte** : Dans `admin_shell_screen.dart`, après la déconnexion, le code utilisait `context.go('/')` au lieu de `context.go('/auth')`.

3. **Session expirée non gérée** : Quand les tokens étaient effacés par `ApiService` (après échec du refresh token), l'état d'authentification dans `authProvider` n'était pas mis à jour, laissant l'application dans un état incohérent.

4. **Redirections insuffisantes** : Le redirect guard du routeur ne gérait pas tous les cas de figure (utilisateur authentifié sur `/splash`, guest sur les routes admin, etc.).

## Corrections apportées

### 1. Configuration du routeur (`app_router.dart`)

**Améliorations du redirect guard :**

```dart
redirect: (context, state) {
  final authState = ref.read(authProvider);
  final path = state.uri.path;
  
  // ✅ Route racine : rediriger vers splash ou auth selon l'état
  if (path == '/') {
    if (authState.isUnknown) return '/splash';
    if (authState.isAuthenticated) return '/home';
    return '/auth';
  }
  
  // ✅ Protection pendant l'initialisation
  if (authState.isUnknown) {
    if (path != '/splash') return '/splash';
    return null;
  }
  
  // ✅ Guest sur routes protégées → /auth
  if (authState.isGuest && _protectedRoutes.contains(path)) {
    ref.read(authProvider.notifier).setRedirectTo(path);
    return '/auth';
  }
  
  // ✅ Guest sur routes admin → /auth
  if (authState.isGuest && _adminRoutes.contains(path)) {
    return '/auth';
  }
  
  // ✅ Authentifié sur /auth → /home
  if (authState.isAuthenticated && path == '/auth') {
    return '/home';
  }
  
  // ✅ Authentifié sur /splash → /home
  if (authState.isAuthenticated && path == '/splash') {
    return '/home';
  }
  
  // ✅ Non-admin sur routes admin → /home
  if (_adminRoutes.contains(path) && !authState.isAdmin) {
    return '/home';
  }
  
  return null;
}
```

### 2. Déconnexion admin (`admin_shell_screen.dart`)

**Correction de la navigation après logout :**

```dart
TextButton(
  onPressed: () async {
    Navigator.pop(ctx);
    // ✅ Appeler logout puis rediriger vers /auth
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      context.go('/auth');
    }
  },
  child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
)
```

**Import ajouté :**
```dart
import '../../../data/providers/app_providers.dart';
```

### 3. Gestion de l'expiration de session (`api_service.dart`)

**Ajout d'un stream pour notifier les listeners :**

```dart
class ApiService {
  // Stream pour notifier quand les tokens sont effacés (session expirée)
  final _sessionExpiredController = StreamController<bool>.broadcast();
  
  /// Stream qui émet `true` quand les tokens sont effacés (session expirée)
  /// Les listeners peuvent utiliser cela pour rediriger vers /auth
  Stream<bool> get onSessionExpired => _sessionExpiredController.stream;
  
  /// Supprime tous les tokens (logout)
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyLegacyToken),
    ]);
    // ✅ Notifier les listeners que la session est expirée
    _sessionExpiredController.add(true);
  }
  
  void dispose() {
    _sessionExpiredController.close();
    _client.close();
  }
}
```

### 4. Mise à jour automatique de l'état d'authentification (`app_providers.dart`)

**Écoute du stream d'expiration de session :**

```dart
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();
  
  // ✅ Écouter les expiration de session et mettre à jour l'état auth
  ref.onDispose(() => apiService.dispose());
  apiService.onSessionExpired.listen((_) {
    final authNotifier = ref.read(authProvider.notifier);
    // Si la session expire, mettre l'état à guest
    authNotifier.handleSessionExpired();
  });
  
  return apiService;
});
```

**Nouvelle méthode dans `AuthNotifier` :**

```dart
/// Gère l'expiration de la session (tokens effacés)
/// Appelé quand ApiService détecte une session expirée
void handleSessionExpired() {
  state = const AuthState(status: AuthStatus.guest);
}
```

## Flux de fonctionnement

### Scénario 1 : Déconnexion manuelle

1. L'utilisateur clique sur "Déconnexion"
2. `logout()` est appelé dans le `AuthNotifier`
3. Les tokens sont effacés via `AuthRepository.logout()`
4. `ApiService.clearTokens()` notifie le stream `onSessionExpired`
5. Le `authProvider` écoute et met l'état à `guest`
6. Le router (via `refreshListenable`) détecte le changement d'état
7. Le redirect guard redirige vers `/auth`

### Scénario 2 : Token expiré

1. L'utilisateur fait une requête avec un token expiré
2. L'API retourne 401
3. `ApiService` tente de refresh le token
4. Si le refresh échoue, `clearTokens()` est appelé
5. Le stream `onSessionExpired` est notifié
6. Le `authProvider` met l'état à `guest`
7. Le router redirige automatiquement vers `/auth`

### Scénario 3 : Rechargement de page sans session

1. L'utilisateur recharge la page (F5 ou hot reload)
2. L'application démarre sur `/splash`
3. Le splash screen appelle `restoreSession()`
4. Si pas de tokens valides, l'état passe à `guest`
5. Le splash screen redirige vers `/auth`
6. Si l'utilisateur essaie d'aller sur `/`, le redirect guard le redirige vers `/auth`

## Bénéfices

✅ **Plus d'erreur `GoException: no routes for location: /`** : La route `/` est maintenant gérée et redirige correctement.

✅ **Déconnexion propre** : L'utilisateur est toujours redirigé vers `/auth` après déconnexion.

✅ **Session expirée gérée automatiquement** : Quand les tokens sont effacés, l'état est mis à jour et l'utilisateur est redirigé.

✅ **Protection renforcée** : Le redirect guard gère tous les cas de figure (guest sur routes protégées, authentifié sur splash, etc.).

✅ **Expérience utilisateur améliorée** : Transitions fluides et prévisibles, pas d'état incohérent.

## Fichiers modifiés

1. `/wiwiga_app/lib/core/router/app_router.dart` - Redirect guard amélioré
2. `/wiwiga_app/lib/presentation/screens/admin/admin_shell_screen.dart` - Déconnexion corrigée
3. `/wiwiga_app/lib/data/services/api_service.dart` - Stream d'expiration de session
4. `/wiwiga_app/lib/data/providers/app_providers.dart` - Écoute du stream et mise à jour de l'état

## Tests recommandés

- [ ] Se déconnecter depuis l'écran admin → doit rediriger vers `/auth`
- [ ] Se déconnecter depuis l'écran settings → doit rediriger vers `/auth`
- [ ] Attendre l'expiration du token → doit rediriger automatiquement vers `/auth`
- [ ] Recharger la page sans session → doit aller vers `/auth`
- [ ] Essayer d'accéder à `/` directement → doit rediriger vers `/auth` ou `/home` selon l'état
- [ ] Essayer d'accéder à une route protégée sans être connecté → doit rediriger vers `/auth`
- [ ] Essayer d'accéder à `/admin` sans être admin → doit rediriger vers `/home`
