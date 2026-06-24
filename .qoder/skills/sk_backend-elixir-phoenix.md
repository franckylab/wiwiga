# Skill: Implémentation Backend Elixir/Phoenix

## Description
Implémenter des modules backend WIWIGA en Elixir/Phoenix suivant les meilleures pratiques de sécurité financière, architecture OTP, et conformité jeux d'argent.

## Quand Utiliser
- Créer un nouveau module métier (wallet, auth, jeux)
- Implémenter un endpoint API REST
- Développer un canal WebSocket Phoenix
- Créer une application OTP plugin de jeu
- Écrire des migrations PostgreSQL

## Étapes d'Implémentation

### 1. Structure du Module

```elixir
defmodule GameHub.[ModuleName] do
  @moduledoc """
  [Description du module en français]
  
  Responsabilités:
  - [Liste des responsabilités]
  """
  
  use GenServer # Si nécessaire
  
  alias GameHub.Repo
  alias GameHub.[RelatedModule]
  
  # Callbacks GenServer si nécessaire
  @impl true
  def init(args) do
    {:ok, initial_state}
  end
end
```

### 2. Fonctions Publiques avec Documentation

```elixir
@doc """
[Description de la fonction]

## Parameters
  - `param1`: Description (type)
  - `param2`: Description (type)

## Returns
  - `{:ok, result}`: Succès
  - `{:error, reason}`: Échec

## Examples

    iex> ModuleName.function(arg1, arg2)
    {:ok, %Result{}}
    
    iex> ModuleName.function(invalid_arg)
    {:error, :validation_failed}
"""
@spec function_name(type1, type2) :: {:ok, Result.t()} | {:error, atom()}
def function_name(param1, param2) do
  # Implementation
end
```

### 3. Transactions Financières (OBLIGATOIRE)

```elixir
def financial_operation(user_id, amount) do
  Repo.transaction(fn ->
    # 1. Verrouillage pessimiste
    wallet = Repo.one!(from w in UserWallet,
      where: w.user_id == ^user_id,
      lock: "FOR UPDATE")
    
    # 2. Validation
    if wallet.balance < amount do
      Repo.rollback(:insufficient_funds)
    end
    
    # 3. Exécution
    new_wallet = update_balance(wallet, -amount)
    create_transaction(new_wallet, amount)
    
    # 4. Log d'audit
    AuditLog.log(:financial_operation, user_id, %{amount: amount})
    
    new_wallet
  end)
end
```

### 4. Migrations PostgreSQL

```elixir
defmodule GameHub.Repo.Migrations.Create[TableName] do
  use Ecto.Migration
  
  def up do
    create table(:table_name, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all)
      add :field_name, :string, null: false
      add :amount, :bigint, default: 0
      add :active, :boolean, default: true
      timestamps()
    end
    
    create index(:table_name, [:user_id])
    create unique_index(:table_name, [:unique_field])
    
    # Contraintes CHECK
    execute """
      ALTER TABLE table_name
      ADD CONSTRAINT amount_positive CHECK (amount >= 0)
    """
  end
  
  def down do
    drop table(:table_name)
  end
end
```

### 5. Endpoint API REST

```elixir
defmodule GameHubWeb.[Resource]Controller do
  use GameHubWeb, :controller
  
  alias GameHub.[Module]
  alias GameWeb.Authorization
  
  def create(conn, params) do
    user = conn.assigns.current_user
    
    # Validation autorisation
    unless Authorization.can_access?(user, params) do
      send_resp(conn, 403, "Forbidden")
    end
    
    # Validation inputs
    with {:ok, validated_data} <- validate_params(params),
         {:ok, result} <- Module.create(user.id, validated_data) do
      
      conn
      |> put_status(:created)
      |> json(%{data: result})
    else
      {:error, :validation_failed, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
      
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end
  
  defp validate_params(params) do
    # Validation stricte
    case ParamsValidator.validate(params) do
      :ok -> {:ok, params}
      {:error, errors} -> {:error, :validation_failed, errors}
    end
  end
end
```

### 6. Canal WebSocket Phoenix

```elixir
defmodule GameHubWeb.GameChannel do
  use GameHubWeb, :channel
  
  alias GameHub.[GamePlugin]
  
  @impl true
  def join("game:" <> game_id, _params, socket) do
    if authorized?(socket, game_id) do
      {:ok, assign(socket, :game_id, game_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
  
  @impl true
  def handle_in("place_bet", %{"amount" => amount}, socket) do
    user_id = socket.assigns.current_user.id
    
    case GamePlugin.place_bet(socket.assigns.game_id, user_id, amount) do
      {:ok, new_state} ->
        broadcast!(socket, "bet_placed", %{
          player_id: user_id,
          amount: amount,
          timestamp: DateTime.utc_now()
        })
        
        {:reply, {:ok, new_state}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{message: reason}}, socket}
    end
  end
  
  @impl true
  def handle_in("make_move", %{"move" => move}, socket) do
    # Validation coup
    # Mise à jour état
    # Broadcast aux autres joueurs
  end
  
  defp authorized?(socket, game_id) do
    # Vérifier participation au jeu
  end
end
```

### 7. Plugin de Jeu OTP

```elixir
defmodule GameHub.Games.DiceGame do
  @behaviour GameHub.GamePlugin
  use GenServer
  
  @impl GameHub.GamePlugin
  def start_game(players, settings) do
    config = validate_settings(settings)
    initial_state = build_initial_state(players, config)
    
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(initial_state.id))
  end
  
  @impl GameHub.GamePlugin
  def handle_move(game_id, move, player_id) do
    GenServer.call(via_tuple(game_id), {:make_move, move, player_id})
  end
  
  @impl GenServer
  def handle_call({:make_move, move, player_id}, _from, state) do
    with :ok <- validate_move(state, move, player_id),
         new_state <- apply_move(state, move, player_id),
         winner <- check_winner(new_state) do
      
      broadcast_state_update(new_state)
      
      if winner do
        handle_game_end(new_state, winner)
      end
      
      {:reply, {:ok, new_state}, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  defp via_tuple(game_id) do
    {:via, Registry, {GameHub.GameRegistry, game_id}}
  end
end
```

### 8. Tests Backend

```elixir
defmodule GameHub.[Module]Test do
  use GameHub.DataCase
  
  alias GameHub.[Module]
  
  describe "function_name/2" do
    test "returns success with valid data" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 10_000)
      
      assert {:ok, result} = Module.function_name(user.id, 1_000)
      assert result.balance == 9_000
    end
    
    test "returns error for insufficient funds" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 500)
      
      assert {:error, :insufficient_funds} = Module.function_name(user.id, 1_000)
    end
    
    test "is idempotent" do
      user = insert(:user)
      insert(:wallet, user: user, balance: 10_000)
      
      {:ok, result1} = Module.function_name(user.id, 1_000, "key_123")
      {:ok, result2} = Module.function_name(user.id, 1_000, "key_123")
      
      assert result1.balance == result2.balance
    end
  end
end
```

## Checklist Validation
- [ ] `@moduledoc` et `@doc` sur toutes fonctions publiques
- [ ] `@spec` avec types corrects
- [ ] Transactions ACID pour opérations financières
- [ ] Verrouillage pessimiste (`FOR UPDATE`)
- [ ] Validation inputs côté backend
- [ ] Authorisation vérifiée
- [ ] Logs d'audit pour actions sensibles
- [ ] Tests unitaires >90% couverture
- [ ] Migration UP + DOWN scripts
- [ ] Feature flags si changement risqué
- [ ] Pas de secrets dans code

## Pièges à Éviter
- ❌ JAMAIS de modification balance sans transaction
- ❌ JAMAIS de confiance dans `user_id` du client
- ❌ JAMAIS de génération aléatoire côté client
- ❌ JAMAIS de webhooks sans idempotence
- ❌ JAMAIS de migrations irréversibles
- ❌ JAMAIS de suppression colonnes en production directement
- ❌ JAMAIS de taux commission hardcodés

## Références
- `GAME_HUB_PROMPT_FR.md` - Spécifications complètes
- `.qoder/rules/rl_development-best-practices.md` - Règles de développement
- Documentation officielle Phoenix: https://hexdocs.pm/phoenix
- Documentation Elixir: https://hexdocs.pm/elixir
