Application: WIWIGA
Auteur: Franck Arlos CHENDJOU
# Plateforme Game Hub - Prompt de Développement Expert

## Contexte
Construire une plateforme de hub de jeux multi-jeux prête pour la production (web + Android) avec multijoueur en temps réel, système de paris et gestion de portefeuille. Marché cible : Cameroun (devise XAF, paiements Mobile Money). La plateforme doit supporter l'ajout futur de jeux via une architecture plugin.

---

## Stack Technique

### Backend
- **Framework** : Elixir/Phoenix avec architecture OTP
- **Base de données** : PostgreSQL (transactions ACID pour les opérations financières)
- **Cache/Temps réel** : Redis (état de jeu, matchmaking, sessions)
- **WebSocket** : Canaux Phoenix (temps réel natif)

### Frontend
- **Framework** : Flutter (code unique : web + Android)
- **Gestion d'état** : Riverpod ou Bloc
- **Temps réel** : `web_socket_channel` pour les canaux Phoenix
- **UI** : Material 3, theming personnalisé, design responsive

### Paiements
- **Principal** : API Campay (MTN MoMo + Orange Money Cameroun)
- **Architecture** : Multi-fournisseur avec fallback configurable en base
- **Pattern** : Système de portefeuille interne (dépôt → jouer → retrait)
- **Devise** : Support multi-devises (XAF par défaut, extensible à USD/EUR)
- **Notifications** : Firebase Cloud Messaging (Android) + Web Push API

### Infrastructure
- **Hébergement** : Fly.io (cluster Phoenix, auto-scaling, multi-région)
- **Base de données** : PostgreSQL managé (Supabase ou Aiven)
- **Redis** : Managé (Upstash ou Aiven)
- **CDN** : CloudFlare (assets statiques, protection DDoS)

---

## Architecture Centrale

```
Hub Central (Application Phoenix)
├── Module Auth (connexion OTP + 2FA configurable pour opérations sensibles)
├── Système Portefeuille (dépôts/retraits via Mobile Money)
├── Passerelle de Paiement (multi-fournisseur avec config en base)
├── Moteur de Matchmaking (file d'attente + créer/rejoindre salles + tournois)
├── Moteur de Commission (4 modes configurables par jeu en base)
├── Registre de Plugins de Jeu (isolation applications OTP)
├── Module Conformité (KYC, AML, vérification âge, RGPD)
├── Module Jeu Responsable (limites, auto-exclusion, rappels réalité)
├── Système de Notation & Réputation (ELO, classements, suivi comportement)
├── Fonctionnalités Sociales (chat, amis, invitations, statut en ligne)
├── Système de Notification (push, in-app, email, SMS)
├── Gestion de Contenu (pages légales, FAQ, annonces)
├── Système de Parrainage & Affiliation
├── Tableau de Bord Admin (Phoenix LiveView)
├── Système Support & Résolution de Litiges
├── Détection de Fraude & Anti-Triche
├── Gestion de Versions & Feature Flags
└── Stack d'Observabilité (télémesure, métriques, alertes)

Plugins de Jeu (applications OTP isolées)
├── Jeu A
├── Jeu B
└── ... (extensible via interface de comportement)
```

---

## Spécifications des Modules

### 1. Authentification & Sécurité

**Mécanisme** (configurable via base de données) :
- Principal : Numéro de téléphone + vérification OTP
- Secondaire : 2FA (TOTP) pour opérations sensibles (retraits >5000 XAF, modifications compte)
- Optionnel : Authentification biométrique (mobile)
- Session : JWT avec refresh token, stockage sécurisé (FlutterSecureStorage)

**Requis de Sécurité** :
- Double vérification de permission (UX frontend + enforcement backend)
- Limitation de débit sur endpoints auth (5 tentatives/15min)
- Empreinte digitale du device pour protection contre hijacking de session
- CORS whitelist stricte
- Assainissement des inputs sur toutes les actions de jeu (prévenir injection)
- Logs d'audit pour tous les événements d'authentification

### 2. Système Portefeuille & Paiement

**Pattern Portefeuille Interne** :
```
L'utilisateur dépose via Mobile Money → Solde portefeuille → Jouer aux jeux → Retirer gains
```

**Config Fournisseur de Paiement** (table DB `payment_providers`) :
```elixir
id, name (Campay/MTN/Orange), active (bool), api_key, api_secret,
configuration (JSON), priority (int), created_at, updated_at
```

**Types de Transactions** :
- Dépôt, Retrait, Pari (mise), Gain (paiement), Commission, Remboursement, Ajustement (admin)

**Requis Financiers** :
- Transactions ACID pour TOUTES les opérations de portefeuille
- Job de réconciliation de portefeuille (horaire) : vérifier balance = sum(transactions)
- Webhooks de paiement idempotents (prévenir double facturation)
- Limites de transaction (configurables par tier utilisateur)
- Auto-remboursement en cas de crash de jeu détecté

### 3. Moteur de Commission

**Système multi-mode** (configurable par jeu en base table `game_commissions`) :

| Mode | Calcul | Exemple (mise 1000 XAF) |
|------|--------|-------------------------|
| A - % sur mise | Commission prélevée avant le jeu | 5% = 50 XAF, pot = 950 XAF |
| B - % sur gains | Commission sur paiement gagnant | Gagnant reçoit 9500 sur pot 10000 (5%) |
| C - Fixe | Montant fixe par jeu | 100 XAF forfaitaire |
| D - Progressif | % échelonné selon montant mise | 5% si <5000, 3% si >5000 |

```elixir
Table: game_commissions
├── game_id, commission_type (A/B/C/D), commission_value (decimal),
├── active (bool), effective_from (date), created_at
```

### 4. Système de Matchmaking

**Approche hybride** (3 modes disponibles simultanément) :

**A. File d'Attente Rapide** :
- Le joueur entre dans la file → le système match par montant de mise + niveau de compétence
- Timeout : 2min → suggérer alternatives

**B. Créer/Rejoindre Salle** :
```
Le créateur définit :
├── Type de jeu
├── Montant de mise (XAF)
├── Max joueurs (2-8)
├── Mode : public (visible dans lobby) ou privé (code d'invitation)
└── Timeout : temps d'attente max (configurable, défaut 5min)
```

**C. Système de Tournoi** :
```elixir
Table: tournament_types
├── type (direct_elimination, round_robin, swiss, battle_royale)
├── rules (JSON: structure, points, qualifications)
├── free_entry (bool), default_stake (nullable)
└── active (bool)

Table: tournament_config
├── type_id, schedule (expr cron), duration_minutes
├── min_players, max_players, stake_override (nullable)
└── auto_create (bool), prize_distribution (JSON: 1er=60%, 2ème=25%, 3ème=15%)
```

**Types de Tournoi** :
- **Élimination Directe** : Perdant éliminé, système de bracket (1v1 ou équipes)
- **Round Robin** : Tous jouent contre tous, classement par points (4-8 joueurs)
- **Suisse** : Match par niveau similaire, pas d'élimination (tournois longs)
- **Battle Royale** : Élimination progressive, dernier debout gagne (4+ joueurs)

### 5. Premier Jeu : Jeu de Dés (Dice Game)

**Description** : Jeu de lancé de dés où le joueur avec le plus grand total gagne.

**Règles du Jeu** :
- Chaque joueur lance un ou plusieurs dés par tour
- Le joueur avec le total le plus élevé gagne la mise
- En cas d'égalité : match nul (mises restituées) ou relance (configurable)

**Configuration du Jeu** (paramétrable en base de données) :
```elixir
Table: dice_game_config
├── game_id (référence vers games)
├── number_of_dice (1 à 3 dés par joueur)
├── number_of_rolls (1 à N lancés par partie)
├── dice_type (d6 standard, ou autre type si extension future)
├── tie_handling (refund/reroll/shared_pot)
│   - refund : égalité = mises restituées
│   - reroll : égalité = relance automatique
│   - shared_pot : égalité = pot divisé équitablement
├── scoring_method (single_roll/sum_of_rolls/best_of_rolls)
│   - single_roll : un seul lancé, le plus haut gagne
│   - sum_of_rolls : somme de tous les lancés, le plus haut gagne
│   - best_of_rolls : meilleur lancé individuel parmi tous les lancés
├── active (bool)
├── created_at, updated_at
```

**Modes de Jeu Supportés** :
- **1v1 Classique** : 2 joueurs, chacun lance ses dés, le plus haut gagne
- **Multi-joueurs** : 2-8 joueurs dans une salle, tous lancent, le meilleur score gagne
- **Tournoi de Dés** : Élimination directe ou round robin avec ce jeu

**Exemple de Configuration** :
```elixir
# Configuration 1 : Simple et rapide
number_of_dice: 1
number_of_rolls: 1
scoring_method: single_roll
tie_handling: reroll
# → Chaque joueur lance 1 dé une fois, le plus haut gagne, égalité = relance

# Configuration 2 : Plus stratégique
number_of_dice: 3
number_of_rolls: 2
scoring_method: sum_of_rolls
tie_handling: shared_pot
# → Chaque joueur lance 3 dés, 2 fois, on additionne tout, le plus haut gagne, égalité = partage

# Configuration 3 : Best of
number_of_dice: 2
number_of_rolls: 5
scoring_method: best_of_rolls
tie_handling: refund
# → Chaque joueur lance 2 dés, 5 fois, on garde le meilleur score, égalité = remboursement
```

**Interface de Jeu (Flutter)** :
- Animation 3D du lancer de dés (physique réaliste)
- Affichage clair des résultats de chaque joueur
- Historique des lancés visibles pendant la partie
- Son de lancer de dés personnalisable (on/off)
- Effet visuel de célébration pour le gagnant

**Logique Backend (Elixir)** :
```elixir
defmodule GameHub.Games.DiceGame do
  @behaviour GameHub.GamePlugin
  
  # Générer un lancé de dés aléatoire (côté serveur uniquement)
  def roll_dice(number_of_dice, dice_type \\ 6) do
    Enum.map(1..number_of_dice, fn _ -> :rand.uniform(dice_type) end)
  end
  
  # Calculer le score selon la méthode configurée
  def calculate_score(rolls, config) do
    case config.scoring_method do
      :single_roll -> hd(rolls) |> Enum.sum()
      :sum_of_rolls -> rolls |> List.flatten() |> Enum.sum()
      :best_of_rolls -> rolls |> Enum.map(&Enum.sum/1) |> Enum.max()
    end
  end
  
  # Déterminer le gagnant
  def determine_winner(player_scores, config) do
    max_score = player_scores |> Enum.map(& &1.score) |> Enum.max()
    winners = Enum.filter(player_scores, & &1.score == max_score)
    
    case length(winners) do
      1 -> {:winner, hd(winners)}
      _ -> handle_tie(winners, config)
    end
  end
  
  defp handle_tie(winners, %{tie_handling: :refund}), do: {:tie, :refund}
  defp handle_tie(winners, %{tie_handling: :shared_pot}), do: {:tie, :share_pot}
  defp handle_tie(_winners, %{tie_handling: :reroll}), do: {:tie, :reroll}
end
```

**Sécurité & Anti-Triche** :
- **Génération aléatoire côté serveur** : JAMAIS côté client
- **Seed cryptographiquement sûr** : `:crypto.strong_rand_bytes/1`
- **Horodatage des lancés** : Traçabilité complète pour investigation
- **Détection de patterns** : Alerte si un joueur gagne >90% des parties
- **Auditabilité** : Tous les résultats stockés pour vérification

**Base de Données** :
```elixir
Table: dice_game_results
├── id, game_id, room_id, tournament_id (nullable)
├── player_id, roll_number (1 à N)
├── dice_results (array JSON: [3, 5, 2])
├── roll_score (total du lancé)
├── timestamp
└── is_final (bool, true si dernier lancé)
```

**Intégration au Matchmaking** :
- Le créateur de salle choisit la config de dés avant de créer
- Les configs populaires sont sauvegardées comme presets
- Support des configs personnalisées (nombre de dés + lancés)
- Affichage clair de la config dans la lobby avant de rejoindre

**Exemple de Flux de Jeu** :
```
1. Joueur A crée une salle :
   - Jeu : Dés
   - Config : 2 dés, 3 lancés, somme totale
   - Mise : 1000 XAF
   - Mode : Public

2. Joueur B rejoint la salle

3. La partie commence :
   - Tour 1 : A lance [4, 6] = 10, B lance [3, 5] = 8
   - Tour 2 : A lance [2, 2] = 4 (total: 14), B lance [6, 6] = 12 (total: 20)
   - Tour 3 : A lance [5, 5] = 10 (total: 24), B lance [4, 3] = 7 (total: 27)

4. Résultat final :
   - A : 24 points
   - B : 27 points → GAGNANT !
   - Commission : 5% = 50 XAF
   - B reçoit : 1950 XAF (2000 - 50)
```

### 6. Politique de Déconnexion

**Période de grâce** (configurable par jeu/mode en base) :
```elixir
Table: game_timeout_config
├── game_id, game_mode, grace_period_seconds (défaut 120)
├── action_on_timeout (forfait/refund/pause)
└── forfeit_stake_distribution (vers_gagnant/divisé/pool)
```

**Politique** : Joueur déconnecté → compte à rebourd période de grâce → forfait si pas de reconnexion → mise redistribuée selon config

### 6. Système de Plugin de Jeu

**Interface** (comportement Elixir) :
```elixir
defmodule GameHub.GamePlugin do
  @callback start_game(players :: list(), settings :: map()) :: {:ok, game_state} | {:error, reason}
  @callback handle_move(game_state :: map(), move :: map(), player_id :: String.t()) :: {:ok, new_state} | {:error, reason}
  @callback check_winner(game_state :: map()) :: {:ok, winner :: String.t() | :draw | :ongoing}
  @callback get_game_state(game_id :: String.t()) :: {:ok, public_state :: map()}
  @callback validate_move(game_state :: map(), move :: map()) :: :ok | {:error, reason}
end
```

**Enregistrement de Plugin** :
```elixir
# Dans config hub
config :game_hub, :games, [
  GameHub.Games.DiceGame,  # Premier jeu implémenté (Phase 2)
  # GameHub.Games.Morabaraba,  # Futur jeu
  # GameHub.Games.Checkers,    # Futur jeu
]
```

**Avantages** :
- Isolation : Le crash d'un jeu n'affecte pas le hub ni les autres jeux
- Hot reload : Ajouter/supprimer des jeux sans redémarrage
- Scaling indépendant : Les jeux populaires peuvent tourner sur des nœuds dédiés

### 7. Module de Conformité

**KYC (Know Your Customer)** :
```elixir
Table: user_kyc
├── user_id, status (pending/verified/rejected)
├── id_document_url, selfie_url
├── verified_by (admin_id), verified_at
└── rejection_reason (nullable)
```

**Requis** :
- Vérification d'âge : >= 18 ans obligatoire à l'inscription (date naissance + document d'identité)
- KYC obligatoire pour retraits > seuil (configurable, défaut 100 000 XAF)
- Limites de transaction par tier (non vérifié/vérifié/VIP)
- AML (Anti-Blanchiment) : signaler patterns suspects (dépôt/retrait rapide, montants inhabituels)
- Conformité RGPD : export de données, suppression de compte, gestion du consentement

**Config de Limites** (table DB `user_tier_limits`) :
```elixir
tier (unverified/verified/vip), daily_deposit_limit, monthly_deposit_limit,
daily_withdrawal_limit, single_transaction_limit, kyc_required (bool)
```

### 8. Module Jeu Responsable (LÉGALEMENT OBLIGATOIRE)

**Fonctionnalités Obligatoires** (requises pour licence de jeu MINFI) :

**Limites Contrôlées par l'Utilisateur** :
```elixir
Table: responsible_gaming_limits
├── user_id, daily_deposit_limit, weekly_deposit_limit
├── monthly_deposit_limit, daily_loss_limit
├── session_time_limit_minutes
├── self_exclusion_until (nullable)
├── reality_check_interval_minutes (défaut 30)
└── updated_at
```

**Fonctionnalités** :
- **Limites de Dépôt** : L'utilisateur définit les dépôts max quotidiens/hebdomadaires/mensuels
- **Limites de Perte** : Auto-stop des paris après avoir perdu X montant en un jour
- **Limites de Temps de Session** : Auto-déconnexion après X heures de jeu continu
- **Auto-Exclusion** : Temporaire (24h, 7 jours, 30 jours) ou permanente
- **Rappel de Réalité** : Popup toutes les 30min montrant durée de session & montant dépensé
- **Période de Réflexion** : Pause obligatoire de 24h après avoir perdu >50% de la limite hebdomadaire
- **Affichage de Ressources** : Liens vers aide addiction au jeu (toujours visible dans profil)

**Suivi d'Auto-Exclusion** :
```elixir
Table: self_exclusions
├── user_id, type (temporary/permanent)
├── start_date, end_date (nullable pour permanent)
├── reason, initiated_by (user/admin)
└── support_resources_shown (bool)
```

**Contrôles Admin** :
- Remplacer les limites utilisateur (avec log d'audit)
- Forcer auto-exclusion pour joueurs problématiques
- Voir dashboard jeu responsable (utilisateurs approchant les limites)

### 9. Système de Notation & Réputation

**Système de Notation ELO** (configurable par jeu) :
```elixir
Table: player_ratings
├── user_id, game_id, rating (entier ELO, défaut 1000)
├── matches_played, wins, losses, draws, win_rate
├── peak_rating, last_match_date
└── rating_change_history (tableau JSON)
```

**Classements** (auto-calculés via jobs cron) :
```elixir
Table: leaderboards
├── game_id, period (daily/weekly/monthly/all_time)
├── user_id, rank, score (rating ou wins)
└── calculated_at
```

**Score de Comportement** :
- Suivre les signalements de joueurs par d'autres utilisateurs
- Auto-signaler les comptes avec >3 signalements en 7 jours
- Suspension temporaire en attendant investigation
- Récompenses bon comportement (badges, taux de commission bonus)

```elixir
Table: player_reports
├── reporter_id, reported_id, game_id
├── reason (toxic/cheating/slow_player/other)
├── evidence (JSON), status (pending/reviewed/actioned)
└── admin_notes, resolved_at
```

**Matchmaking par Compétence** :
- Matcher les joueurs dans ±100 points ELO
- Files d'attente séparées par brackets de rating (débutant/intermédiaire/expert)
- Seedings de tournoi basés sur le rating

### 10. Fonctionnalités Sociales & Système de Chat

**Système d'Amis** :
```elixir
Table: friendships
├── user_id, friend_id, status (pending/accepted/blocked)
├── created_at, updated_at
└── last_game_together (nullable)
```

**Fonctionnalités** :
- Ajouter des amis par numéro de téléphone ou nom d'utilisateur
- Affichage du statut en ligne (en jeu/en ligne/hors ligne)
- Inviter des amis aux jeux (deep links pour mobile)
- Bloquer/débloquer des utilisateurs
- Feed d'activité des amis (victoires récentes, tournois rejoints)

**Chat en Jeu** :
```elixir
Table: chat_messages
├── id, room_id (nullable), game_id (nullable), sender_id
├── message, language (auto-détecté: fr/en)
├── flagged (bool), flag_reason, flagged_by (array)
└── created_at, edited_at (nullable)
```

**Fonctionnalités Chat** :
- Messagerie temps réel via Canaux Phoenix
- Auto-filtrage des mots toxiques (liste de mots configurable)
- Fonctionnalité de signalement de message
- Mute chat (temporaire/permanent) pour utilisateurs abusifs
- Support emoji, historique des messages (100 derniers messages)
- Chat multi-langue (option auto-traduction)

**Invitations de Jeu** :
- Liens partageables : `gamehub.com/invite/{token}`
- Génération de code QR pour invitations en personne
- Notification push aux amis invités
- Invitations expirant (valides 1 heure)

### 11. Système de Notification

**Notifications Multi-Canal** :
```elixir
Table: notification_preferences
├── user_id, channel (push/email/sms/in_app)
├── notification_type (game/tournament/wallet/system/marketing)
└── enabled (bool)
```

**Implémentation** :
- **In-App** : Canaux Phoenix → livraison temps réel
- **Push Notifications** : Firebase Cloud Messaging (Android) + Web Push API
- **Email** : SendGrid/Mailgun (transactionnel uniquement, optionnel)
- **SMS** : Africa's Talking (alertes critiques, Cameroun)

**Types de Notification** :
```
Notifications de Jeu :
├── your_turn (c'est votre tour)
├── game_started (vous avez rejoint un jeu)
├── opponent_joined (quelqu'un a rejoint votre salle)
├── game_ended (résultat disponible)
└── opponent_disconnected

Notifications de Tournoi :
├── tournament_starting (avertissement 5min)
├── round_starting (votre prochain match)
├── you_advanced (avez gagné le round précédent)
├── you_eliminated
└── tournament_ended (vous avez gagné !)

Notifications de Portefeuille :
├── deposit_confirmed
├── withdrawal_processed
├── low_balance_warning (<1000 XAF)
└── limit_approaching (jeu responsable)

Notifications Système :
├── kyc_status_updated
├── maintenance_scheduled
├── new_game_available
└── announcement (broadcast admin)
```

**Configuration Firebase** :
```yaml
# configuration flutter
firebase_core + firebase_messaging
gestionnaire de message en arrière-plan
gestion de la barre de notification
compteur de badge
```

### 12. Système de Gestion de Contenu (Admin)

**Contenu Gérable** :
```elixir
Table: cms_pages
├── slug (unique), title_en, title_fr
├── content_en (rich text/HTML), content_fr (rich text/HTML)
├── category (legal/faq/tutorial/announcement)
├── published (bool), published_at
├── version (integer, pour historique)
└── updated_by (admin_id), updated_at
```

**Types de Contenu** :
- **Pages Légales** : CGU, Politique de Confidentialité, Politique de Jeu Responsable, Politique de Cookies
- **FAQ** : Questions/réponses catégorisées, fonctionnalité de recherche
- **Tutoriels de Jeu** : Règles par jeu, guides comment jouer (multilingue)
- **Annonces** : Bannières planifiées, audience cible (tous/vérifiés/VIP)
- **Conditions de Tournoi** : Règles spécifiques par type de tournoi

```elixir
Table: announcements
├── title_en, title_fr, body_en, body_fr
├── type (info/promotion/maintenance/urgent)
├── target_audience (all/verified/vip/new_users)
├── scheduled_from, scheduled_to
├── display_priority (1-10)
├── active (bool), created_by (admin_id)
└── impression_count, click_count
```

**Fonctionnalités Admin** :
- Éditeur WYSIWYG pour création de contenu
- Prévisualisation avant publication
- Historique des versions & rollback
- Planification de publication
- Suivi de l'engagement (vues, clics)

### 13. Système de Parrainage & Affiliation

**Programme de Parrainage** :
```elixir
Table: referrals
├── id, referrer_id, referee_id, referral_code
├── status (pending/rewarded), reward_amount
├── referee_registered_at, referee_first_deposit_at
└── rewarded_at
```

**Mécanique** :
- Chaque utilisateur reçoit un code de parrainage unique à l'inscription
- Parrain ET filleul reçoivent un bonus (ex: 500 XAF) après le premier dépôt du filleul
- Saisie du code de parrainage lors de l'inscription (optionnel)
- Suivre la chaîne de parrainage (qui a parrainé qui)
- Dashboard de parrainage dans le profil utilisateur (codes, statistiques, gains)

**Programme d'Affiliation** (pour influenceurs, salons de coiffure, agents) :
```elixir
Table: affiliates
├── user_id, tier (bronze/silver/gold)
├── commission_percentage (bronze=5%, silver=7%, gold=10%)
├── total_referrals, total_earnings, pending_payout
├── tracking_code, payout_phone_number
└── status (active/suspended), approved_by (admin_id)
```

**Système de Tier** :
- **Bronze** : 1-10 parrainages actifs → 5% de commission sur les dépôts du filleul
- **Silver** : 11-50 parrainages actifs → 7% de commission
- **Gold** : 51+ parrainages actifs → 10% de commission + support dédié

**Paiement** : Gains d'affiliation mensuels payés automatiquement via Mobile Money

### 14. Gestion de Versions & Feature Flags

**Versionnement API** :
- Basé sur URL : `/api/v1/...`, `/api/v2/...`
- Compatibilité ascendante pour v1 quand v2 sort
- Headers de dépréciation dans les réponses API
- Date de fin pour les anciennes versions (6 mois minimum)

**Forçage de Version d'App** :
```elixir
Table: app_versions
├── platform (android/web), version_code (integer)
├── version_name (string, ex: "1.2.3")
├── minimum_supported (bool), latest_version (bool)
├── release_notes_en, release_notes_fr
├── force_update (bool), download_url
└── published_at
```

**Comportement** :
- L'app vérifie la version au démarrage (`GET /api/version/check`)
- Si `force_update=true` → bloquer utilisation app, afficher modal de mise à jour
- Si `minimum_supported=false` → bannière d'avertissement, autoriser continuer
- Deep link vers Play Store / page de téléchargement

**Feature Flags** :
```elixir
Table: feature_flags
├── flag_name (unique), description
├── enabled (bool), percentage_rollout (0-100)
├── user_ids_whitelist (array), user_ids_blacklist (array)
├── environment (dev/staging/production)
└── created_at, updated_at, created_by (admin_id)
```

**Cas d'Utilisation** :
- Lancement progressif de fonctionnalité (10% → 50% → 100%)
- Tests A/B (flag par segment d'utilisateur)
- Kill switch (désactiver fonctionnalité buguée sans déploiement)
- Fonctionnalités beta (activer pour utilisateurs spécifiques uniquement)
- Flags spécifiques à l'environnement (activer debug en staging)

**Dashboard Admin** : Basculer les flags en temps réel, sans redéploiement nécessaire

### 15. Limitation de Débit & Quotas (Avancé)

**Limitation de Débit par Tier** :
```elixir
Table: rate_limit_configs
├── endpoint_pattern (regex), requests_limit
├── window_seconds, user_tier_multiplier
├── ip_based (bool), user_based (bool)
├── action_on_exceed (block/captcha/delay/queue)
└── active (bool)
```

**Limites par Défaut** :
```
Global : 100 requêtes/minute par IP
Endpoints auth : 5 tentatives/15 minutes par numéro de téléphone
Paris : max 10 paris/minute par utilisateur
Retraits : max 5 par jour par utilisateur
Messages chat : 30/minute par utilisateur (anti-spam)
Recherche API : 20/minute par utilisateur

Tier VIP : 2x toutes les limites
Admin : pas de limites
```

**Implémentation** : Hammer (bibliothèque Elixir) + Redis pour limitation de débit distribuée

**Protection DDoS** :
- CloudFlare WAF (Pare-feu d'Application Web)
- Vérification de réputation IP
- CAPTCHA après activité suspecte
- Auto-bannir IPs avec >1000 requêtes échouées/heure

### 16. Support Multi-Devises

**Configuration de Devise** :
```elixir
Table: currencies
├── code (XAF, USD, EUR), symbol (FCFA, $, €)
├── decimal_places (0 pour XAF, 2 pour USD/EUR)
├── exchange_rate_to_base (base=XAF)
├── minimum_deposit, maximum_withdrawal
├── active (bool), is_default (bool)
└── updated_at
```

**Implémentation** :
- Stocker tous les montants en entiers (plus petite unité : centimes XAF, mais XAF a 0 décimales)
- Devise de base : XAF (toutes les conversions passent par XAF)
- Devise d'affichage : préférence utilisateur (défaut = XAF)
- Taux de change mis à jour quotidiennement via API (taux Banque Centrale)
- Frais de conversion de devise : 2% (configurable)

**Table de Transactions Modifiée** :
```elixir
transactions (
  id, user_id, type, amount (bigint), currency_code (FK),
  amount_xaf (bigint, normalisé), exchange_rate_used,
  balance_before, balance_after,
  payment_provider_id, status, metadata, created_at
)
```

**Formatage Flutter** :
```dart
// Formateur conscient de la devise
formatCurrency(10000, 'XAF') → "10 000 FCFA"
formatCurrency(10.50, 'USD') → "$10.50"
```

### 17. Localisation Avancée

**Préférences de Localisation Utilisateur** :
```elixir
# Ajouté à la table users :
timezone (varchar, défaut 'Africa/Douala')
locale (varchar, défaut 'fr')
date_format (varchar, défaut 'DD/MM/YYYY')
time_format (varchar, défaut '24h')
preferred_currency (varchar, défaut 'XAF')
```

**Fonctionnalités** :
- Auto-détection du fuseau horaire depuis device/navigateur
- Afficher tous les timestamps dans le fuseau horaire local de l'utilisateur
- Préférences de format de date (DD/MM/YYYY vs MM/DD/YYYY)
- Format d'heure 12h vs 24h
- Formatage des nombres (10 000 vs 10,000 vs 10.000)
- Filtrage de contenu régional (afficher tournois spécifiques Cameroun)
- Support RTL prêt (si expansion vers pays arabophones)

**Implémentation Flutter** :
```dart
// Utiliser le package intl pour le formatage conscient de la locale
DateFormat('dd/MM/yyyy', 'fr_FR').format(date)
NumberFormat.decimalPattern('fr_FR').format(10000)
```

### 18. Analytique & Business Intelligence

**Suivi d'Événements** :
```elixir
Table: analytics_events
├── id, user_id, event_type, event_data (JSON)
├── session_id, device_info (OS, version app)
├── ip_address, timestamp
└── processed (bool), processed_at
```

**Événements Suivis** :
```
Parcours Utilisateur :
├── app_opened, registered, login_success, login_failed
├── kyc_submitted, kyc_approved, kyc_rejected
├── deposit_initiated, deposit_confirmed, deposit_failed
├── first_game_joined, first_bet_placed
└── withdrawal_requested, withdrawal_completed

Engagement :
├── game_started, game_completed, game_abandoned
├── tournament_registered, tournament_won
├── chat_message_sent, friend_invite_sent
└── session_duration (toutes les 5min)

Business :
├── commission_earned, referral_rewarded
├── affiliate_commission_paid
└── limit_changed (jeu responsable)
```

**Dashboard de Métriques Clés** (Admin) :
- **Acquisition** : Nouveaux utilisateurs/jour, taux de conversion parrainage
- **Activation** : % qui déposent sous 24h, % qui jouent au premier jeu
- **Engagement** : Ratio DAU/MAU, durée moyenne de session, jeux/utilisateur/jour
- **Rétention** : Taux de rétention D1/D7/D30, analyse de cohorte
- **Revenu** : Total dépôts, total retraits, revenu net, ARPU, ARPPU
- **Valeur Vie** : LTV par canal d'acquisition, ratio LTV:CAC
- **Performance de Jeu** : Plus joués, plus haut revenu, mise moyenne par jeu
- **Stats Tournoi** : Taux de participation, taux de complétion, distribution des prizes

**Intégration** :
- **Option A** : PostHog (open source, auto-hébergé sur Fly.io)
- **Option B** : Mixpanel/Amplitude (cloud, configuration plus facile)
- **Export** : CSV/Excel pour outils BI externes (Metabase, Looker)

**Framework de Test A/B** :
- Utiliser des feature flags pour diviser les utilisateurs en groupes
- Suivre les métriques de conversion par groupe
- Calculateur de signification statistique
- Exemple de test : "Le bonus de parrainage de 500 XAF convertit-il mieux que 1000 XAF ?"

### 8. Détection de Fraude & Anti-Triche

**Systèmes de Détection** :
- **Détection de collusion** : Même adresse IP, empreinte digitale de device, patterns de paris coordonnés
- **Détection de bot** : Analyse de timing des coups (trop cohérent = bot), reconnaissance de patterns
- **Contrôles de vélocité** : Paris rapides, pics d'activité inhabituels
- **Anomalie de taux de victoire** : Analyse statistique (>95% de victoire sur 100+ jeux = signal)
- **Détection multi-comptes** : Même téléphone, pattern d'email, ID de device

**Actions lors de Détection** :
- Auto-signaler le compte pour révision
- Suspendre temporairement la capacité de parier
- Alerter le dashboard admin
- Loguer toutes les preuves pour investigation

```elixir
Table: fraud_flags
├── user_id, flag_type, severity (low/medium/high/critical)
├── evidence (JSON), status (open/investigating/resolved/false_positive)
├── assigned_to (admin_id), resolved_at, resolution_notes
```

### 9. Support & Résolution de Litiges

**Système de Replay de Jeu** :
- Log complet d'actions par jeu (stocké en base)
- Machine d'état rejouable pour investigation
- Rétention : 90 jours (configurable)

**Système de Tickets de Litige** :
```elixir
Table: support_tickets
├── user_id, game_id (nullable), type (bug/dispute/fraud/general)
├── status (open/in_progress/resolved/closed), priority
├── description, evidence_urls, assigned_to (admin_id)
└── resolution, resolved_at, created_at
```

**Politique d'Auto-Remboursement** :
- Crash serveur détecté pendant un jeu avec mises → remboursement automatique à tous les joueurs
- Incohérence de base de données détectée → pause des jeux affectés, révision manuelle
- Échec de webhook de paiement → retry avec backoff exponentiel, intervention manuelle après 24h

### 10. Tableau de Bord Admin (Phoenix LiveView)

**Fonctionnalités** :
```
Accueil Dashboard
├── KPIs (DAU, MAU, revenu, commission gagnée, jeux actifs)
├── Métriques temps réel (joueurs concurrents, jeux en cours)
└── Alertes (signaux de fraude, erreurs système, providers à faible balance)

Gestion Utilisateurs
├── Rechercher, filtrer, voir profils utilisateurs
├── Validation KYC (approuver/rejeter documents)
├── Actions sur compte (suspendre/réactiver, ajustement manuel de balance avec audit)
├── Historique des transactions par utilisateur
└── Signaux de fraude & notes d'investigation

Portefeuille & Transactions
├── Visionneuse de transactions (recherche, filtre, export CSV)
├── Ajustements manuels (requièrent raison + workflow d'approbation)
├── État de réconciliation (dernière vérification, incohérences)
└── File de retraits (approuver/rejeter)

Gestion de Jeux
├── Activer/désactiver des jeux
├── Configuration de commission (par jeu, mode A/B/C/D)
├── Configuration de timeout (par jeu/mode)
└── Métriques de performance de jeu

Gestion de Tournois
├── Créer/annuler des tournois
├── Voir résultats, distribution des prix
├── Configuration de planification
└── Gestion des participants

Tickets de Support
├── File de tickets (filtrer par statut/priorité)
├── Visionneuse de replay de jeu (outil d'investigation)
├── Communication avec utilisateur
└── Workflow de résolution

Détection de Fraude
├── Dashboard de signaux (compte par sévérité)
├── Outils d'investigation (recherche IP, analyse d'empreinte de device)
├── Visualisation de patterns
└── Boutons d'action (suspendre/avertir/effacer)

Santé Système
├── Métriques serveur (CPU, mémoire, latence)
├── Santé base de données (pool de connexions, performance de requêtes)
├── État Redis (mémoire, taux de hit)
├── État des providers de paiement (actif, tester connexion)
└── Suivi de taux d'erreur

Fournisseurs de Paiement
├── Activer/désactiver des fournisseurs
├── Tester la connexion API
├── Voir taux de succès/échec des transactions
└── Éditeur de configuration

Rapports & Analytique
├── Rapports de revenu (quotidien/hebdomadaire/mensuel)
├── Détail des commissions par jeu
├── Croissance & rétention utilisateurs
├── Classement de popularité de jeux
├── Stats de participation aux tournois
└── Export vers PDF/Excel
```

### 11. Stack d'Observabilité

**Métriques d'Application** (Prometheus + Grafana) :
- Latence de requête (p50, p95, p99)
- Taux d'erreur par endpoint
- Connexions WebSocket actives
- Utilisation du pool de connexions de base de données
- Taux de hit Redis & utilisation mémoire
- Taux de rejoins/quittages de canaux Phoenix

**Métriques Business** (dashboards Grafana personnalisés) :
- Utilisateurs Actifs Quotidiens (DAU), Utilisateurs Actifs Mensuels (MAU)
- Revenu (dépôts, commissions, profit net)
- Rétention des joueurs (D1, D7, D30)
- Distribution de jeux (plus joués, plus haut revenu)
- Taux de participation aux tournois
- Durée moyenne de session
- Taux de churn

**Suivi d'Erreurs** (Sentry) :
- Backend : intégration `sentry-elixir`
- Frontend : intégration `sentry_flutter`
- Contexte : user_id, game_id, action, info device

**Logging** (logs JSON structurés → Loki) :
- Logs de requêtes (méthode, chemin, statut, durée, user_id)
- Logs d'actions de jeu (game_id, player_id, action, timestamp)
- Logs financiers (transaction_id, montant, type, balance_avant, balance_après)
- Logs d'audit (admin_id, action, entité, changements, timestamp, ip_address)

**Règles d'Alerte** (PagerDuty/Slack) :
- Latence p95 > 200ms pendant 5min
- Taux d'erreur > 1% pendant 10min
- Incohérence de réconciliation de portefeuille détectée
- Taux d'échec de fournisseur de paiement > 10%
- Pic de comptage de signaux de fraude (>50 en 1h)
- Pool de connexions de base de données > 80% de capacité

### 12. Sauvegarde & Reprise après Sinistre

**PostgreSQL** :
- Sauvegardes automatisées quotidiennes (rétention : 30 jours)
- Récupération Point-in-Time (PITR) activée (rétention : 7 jours)
- Réplication de sauvegarde cross-région

**Redis** :
- Persistance AOF (Append Only File) : politique `everysec`
- Snapshots RDB : toutes les 15min si >1000 clés changées
- Mode cluster Redis pour haute disponibilité

**Réconciliation de Portefeuille** :
- Job cron horaire : vérifier `user.balance = SUM(transactions)`
- Alerte en cas d'incohérence + auto-pause des comptes affectés
- Le dashboard admin montre l'état de réconciliation

**Déploiement Multi-Région** :
- Primaire : Région Fly.io Johannesbourg (plus proche du Cameroun)
- Secondaire : Région Fly.io Paris (fallback)
- Base de données : read replicas en région secondaire

**Runbook** (procédures documentées) :
- Récupération de corruption de base de données
- Flush Redis & restauration depuis snapshot
- Traitement du backlog de webhooks de paiement
- Workflow d'investigation de fraude
- Procédure d'arrêt d'urgence

---

## Endpoints API (REST + WebSocket)

### Authentification
```
POST   /api/auth/register          # Téléphone + configuration OTP
POST   /api/auth/login             # Téléphone + vérification OTP
POST   /api/auth/2fa/enable        # Activer TOTP
POST   /api/auth/2fa/verify        # Vérifier code 2FA
POST   /api/auth/logout            # Invalider session
POST   /api/auth/refresh-token     # Rafraîchir JWT
```

### Portefeuille
```
GET    /api/wallet/balance         # Balance actuelle
POST   /api/wallet/deposit/initiate # Initier dépôt Mobile Money
POST   /api/wallet/deposit/confirm # Confirmer via webhook
POST   /api/wallet/withdraw        # Demander retrait
GET    /api/wallet/transactions    # Historique des transactions (paginé)
```

### Paiements (Webhooks)
```
POST   /api/webhooks/campay        # Confirmation de paiement Campay
POST   /api/webhooks/mtn           # Mise à jour statut MTN MoMo
POST   /api/webhooks/orange        # Mise à jour statut Orange Money
```

### Jeux
```
GET    /api/games                  # Lister jeux disponibles
GET    /api/games/:id              # Détails du jeu + info commission
POST   /api/games/:id/play         # Démarrer jeu hors ligne/local
```

### Matchmaking
```
POST   /api/matchmaking/queue      # Rejoindre file d'attente rapide
DELETE /api/matchmaking/queue      # Quitter file d'attente
POST   /api/rooms/create           # Créer salle privée/publique
GET    /api/rooms/public           # Lister salles publiques
POST   /api/rooms/:id/join         # Rejoindre salle
POST   /api/rooms/:id/leave        # Quitter salle
```

### Tournois
```
GET    /api/tournaments            # Lister tournois à venir/actifs
GET    /api/tournaments/:id        # Détails du tournoi
POST   /api/tournaments/:id/register # S'inscrire au tournoi
GET    /api/tournaments/:id/bracket # Voir bracket/classement
```

### Conformité
```
POST   /api/kyc/submit             # Soumettre documents KYC
GET    /api/kyc/status             # Vérifier statut KYC
GET    /api/user/limits            # Voir limites de transaction (basé sur tier)
POST   /api/user/data-export       # Demander export de données (RGPD)
DELETE /api/user/account           # Demander suppression de compte (RGPD)
```

### Support
```
POST   /api/support/tickets        # Créer ticket de support
GET    /api/support/tickets        # Lister tickets utilisateur
GET    /api/support/tickets/:id    # Détails du ticket
POST   /api/support/tickets/:id/message # Ajouter message au ticket
```

### Social
```
GET    /api/friends                # Lister amis
POST   /api/friends/:id/request    # Envoyer demande d'ami
PUT    /api/friends/:id/accept     # Accepter demande d'ami
DELETE /api/friends/:id            # Supprimer/bloquer ami
GET    /api/friends/online         # Lister amis en ligne
POST   /api/friends/invite         # Inviter ami à un jeu
```

### Notation & Classements
```
GET    /api/rating/:game_id        # Obtenir notation utilisateur
GET    /api/rating/:game_id/history # Historique de changement de notation
GET    /api/leaderboards/:game_id  # Voir classement (filtre de période)
POST   /api/players/:id/report     # Signaler joueur (toxique/triche)
```

### Notifications
```
GET    /api/notifications          # Lister notifications utilisateur
PUT    /api/notifications/:id/read # Marquer comme lu
PUT    /api/notifications/read-all # Marquer tous comme lus
GET    /api/notifications/preferences # Obtenir paramètres de notification
PUT    /api/notifications/preferences # Mettre à jour paramètres
```

### Jeu Responsable
```
GET    /api/responsible-gaming/limits # Obtenir limites actuelles
PUT    /api/responsible-gaming/limits # Définir/mettre à jour limites
POST   /api/responsible-gaming/self-exclude # Demander auto-exclusion
GET    /api/responsible-gaming/status     # Vérifier statut d'exclusion
DELETE /api/responsible-gaming/self-exclude # Annuler (seulement si date future)
```

### Parrainage & Affiliation
```
GET    /api/referral/code          # Obtenir mon code de parrainage
GET    /api/referral/stats         # Voir statistiques de parrainage
POST   /api/referral/apply         # Appliquer code de parrainage (pendant inscription)
GET    /api/affiliate/status       # Vérifier statut d'affiliation & gains
GET    /api/affiliate/payouts      # Voir historique de paiements
```

### Contenu & CMS
```
GET    /api/cms/pages/:slug        # Obtenir contenu de page (légal, FAQ, etc.)
GET    /api/cms/faq                # Lister articles FAQ
GET    /api/cms/announcements      # Lister annonces actives
GET    /api/cms/tutorials/:game_id # Obtenir tutoriel de jeu
```

### Version & Fonctionnalités
```
GET    /api/version/check          # Vérifier si mise à jour d'app requise
GET    /api/feature-flags          # Obtenir feature flags actifs pour utilisateur
```

### WebSocket (Canaux Phoenix)
```
# Salle de jeu
join: "game_room:{game_id}"
events: player_joined, move_made, game_state_update, game_ended, player_left

# Matchmaking
join: "matchmaking:{queue_id}"
events: queue_position_update, match_found, room_created

# Tournoi
join: "tournament:{tournament_id}"
events: round_started, match_result, bracket_update, tournament_ended

# Notifications
join: "user_notifications:{user_id}"
events: deposit_confirmed, withdrawal_processed, tournament_starting,
        fraud_flag_alert, ticket_response
```

---

## Schéma de Base de Données (Tables Centrales)

```sql
-- Utilisateurs
users (id, phone, email, name, date_of_birth, status, kyc_tier, 
       two_factor_enabled, created_at, updated_at)

-- Portefeuille
user_wallets (user_id, balance, currency, updated_at)

-- Transactions
transactions (id, user_id, type, amount, balance_before, balance_after,
              payment_provider_id, status, metadata, created_at)

-- Fournisseurs de Paiement
payment_providers (id, name, active, api_key_encrypted, api_secret_encrypted,
                   configuration_json, priority, created_at, updated_at)

-- Jeux
games (id, name, description_en, description_fr, icon_url, active, 
       plugin_module, created_at)

-- Config Commission
game_commissions (id, game_id, commission_type, commission_value, 
                  active, effective_from, created_at)

-- Config Timeout
game_timeout_config (id, game_id, game_mode, grace_period_seconds, 
                      action_on_timeout, forfeit_distribution, created_at)

-- Salles
rooms (id, game_id, creator_id, stake_amount, max_players, 
       current_players, mode (public/private), invite_code, status,
       created_at, started_at, ended_at)

-- Types de Tournoi
tournament_types (id, name, type, rules_json, free_entry, 
                  default_stake, active)

-- Config Tournoi
tournament_config (id, type_id, schedule_cron, duration_minutes, 
                    min_players, max_players, stake_override,
                    auto_create, prize_distribution_json)

-- Tournois
tournaments (id, type_id, status, prize_pool, current_round, 
             start_time, end_time, created_at)

-- Participants au Tournoi
tournament_participants (tournament_id, user_id, seed, status, 
                          eliminated_at, final_rank)

-- KYC
user_kyc (user_id, status, id_document_url, selfie_url, 
           verified_by, verified_at, rejection_reason)

-- Limites de Tier Utilisateur
user_tier_limits (tier, daily_deposit_limit, monthly_deposit_limit,
                   daily_withdrawal_limit, single_transaction_limit,
                   kyc_required)

-- Signaux de Fraude
fraud_flags (id, user_id, flag_type, severity, evidence_json, 
              status, assigned_to, resolved_at, resolution_notes)

-- Tickets de Support
support_tickets (id, user_id, game_id, type, status, priority, 
                  description, assigned_to, resolution, resolved_at, created_at)

-- Logs d'Action de Jeu (pour replay)
game_action_logs (id, game_id, room_id, player_id, action_type, 
                   action_data_json, timestamp)

-- Logs d'Audit
audit_logs (id, admin_id, action, entity_type, entity_id, 
            changes_json, ip_address, created_at)

-- Sessions d'Authentification
auth_sessions (id, user_id, device_fingerprint, jwt_token, 
                refresh_token, expires_at, last_active, created_at)

-- Devises
currencies (code, symbol, decimal_places, exchange_rate_to_base,
            minimum_deposit, maximum_withdrawal, active, is_default)

-- Notations de Joueur
player_ratings (user_id, game_id, rating, matches_played, wins,
                 losses, draws, win_rate, peak_rating, last_match_date)

-- Classements
leaderboards (game_id, period, user_id, rank, score, calculated_at)

-- Signalements de Joueur
player_reports (id, reporter_id, reported_id, game_id, reason,
                 evidence_json, status, admin_notes, resolved_at)

-- Amitiés
friendships (user_id, friend_id, status, created_at, updated_at,
              last_game_together)

-- Messages de Chat
chat_messages (id, room_id, game_id, sender_id, message, language,
                flagged, flag_reason, flagged_by, created_at, edited_at)

-- Préférences de Notification
notification_preferences (user_id, channel, notification_type, enabled)

-- Notifications (historique in-app)
notifications (id, user_id, type, title, body, data_json,
                read, created_at)

-- Limites de Jeu Responsable
responsible_gaming_limits (user_id, daily_deposit_limit,
                            weekly_deposit_limit, monthly_deposit_limit,
                            daily_loss_limit, session_time_limit_minutes,
                            self_exclusion_until, reality_check_interval_minutes,
                            updated_at)

-- Auto Exclusions
self_exclusions (user_id, type, start_date, end_date, reason,
                  initiated_by, support_resources_shown)

-- Pages CMS
cms_pages (slug, title_en, title_fr, content_en, content_fr,
            category, published, published_at, version,
            updated_by, updated_at)

-- Annonces
announcements (id, title_en, title_fr, body_en, body_fr, type,
                target_audience, scheduled_from, scheduled_to,
                display_priority, active, created_by,
                impression_count, click_count)

-- Parrainages
referrals (id, referrer_id, referee_id, referral_code, status,
            reward_amount, referee_registered_at,
            referee_first_deposit_at, rewarded_at)

-- Affiliés
affiliates (user_id, tier, commission_percentage, total_referrals,
             total_earnings, pending_payout, tracking_code,
             payout_phone_number, status, approved_by)

-- Versions d'App
app_versions (platform, version_code, version_name,
               minimum_supported, latest_version,
               release_notes_en, release_notes_fr,
               force_update, download_url, published_at)

-- Feature Flags
feature_flags (flag_name, description, enabled, percentage_rollout,
                user_ids_whitelist, user_ids_blacklist,
                environment, created_at, updated_at, created_by)

-- Configs de Limite de Débit
rate_limit_configs (endpoint_pattern, requests_limit, window_seconds,
                     user_tier_multiplier, ip_based, user_based,
                     action_on_exceed, active)

-- Événements d'Analytique
analytics_events (id, user_id, event_type, event_data_json,
                   session_id, device_info, ip_address,
                   timestamp, processed, processed_at)

-- Plan Comptable (comptabilité en double entrée)
chart_of_accounts (account_code, account_name, account_type,
                    parent_account_code, active)

-- Écritures Comptables (double entrée)
accounting_entries (id, transaction_id, journal_entry_id,
                     account_code, entry_type, amount, currency,
                     balance_after, description, reconciled,
                     reconciled_at, created_at)

-- Rapports Fiscaux
tax_reports (id, period, tax_type, taxable_amount, tax_rate,
              tax_due, filed, filed_at, reference_number,
              supporting_documents, created_by, reviewed_by)

-- Taux de Taxe
tax_rates (tax_type, rate, applicable_from, applicable_to,
            description, legal_reference, active)

-- Réconciliation Bancaire
bank_reconciliation (id, reconciliation_date, provider_id,
                      provider_total, system_total, discrepancy_amount,
                      status, investigated_by, resolved_at,
                      resolution_notes, created_at)

-- Clés d'Idempotence
idempotency_keys (key, user_id, endpoint, request_hash,
                   response_body, status, created_at, expires_at)

-- Versions de Documents Légaux
legal_document_versions (document_type, version, content_en,
                          content_fr, effective_from, effective_to,
                          change_summary, requires_reacceptance,
                          created_by, approved_by, created_at)

-- Acceptations Légales Utilisateur
user_legal_acceptances (user_id, document_type, document_version,
                         accepted_at, ip_address, user_agent,
                         acceptance_method)
```

---

## Structure de l'App Flutter

```
lib/
├── main.dart
├── core/
│   ├── config/ (config app, constantes, thème)
│   ├── network/ (client API, gestionnaire WebSocket, intercepteurs)
│   ├── storage/ (stockage sécurisé, préférences partagées, hive)
│   ├── utils/ (validateurs, formateurs, extensions)
│   └── localization/ (app_en.arb, app_fr.arb)
├── data/
│   ├── models/ (User, Wallet, Game, Room, Tournament, Transaction)
│   ├── repositories/ (AuthRepository, WalletRepository, GameRepository)
│   └── datasources/ (RemoteDataSource, LocalDataSource)
├── domain/
│   ├── entities/ (modèles de logique métier)
│   ├── usecases/ (LoginUseCase, DepositUseCase, JoinRoomUseCase)
│   └── repositories/ (interfaces abstraites)
├── presentation/
│   ├── providers/ (gestion d'état Riverpod/Bloc)
│   ├── screens/
│   │   ├── auth/ (connexion, inscription, 2FA, KYC)
│   │   ├── home/ (liste de jeux, tournois en vedette)
│   │   ├── wallet/ (balance, dépôt, retrait, transactions)
│   │   ├── lobby/ (salles publiques, match rapide, créer salle)
│   │   ├── game/ (UI de jeu, coups, chat)
│   │   ├── tournament/ (brackets, inscription, matchs en direct)
│   │   ├── profile/ (paramètres, statut kyc, historique)
│   │   └── support/ (tickets, FAQ, contact)
│   └── widgets/ (composants UI réutilisables)
└── games/
    ├── dice_game/ (UI & logique spécifiques au jeu de dés)
    │   ├── dice_game_screen.dart
    │   ├── dice_animation.dart
    │   ├── dice_game_provider.dart
    │   └── dice_config_selector.dart
    ├── morabaraba/ (UI & logique spécifiques au jeu - futur)
    ├── checkers/ (UI & logique spécifiques au jeu - futur)
    └── ... (futurs jeux)
```

---

## Liste de Contrôle de Sécurité & Conformité

- [ ] Double vérification de permission (frontend + backend)
- [ ] Transactions ACID pour toutes les opérations financières
- [ ] Récupération après crash supervisée par OTP (pas de perte d'état)
- [ ] Limitation de débit sur tous les endpoints d'authentification et de paiement
- [ ] CORS whitelist stricte
- [ ] Assainissement des inputs sur les actions de jeu
- [ ] Empreinte digitale du device pour la sécurité des sessions
- [ ] Stockage chiffré des clés API (jamais en clair)
- [ ] Vérification KYC avant les retraits de haute valeur
- [ ] Vérification d'âge (>=18) obligatoire à l'inscription
- [ ] Détection & signalement de patterns AML
- [ ] Conformité RGPD (export de données, suppression, consentement)
- [ ] Logs d'audit pour toutes les actions admin & opérations financières
- [ ] Détection anti-triche (bots, collusion, anomalies)
- [ ] Réconciliation de portefeuille (vérification automatisée horaire)
- [ ] Récupération Point-in-Time pour PostgreSQL
- [ ] Déploiement multi-région pour la reprise après sinistre
- [ ] Pages de conformité légale (CGU, CGV, politique de confidentialité)
- [ ] Affichage de licence (licence de jeu MINFI)

---

## Stratégie de Test

### Backend (Elixir)
- **Tests Unitaires** : ExUnit pour la logique métier, les calculs financiers
- **Tests de Propriété** : StreamData pour les tests génératifs (cas limites)
- **Tests d'Intégration** : Phoenix.ConnTest pour les endpoints API
- **Tests WebSocket** : Phoenix.ChannelTest pour les flux temps réel
- **Tests de Charge** : k6 pour la simulation de 10K+ joueurs concurrents
- **Tests de Chaos** : Simuler crash DB, partition réseau, échec Redis

### Frontend (Flutter)
- **Tests Unitaires** : Logique métier, gestion d'état
- **Tests de Widget** : Composants UI, formulaires, validation
- **Tests d'Intégration** : Parcours utilisateur complets (connexion → dépôt → jouer → retrait)
- **Tests E2E** : Package `integration_test` avec API réelle

### Objectifs de Couverture
- Backend : >90% de couverture de code (100% pour les modules financiers)
- Frontend : >80% de couverture de code
- Chemins critiques : 100% de couverture (auth, portefeuille, paiements)

---

## Pipeline CI/CD (GitHub Actions)

```yaml
Workflow :
1. Qualité du Code
   - Elixir : `mix credo`, `mix format --check-formatted`
   - Flutter : `dart analyze`, `dart format --set-exit-if-changed`

2. Audit de Sécurité
   - Elixir : `mix sobelow --config`
   - Flutter : `flutter pub audit`, `dart pub outdated`

3. Suite de Tests
   - Backend : `mix test` (unitaire + intégration)
   - Frontend : `flutter test` (unitaire + widget)

4. Build
   - Backend : Création d'image Docker
   - Frontend : Build web + Android APK/AAB

5. Déploiement en Staging (Fly.io)
   - Automatique lors du merge sur la branche main

6. Tests de Fumée
   - Exécuter les tests de chemins critiques en staging

7. Déploiement en Production
   - Approbation manuelle requise
   - Stratégie de déploiement blue-green
```

---

## Requis de Performance

- **Latence WebSocket** : <100ms (p95)
- **Temps de Réponse API** : <200ms (p95)
- **Joueurs Concurrents** : 10 000+ par nœud de serveur
- **Requêtes Base de Données** : <50ms (p95)
- **Opérations Redis** : <10ms (p95)
- **App Flutter** : 60 FPS, <2s de chargement initial, <500ms transitions d'écran
- **Démarrage à Froid** : <3s (auto-scaling Fly.io)

---

## Phases de Développement

### Phase 1 : Fondation du Hub (Semaines 1-4)
- Configuration du projet Phoenix + architecture OTP
- Schéma PostgreSQL + migrations (toutes les tables centrales)
- Intégration Redis
- Support multi-devises (XAF par défaut)
- Module d'authentification (connexion OTP, JWT, 2FA)
- Système de portefeuille (balance, transactions, comptabilité en double entrée)
- Intégration de paiement (Campay)
- Feature flags & gestion de versions
- Configuration de limitation de débit + clés d'idempotence
- Contrôle de concurrence (verrouillage pessimiste, SETNX)
- Squelette du dashboard admin (LiveView)
- Squelette de l'app Flutter + navigation
- Configuration de la localisation (fichiers ARB, fuseau horaire, formats de date)
- Configuration du pipeline CI/CD
- Fondation du suivi d'événements d'analytique
- Implémentation des en-têtes de sécurité

### Phase 2 : Fonctionnalités Centrales (Semaines 5-8)
- Système de matchmaking (file d'attente + salles, opérations atomiques)
- Interface de registre de plugins de jeu
- **Premier plugin de jeu : Jeu de Dés (Dice Game)**
  - Implémentation complète du jeu de lancé de dés
  - Configuration paramétrable (1-3 dés, 1-N lancés, méthode de score)
  - Gestion des égalités (remboursement/relance/partage)
  - Animation Flutter des dés avec physique réaliste
  - Génération aléatoire côté serveur avec seed cryptographique
  - Table de résultats et traçabilité complète
- Moteur de commission
- Gameplay temps réel WebSocket
- Intégration UI de jeu Flutter
- Module KYC
- Système de tickets de support
- Fonctionnalités sociales (amis, chat, invitations)
- Système de notifications in-app
- Notifications push (Firebase)
- Implémentation du système de notation (ELO)
- Classements (auto-calcul)
- Configuration de la gestion de contenu (CMS)
- Publication des pages légales (CGU, confidentialité, règles du jeu de dés)
- Parcours d'intégration utilisateur (tutoriel, mode démo avec jeu de dés)
- Mode hors ligne & UX de récupération d'erreurs

### Phase 3 : Fonctionnalités Avancées (Semaines 9-12)
- Système de tournoi (tous les types)
- Détection de fraude & anti-triche
- Module de jeu responsable (limites, auto-exclusion)
- Système de parrainage & d'affiliation
- Gestion comptable & fiscale (double entrée, calcul TVA)
- Automatisation de la réconciliation bancaire
- Dashboard d'analytique avancé (intégration PostHog)
- Stack d'observabilité (métriques, alertes)
- Configuration de sauvegarde & reprise après sinistre
- Dashboard admin complet (toutes les sections)
- Tests de charge & optimisation
- Support multi-langue (EN/FR)
- Framework de test A/B
- Audit d'accessibilité (WCAG 2.1 AA)
- Durcissement de la sécurité (validation d'input, vérifications d'autorisation)
- Audit de sécurité (tests de pénétration)

### Phase 4 : Prêt pour la Production (Semaines 13-14)
- Tests de pénétration (cabinet de sécurité externe)
- Vérification de conformité légale (MINFI, COBAC)
- Audit de conformité de jeu responsable
- Validation du calcul des taxes (TVA 19,25%, retenue à la source)
- Documentation (API, guide admin, guide utilisateur, runbooks)
- Test bêta (groupe fermé, 100+ utilisateurs, 2 semaines)
- Optimisation de performance (latence, scaling, index de base de données)
- Test de reprise après sinistre (restauration complète depuis sauvegarde)
- Corrections de bugs & peaufinage
- Déploiement en production (stratégie blue-green)
- Mise en service des dashboards de monitoring
- Configuration de la rotation d'astreinte

---

## Livrables

1. **Codebase prête pour la production** (backend + frontend)
2. **Suite de tests complète** (>90% de couverture sur les chemins critiques)
3. **Documentation API** (spécification OpenAPI/Swagger)
4. **Documentation du schéma de base de données** (ERD + guide de migration)
5. **Guide de déploiement** (Fly.io, configuration DB, variables d'environnement, Firebase)
6. **Manuel utilisateur admin** (guide du dashboard LiveView)
7. **Rapport d'audit de sécurité** (évaluation des vulnérabilités)
8. **Résultats des tests de charge** (benchmarks de performance, 10K+ concurrents)
9. **Runbook** (procédures de réponse aux incidents, reprise après sinistre)
10. **Liste de contrôle de conformité légale** (MINFI, COBAC, RGPD, jeu responsable)
11. **Dashboard d'analytique** (PostHog/Mixpanel configuré)
12. **Documentation des feature flags** (tous les flags, cas d'utilisation, stratégie de déploiement)

---

### 19. Gestion Comptable & Fiscale (LÉGALEMENT OBLIGATOIRE)

**Système de Comptabilité en Double Entrée** (obligatoire pour l'audit financier) :
```elixir
Table: chart_of_accounts
├── account_code (unique), account_name
├── account_type (asset/liability/equity/revenue/expense)
├── parent_account_code (pour la hiérarchie)
└── active (bool)

Table: accounting_entries (double entrée)
├── id, transaction_id, journal_entry_id
├── account_code, entry_type (debit/credit)
├── amount, currency, balance_after
├── description, created_at
└── reconciled (bool), reconciled_at

# Chaque transaction financière crée 2 écritures :
# Exemple : Utilisateur dépose 10 000 XAF
#   DÉBIT : Compte de caisse (actif) +10 000
#   CRÉDIT : Passif du portefeuille utilisateur +10 000
```

**Gestion Fiscale** (conformité fiscale camerounaise) :
```elixir
Table: tax_reports
├── id, period (trimestre/année), tax_type (VAT/corporate/gaming)
├── taxable_amount, tax_rate, tax_due
├── filed (bool), filed_at, reference_number
├── supporting_documents (array d'URLs)
└── created_by (admin_id), reviewed_by (admin_id)

Table: tax_rates
├── tax_type, rate (decimal, ex: 0.1925 pour TVA 19,25%)
├── applicable_from, applicable_to (nullable)
├── description, legal_reference
└── active (bool)
```

**Règles Fiscales** :
- TVA (19,25%) sur les commissions de la plateforme (pas sur les mises des joueurs)
- Retenue à la source sur les gains > 1 000 000 XAF (10%)
- Déclarations fiscales trimestrielles au MINFI
- Déclaration fiscale annuelle des sociétés
- Calcul automatisé au niveau de la transaction

**Réconciliation Bancaire** (quotidienne automatisée) :
```elixir
Table: bank_reconciliation
├── id, reconciliation_date, provider_id
├── provider_total (depuis API MoMo), system_total (depuis DB)
├── discrepancy_amount, status (matched/investigating/resolved)
├── investigated_by (admin_id), resolved_at, resolution_notes
└── created_at

# Le job cron s'exécute quotidiennement à 2h du matin :
# 1. Récupérer les totaux de la veille depuis les APIs Campay/MTN/Orange
# 2. Additionner tous les dépôts confirmés dans le système
# 3. Comparer les totaux, signaler les incohérences > 100 XAF
# 4. Alerter l'admin en cas de non-concordance détectée
```

**Rétention Légale** :
- Toutes les transactions : 10 ans minimum (exigence COBAC)
- Documents KYC : 10 ans après la fermeture du compte
- Logs d'audit : 10 ans
- Messages de chat : 2 ans (résolution de litiges)
- Événements d'analytique : 3 ans (agrégés, anonymisés après 1 an)

**Rapports Financiers** (auto-générés mensuellement) :
- Détail des revenus (commissions, frais de tournoi, coûts d'affiliation)
- Résumé des balances des joueurs (passif total)
- Ratio dépôt vs retrait
- Commission gagnée par jeu
- Résumé du passif fiscal
- Rapport d'état de réconciliation

### 20. Contrôle de Concurrence & Prévention des Conditions de Course

**Sécurité des Transactions Financières** :
```elixir
# Verrouillage pessimiste pour les mutations de portefeuille :
defmodule GameHub.Wallet do
  def withdraw(user_id, amount, idempotency_key) do
    Repo.transaction(fn ->
      # Verrouiller la ligne de portefeuille (prévient les retraits concurrents)
      wallet = Repo.one!(from w in UserWallet,
        where: w.user_id == ^user_id,
        lock: "FOR UPDATE")

      # Vérifier l'idempotence (prévenir les webhooks dupliqués)
      case get_idempotency_key(idempotency_key) do
        nil ->
          # Traiter le retrait
          if wallet.balance < amount, do: throw(:insufficient_funds)
          
          new_wallet = update_wallet_balance(wallet, -amount)
          create_transaction(new_wallet, :withdrawal, amount)
          store_idempotency_key(idempotency_key, new_wallet)
          
          new_wallet
        
        existing ->
          # Retourner la réponse en cache (idempotent)
          existing
      end
    end)
  end
end

Table: idempotency_keys
├── key (unique, varchar 64), user_id, endpoint
├── request_hash (SHA256), response_body (JSON)
├── status (pending/completed), created_at, expires_at (24h)
```

**Atomicité du Matchmaking** :
```elixir
# Utiliser Redis SETNX pour l'assignation atomique de joueur :
defmodule GameHub.Matchmaking do
  def match_player(queue_id, player_id) do
    case Redix.command(redis, ["SETNX", "queue:#{queue_id}:player:#{player_id}", "1"]) do
      {:ok, 1} ->
        # Verrouillé avec succès, procéder au matching
        find_opponent(queue_id, player_id)
      
      {:ok, 0} ->
        # Déjà verrouillé (en cours de matching ailleurs)
        {:error, :already_in_match}
    end
  end
end
```

**Contraintes de Rejoindre une Salle** :
```sql
-- La contrainte au niveau de la base de données empêche le surpeuplement :
ALTER TABLE rooms ADD CONSTRAINT max_players_check 
  CHECK (current_players <= max_players);

-- Rejoindre atomique au niveau de l'application :
defmodule GameHub.Room do
  def join_player(room_id, player_id) do
    Repo.transaction(fn ->
      room = Repo.one!(from r in Room,
        where: r.id == ^room_id,
        lock: "FOR UPDATE")
      
      if room.current_players >= room.max_players do
        throw(:room_full)
      end
      
      # Ajouter le joueur et incrémenter atomiquement
      RoomPlayer.create(room_id, player_id)
      Room.increment_current_players(room_id, 1)
    end)
  end
end
```

**Séquençage des Coups de Jeu** :
- Chaque jeu a un GenServer dédié (traitement séquentiel)
- Les coups sont mis en file et traités dans l'ordre
- Les coups dupliqués sont détectés et rejetés (même joueur, même tour)
- La validation du coup se produit AVANT la mutation d'état

**Isolation des Transactions de Base de Données** :
- Opérations financières : niveau d'isolation `SERIALIZABLE`
- État de jeu : `READ COMMITTED` (suffisant pour la logique de jeu)
- Analytique/événements : `READ UNCOMMITTED` (performance sur précision)

**Prévention des Interblocages** :
- Toujours verrouiller les ressources dans un ordre cohérent (user_id ASC, puis room_id ASC)
- Timeout après 5 secondes, retry avec backoff exponentiel (3 tentatives)
- Monitorer le taux d'interblocage dans le dashboard d'observabilité

### 21. Contrôles de Sécurité Avancés

**Validation & Assainissement des Inputs** :
```elixir
# Validation stricte du montant monétaire :
defmodule GameHub.Validators do
  def validate_bet_amount(amount) do
    cond do
      not is_integer(amount) -> {:error, "Le montant doit être un entier"}
      amount <= 0 -> {:error, "Le montant doit être positif"}
      amount > 1_000_000_000 -> {:error, "Le montant dépasse la mise maximale"}
      true -> :ok
    end
  end
  
  def validate_phone(phone) do
    case Regex.match?(~r/^\+237[67][0-9]{8}$/, phone) do
      true -> :ok
      false -> {:error, "Numéro de téléphone camerounais invalide"}
    end
  end
  
  def sanitize_chat_message(message) do
    message
    |> String.replace(~r/<[^>]*>/, "")  # Supprimer HTML
    |> String.slice(0, 500)  # Longueur max
    |> HtmlSanitizeEx.basic_html()  # Assainir le reste
  end
end
```

**Enforcement d'Autorisation** :
```elixir
# Chaque endpoint doit vérifier la propriété de la ressource :
defmodule GameHub.Authorization do
  def can_access_transaction?(user_id, transaction_id) do
    transaction = Repo.get(Transaction, transaction_id)
    transaction.user_id == user_id
  end
  
  def can_access_room?(user_id, room_id) do
    room = Repo.get(Room, room_id)
    room.creator_id == user_id or 
    Repo.exists?(from p in RoomPlayer,
      where: p.room_id == ^room_id and p.user_id == ^user_id)
  end
  
  def require_admin(conn, _opts) do
    if conn.assigns.current_user.role != :admin do
      conn |> send_resp(403, "Interdit") |> halt()
    else
      conn
    end
  end
end
```

**Mesures Anti-Fraude** :
- **Empreinte digitale de device** : Hash(device_info + IP + navigateur) → détecter multi-comptes
- **Contrôles de vélocité IP** : Max 3 inscriptions de compte par IP par 24h
- **KYC avant les récompenses de parrainage** : Prévenir l'agriculture de faux comptes
- **Liste blanche de retrait** : L'utilisateur doit mettre en liste blanche le numéro de téléphone 48h avant le retrait
- **Analyse de pattern de pari** : Signaler les comptes avec >95% de taux de victoire sur 50+ jeux
- **Détection de collusion** : Même IP jouant dans la même salle = auto-signalement
- **Abus de parrainage** : Max 10 parrainages par device, KYC requis pour >5 parrainages

**En-têtes de Sécurité** (toutes les réponses HTTP) :
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

**Sécurité JWT** :
- Algorithme : HMAC-SHA256 uniquement (pas de RSA, pas d'algorithme "none")
- Expiration : Token d'accès 15min, Token de rafraîchissement 7 jours
- Rotation : Nouveau token de rafraîchissement émis à chaque rafraîchissement (prévenir le replay)
- Révocation : Liste noire stockée dans Redis (déconnexion, changement de mot de passe)
- Claims : user_id, role, device_fingerprint, iat, exp

**Épinglage de Certificat** (mobile) :
- Intégrer le hash du certificat de l'API Campay dans l'app Flutter
- Rejeter les connexions avec des certificats non correspondants
- Prévient les attaques MITM sur les webhooks de paiement

### 22. Excellence UX & Accessibilité

**Hors Ligne & Récupération** :
- Mettre en cache la balance du portefeuille localement (chiffré avec FlutterSecureStorage)
- Mettre en file les actions quand hors ligne (pari, message de chat), synchroniser à la reconnexion
- Auto-reprendre les jeux interrompus au redémarrage de l'app (charger le dernier état depuis le serveur)
- Afficher l'horodatage "dernière synchronisation" dans l'écran de portefeuille
- Badge d'indicateur hors ligne (point rouge quand déconnecté)

**UX de Gestion d'Erreurs** :
```dart
// Paiement échoué : erreur claire et actionnable
if (depositFailed) {
  showDialog(
    title: "Dépôt échoué",
    message: "Votre dépôt de 5 000 FCFA n'a pas abouti. Vérifiez votre téléphone et réessayez.",
    actions: [
      PrimaryButton("Réessayer", onPressed: retryDeposit),
      SecondaryButton("Changer de méthode", onPressed: showAlternativeMethods),
      TextButton("Contacter support", onPressed: openSupportTicket)
    ]
  );
}

// Erreur serveur : amicale, non technique
if (serverError) {
  showSnackBar(
    "Oups ! Quelque chose s'est mal passé. Nous avons été notifiés et travaillons à résoudre le problème.",
    action: SnackBarAction("Réessayer", onPressed: retry)
  );
}

// Erreurs de validation : inline, au niveau du champ
if (validationError) {
  TextFormField(
    errorText: "Le montant doit être entre 100 et 1 000 000 FCFA",
    helperText: "Exemple : 5000"
  );
}
```

**Parcours d'Intégration** :
1. **Écran de bienvenue** (proposition de valeur, 3 slides)
2. **Inscription par téléphone** (OTP, <30 secondes)
3. **Tutoriel interactif** :
   - Étape 1 : "Déposez 1 000 FCFA" (parcours de dépôt guidé)
   - Étape 2 : "Rejoignez une partie" (démo de matchmaking)
   - Étape 3 : "Placez votre première mise" (jeu simulé)
   - Étape 4 : "Gagnez !" (célébration, explication des gains)
4. **Mode démo** : Jouer les 3 premiers jeux avec de l'argent virtuel (aucun dépôt requis)
5. **Divulgation progressive** : Débloquer les fonctionnalités progressivement (tournois après 5 jeux joués)

**Fonctionnalités UX de Jeu** :
- **Minuteur de coup** : Compte à rebours visuel (barre de progression circulaire, changement de couleurs vert→jaune→rouge)
- **Annuler le coup** : Autorisé dans les 3 secondes (avant que l'adversaire ne voie le coup)
- **Offre de match nul** : Bouton (l'adversaire accepte/décline, les mises sont partagées si accepté)
- **Abandonner** : Bouton avec dialogue de confirmation (forfait, mise perdue)
- **Mode spectateur** : Regarder les jeux des amis (délai de 30 secondes pour prévenir la triche)
- **Effets sonores** : Activer/désactiver, contrôle du volume, différents sons pour victoire/défaite/coup
- **Retour haptique** : Mobile uniquement (vibrer en cas de victoire, défaite, votre tour)
- **Historique de jeu** : 50 derniers jeux avec bouton de replay (voir les coups chronologiquement)
- **Statistiques** : Taux de victoire, durée moyenne de jeu, meilleure série

**Accessibilité (WCAG 2.1 AA)** :
- Étiquettes de lecteur d'écran sur tous les éléments interactifs (`Semantics(label: ...)`)
- Ratio de contraste de couleur ≥ 4,5:1 (testé avec axe DevTools)
- Cibles tactiles ≥ 44x44 pixels (Flutter `kMinInteractiveDimension`)
- Navigation au clavier (web) : Tab, Entrée, Échap, touches fléchées
- Option de mouvement réduit (désactiver les animations pour les utilisateurs avec des troubles vestibulaires)
- Palette de couleurs adaptée au daltonisme : Ne pas reposer uniquement sur la distinction rouge/vert
- Mise à l'échelle de la taille de police : Support de la taille de police du système (jusqu'à 200%)
- Indicateurs de focus : Anneaux de focus visibles sur le web (outline : 2px solid blue)

**Confiance & Transparence** :
- Commission affichée AVANT la confirmation du pari ("Mise : 1000 FCFA, Commission : 50 FCFA, Gain potentiel : 950 FCFA")
- Probabilité de victoire affichée dans les brackets de tournoi (basée sur le rating ELO)
- Historique des transactions exportable en CSV (avec filtre de plage de dates)
- Badge de certification de jeu loyal visible en pied de page ("Certifié par MINFI, Licence #XXX")
- Processus de litige clairement expliqué dans les règles de jeu ("Comment signaler un problème")
- Résumé des limites de jeu responsable dans le profil ("Vous avez déposé 50 000/100 000 FCFA ce mois-ci")

### 23. Excellence DevOps & Opérations

**Gestion des Secrets** :
```yaml
# JAMAIS stocker les secrets dans le code ou les fichiers .env
# Utiliser les secrets Fly.io (chiffrés au repos) :
flyctl secrets set CAMPAY_API_KEY=sk_live_xxx
flyctl secrets set JWT_SECRET=votre-secret-256-bit
flyctl secrets set DATABASE_URL=postgres://xxx

# Rotation des clés API de paiement tous les 90 jours :
# 1. Générer une nouvelle clé dans le dashboard Campay
# 2. `flyctl secrets set CAMPAY_API_KEY=new_key`
# 3. Monitorer pendant 24h (l'ancienne clé reste active pendant la transition)
# 4. Révoquer l'ancienne clé dans le dashboard Campay

# Clés de chiffrement : HashiCorp Vault ou AWS KMS
# - Clé de chiffrement de portefeuille (AES-256-GCM)
# - Clé de chiffrement PII (pour les documents KYC)
# - Clé de chiffrement de sauvegarde (pour les sauvegardes DB)
```

**Stratégie de Migration de Base de Données** :
```elixir
# TOUTES les migrations DOIVENT avoir des scripts UP et DOWN :
defmodule GameHub.Repo.Migrations.AddUserBalance do
  def up do
    alter table(:user_wallets) do
      add :balance, :bigint, default: 0
    end
  end
  
  def down do
    alter table(:user_wallets) do
      remove :balance
    end
  end
end

# Bonnes pratiques de migration :
# - Tester les migrations en staging AVANT la production
# - Utiliser `mix ecto.dump` pour les snapshots de schéma après chaque migration
# - Migrations de longue durée : opérations par lot (1000 lignes par transaction)
# - Compatible vers l'arrière : déployer le code → migrer → supprimer l'ancien code au prochain déploiement
# - JAMAIS supprimer des colonnes dans le même déploiement que le code qui les lit
```

**Déploiement sans Interruption de Service** :
```yaml
# Stratégie de déploiement blue-green :
# 1. Déployer la nouvelle version vers les instances "green" (fly deploy --ha)
# 2. Exécuter les checks de santé sur green (HTTP 200 sur /health)
# 3. Basculer le trafic de "blue" vers "green" (automatique avec Fly.io)
# 4. Monitorer pendant 10 minutes (taux d'erreur, latence)
# 5. En cas de problèmes : rollback vers "blue" (fly rollback)
# 6. Si stable : terminer les instances "blue"

# Compatibilité de base de données :
# - Changements additifs uniquement (nouvelles colonnes, nouvelles tables)
# - Déployer le code qui gère l'ANCIEN et le NOUVEAU schéma
# - Exécuter la migration
# - Déployer le code qui utilise uniquement le nouveau schéma (prochaine version)

# Feature flags pour déploiement progressif :
# - Nouvelle fonctionnalité désactivée par défaut
# - Activer pour 10% des utilisateurs (percentage_rollout)
# - Monitorer les métriques (taux d'erreur, engagement)
# - Augmenter progressivement à 50% → 100%
# - En cas de problèmes : désactiver le flag (rollback instantané)
```

**Réponse aux Incidents** :
```
Rotation d'astreinte : Hebdomadaire (équipe d'ingénieurs)

Runbooks pour les incidents courants :

1. Échecs de webhook de paiement :
   - Vérifier la page de statut Campay (status.campay.net)
   - Vérifier la validité de la clé API
   - Vérifier les logs de l'endpoint webhook (Sentry)
   - Traiter manuellement les webhooks en attente de la file
   - Si provider en panne : activer le provider de fallback

2. Épuisement des connexions de base de données :
   - Vérifier l'utilisation du pool de connexions (dashboard Grafana)
   - Identifier les requêtes de longue durée (pg_stat_activity)
   - Tuer les requêtes bloquées (pg_terminate_backend)
   - Mettre à l'échelle la base de données (augmenter max_connections)
   - Alerter si >80% de capacité pendant >5 minutes

3. Mémoire Redis pleine :
   - Vérifier l'utilisation de la mémoire (INFO memory)
   - Expulser les anciennes sessions (politique volatile-lru)
   - Effacer les files de matchmaking obsolètes
   - Mettre à l'échelle Redis (augmenter maxmemory)
   - Alerter si >90% de capacité

4. Non-concordance de réconciliation de portefeuille :
   - Pause de tous les retraits (prévenir d'autres incohérences)
   - Exécuter le script de réconciliation manuelle
   - Identifier les transactions affectées
   - Contacter le fournisseur de paiement pour clarification
   - Ajuster les balances (avec approbation admin + log d'audit)
   - Reprendre les retraits après résolution

5. Détection de pic de fraude :
   - Auto-suspendre les comptes avec >10 signaux de fraude en 1 heure
   - Activer CAPTCHA sur l'inscription
   - Augmenter les exigences KYC (obligatoire pour tous les retraits)
   - Alerter l'équipe de conformité
   - Réviser les règles de fraude (ajuster les seuils si nécessaire)

Revue post-incident : Dans les 48 heures (sans blâme)
- Que s'est-il passé ?
- Quel était l'impact ?
- Quelle était la cause racine ?
- Qu'est-ce qui a bien fonctionné ?
- Qu'est-ce qui pourrait être amélioré ?
- Éléments d'action (avec responsables et échéances)
```

**Règles d'Auto-Scaling** :
```yaml
# Configuration de scaling Fly.io :
# Minimum : 2 instances (haute disponibilité)
# Maximum : 5 instances (contrôle des coûts)

scaling:
  min_instances: 2
  max_instances: 5
  
  cpu_threshold: 70%  # Scale up si CPU > 70% pendant 5 minutes
  memory_threshold: 80%  # Scale up si mémoire > 80% pendant 5 minutes
  
  # Connexions WebSocket par nœud :
  # Alerte à 8 000 connexions
  # Scale up à 9 000 connexions
  
  # Pool de connexions de base de données :
  # Alerte à 80% de capacité
  # Scale up de la base de données à 90% de capacité
  
  # Auto-scale down pendant le trafic faible (2h-6h) :
  # Réduire à min_instances (2) pour économiser les coûts
```

**Tests de Reprise après Sinistre** :
```
Fréquence : Trimestrielle (tous les 3 mois)

Scénarios de test :

1. Restauration complète de la base de données depuis PITR :
   - Créer un environnement de test isolé
   - Restaurer la base de données à un point il y a 24 heures
   - Vérifier l'intégrité des données (nombre de lignes, checksums)
   - Tester les flux critiques (connexion, dépôt, jouer, retrait)
   - Documenter le RTO (Recovery Time Objective) : Objectif < 1 heure
   - Documenter le RPO (Recovery Point Objective) : Objectif < 15 minutes

2. Basculement Redis :
   - Simuler la défaillance du primaire Redis
   - Vérifier le basculement automatique vers le réplica
   - Vérifier la perte de données (devrait être < 1 seconde de commandes)
   - Vérifier que les sessions sont toujours valides

3. Défaillance de région :
   - Simuler la région Fly.io Johannesbourg en panne
   - Vérifier que le trafic bascule vers la région Paris
   - Vérifier la synchronisation des read replicas de la base de données
   - Tester l'expérience utilisateur (augmentation de latence acceptable ?)

4. Validation de sauvegarde :
   - Restaurer la dernière sauvegarde dans un environnement isolé
   - Vérifier que toutes les tables sont présentes et peuplées
   - Tester la récupération point-in-time (restaurer à un horodatage spécifique)
   - Vérifier que les clés de chiffrement fonctionnent

Documentation : Mettre à jour le runbook après chaque test
- Qu'est-ce qui a fonctionné ?
- Qu'est-ce qui a échoué ?
- Qu'est-ce qui doit être amélioré ?
- Mettre à jour les métriques RTO/RPO
```

### 24. Documents Légaux & Conformité Contractuelle

**Pages Légales Obligatoires** (gérées via CMS, mais légalement requises) :

1. **Conditions Générales d'Utilisation (CGU)** - Français & Anglais
   - Obligations de l'utilisateur (âge >= 18, compte unique, jeu loyal)
   - Responsabilités de la plateforme (disponibilité des jeux, délais de paiement)
   - Structure des commissions (détail transparent)
   - Processus de résolution de litiges
   - Limitation de responsabilité
   - Conditions de résiliation
   - Droit applicable (Cameroun)

2. **Politique de Confidentialité** (conforme RGPD + loi camerounaise sur la protection des données)
   - Données collectées (personnelles, financières, comportementales)
   - Finalité de la collecte (fourniture de service, conformité, analytique)
   - Durées de rétention des données (10 ans pour transactions, 2 ans pour chat)
   - Droits des utilisateurs (accès, rectification, suppression, portabilité)
   - Partage de données (fournisseurs de paiement, régulateurs)
   - Politique de cookies (web uniquement)
   - Contacter le DPO (Délégué à la Protection des Données)

3. **Règles de Jeu** (par jeu, publiées AVANT la première partie)
   - Comment jouer (tutoriel)
   - Conditions de victoire
   - Règles de tiebreaker
   - Politique de timeout/déconnexion
   - Commission appliquée
   - Processus de litige

4. **Conditions de Tournoi**
   - Critères d'éligibilité (KYC requis ? rating minimum ?)
   - Distribution des prix (pourcentages exacts)
   - Planning et échéances
   - Politique d'annulation (que faire si pas assez de joueurs ?)
   - Conditions de disqualification (triche, comportement toxique)
   - Implications fiscales (gains > 1 000 000 XAF)

5. **Politique de Jeu Responsable**
   - Limites disponibles (dépôt, perte, temps, auto-exclusion)
   - Comment définir/modifier les limites
   - Signes avant-coureurs du jeu problématique
   - Ressources d'auto-assistance (liens vers des organisations de soutien)
   - Comment demander la fermeture de compte
   - Explication de la période de réflexion

6. **Politique de Remboursement**
   - Quand les remboursements sont émis (erreurs techniques, crashes de jeu)
   - Délai de remboursement (24-72 heures)
   - Méthode de remboursement (vers la méthode de paiement d'origine)
   - Scénarios non remboursables (paris perdus, abandon volontaire)
   - Processus de litige pour les demandes de remboursement

7. **Accord d'Affiliation**
   - Structure de commission (5%/7%/10% par tier)
   - Conditions de paiement (mensuel, via Mobile Money)
   - Éligibilité (KYC requis, pas d'auto-parrainage)
   - Pratiques interdites (spam, faux comptes, publicité trompeuse)
   - Conditions de résiliation
   - Obligations fiscales (l'affilié responsable de déclarer les revenus)

8. **Politique de Cookies** (web uniquement)
   - Types de cookies (essentiels, analytiques, marketing)
   - Finalité de chaque cookie
   - Comment gérer les préférences
   - Cookies tiers (Firebase, Sentry, PostHog)

**Requis d'Affichage Légal** (licence MINFI) :
- Numéro de licence de jeu en pied de page (toujours visible sur toutes les pages)
- Lien vers le site officiel du MINFI (pour vérification de licence)
- Popup de vérification d'âge à la première visite (doit confirmer >= 18 avant de naviguer)
- Badge "18+" affiché de manière proéminente
- Avertissement de jeu responsable sur les écrans de jeu ("Jouer comporte des risques : endettement, isolement, etc.")
- Date d'expiration de la licence visible

**Contrôle de Version pour les Documents Légaux** :
```elixir
Table: legal_document_versions
├── document_type (cgu/privacy/game_rules/etc)
├── version (sémantique, ex: "2.1.0")
├── content_en, content_fr
├── effective_from (date), effective_to (nullable)
├── change_summary (ce qui a changé par rapport à la version précédente)
├── requires_reacceptance (bool, true pour les changements majeurs)
├── created_by (admin_id), approved_by (legal_team_id)
└── created_at

# Suivi de l'acceptation par l'utilisateur :
Table: user_legal_acceptances
├── user_id, document_type, document_version
├── accepted_at, ip_address, user_agent
└── acceptance_method (checkbox/scroll_to_bottom)

# Avant le premier dépôt, l'utilisateur doit accepter :
# - CGU (version actuelle)
# - Politique de Confidentialité
# - Politique de Jeu Responsable
# - Règles de Jeu (pour chaque jeu qu'il joue)
```

**Processus de Plainte & d'Appel** :
1. L'utilisateur soumet une plainte via un ticket de support (réponse sous 24h)
2. Révision interne par l'équipe de support (résolution sous 72h)
3. Si insatisfait : escalade vers l'équipe de conformité (réponse sous 7 jours)
4. Si toujours insatisfait : l'utilisateur peut déposer une plainte auprès du MINFI (contact fourni)
5. Toutes les plaintes sont journalisées avec horodatages et résolutions (traçabilité d'audit)

---

## Principes Clés

1. **Sécurité d'Abord** : Chaque opération financière est ACID, auditée et réconciliée
2. **Conformité par Conception** : Requis légaux (KYC, AML, jeu responsable) intégrés dès le jour 1
3. **Extensibilité** : L'architecture plugin permet d'ajouter des jeux sans modifications du hub
4. **Observabilité** : Tout est journalisé, mesuré et alertable
5. **Configurabilité** : Les règles métier (commissions, timeouts, limites, fonctionnalités) sont en base, pas dans le code
6. **Résilience** : Récupération après crash, sauvegardes, déploiement multi-région, kill switch de feature flags
7. **Performance** : Latence sous-100ms, 10K+ joueurs concurrents, 60 FPS mobile
8. **Centré sur l'Utilisateur** : Protections de jeu responsable, matchmaking équitable, commissions transparentes
9. **Piloté par les Données** : Analytique suivant tous les parcours utilisateur, tests A/B pour l'optimisation
10. **Expérience Développeur** : Architecture propre, tests complets, CI/CD, hot reload

---

**Commencer la Phase 1 maintenant. Livrer de manière incrémentale avec un logiciel fonctionnel à la fin de chaque phase. Suivre les meilleures pratiques Elixir/Phoenix et Flutter. Prioriser la sécurité et l'intégrité des données par-dessus tout.**
