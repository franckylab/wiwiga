# WIWIGA — Activation Push Firebase Cloud Messaging (FCM)

> Projet Firebase : **wiwiga** (`wiwiga-d9a7e`, n° `660834792043`).
> Backend Elixir (`fcm_v1`, FCM HTTP v1 + OAuth2 compte de service) +
> Frontend Flutter (Android/Web/iOS, `firebase_messaging`).
> État : backend **actif** (`fcm_v1`, santé `healthy`) ; app **prête** côté
> code (dégradation gracieuse tant que les derniers identifiants manquent).
> Valeurs par défaut = placeholders désactivés : l'inbox in_app + WebSocket
> prennent le relais tant que Firebase n'est pas renseigné.

## 1. Identifiants réels à fournir

| # | Valeur | Où l'obtenir | Utilisée par |
|---|--------|--------------|--------------|
| 1 | `project_id` (`wiwiga-d9a7e`) | Console Firebase → Paramètres projet | Champ admin `fcm_v1` → `project_id` |
| 2 | Compte de service JSON | IAM → Comptes de service → Clés → Créer (JSON) | Champ admin `fcm_v1` → `service_account_json` (chiffré, jamais côté app) |
| 3 | `google-services.json` | Paramètres projet → Applications Android → Télécharger | `wiwiga_app/android/app/google-services.json` |
| 4 | Config Web (`FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_SENDER_ID`, `FIREBASE_APP_ID`) | Paramètres projet → Applications Web | `tool/setup-fcm-web.sh` + `--dart-define` |
| 5 | `FCM_VAPID_KEY` | Cloud Messaging → Web Push certificates | Build web `--dart-define=FCM_VAPID_KEY=...` |
| 6 | `GoogleService-Info.plist` (optionnel iOS) | Paramètres projet → Applications iOS | `ios/Runner/GoogleService-Info.plist` |

Transmettre (1) et (2) suffit pour activer le push Android de bout en bout.
(4)+(5) ajoutent le push Web, (6) le push iOS.

## 2. Backend — activer le provider `fcm_v1` (admin uniquement)

> Règle d'architecture : les credentials providers se configurent
> EXCLUSIVEMENT via l'interface admin, jamais en variables
> d'environnement ni en seeds. Ils sont persistés en base
> (`notification_providers`, secrets chiffrés AES-256-GCM).

1. Ouvrir `/admin/notification-providers` (bouton **Installer les défauts**
   si la ligne `fcm_v1` est absente).
2. Ligne `Firebase Cloud Messaging` → **Configurer** : renseigner
   `project_id` (`wiwiga-d9a7e`) + coller le JSON du compte de service
   dans `service_account_json` (champ multiligne, masqué, vide = conserver).
   Le champ reste vide par sécurité, mais un aperçu confirme l'enregistrement
   (ex. `Configuré : firebase-adminsdk-...@wiwiga-d9a7e.iam.gserviceaccount.com (clé …xxxxxx)`).
3. **Enregistrer** → activer le toggle → **Santé** (sans envoi) :
   `healthy — Credentials FCM valides (envoi non testé)`.
4. **Tester** avec `recipient` = token FCM d'un appareil connecté
   (l'aide du champ l'indique). Avec un token invalide, le test répond
   `200` + statut `rejected`/`token_invalid` (connexion prouvée, seul le
   destinataire est en cause) ; un vrai problème provider répond `422`.

### Persistance (reboots, seeds initiaux)

La config vit en base (`notification_providers`, secret chiffré,
volume `postgres_data`) : elle survit aux redémarrages.
Les seeds initiaux (`priv/repo/seeds.exs`, étape 14) ne créent que le
scaffolding (lignes vides, providers désactivés) et ne touchent jamais
aux credentials existants.

Détails d'exploitation (failover, topics `all`/`promos`, quotas, files Oban,
rotation de clé) : voir `docs/NOTIFICATIONS_RUNBOOK.md`.

## 3. Frontend — Android

Package applicatif : `com.wiwiga.wiwiga` (à déclarer tel quel dans la
console Firebase lors de l'ajout de l'app Android).

```bash
cd wiwiga_app
# 1. Déposer le vrai fichier (jamais commité, voir .gitignore)
cp /chemin/google-services.json android/app/google-services.json
# 2. Activer le plugin Google Services (requis pour lire le json au build)
#    android/settings.gradle.kts → ajouter dans plugins {} :
#      id("com.google.gms.google-services") version "4.4.2" apply false
#    android/app/build.gradle.kts → ajouter dans plugins {} :
#      id("com.google.gms.google-services")
# 3. Dépendances déjà présentes (firebase_core, firebase_messaging,
#    flutter_local_notifications) puis build
flutter pub get
flutter build apk
```

> Desugaring JDK déjà activé dans `android/app/build.gradle.kts`
> (requis par `flutter_local_notifications`). APK debug vérifié OK.

Au premier login, le token FCM s'enregistre seul
(`POST /api/notifications/device-token`, table `device_tokens`).
Au logout, il est supprimé (`unregisterPushToken`).

## 4. Frontend — Web

```bash
cd wiwiga_app
# 1. Générer le service worker depuis l'environnement
FIREBASE_API_KEY=... FIREBASE_AUTH_DOMAIN=... FIREBASE_PROJECT_ID=... \
FIREBASE_SENDER_ID=... FIREBASE_APP_ID=... ./tool/setup-fcm-web.sh
# 2. Builder avec la clé VAPID (sinon getToken() retourne null → inbox en repli)
flutter build web \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FCM_VAPID_KEY=...
```

`lib/firebase_options.dart` lit ces `--dart-define` (placeholders
`WIWIGA_DEFAULT_*` par défaut → `isConfigured == false` → push désactivé,
silencieux). `PushNotificationService` utilise les options explicites si
configurées, sinon la config native, sinon se désactive sans jamais échouer.

## 5. Frontend — iOS (optionnel)

```bash
cd wiwiga_app
# Plateforme régénérée à l'étape Android, puis :
cp /chemin/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
# Xcode : activer Push Notifications + Background Modes (remote notifications).
flutter build ipa
```

## 6. Vérification de bout en bout

1. Admin → providers `fcm_v1` → **Santé** = `healthy`.
2. App Android : login → `device_tokens` contient le token
   (`platform = android`, `is_valid = true`).
3. Admin → providers `fcm_v1` → **Tester** avec `recipient` = token FCM →
   notification reçue (foreground = locale, background = système, tap → inbox).
4. Token rejeté (`NOT_REGISTERED`) → invalidé automatiquement en base,
   ré-enregistré au prochain login.
5. Broadcasts : topics `all`/`promos` (1 appel FCM au lieu de N, repli
   per-token) — voir runbook §6.

## 7. Dépannage

| Symptôme | Cause probable | Correctif |
|----------|----------------|-----------|
| `santé down : missing_credentials` | `project_id` ou JSON absent/invalide | Re-**Configurer** `fcm_v1` via l'admin (`client_email` + `private_key` requis) |
| `FCM : 403` au test | Compte de service sans rôle / mauvaise API | Activer FCM API, rôle `firebase.messaging.sender` |
| Token `null` sur web | `FCM_VAPID_KEY` manquant | Rebuilder avec `--dart-define=FCM_VAPID_KEY=...` |
| Pas de push web | SW non généré | Relancer `tool/setup-fcm-web.sh` avec les 5 vars |
| Build Android impossible | `android/` incomplet | `flutter create --platforms=android,ios .` (voir §3) |
| Push silencieux (aucune erreur) | Placeholders par défaut | Normal : inbox in_app en repli, renseigner §1 |

## 8. Sécurité

- Compte de service : côté backend uniquement, chiffré AES-256-GCM
  (`NOTIFICATION_CONFIG_KEY`, rotation en 4 étapes — voir runbook §5).
- `google-services.json` / `GoogleService-Info.plist` : jamais commités
  (`.gitignore`), clés API clientes publiques par design Firebase.
- Format API inchangé : `%{success, data, message}` ; validation backend
  obligatoire même si le frontend valide déjà.
