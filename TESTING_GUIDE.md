# WIWIGA - Guide de Test

## 📋 Vue d'Ensemble

Ce document explique comment exécuter les tests et comprendre la stratégie de test du projet WIWIGA.

## 🏗️ Structure des Tests

```
game_hub/apps/game_hub/test/
├── test_helper.exs              # Configuration et helpers
├── game_hub/
│   ├── wallet_test.exs          # Tests module Wallet (ACID)
│   ├── auth_test.exs            # Tests module Auth (OTP + JWT)
│   └── commission_test.exs      # Tests module Commission
└── config/
    └── test.exs                 # Configuration environnement test
```

## 🎯 Stratégie de Test

### Modules Critiques Testés

1. **Wallet** (CRITIQUE -argent réel)
   - Transactions ACID
   - Verrouillage pessimiste
   - Idempotence
   - Gestion erreurs (solde insuffisant, user not found)
   
2. **Auth** (CRITIQUE -sécurité)
   - Génération OTP
   - Vérification OTP avec expiration
   - JWT token generation/verification
   - Création automatique utilisateur
   
3. **Commission** (CRITIQUE -business model)
   - Calcul percentage (5%)
   - Calcul fixed (montant fixe)
   - Calcul tiered (barème progressif)
   - Déduction commission sur gains

## 🚀 Exécution des Tests

### Prérequis

```bash
# 1. PostgreSQL doit être en cours d'exécution
sudo systemctl start postgresql

# 2. Créer la base de test
createdb game_hub_test

# 3. Exécuter les migrations sur la DB de test
cd /mnt/DONNEES/projets/wiwiga/game_hub
MIX_ENV=test mix ecto.migrate

# 4. Redis doit être en cours d'exécution (pour certains tests)
sudo systemctl start redis
```

### Commandes de Test

```bash
# Exécuter TOUS les tests
cd /mnt/DONNEES/projets/wiwiga/game_hub
mix test

# Exécuter les tests d'un module spécifique
mix test apps/game_hub/test/game_hub/wallet_test.exs
mix test apps/game_hub/test/game_hub/auth_test.exs
mix test apps/game_hub/test/game_hub/commission_test.exs

# Exécuter avec couverture de code
mix test --cover

# Exécuter un test spécifique
mix test apps/game_hub/test/game_hub/wallet_test.exs:27
# (ligne 27 = test spécifique)

# Exécuter en mode watch (re-run automatique)
mix test.watch

# Exécuter avec logs détaillés
mix test --trace
```

## 📊 Coverage Attendu

| Module | Coverage Cible | Statut |
|--------|---------------|--------|
| Wallet | 90%+ | ✅ Implémenté |
| Auth | 85%+ | ✅ Implémenté |
| Commission | 85%+ | ✅ Implémenté |
| Matchmaking | 70% | ⏳ À faire |
| GameController | 75% | ⏳ À faire |
| PaymentWebhook | 80% | ⏳ À faire |

## 🧪 Types de Tests

### 1. Tests Unitaire (Implémentés)
- Testent une fonction isolée
- Utilisent mocks si nécessaire
- Rapides et déterministes

### 2. Tests d'Intégration (À faire)
- Testent plusieurs modules ensemble
- Utilisent la DB réelle
- Plus lents mais plus réalistes

### 3. Tests de Properties (À faire)
- Testent des invariants (ex: balance toujours >= 0)
- Génèrent des données aléatoires
- Trouvent des edge cases

## 🔍 Exemples de Tests

### Test Wallet - Idempotence

```elixir
test "respecte l'idempotence - même clé = même transaction", %{user: user} do
  idempotency_key = "unique_deposit_#{System.unique_integer()}"
  
  # Premier dépôt
  assert {:ok, tx1} = Wallet.deposit(user.id, 10000, idempotency_key)
  
  # Second dépôt avec même clé
  assert {:error, :idempotency_key_used} = 
    Wallet.deposit(user.id, 10000, idempotency_key)
  
  # Le balance ne doit avoir augmenté qu'une seule fois
  assert Wallet.get_balance(user.id) == {:ok, 110000}
end
```

### Test Auth - Flow Complet

```elixir
test "flow complet: send_otp -> verify_otp -> JWT -> verify_jwt" do
  phone = "+237699000040"
  
  # 1. Envoyer OTP
  {:ok, otp} = Auth.send_otp(phone)
  
  # 2. Vérifier OTP et obtenir JWT
  {:ok, jwt_token, user} = Auth.verify_otp(phone, otp)
  
  # 3. Vérifier JWT
  {:ok, claims} = Auth.verify_jwt_token(jwt_token)
  
  # 4. Vérifier cohérence
  assert claims.user_id == user.id
  assert claims.user.phone == phone
end
```

### Test Commission - Tiered

```elixir
test "calcule commission tiered (troisième tier)", %{roulette_config: _} do
  # 100000 est dans le troisième tier (50001+) à 3%
  assert {:ok, commission} = Commission.calculate_commission("roulette", 100000)
  
  # 3% de 100000 = 3000
  assert commission == 3000
end
```

## ⚠️ Pièges à Éviter

### 1. Données Partagées entre Tests
- **Problème**: Tests qui échouent à cause de données残留
- **Solution**: Utiliser `setup` block pour nettoyer avant chaque test

```elixir
setup do
  Repo.delete_all(WalletTransaction)
  Repo.delete_all(User)
  :ok
end
```

### 2. Tests Non-Déterministes
- **Problème**: Tests qui passent parfois, échouent d'autres fois
- **Solution**: Utiliser `System.unique_integer()` pour clés uniques

```elixir
idempotency_key = "deposit_#{System.unique_integer()}"
```

### 3. Tests Dépendants de l'Ordre
- **Problème**: Test B échoue si Test A n'est pas exécuté avant
- **Solution**: Chaque test doit être autonome

### 4. Mock de Redis
- **Problème**: Redis non disponible en test
- **Solution**: Installer Redis local ou utiliser mock

## 🔧 Helpers de Test

Le module `GameHub.TestHelpers` fournit des fonctions utilitaires :

```elixir
# Créer utilisateur de test
user = TestHelpers.create_test_user(balance: 200000)

# Créer config jeu
config = TestHelpers.create_game_config(
  game_type: "dice",
  commission_rate: Decimal.new("0.05")
)

# Générer clé idempotence
key = TestHelpers.unique_idempotency_key("deposit")

# Nettoyer données
TestHelpers.cleanup_test_data()
```

## 📈 Améliorations Futures

### Tests à Ajouter (Priorité)

1. **Matchmaking Tests**
   - Test file d'attente Redis
   - Test matching joueurs
   - Test TTL expiration
   - Test race conditions

2. **GameController Tests**
   - Test validation bets (min/max)
   - Test solde insuffisant
   - Test join queue
   - Test game state retrieval

3. **PaymentWebhook Tests**
   - Test signature HMAC
   - Test idempotence webhook
   - Test crédit portefeuille
   - Test user not found

4. **Integration Tests**
   - Flow complet: Auth → Deposit → Join Game → Play → Win → Withdraw
   - Test concurrence (multi-users)
   - Test rollback transactions

### Outils Recommandés

```elixir
# Ajouter au mix.exs
defp deps do
  [
    {:mock, "~> 0.3.0"},           # Mocking
    {:faker, "~> 0.17"},           # Données fake
    {:shouldi, "~> 0.3.0"}         # Matchers avancés
  ]
end
```

## 🐛 Debug des Tests

### Test Échoue avec `DBConnection.OwnershipError`

```bash
# Solution: Activer Sandbox
Ecto.Adapters.SQL.Sandbox.mode(GameHub.Repo, :manual)

# Dans le test:
setup do
  pid = Sandbox.start_owner!(GameHub.Repo)
  on_exit(fn -> Sandbox.stop_owner(pid) end)
end
```

### Test Échoue avec `Redis Connection Refused`

```bash
# Vérifier que Redis tourne
redis-cli ping
# Doit retourner: PONG

# Si pas installé:
sudo apt install redis-server
sudo systemctl start redis
```

### Test Lent (> 100ms par test)

```bash
# Identifier tests lents
mix test --slowest 10

# Optimisations possibles:
# - Réduire pool_size dans test.exs
# - Utiliser async: true si pas de shared state
# - Mock Redis au lieu d'instance réelle
```

## 📝 Conventions de Nommage

```elixir
# Describe blocks par fonction
describe "deposit/3" do
  test "dépose des fonds avec succès" do
  end
  
  test "rejette un montant invalide" do
  end
  
  test "respecte l'idempotence" do
  end
end

# Describe blocks pour scénarios
describe "intégrité ACID" do
  test "rollback en cas d'erreur" do
  end
end

# Describe blocks pour edge cases
describe "edge cases" do
  test "balance = 0 après retrait total" do
  end
end
```

## ✅ Checklist Qualité Test

- [ ] Chaque test est autonome
- [ ] Tests déterministes (pas de timing)
- [ ] Setup nettoie les données
- [ ] Clés uniques avec `System.unique_integer()`
- [ ] Assertions claires et spécifiques
- [ ] Coverage > 80% sur modules critiques
- [ ] Tests nommés clairement
- [ ] Pas de code dupliqué entre tests
- [ ] Helpers extraits dans TestHelpers

## 📚 Ressources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Ecto Sandbox](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Phoenix Testing Guide](https://hexdocs.pm/phoenix/testing.html)

---

**Dernière mise à jour**: 23 Juin 2026  
**Prochaine revue**: Après ajout tests d'intégration
