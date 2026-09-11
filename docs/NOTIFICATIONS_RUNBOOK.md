# WIWIGA — Runbook Notifications Multi-Canal

> Phase 0 : inbox in_app · Phase 1 : workers + adapters · Phase 2 : OTP live + FCM + rotation.
> Toute la configuration est centralisée en base (`notification_providers`,
> `notification_templates`, `notification_routing_rules`) et administrable depuis
> la section **NOTIFICATIONS** du menu admin : Vue d'ensemble (`/admin/notification-logs`),
> Canaux (`/admin/notification-providers`), Templates (`/admin/notification-templates`),
> Routage (`/admin/notification-routing`).
> L'ancien écran `/admin/notifications` (doublon) est **supprimé** : la route redirige
> vers la Vue d'ensemble, la cloche du header et son badge (`unread_total` des logs)
> pointent vers le hub. Les alertes système internes vivent dans
> `/admin/alertes` (OPÉRATIONS). Aucun secret en dur.

## 1. Activer un provider SMS

Principe : créer/activer le provider dans l'admin, renseigner sa `config`
via le bouton **Configurer** (formulaire guidé par schéma, secrets masqués —
vide = conserver), bouton **Tester** (envoi réel), puis surveiller les logs.

### 1.1 Orange SMS Cameroun (recommandé, délivrabilité directe)

1. Créer une application sur le portail développeur Orange, souscrire à l'API SMS Cameroun.
2. Faire pré-enregistrer le sender ID / l'adresse d'envoi (obligatoire, côté Orange).
3. Dans l'admin, activer le provider `orange_cm` et renseigner :
   `client_id`, `client_secret`, `sender_address` (`tel:+237...`), `sender_name`.
4. Tester vers un numéro Orange CM, vérifier le statut `sent` puis `delivered`
   (configurer le notify URL DLR côté Orange vers
   `https://<domaine>/api/webhooks/sms/orange_cm` si disponible).

### 1.2 Africa's Talking (agrégateur, KYC + sender ID via leur console)

1. Créer un compte, compléter le KYC Cameroun, enregistrer un sender ID.
2. Activer le provider `africas_talking` : `username`, `api_key`, `sender_id`.
3. Tester, vérifier les logs.

### 1.3 eSMS Africa / MTN CM (adapter HTTP générique)

Ces providers n'ont pas d'adapter dédié : utiliser `esms_africa` / `mtn_cm`
(adapter `http_sms`, 100 % piloté par la config — aucun endpoint deviné).
Renseigner depuis la console du fournisseur : `base_url` (URL exacte fournie
par le fournisseur), `to_field`, `body_field`, `sender_field`/`sender_id`,
`auth_header` (ex. `Bearer ...`) ou `auth_query_key`/`auth_query_value`,
`extra_fields`, `id_path` (chemin de l'ID dans la réponse, ex. `data/message_id`).
Configurer le webhook DLR du fournisseur vers `/api/webhooks/sms/esms_africa`.

### 1.4 Twilio (fallback global)

Renseigner `account_sid`, `auth_token`, `from`. Couverture CM correcte mais
coût 5 à 10× les routes locales — à réserver au failover (priorité élevée = 50).

### Règle de failover

Les providers actifs sont tentés par `priority` croissante. Premier succès
gagne ; erreurs `retryable` (timeout, 5xx, 429) → worker retry/backoff ;
`permanent` (400, numéro invalide) → `cancel`. Le 429 déclenche un snooze 120 s.

## 2. Activer l'email

- **SMTP** : `relay`, `port`, `username`, `password`, `from`, `tls`
  (`always` recommandé). Tester vers une adresse réelle.
- **SendGrid** : `api_key`, `from` (domaine authentifié côté SendGrid : SPF/DKIM).
- **SES** : `access_key`, `secret`, `region`, `from` (identité vérifiée, sortie
  du bac à sable SES requise en prod).

## 3. Activer le push (FCM v1)

### 3.1 Côté Firebase

1. Créer un projet Firebase, ajouter une application Android
   (package de `android/app/build.gradle`) et télécharger `google-services.json`
   dans `wiwiga_app/android/app/`.
2. (Optionnel iOS) Ajouter l'app iOS, intégrer `GoogleService-Info.plist`.
3. (Optionnel Web) La config Web est en place (`web/firebase-messaging-sw.js`
   + enregistrement dans `index.html`, clé VAPID via
   `flutter build web --dart-define=FCM_VAPID_KEY=...`). Renseigner les
   placeholders du SW avec la config de l'app Web Firebase.
   Build release vérifié OK (imports conditionnels + SW embarqué).
4. Créer un **compte de service** (IAM → Comptes de service → Clés → JSON).

### 3.2 Côté WIWIGA

1. Activer le provider `fcm_v1` : `project_id` + coller le JSON du compte de
   service dans `service_account_json` (chiffré au repos).
2. Lancer l'app Android : le token FCM s'enregistre seul après login
   (`POST /api/notifications/device-token`, visible en base `device_tokens`).
3. Tester avec `recipient` = token FCM. Token rejeté (`NotRegistered`) →
   invalidé automatiquement, l'utilisateur se ré-enregistre au prochain login.

## 4. OTP par SMS / email

`Auth.send_otp/2` et `send_otp_email/2` passent par
`ChannelDispatch.send_otp_sms/2` / `send_otp_email/2` :
providers actifs d'abord (synchrone, timeout 15 s), **repli legacy automatique**
(`SmsProvider`/log) si aucun provider actif ou échec total. Le code OTP reste
donc toujours délivrable et vérifiable, avec ou sans provider configuré.

## 5. Rotation de la clé de chiffrement

1. `openssl rand -base64 32` → nouvelle clé.
2. Mettre l'ancienne dans `NOTIFICATION_CONFIG_PREVIOUS_KEYS`, la nouvelle
   dans `NOTIFICATION_CONFIG_KEY`, redémarrer (zéro interruption : les
   anciennes enveloppes restent lisibles).
3. `mix notifications.reencrypt_providers` (re-chiffre avec la primaire).
4. Au cycle suivant, retirer l'ancienne clé des précédentes.

## 6. Exploitation

- **Inbox joueur** : `/notifications` (cloche à badge, temps réel WS, tap →
  écran concerné, suppression confirmée, pagination « Charger plus »),
  préférences `/notifications/preferences` (matrice catégorie × canal,
  sécurité verrouillée). Opt-in push expliqué au premier login (une fois).
  Réglages et profil redirigent vers les préférences serveur.
- **Dashboard admin** : section Notifications (envoyées/échouées/en attente/
  non lues + accès logs).
- **Broadcast** : écran Logs Notif → **Diffuser à tous** (lots async de 500,
  idempotent, `event_id` traçable dans les logs). Seul point d'entrée
  (l'ancien écran de diffusion est supprimé).
- **Providers** : pastilles de couverture (clés • secrets), **Configurer**,
  **Santé** (sans envoi : credentials/connectivité, badge persisté),
  **Tester** (envoi réel), suppression (logs conservés).
- **Templates** : un jeu par canal (`in_app`, `sms` court, `push` concis,
  `email` avec formule + désinscription promo). Rendu au moment de l'envoi
  (toujours la version active), repli in_app si canal manquant. Priorité
  (`urgent/high/normal/low`) et deep-link (`action`, allowlist côté app)
  hérités par chaque envoi. Éditeur : priorité, action, variables
  autorisées cliquables, aperçu live, segments SMS (coût).
  **Cloner v+1** (versionnage sans écraser), suppression (envois conservés).
  Locale : préférence utilisateur (`fr`/`en`), repli `fr`.
- **Emails** : layout HTML brandé mobile-first (table 600px, CSS inline,
  CTA, pré-header) + version texte ; sujets courts (marque en fin).
  Marketing : lien désinscription + headers one-click (exigence Gmail).
  Authentification SPF/DKIM/DMARC et flux séparé transactionnel/marketing
  à configurer côté DNS/fournisseur.
- **Broadcast** : bulk `insert_all` (2 requêtes/lot de 500), opt-out
  re-vérifiés, lots chaînés +15 s, file basse priorité (l'urgent passe
  devant), heures creuses marketing (22h–7h Douala), envoi planifié
  (`scheduled_at`), 429 honoré (Retry-After). Push des broadcasts via
  **topics FCM** (`all`, `promos` — 1 appel au lieu de N, repli per-token),
  abonnements syncés (register, opt-out marketing, logout).
- **Logs** : recherche titre/corps, **Détail** (timeline par canal),
  **Exporter CSV** (filtre courant, 5000 lignes ; web = téléchargement,
  mobile = dossier temporaire).
- **Routage** (`/admin/notification-routing`, API `/api/admin/notification-routing`) :
  par événement, canaux tentés (`in_app`, `push`, `sms`, `email`) + kill-switch
  `is_active: false` (coupe même l'inbox). Sans ligne : repli inbox.
  Badge « perso » = ligne DB existante.
- **Alertes internes** (`/admin/notifications`, ancien système `admin_notifications`) :
  alertes et annonces internes de l'équipe admin, compteur de la cloche du header.
  À ne pas confondre avec les logs d'envoi multi-canal (Vue d'ensemble).
- **Santé auto** : cron toutes les 6h (UTC) vérifiant les providers actifs
  supportés (badges à jour sans envoi). Bouton **Santé** pour un check
  immédiat.

- **Santé** : `/api/admin/notification-logs/stats` (`by_status`, `by_channel`,
  `unread_total`) + `/timeseries?days=14` (graphique envoyées/échouées) ;
  écran admin Logs Notif. Envois via cache ETS (5 min), jamais de requête
  par envoi sur le hot-path.
- **Télémétrie** : événements `[:wiwiga, :notifications, :dispatch|:delivery
  |:broadcast_batch]` (compteurs + statuts). À brancher sur Prometheus via
  TelemetryMetrics, ex. taux d'échec push/sms par provider et profondeur
  des files Oban (`oban_jobs` par queue/état).
- **Jobs bloqués** : `SELECT queue, state, count(*) FROM oban_jobs GROUP BY 1,2;`
- **DLQ** : deliveries `failed` + jobs `discarded` ; bouton **Rejouer** (nouvel
  `event_id`, opt-out respecté).
- **Alertes** : échec provider > 30 % ou DLQ qui grandit → vérifier crédits/
  quotas (`quota_monthly`, `rate_limit_per_min` par provider) puis basculer
  les priorités.
- **Coûts** : chaque SMS est facturé par le provider — garder le marketing en
  push/in_app par défaut, réserver le SMS au transactionnel/sécurité.
- **Caps** : quotas journaliers par utilisateur (`sms: 10, email: 20,
  push: 50`, `security` exemptée, in_app illimité), débit minute par provider
  (`rate_limit_per_min`). Config `config :game_hub, :notification_caps`.

## Répartition des responsabilités (source unique par sujet)

| Sujet | Source unique | Le reste est supprimé/ignoré |
|---|---|---|
| Canaux, secrets, priorités providers | `notification_providers` (NOTIFICATIONS → Canaux) | onglets `email`/`notification` settings + platform (supprimés ; clés `smtp_*`, `enable_*` non lues) |
| Routage événement → canaux | `notification_routing_rules` (NOTIFICATIONS → Routage) | rien en dur dans le code |
| Contenus, sujets, deep-links | `notification_templates` (NOTIFICATIONS → Templates) | — |
| Opt-in catégorie × canal | `notification_preferences` + écran joueur | `users.preferences.notifications_enabled` (bool global mort, ignoré) |
| Heures creuses perso | `users.preferences.quiet_hours` | — |
| Appareil (son, vibration, thème) | local Flutter + `users.preferences` | — |

## Matrice des événements (quoi → qui, best-effort, jamais bloquant)

Canaux par défaut modifiables dans `/admin/notification-routing`
(kill-switch par événement : désactivé = aucun envoi, même inbox).
Les appels internes peuvent surcharger `:channels` explicitement.

| Événement | Déclencheur | Destinataire | Clé / catégorie | Canaux défaut |
|---|---|---|---|---|
| Achat / gain / promo / cadeau reçu | `Tokens.*` | concerné (+ expéditeur débit) | `wallet_credit` / transactional | in_app, push |
| Cadeau envoyé | `Tokens.send_gift` | expéditeur | `wallet_debit` / transactional | in_app, push |
| Retrait Mobile Money | `Wallet.withdraw` | concerné | `cash_withdraw` / transactional | in_app, push |
| Demande d'ami | `Friends.send_friend_request` | destinataire | `friend_request` / social | in_app, push |
| Demande acceptée | `Friends.accept_friend_request` | demandeur | `friend_accepted` / social | in_app, push |
| Mot de passe modifié | `Auth.set_password` | concerné | `security_alert` / security | in_app, push |
| 2FA activée/désactivée | `TwoFactor.*` | concerné | `security_alert` / security | in_app, push |
| Nouvel appareil | login OTP/mot de passe | concerné | `security_alert` / security | in_app, push |
| Limites / exclusion / pause / levée | `ResponsibleGaming.*` | concerné | `security_alert` / security | in_app, push |
| Ban / unban | `Admin.Security.*` | concerné | `security_alert` / security | in_app, push |
| Succès débloqué | `AchievementManager` | concerné | `achievement_unlocked` / game | in_app, push |
| Résultat de match | `GameMatch` (victoire/défaite/nul) | joueurs | `match_result` / game | in_app, push |
| Annonce | admin broadcast | tous (lots) | `admin_broadcast` / transactional | in_app, push |
| Promo | admin broadcast | tous (lots) | `promo_broadcast` / marketing | in_app |

**Volontairement non notifiés** : mises (bruit, historique suffit),
rejets/blocages d'amis (anti-harcèlement), lobby/matchmaking éphémère
(WS temps réel suffit), transferts internes déjà couverts.
- **Consentement** : STOP SMS (mots FR+EN, mot entier) → suppression
  immédiate + marketing coupé sur les 3 canaux (OTP intact) ; START →
  réinscription. Bounces durs / plaintes SES (signature vérifiée) →
  suppression email. Webhooks : `/webhooks/sms/:provider/inbound`,
  `/webhooks/ses`. Configurer l'URL entrante côté provider SMS et le topic
  SNS côté SES. Le transactionnel n'est jamais supprimé.
- **Heures creuses** : globales marketing 22h–7h Douala (broadcast) +
  personnelles (`Notifications > Préférences > Heures creuses`, push/sms/
  email différés, inbox immédiate). Sécurité/transactionnel exemptés.
  Dépassement → canal ignoré (`rate_limited`) ou retry différé.
