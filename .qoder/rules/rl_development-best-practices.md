# Règles de Développement WIWIGA

## Règle 1: Architecture OTP Plugins
**Quand**: Créer un nouveau jeu ou module isolé  
**Règle**: Chaque jeu DOIT être une application OTP séparée implémentant `GameHub.GamePlugin`

```elixir
defmodule GameHub.Games.DiceGame do
  @behaviour GameHub.GamePlugin
  
  @impl true
  def start_game(players, settings) do
    # Validation initiale
    # Création état de jeu
    # Retourner {:ok, game_state}
  end
  
  @impl true
  def handle_move(game_state, move, player_id) do
    # Validation coup
    # Mise à jour état
    # Broadcast si nécessaire
  end
end
```

**Checklist**:
- [ ] Module dans `apps/dice_game/` (répertoire séparé)
- [ ] Implémente `@behaviour GameHub.GamePlugin`
- [ ] Configuration dans `config/config.exs`
- [ ] Tests d'isolation (crash jeu ≠ crash hub)
- [ ] Enregistré dans `config :game_hub, :games, [GameHub.Games.DiceGame]`

---

## Règle 2: Transactions Financières ACID
**Quand**: Toute opération de portefeuille (dépôt, retrait, mise, gain)  
**Règle**: TOUJOURS utiliser `Repo.transaction` avec verrouillage pessimiste

```elixir
defmodule GameHub.Wallet do
  def place_bet(user_id, amount, idempotency_key) do
    Repo.transaction(fn ->
      wallet = Repo.one!(from w in UserWallet,
        where: w.user_id == ^user_id,
        lock: "FOR UPDATE")
      
      if wallet.balance < amount do
        Repo.rollback(:insufficient_funds)
      end
      
      # Vérifier idempotence
      case IdempotencyKey.get(idempotency_key) do
        nil ->
          new_wallet = update_wallet_balance(wallet, -amount)
          create_transaction(:bet, amount, new_wallet)
          IdempotencyKey.store(idempotency_key, new_wallet)
          new_wallet
        
        existing -> existing
      end
    end)
  end
end
```

**Obligations**:
- ✅ Verrouillage `FOR UPDATE` sur wallet
- ✅ Clé d'idempotence pour webhooks
- ✅ Rollback explicite en cas d'erreur
- ✅ Transaction dans `balance_before` et `balance_after`
- ✅ Log d'audit créé
- ❌ JAMAIS de modification de balance sans transaction
- ❌ JAMAIS de confiance dans le client pour les montants

---

## Règle 3: Génération Aléatoire Sécurisée
**Quand**: Jeux de hasard (dés, cartes, etc.)  
**Règle**: Génération ALÉATOIRE CÔTÉ SERVEUR UNIQUEMENT avec `:crypto.strong_rand_bytes/1`

```elixir
defmodule GameHub.Games.DiceGame do
  def roll_dice(number_of_dice, dice_type \\ 6) do
    # Utiliser crypto strong random, PAS :rand.uniform
    number_of_dice
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> rem(byte, dice_type) + 1 end)
  end
end
```

**Interdictions absolues**:
- ❌ `:rand.uniform` côté serveur
- ❌ `Random` côté client Flutter
- ❌ Seeds basés sur timestamp
- ❌ Logique de détermination du gagnant côté client

**Traçabilité obligatoire**:
- Stocker TOUS les résultats dans `dice_game_results`
- Horodatage précis de chaque lancé
- Conservation 10 ans pour audit

---

## Règle 4: Matchmaking Atomique avec Redis
**Quand**: Créer/rejoindre salles, files d'attente  
**Règle**: Utiliser Redis SETNX pour éviter les conditions de course

```elixir
defmodule GameHub.Matchmaking do
  def join_queue(queue_id, player_id, stake_amount) do
    case Redix.command(redis, ["SETNX", "queue:#{queue_id}:player:#{player_id}", "1"]) do
      {:ok, 1} ->
        # Verrouillé avec succès
        find_and_match_opponent(queue_id, player_id, stake_amount)
      
      {:ok, 0} ->
        {:error, :already_in_queue}
    end
  end
end
```

**Règles**:
- ✅ SETNX pour verrouillage atomique
- ✅ TTL sur clés Redis (expiration automatique)
- ✅ Nettoyage des files abandonnées
- ✅ Contraintes DB `CHECK (current_players <= max_players)`
- ❌ JAMAIS de check-then-act sans verrou

---

## Règle 5: Validation & Sanitisation des Inputs
**Quand**: Recevoir des données du client  
**Règle**: TOUJOURS valider ET sanitiser AVANT traitement

```elixir
defmodule GameHub.Validators do
  def validate_bet_amount(amount) do
    cond do
      not is_integer(amount) -> {:error, "Montant doit être entier"}
      amount <= 0 -> {:error, "Montant doit être positif"}
      amount > 1_000_000_000 -> {:error, "Excède mise maximale"}
      true -> :ok
    end
  end
  
  def validate_phone("+237" <> rest) when byte_size(rest) == 9 do
    case Regex.match?(~r/^[67][0-9]{8}$/, rest) do
      true -> :ok
      false -> {:error, "Numéro invalide"}
    end
  end
  
  def sanitize_chat_message(message) do
    message
    |> String.replace(~r/<[^>]*>/, "")  # Strip HTML
    |> String.slice(0, 500)  # Max length
    |> HtmlSanitizeEx.basic_html()
  end
end
```

**Validation obligatoire pour**:
- ✅ Montants financiers (entiers, limites)
- ✅ Numéros de téléphone (format camerounais)
- ✅ Messages de chat (XSS prevention)
- ✅ IDs de ressource (injection SQL)
- ✅ URLs de documents KYC (path traversal)

---

## Règle 6: Authorisation Backend Enforcement
**Quand**: Accès aux ressources protégées  
**Règle**: TOUJOURS vérifier la propriété côté backend

```elixir
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
end
```

**Obligations**:
- ✅ Vérification propriété dans CHAQUE endpoint
- ✅ Middleware `require_admin` pour routes admin
- ✅ Vérification KYC tier avant retraits élevés
- ✅ Double vérification (frontend + backend)
- ❌ JAMAIS faire confiance au `user_id` du client

---

## Règle 7: Commission Configurée par Jeu
**Quand**: Calculer les gains d'un jeu  
**Règle**: Récupérer config commission depuis DB, JAMAIS hardcoded

```elixir
defmodule GameHub.Commission do
  def calculate_pot(stake_amount, game_id, player_count) do
    config = Repo.get_by(GameCommission, game_id: game_id, active: true)
    
    case config.commission_type do
      "A" -> # % sur mise
        commission = Decimal.mult(stake_amount, config.commission_value)
        gross_pot = Decimal.sub(stake_amount, commission)
        Decimal.mult(gross_pot, player_count)
      
      "B" -> # % sur gains
        gross_pot = Decimal.mult(stake_amount, player_count)
        # Commission appliquée au gagnant seulement
      
      "C" -> # Fixe
        commission = config.commission_value
        gross_pot = Decimal.sub(stake_amount, commission)
        Decimal.mult(gross_pot, player_count)
      
      "D" -> # Progressif
        rate = get_progressive_rate(stake_amount, config)
        commission = Decimal.mult(stake_amount, rate)
        gross_pot = Decimal.sub(stake_amount, commission)
        Decimal.mult(gross_pot, player_count)
    end
  end
end
```

**Règles**:
- ✅ Config depuis `game_commissions` table
- ✅ Support modes A/B/C/D
- ✅ `effective_from` pour changements futurs
- ✅ Affichage commission AVANT confirmation pari
- ❌ JAMAIS de taux en dur dans le code

---

## Règle 8: Gestion Déconnexion & Timeout
**Quand**: Joueur perd connexion pendant partie  
**Règle**: Appliquer politique configurée dans `game_timeout_config`

```elixir
defmodule GameHub.GameTimeout do
  def handle_disconnect(player_id, game_id) do
    config = Repo.get_by(GameTimeoutConfig, game_id: game_id)
    
    Process.send_after(self(), :timeout_check, config.grace_period_seconds * 1000)
    
    receive do
      :player_reconnected -> cancel_timeout(player_id)
      :timeout_check -> apply_forfeit(player_id, config)
    end
  end
  
  defp apply_forfeit(player_id, %{action_on_timeout: "forfeit"}) do
    # Redistribuer mise selon config
    # Mettre à jour état jeu
    # Notifier adversaire
  end
end
```

**Configuration DB**:
- `grace_period_seconds`: Délai avant action (défaut 120s)
- `action_on_timeout`: "forfait" | "refund" | "pause"
- `forfeit_distribution`: "vers_gagnant" | "divisé" | "pool"

---

## Règle 9: Logs d'Audit Obligatoires
**Quand**: Actions admin, opérations financières, changements sécurité  
**Règle**: TOUJOURS logger avec `AuditLog` struct

```elixir
defmodule GameHub.AuditLog do
  def log_admin_action(admin_id, action, entity_type, entity_id, changes, conn) do
    %AuditLog{
      admin_id: admin_id,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      changes: changes,
      ip_address: conn.remote_ip,
      created_at: NaiveDateTime.utc_now()
    }
    |> Repo.insert!()
  end
end
```

**Obligations de logging**:
- ✅ Toute action admin (ajustement balance, validation KYC)
- ✅ Transactions financières (dépôt, retrait, mise, gain)
- ✅ Changements de sécurité (2FA, mot de passe, déconnexion)
- ✅ Signaux de fraude détectés
- ✅ Format JSON structuré pour Loki
- ✅ Rétention 10 ans minimum

---

## Règle 10: Feature Flags pour Déploiement Progressif
**Quand**: Nouvelle fonctionnalité ou changement risqué  
**Règle**: Utiliser `feature_flags` table, JAMAIS de déploiement brutal

```elixir
defmodule GameHub.FeatureFlags do
  def enabled?(flag_name, user_id \\ nil) do
    flag = Repo.get_by(FeatureFlag, flag_name: flag_name)
    
    cond do
      flag == nil -> false
      user_id in (flag.user_ids_whitelist || []) -> true
      user_id in (flag.user_ids_blacklist || []) -> false
      flag.enabled == false -> false
      flag.percentage_rollout == 100 -> true
      flag.percentage_rollout == 0 -> false
      true -> rem(:crypto.strong_rand_bytes(1) |> :binary.decode_unsigned(), 100) < flag.percentage_rollout
    end
  end
end
```

**Utilisation**:
```elixir
if FeatureFlags.enabled?("new_dice_animation", user.id) do
  render_new_animation()
else
  render_old_animation()
end
```

**Stratégie de rollout**:
1. Désactivé par défaut (`enabled: false`)
2. Activer pour 10% (`percentage_rollout: 10`)
3. Monitorer métriques (erreurs, performance)
4. Augmenter à 50% → 100%
5. Kill switch instantané en cas de problème

---

## Règle 11: Réconciliation Portefeuille Automatisée
**Quand**: Job cron horaire  
**Règle**: Vérifier `balance = SUM(transactions)` pour chaque utilisateur

```elixir
defmodule GameHub.WalletReconciliation do
  def run do
    mismatched_users = Repo.all("""
      SELECT u.id, u.balance, SUM(t.amount) as calculated_balance
      FROM users u
      LEFT JOIN transactions t ON t.user_id = u.id
      GROUP BY u.id
      HAVING u.balance != SUM(t.amount)
    """)
    
    if length(mismatched_users) > 0 do
      # Alerte admin
      # Pause retraits affectés
      # Investigation requise
      AlertSystem.notify_admins(:wallet_mismatch, mismatched_users)
    end
  end
end
```

**Fréquence**: Toutes les heures  
**Action si incohérence**:
1. Pause automatique des retraits
2. Alerte dashboard admin
3. Investigation manuelle requise
4. Ajustement avec log d'audit
5. Reprise après résolution

---

## Règle 12: Migration DB Safe
**Quand**: Modifier schéma base de données  
**Règle**: TOUJOURS UP + DOWN scripts, compatible backward

```elixir
defmodule GameHub.Repo.Migrations.AddDiceGameConfig do
  def up do
    create table(:dice_game_config, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :game_id, references(:games, on_delete: :delete_all)
      add :number_of_dice, :integer, default: 1
      add :number_of_rolls, :integer, default: 1
      add :scoring_method, :string, default: "single_roll"
      add :tie_handling, :string, default: "reroll"
      add :active, :boolean, default: true
      timestamps()
    end
    
    create index(:dice_game_config, [:game_id])
  end
  
  def down do
    drop table(:dice_game_config)
  end
end
```

**Bonnes pratiques**:
- ✅ Tester migration en staging d'abord
- ✅ `mix ecto.dump` après chaque migration
- ✅ Opérations par lots si >1000 lignes
- ✅ Déployer code → migrer → cleanup (3 déploiements)
- ❌ JAMAIS supprimer colonnes dans même déploiement
- ❌ JAMAIS de migrations irréversibles

---

## Règle 13: WebSocket Events Structurés
**Quand**: Communication temps réel jeu  
**Règle**: Événements standardisés avec validation

```elixir
defmodule GameHub.GameSocket do
  def handle_in("place_bet", %{"amount" => amount, "idempotency_key" => key}, socket) do
    case Wallet.place_bet(socket.assigns.user_id, amount, key) do
      {:ok, new_state} ->
        broadcast(socket, "bet_placed", %{
          player_id: socket.assigns.user_id,
          amount: amount,
          timestamp: DateTime.utc_now()
        })
        {:reply, {:ok, new_state}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{message: reason}}, socket}
    end
  end
end
```

**Format événements**:
```
player_joined: {player_id, timestamp}
bet_placed: {player_id, amount, timestamp}
game_state_update: {state_snapshot, last_action}
game_ended: {winner_id, pot_amount, commission, timestamp}
player_left: {player_id, reason, timestamp}
```

---

## Règle 14: Flutter State Management Riverpod
**Quand**: Gestion d'état frontend  
**Règle**: Utiliser Riverpod avec providers immutables

```dart
// Provider wallet
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(WalletState.initial());
  
  Future<void> deposit(int amount) async {
    state = state.copyWith(isLoading: true);
    
    try {
      final result = await walletRepository.initiateDeposit(amount);
      state = state.copyWith(
        balance: result.newBalance,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}

// Utilisation dans widget
class WalletScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    
    return Text('${wallet.balance} FCFA');
  }
}
```

**Bonnes pratiques Flutter**:
- ✅ Providers immutables (`StateNotifier`)
- ✅ Error states gérés dans chaque provider
- ✅ Loading states pour UX réactive
- ✅ Repository pattern pour isolation données
- ❌ JAMAIS de `setState` global pour état partagé
- ❌ JAMAIS de logique métier dans widgets

---

## Règle 15: Sécurité En-têtes HTTP
**Quand**: Configuration Phoenix  
**Règle**: TOUJOURS inclure en-têtes de sécurité

```elixir
defmodule GameHubWeb.SecurityHeaders do
  def call(conn, _opts) do
    conn
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", "default-src 'self'; script-src 'self'")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end
```

**En-têtes obligatoires**:
- ✅ `Strict-Transport-Security`
- ✅ `Content-Security-Policy`
- ✅ `X-Frame-Options: DENY`
- ✅ `X-Content-Type-Options: nosniff`
- ✅ `X-XSS-Protection: 1; mode=block`
- ✅ `Referrer-Policy`
- ✅ `Permissions-Policy`

---

## Règle 16: Tests Backend Obligatoires
**Quand**: Écrire nouvelle fonctionnalité  
**Règle**: Tests unitaires + intégration pour chaque module

```elixir
defmodule GameHub.WalletTest do
  use GameHub.DataCase
  
  describe "place_bet/3" do
    test "deducts amount from wallet balance" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 10_000)
      
      assert {:ok, wallet} = Wallet.place_bet(user.id, 1_000, "unique_key")
      assert wallet.balance == 9_000
    end
    
    test "returns error for insufficient funds" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 500)
      
      assert {:error, :insufficient_funds} = Wallet.place_bet(user.id, 1_000, "key")
    end
    
    test "is idempotent with same key" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 10_000)
      
      {:ok, wallet1} = Wallet.place_bet(user.id, 1_000, "key_123")
      {:ok, wallet2} = Wallet.place_bet(user.id, 1_000, "key_123")
      
      assert wallet1.balance == wallet2.balance
    end
  end
end
```

**Exigences couverture**:
- ✅ >90% modules financiers
- ✅ 100% chemins critiques (auth, wallet, paiements)
- ✅ Tests de propriété avec StreamData (cas limites)
- ✅ Tests de charge avec k6 (10K+ joueurs)
- ✅ Tests chaos (crash DB, partition réseau)

---

## Règle 17: Documentation Inline Elixir
**Quand**: Écrire modules et fonctions publiques  
**Règle**: Docstrings obligatoires avec `@doc` et `@moduledoc`

```elixir
defmodule GameHub.Wallet do
  @moduledoc """
  Gestion du portefeuille utilisateur avec transactions ACID.
  
  Toutes les opérations financières passent par ce module pour garantir:
  - Atomicité des transactions
  - Verrouillage pessimiste pour éviter les conditions de course
  - Idempotence pour les webhooks de paiement
  - Traçabilité complète via logs d'audit
  """
  
  @doc """
  Place un pari en débitant le portefeuille de l'utilisateur.
  
  ## Parameters
    - `user_id`: ID de l'utilisateur (integer)
    - `amount`: Montant du pari en centimes XAF (integer)
    - `idempotency_key`: Clé unique pour idempotence (string)
  
  ## Returns
    - `{:ok, wallet}`: Pari placé avec succès
    - `{:error, :insufficient_funds}`: Balance insuffisante
    - `{:error, :duplicate_key}`: Clé d'idempotence déjà utilisée
  
  ## Examples
  
      iex> Wallet.place_bet(1, 1000, "unique_key_123")
      {:ok, %UserWallet{balance: 9000}}
      
      iex> Wallet.place_bet(1, 99999, "unique_key_456")
      {:error, :insufficient_funds}
  """
  def place_bet(user_id, amount, idempotency_key) do
    # Implementation
  end
end
```

**Obligations documentation**:
- ✅ `@moduledoc` sur TOUS les modules
- ✅ `@doc` sur TOUTES les fonctions publiques
- ✅ Examples dans docstrings
- ✅ Types avec `@spec`
- ✅ Documentation en français

---

## Règle 18: Gestion Erreurs Flutter UX
**Quand**: Afficher erreurs à l'utilisateur  
**Règle**: Messages clairs, actionnables, non techniques

```dart
void showDepositError(BuildContext context, String error) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Dépôt échoué'),
      content: Text(
        'Votre dépôt de 5 000 FCFA n\'a pas abouti. '
        'Vérifiez votre téléphone et réessayez.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.read<WalletProvider>().retryDeposit();
          },
          child: const Text('Réessayer'),
        ),
      ],
    ),
  );
}
```

**Principes UX erreurs**:
- ✅ Message en français clair
- ✅ Pas de stack trace technique
- ✅ Actions proposées (réessayer, contacter support)
- ✅ Ton empathique ("Oups !", "Nous travaillons à résoudre")
- ✅ Erreurs validation inline au niveau du champ
- ❌ JAMAIS de messages d'erreur techniques bruts

---

## Règle 19: Conformité Jeu Responsable
**Quand**: Implémenter limites, auto-exclusion  
**Règle**: Obligations légales MINFI non négociables

```elixir
defmodule GameHub.ResponsibleGaming do
  def check_before_bet(user_id, amount) do
    limits = Repo.get_by(ResponsibleGamingLimit, user_id: user_id)
    
    cond do
      limits.self_exclusion_until && limits.self_exclusion_until > DateTime.utc_now() ->
        {:error, :self_excluded}
      
      daily_spent(user_id) + amount > limits.daily_loss_limit ->
        {:error, :daily_limit_reached}
      
      current_session_time(user_id) > limits.session_time_limit_minutes * 60 ->
        {:error, :session_time_exceeded}
      
      true -> :ok
    end
  end
  
  def reality_check(user_id) do
    limits = Repo.get_by(ResponsibleGamingLimit, user_id: user_id)
    
    if limits.reality_check_interval_minutes do
      Process.send_after(self(), :reality_check, 
        limits.reality_check_interval_minutes * 60_000)
    end
  end
end
```

**Obligations légales**:
- ✅ Vérification âge >= 18 ans obligatoire
- ✅ Limites de dépôt configurables par utilisateur
- ✅ Limites de perte quotidiennes
- ✅ Limites de temps de session
- ✅ Auto-exclusion temporaire ou permanente
- ✅ Rappel de réalité toutes les 30min (configurable)
- ✅ Période de réflexion après perte >50% limite hebdo
- ✅ Ressources d'aide addiction visibles dans profil

---

## Règle 20: Déploiement Blue-Green
**Quand**: Mise en production  
**Règle**: TOUJOURS déploiement progressif avec rollback possible

**Processus**:
1. Déployer nouvelle version vers instances "green" (`fly deploy --ha`)
2. Exécuter health checks (HTTP 200 sur `/health`)
3. Basculer trafic blue → green (automatique Fly.io)
4. Monitorer 10 minutes (taux d'erreur, latence)
5. Si problèmes: rollback vers blue (`fly rollback`)
6. Si stable: terminer instances blue

**Compatibilité DB**:
1. Déployer code compatible ANCIEN + NOUVEAU schéma
2. Exécuter migration
3. Déployer code utilisant NOUVEAU schéma uniquement (prochain déploiement)

**Feature flags**:
- Nouvelle fonctionnalité désactivée par défaut
- Rollout progressif 10% → 50% → 100%
- Kill switch instantané en cas de problème

---

## Checklist Pré-Commit

### Backend Elixir
- [ ] `mix format` exécuté
- [ ] `mix credo --strict` sans erreurs
- [ ] `mix test` tous verts
- [ ] Docstrings `@doc` ajoutées
- [ ] Types `@spec` définis
- [ ] Transactions ACID pour opérations financières
- [ ] Logs d'audit ajoutés si action sensible
- [ ] Feature flags si changement risqué

### Frontend Flutter
- [ ] `dart format` exécuté
- [ ] `dart analyze` sans erreurs
- [ ] `flutter test` tous verts
- [ ] Error states gérés
- [ ] Loading states ajoutés
- [ ] Messages erreur en français
- [ ] Accessibilité vérifiée (labels, contraste)

### Base de Données
- [ ] Migration UP + DOWN scripts
- [ ] Index ajoutés si nécessaire
- [ ] Contraintes FK et CHECK
- [ ] Testé en staging

### Sécurité
- [ ] Validation inputs côté backend
- [ ] Authorisation vérifiée
- [ ] En-têtes sécurité présents
- [ ] Pas de secrets dans code
- [ ] Idempotence webhooks

---

## Règle 21 : Performance et Optimisation

### Base de Données (PostgreSQL)
- ✅ TOUJOURS indexer les foreign keys (`user_id`, `game_id`, `room_id`)
- ✅ TOUJOURS ajouter des index composites pour requêtes multi-colonnes
- ✅ Index unique pour contraintes d'unicité (phone, email)
- ✅ Utiliser `SELECT` spécifique, JAMAIS `SELECT *`
- ✅ Pagination obligatoire sur toutes les listes (`LIMIT` + `OFFSET`)
- ❌ ÉVITER le problème N+1 (charger les relations en une requête)

### Cache (Redis)
- TTL : 5 min pour config, 1 min pour données volatiles
- Clés composées : `"user_balance:#{user_id}"` pour multi-utilisateur
- Invalidation TOUJOURS après write (create/update/delete)
- Hit ratio target : >80%

### Requêtes Ecto
```elixir
# ✅ CORRECT — Sélectif avec relations
query = from u in User,
  where: u.id == ^user_id,
  select: [:id, :phone, :name]

# ❌ ÉVITER — Toutes les colonnes
user = Repo.get(User, user_id)
```

### Métriques à Monitorer
- Temps de réponse API > 500ms → alerte
- Taux d'erreur > 5% → critique
- Cache hit ratio < 80% → optimiser
- Pool connexions DB > 80% → scaler

---

## Règle 22 : Anti-patterns Interdits WIWIGA

### Backend Elixir — INTERDITS ABSOLUS
- ❌ NE JAMAIS modifier un balance sans transaction ACID
- ❌ NE JAMAIS utiliser `:rand.uniform` pour les jeux de hasard
- ❌ NE JAMAIS faire confiance au `user_id` envoyé par le client
- ❌ NE JAMAIS créer de webhook sans clé d'idempotence
- ❌ NE JAMAIS stocker de secrets en clair dans le code
- ❌ NE JAMAIS supprimer une colonne en production directement
- ❌ NE JAMAIS hardcoder les taux de commission
- ❌ NE JAMAIS catcher une erreur financièrement sans log d'audit

### Frontend Flutter — INTERDITS ABSOLUS
- ❌ NE JAMAIS utiliser `setState` global pour l'état partagé (utiliser Riverpod)
- ❌ NE JAMAIS mettre de logique métier dans les widgets
- ❌ NE JAMAIS générer de nombres aléatoires côté client pour les jeux
- ❌ NE JAMAIS stocker de tokens JWT en clair (utiliser FlutterSecureStorage)
- ❌ NE JAMAIS valider des montants financiers côté client uniquement
- ❌ NE JAMAIS ignorer les error states dans les providers
- ❌ NE JAMAIS afficher de stack traces techniques à l'utilisateur

### Base de Données — INTERDITS ABSOLUS
- ❌ NE JAMAIS créer de migration sans script DOWN
- ❌ NE JAMAIS oublier les index sur les foreign keys
- ❌ NE JAMAIS utiliser de `SELECT *` en production
- ❌ NE JAMAIS faire de requêtes sans pagination sur les listes
- ❌ NE JAMAIS laisser des contraintes CHECK de côté pour les montants

---

## Règle 23 : Réponses API Standardisées

### Format Succès
```elixir
# GET (liste ou unité)
%{
  success: true,
  data: result,
  meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
}

# POST (création)
conn
|> put_status(:created)
|> json(%{success: true, data: created})

# Pagination (listes)
%{
  success: true,
  data: games_list,
  pagination: %{
    page: 1,
    limit: 20,
    total: 150,
    total_pages: 8,
    has_next: true,
    has_prev: false
  }
}
```

### Format Erreur
```elixir
%{
  success: false,
  error: %{
    code: "INSUFFICIENT_FUNDS",
    message: "Solde insuffisant pour effectuer cette opération",
    details: %{required: 1000, available: 500}
  },
  timestamp: "2026-06-23T10:30:00Z",
  path: "/api/wallet/deposit"
}
```

### Codes d'Erreur Standardisés
- `VALIDATION_ERROR` (400) — Erreur de validation
- `INSUFFICIENT_FUNDS` (400) — Solde insuffisant
- `UNAUTHORIZED` (401) — Non authentifié
- `FORBIDDEN` (403) — Non autorisé
- `NOT_FOUND` (404) — Ressource non trouvée
- `CONFLICT` (409) — Conflit (déjà existe)
- `GAME_ALREADY_STARTED` (409) — Jeu déjà commencé
- `ROOM_FULL` (409) — Salle pleine
- `IDEMPOTENCY_KEY_USED` (409) — Clé d'idempotence déjà utilisée
- `SELF_EXCLUDED` (403) — Utilisateur auto-exclu
- `DAILY_LIMIT_REACHED` (403) — Limite quotidienne atteinte

---

## Règle 24 : Gestion Centralisée des Erreurs

### Module GameHub.Errors
```elixir
defmodule GameHub.Errors do
  @doc """
  Crée une erreur standardisée pour l'API.
  
  ## Parameters
    - `message`: Message en français pour l'utilisateur
    - `status_code`: Code HTTP (400, 401, 403, 404, 409, 500)
    - `code`: Code d'erreur standardisé (string)
    - `details`: Détails optionnels (map ou nil)
  
  ## Returns
    Map standardisée pour réponse JSON
  """
  def error(message, status_code, code, details \\ nil) do
    %{
      success: false,
      error: %{
        code: code,
        message: message,
        details: details
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
```

### Utilisation dans Controller
```elixir
def create(conn, params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, result} <- Service.create(validated) do
    json(conn, %{success: true, data: result})
  else
    {:error, :validation_failed, errors} ->
      conn
      |> put_status(400)
      |> json(Errors.error("Erreur de validation", 400, "VALIDATION_ERROR", errors))
    
    {:error, :insufficient_funds} ->
      conn
      |> put_status(400)
      |> json(Errors.error("Solde insuffisant", 400, "INSUFFICIENT_FUNDS"))
    
    {:error, :not_found} ->
      conn
      |> put_status(404)
      |> json(Errors.error("Ressource non trouvée", 404, "NOT_FOUND"))
  end
end
```

### Règles
- ✅ TOUJOURS utiliser `GameHub.Errors.error/4` pour les réponses d'erreur
- ✅ Messages d'erreur **en français** pour l'utilisateur
- ✅ Ne JAMAIS catcher silencieusement une erreur — toujours logger et retourner
- ✅ Codes d'erreur standardisés pour le frontend Flutter
- ❌ NE JAMAIS bypasser le système avec `send_resp` direct

---

## Règle 25 : Responsivité Progressive Obligatoire

### Exigence Critique
**TOUS** les écrans et composants Flutter DOIVENT s'adapter automatiquement de **50px à 2300px+** avec **17 niveaux de responsivité**.

### 17 Breakpoints WIWIGA

| Niveau | Breakpoint | Catégorie | Usage |
|--------|-----------|-----------|-------|
| 1 | 50-100px | Micro | Montres, IoT |
| 2 | 101-180px | Nano | Mini écrans |
| 3 | 181-240px | Ultra Petit | Téléphones anciens |
| 4 | 241-320px | Très Petit | Smartphones compacts |
| 5 | 321-360px | Petit | Android standard |
| 6 | 361-400px | Moyen-Petit | Android moyen |
| 7 | 401-480px | Moyen | Android large |
| 8 | 481-600px | Grand Mobile | Phablettes |
| 9 | 601-768px | Petite Tablette | iPad Mini |
| 10 | 769-900px | Tablette | iPad 10" |
| 11 | 901-1024px | Grande Tablette | iPad Pro |
| 12 | 1025-1280px | Laptop Petit | Netbooks |
| 13 | 1281-1440px | Laptop Standard | 14"-15" |
| 14 | 1441-1600px | Desktop Petit | 17"-19" |
| 15 | 1601-1920px | Desktop Full HD | 21"-24" |
| 16 | 1921-2300px | Desktop Large | 27"+, 2K |
| 17 | 2301px+ | Ultra Large | 4K, gaming |

### Facteurs d'Échelle Proportionnels

- **0.25x** (50px) → **2.2x+** (2301px+)
- Base 1.0x = 768px (tablette)
- Tous les éléments UI scalent proportionnellement :
  - Icônes, textes, espacements, padding
  - Boutons, champs, cartes, bordures
  - Dialogs, modals, grilles

### Mobile Android Critique (321-480px)

**Priorité absolue** pour WIWIGA :
- ✅ Montants financiers : **MINIMUM 20px**
- ✅ Boutons : **hauteur 40-48px** (tactile friendly)
- ✅ Icônes : **20-24px** minimum
- ✅ Espacements : **6-8px** minimum
- ✅ Touch targets : **44x44px** minimum (Apple HIG)

### Implémentation Obligatoire

```dart
// ✅ CORRECT — Écran responsive
Widget build(BuildContext context) {
  return ResponsiveBuilder(
    builder: (context, config, constraints) {
      return Scaffold(
        body: Padding(
          padding: EdgeInsets.all(config.padding),
          child: Column(
            children: [
              Text(
                'Solde: ${balance} FCFA',
                style: TextStyle(
                  fontSize: config.scaleFont(config.isMobile ? 20 : 36),
                ),
              ),
              SizedBox(height: config.spacing * 2),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, config.buttonHeight),
                ),
                child: Text('Déposer'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ❌ INCORRECT — Tailles fixes
Widget build(BuildContext context) {
  return Scaffold(
    body: Padding(
      padding: EdgeInsets.all(16), // FIXE
      child: Text(
        'Solde',
        style: TextStyle(fontSize: 16), // FIXE
      ),
    ),
  );
}
```

### Layout Adaptatif

- **Mobile (<600px)** : ListView verticale, 1 colonne
- **Tablette (600-1024px)** : GridView 2 colonnes
- **Desktop (>1024px)** : Row multi-colonnes (sidebar + contenu)

### Références

Voir `.qoder/rules/responsive-design.md` pour :
- Implémentation complète `ResponsiveConfig`
- Widget `ResponsiveBuilder` obligatoire
- Extensions responsives
- Templates écrans
- Cas spéciaux (jeux, dialogs)

### Règles Absolues

- ✅ TOUJOURS utiliser `ResponsiveBuilder` pour TOUS les écrans
- ✅ TOUJOURS scaler icônes/textes/espacements avec `config.scale*()`
- ✅ TOUJOURS layout adaptatif mobile/tablette/desktop
- ✅ TOUJOURS tester sur 3 breakpoints minimum (360px, 768px, 1440px)
- ❌ NE JAMAIS utiliser de tailles fixes (px) sans scaling
- ❌ NE JAMAIS créer un écran sans version mobile
- ❌ NE JAMAIS ignorer les petits écrans (<320px)

---

**Ces règles sont OBLIGATOIRES pour TOUT développement WIWIGA. Les violations seront détectées en CI/CD.**
