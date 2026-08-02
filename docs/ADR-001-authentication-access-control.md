# ADR-001: Système d'Authentification et Contrôle d'Accès

**Statut** : ACCEPTÉ — Décisions validées  
**Date** : 2026-08-01  
**Décideur** : Franck Arlos CHENDJOU  
**Contexte** : WIWIGA — Plateforme de jeux en ligne avec argent réel

---

## Contexte

WIWIGA est une application de jeux en ligne ciblant l'Afrique subsaharienne (Cameroun, +237). L'application utilise OTP SMS + JWT pour l'authentification, avec de l'argent réel (Mobile Money via Campay). 

Le système d'authentification actuel présente plusieurs lacunes :
1. L'authentification est forcée au démarrage (splash → auth si pas de user)
2. Tout le contenu est derrière l'authentification (y compris le catalogue de jeux)
3. L'écran d'auth n'a pas d'intégration API réelle (TODO)
4. Pas de refresh token rotation
5. Pas de persistance de session au redémarrage
6. Pas de notion de guest / browsing public
7. Pas de logout côté serveur
8. Pas de device binding

---

## Décisions

### D1 : Modèle d'accès — "Hybrid Shell" avec Guest Browsing

**Décision** : L'application utilise un modèle **Hybrid Shell** :
- Le splash screen vérifie la session et redirige vers `/home` (même en mode guest)
- Le shell à 5 onglets est toujours visible
- Les onglets "Accueil", "Jeux", "Classement" sont accessibles en mode guest (contenu public)
- Les onglets "Jetons" et "Amis" affichent un état "connectez-vous" avec CTA
- Les actions protégées (jouer, miser, déposer) déclenchent un **Auth Gate**

**Rationale** : Maximise l'engagement et la découverte du contenu avant l'inscription. Réduit la friction d'onboarding.

### D2 : Classification du contenu — Public vs Protégé

**Décision** : Le contenu est classifié comme suit :

**PUBLIC (sans auth)** :
- `GET /api/games` — Catalogue
- `GET /api/games/:id` — Détails (règles, config, mise min/max)
- `GET /api/games/:type/rules` — Règles du jeu
- `GET /api/games/:type/tips` — Astuces
- `GET /api/games/:type/leaderboard` — Classement global
- `GET /api/games/:type/activity` — Activité communauté
- `GET /api/tokens/promos` — Promotions
- `GET /api/config/features` — Config features (maintenance, etc.)
- `GET /api/health/*` — Health checks

**PROTÉGÉ (auth requise)** :
- `POST /api/games/:id/join` — Rejoindre une partie
- `GET /api/games/:id/state` — État partie en cours
- `GET /api/games/:type/stats` — Stats globales (peut devenir public)
- `GET /api/games/:type/my-stats` — Stats personnelles
- Toutes les routes wallet, tokens, rooms, friends, profile

**ADMIN (admin auth)** : inchangé

### D3 : Refresh Token Rotation

**Décision** : Implémenter le refresh token rotation avec :
- Access token : durée **30 minutes** (compromis gaming/sécurité)
- Refresh token : durée **30 jours**, usage unique (rotation)
- Stockage refresh token en table DB `refresh_tokens`
- Revocation via blacklist Redis + suppression DB
- Endpoint `POST /api/auth/logout` pour révocation explicite
- Endpoint `GET /api/auth/me` pour vérifier la session

**Rationale** : OWASP et Auth0 recommandent cette approche pour les applications financières. Le refresh token rotation prévient le replay attack. 30 min est un bon compromis pour le gaming (tours de jeu peuvent durer).

### D3b : Gestion de l'expiration en cours de partie

**Décision** : Double mécanisme :
1. **Silent refresh + retry** : L'interceptor Flutter tente le refresh automatiquement. Si échec, la requête est mise en queue et retry quand le réseau revient.
2. **Grace period (5 min)** : Pour les endpoints de jeu uniquement (`/games/:id/state`, actions de jeu), le token reste accepté jusqu'à 5 min après expiration. Après la grace period, si pas de refresh → perte de la partie.

### D3c : OTP Dev Mode avec Bypass

**Décision** : En mode dev/test, le code OTP `123456` est toujours accepté pour tout numéro. En production, SMS réel via provider (Campay/Twilio). Le mode bypass est contrôlé par `EnvConfig.dev?()`.

### D3d : Stats globales de jeu — Public

**Décision** : `GET /api/games/:type/stats` (total parties, joueurs actifs) est **PUBLIC**. Données agrégées, non personnelles. Alimente l'accueil et le catalogue.

### D4 : Persistance de Session

**Décision** :
1. Token JWT stocké dans `flutter_secure_storage` (Keychain/Keystore)
2. Refresh token stocké séparément dans `flutter_secure_storage`
3. Au démarrage : `AuthNotifier.restoreSession()` tente de :
   a. Lire le refresh token depuis secure storage
   b. Appeler `POST /api/auth/refresh` pour obtenir un nouvel access token
   c. Si succès → état `authenticated`
   d. Si échec → état `guest`
4. L'état `unknown` est utilisé uniquement pendant la restauration (splash)

### D5 : Auth Gate — In-Context + Redirection

**Décision** : Deux niveaux d'Auth Gate :
- **Soft Wall** (modal bottom sheet) : pour les actions de jeu (JOUER, miser, rejoindre). L'utilisateur reste dans le contexte. Après auth, reprend exactement là où il était.
- **Hard Wall** (redirection `/auth`) : pour les actions sensibles (dépôt, retrait, paramètres compte). Après auth, retourne à `/home`.

### D6 : Device Binding

**Décision** :
1. UUID unique généré au premier lancement, stocké en secure storage
2. Envoyé dans le header `X-Device-ID` avec chaque requête OTP
3. Rate limiting OTP : max 5 tentatives/heure/device (stocké Redis)
4. Le device ID est lié au compte utilisateur lors de l'inscription
5. Détection de comptes multiples par device (alerte admin)

### D7 : Modèle d'État AuthState

**Décision** : Enum `AuthStatus` avec 4 états :

```dart
enum AuthStatus { unknown, guest, authenticating, authenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final String? redirectTo; // Intent original après auth
}
```

---

## Conséquences

### Positives
- UX fluide : l'utilisateur découvre le contenu avant de s'inscrire
- Sécurité renforcée : refresh token rotation, device binding, rate limiting
- Architecture claire : séparation public/protégé/admin
- Session persistante : pas de déconnexion au redémarrage
- Conforme aux standards OWASP pour les applications financières

### Négatives / Risques
- Complexité accrue : refresh token rotation nécessite une table DB et de la logique supplémentaire
- Device binding : peut bloquer les utilisateurs qui changent d'appareil (prévoir un mécanisme de reset)
- Secure storage : dépendance supplémentaire (`flutter_secure_storage`)
- Routes publiques : exposition accrue de l'API (nécessite un rate limiting global)

### Mitigations
- Device binding : prévoir un endpoint `POST /api/auth/reset-device` après vérification OTP
- Rate limiting : implémenter un rate limiter global (Plug Phoenix) en plus du rate limiting OTP
- Fallback : si secure storage indisponible, fallback sur SharedPreferences (moins sécurisé mais fonctionnel)

---

## Alternatives Rejetées

### A1 : Session-based auth (cookies)
Rejeté car : Flutter mobile ne gère pas nativement les cookies comme un navigateur. JWT est plus adapté aux APIs REST mobile.

### A2 : Firebase Authentication
Rejeté car : WIWIGA utilise OTP SMS custom (Campay) ciblant le Cameroun. Firebase Auth ne supporte pas nativement Campay. L'architecture OTP existante est conservée.

### A3 : JWT simple sans refresh (statu quo amélioré)
Rejeté car : insuffisant pour une application financière. OWASP recommande le refresh token rotation.

### A4 : Authentification forcée au démarrage
Rejeté car : contraire aux exigences produit. Réduit l'onboarding et la découverte du contenu.

---

## Plan d'Implémentation

### Phase 1 : Backend — Routes publiques + Refresh tokens
1. Déplacer les routes publiques hors du scope `:api_auth`
2. Créer la migration `refresh_tokens`
3. Modifier `Guardian` pour supporter access/refresh tokens
4. Ajouter `POST /api/auth/logout` et `GET /api/auth/me`
5. Ajouter le rate limiting OTP par device

### Phase 2 : Frontend — Guest browsing + Auth Gate
1. Modifier `AuthState` avec `AuthStatus` enum
2. Implémenter `restoreSession()` dans `AuthNotifier`
3. Modifier le splash screen pour le flux guest
4. Créer le widget `AuthGate` (soft wall + hard wall)
5. Adapter les écrans pour le mode guest

### Phase 3 : Frontend — Auth integration réelle
1. Connecter `AuthScreenNeon` à l'API réelle
2. Implémenter le secure storage pour les tokens
3. Ajouter l'interceptor de refresh token
4. Implémenter le device ID

### Phase 4 : Sécurité avancée
1. Device binding dans les requêtes OTP
2. Détection comptes multiples
3. Token blacklist Redis pour logout
4. Audit logging des événements auth
