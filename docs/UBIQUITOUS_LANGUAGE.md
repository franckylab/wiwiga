# Ubiquitous Language — WIWIGA Auth & Access Control

_Dernière mise à jour : 2026-08-01_

## Termes du Domaine

### Identité & Authentification

| Terme | Définition | Contexte d'usage |
|---|---|---|
| **OTP** (One-Time Password) | Code à 6 chiffres, valide 5 minutes, envoyé par SMS au numéro +237. Stocké dans Redis avec expiration TTL. | `POST /api/auth/send-otp`, `POST /api/auth/verify-otp` |
| **JWT** (JSON Web Token) | Token d'authentification signé par Guardian (HS256). Contient le `sub` (user_id). Utilisé comme Bearer token. | Header `Authorization: Bearer <jwt>` |
| **Access Token** | JWT de courte durée (à définir : 15-30 min). Utilisé pour chaque requête API authentifiée. | Toutes les routes `:api_auth` |
| **Refresh Token** | Token de longue durée (à définir : 7-30 jours). Usage unique avec rotation. Stocké en DB. Permet d'obtenir un nouvel access token. | `POST /api/auth/refresh` |
| **Session** | Période entre la vérification OTP réussie et la déconnexion (ou expiration). Liée à un device optionnel. | Gérée côté client via secure storage |
| **Device ID** | UUID unique généré au premier lancement de l'app. Permet la liaison appareil et le rate limiting. | Stocké en `flutter_secure_storage` |
| **Guest** | Utilisateur non authentifié qui navigue le contenu public sans compte. N'a pas de token JWT. | Accès au catalogue, leaderboard, règles |
| **Authenticated User** | Utilisateur ayant vérifié son numéro via OTP et possédant un JWT valide. Accès complet aux fonctionnalités. | Peut jouer, déposer, retirer |

### Contrôle d'Accès

| Terme | Définition | Contexte d'usage |
|---|---|---|
| **Contenu Public** | Ressources accessibles sans authentification : catalogue, détails jeux, règles, astuces, promotions, leaderboard global, activité communauté. | Routes `:api` (sans `:api_auth`) |
| **Contenu Protégé** | Ressources nécessitant un JWT valide : jouer, wallet, amis, profil, rooms, stats personnelles. | Routes `:api_auth` |
| **Auth Gate** | Point de contrôle qui intercepte une action protégée et déclenche le flux d'authentification. Peut être un modal ou une redirection. | Widget `AuthGate` en Flutter |
| **Soft Wall** | Modal/bottom-sheet d'authentification in-context, sans perdre la page courante. | Utilisé pour "JOUER", "Miser" |
| **Hard Wall** | Redirection complète vers l'écran `/auth`. Utilisé pour les actions sensibles. | Utilisé pour deposit, withdraw |
| **Auth Redirect** | Mécanisme qui renvoie l'utilisateur vers `/auth` après avoir mémorisé l'intent original (deep link de retour). | `GoRouter.redirect` |

### Sécurité

| Terme | Définition | Contexte d'usage |
|---|---|---|
| **Token Rotation** | Mécanisme où chaque utilisation d'un refresh token génère un nouveau refresh token et invalide l'ancien. | Prévention du token replay |
| **Token Revocation** | Invalidation d'un token avant son expiration naturelle. Via blacklist Redis ou suppression DB. | `POST /api/auth/logout` |
| **Rate Limiting OTP** | Limite d'envoi OTP par numéro et par device (ex: 5/heure). Stocké dans Redis. | `Auth.send_otp/1` |
| **HMAC Signature** | Vérification des webhooks Campay via signature HMAC-SHA256. | `PaymentWebhookController` |
| **Secure Storage** | Stockage chiffré natif (Keychain iOS / Keystore Android) via `flutter_secure_storage`. | Token JWT, Device ID |

### États Utilisateur

| État | Description | Accès |
|---|---|---|
| **unknown** | App vient de démarrer, vérification de session en cours | Splash screen |
| **guest** | Pas de token, pas de session active | Contenu public uniquement |
| **authenticating** | OTP envoyé ou en cours de vérification | En attente |
| **authenticated** | JWT valide, session active | Contenu public + protégé |

## Relations entre Termes

```
Guest ──[Auth Gate]──> Authenticating ──[OTP valid]──> Authenticated
  │                                                         │
  │                                                         ├──[Token expiré]──> Authenticating (refresh)
  │                                                         │
  │                                                         └──[Logout]──> Guest
  │
  └──[Browsing public content]
```

## Conventions de Nommage

- **Backend (Elixir)** : `AuthPlug`, `AuthController`, `Auth`, `Guardian`
- **Frontend (Flutter)** : `AuthState`, `AuthNotifier`, `authProvider`, `AuthGate`
- **Routes** : `/api/auth/*` (public), `/api/*` (protégé via `:api_auth`)
- **États** : `unknown | guest | authenticating | authenticated`
