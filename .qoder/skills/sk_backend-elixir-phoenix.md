# Skill Backend Elixir/Phoenix — WIWIGA

## Quand Utiliser

Toute tâche backend impliquant :
- Modules Elixir (GenServer, contexts, schemas)
- Migrations Ecto
- Controllers REST
- Channels WebSocket
- Transactions financières
- Authentification/autorisation

## Architecture Umbrella

```
game_hub/
├── apps/game_hub/          # Domaine métier principal
├── apps/game_hub_web/      # Couche web (HTTP + WebSocket)
└── apps/dice_game/         # Plugin jeu de dés
```

## Modules GenServer — Pattern Standard

```elixir
defmodule GameHub.GameMatch do
  use GenServer
  
  # === API Publique ===
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def create_match(config), do: GenServer.call(__MODULE__, {:create_match, config})
  
  # === Callbacks ===
  @impl true
  def init(_opts) do
    state = %{matches: %{}}
    :ets.new(:game_matches, [:set, :public, :named_table])
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_match, config}, _from, state) do
    match_id = generate_id()
    match = build_match(match_id, config)
    :ets.insert(:game_matches, {match_id, match})
    {:reply, {:ok, match}, %{state | matches: Map.put(state.matches, match_id, match)}}
  end
end
```

## Transactions ACID — OBLIGATOIRE pour Finances

```elixir
# ✅ CORRECT — Transaction ACID
def place_bet(user_id, amount) do
  Repo.transaction(fn ->
    wallet = Repo.get_for_update!(Wallet, user_id)
    
    if wallet.balance < amount do
      Repo.rollback(:insufficient_funds)
    end
    
    {:ok, debit} = Wallet.create_transaction(wallet, -amount, :bet_placed)
    {:ok, match} = GameMatch.update_bet(match_id, amount)
    
    %{transaction: debit, match: match}
  end)
end

# ❌ INCORRECT — Pas de transaction
def place_bet(user_id, amount) do
  wallet = Repo.get(Wallet, user_id)  # Pas de lock !
  Wallet.update(wallet, %{balance: wallet.balance - amount})  # Race condition !
end
```

## Cache ETS — Pattern

```elixir
@table __MODULE__
@ttl_seconds 300

def get_rules(game_type, rule_type) do
  case :ets.lookup(@table, {game_type, rule_type}) do
    [{_key, rules, inserted_at}] ->
      if elapsed_since(inserted_at) < @ttl_seconds, do: rules, else: refresh(game_type, rule_type)
    [] ->
      refresh(game_type, rule_type)
  end
end

defp refresh(game_type, rule_type) do
  rules = Repo.get_by(GameRule, game_type: game_type, rule_type: rule_type)
  :ets.insert(@table, {{game_type, rule_type}, rules, System.system_time(:second)})
  rules
end
```

## Format de Réponse API

```elixir
# Succès
conn |> json(%{success: true, data: resource})

# Erreur
conn |> put_status(422) |> json(%{success: false, message: "Erreur explicite"})

# Liste paginée
conn |> json(%{success: true, data: items, meta: %{page: 1, total: 100}})
```

## Channels WebSocket

```elixir
defmodule GameHubWeb.RoomChannel do
  use Phoenix.Channel
  
  def join("room:" <> room_id, _params, socket) do
    {:ok, assign(socket, :room_id, room_id)}
  end
  
  def handle_in("start_match", _params, socket) do
    # Logique + broadcast
    broadcast!(socket, "match_started", %{match_id: match_id})
    {:noreply, socket}
  end
end
```

## Supervision Tree

Ajouter tout GenServer dans `application.ex` :
```elixir
children = [
  GameHub.Repo,
  {Phoenix.PubSub, name: GameHub.PubSub},
  GameHub.GameRules,    # Cache ETS
  GameHub.GameMatch,    # State machine
  GameHub.GameRoom,     # Salles
]
```

## Checklist Backend

- [ ] `@spec` et `@doc` sur fonctions publiques
- [ ] Transactions ACID pour opérations financières
- [ ] Pattern matching > conditions imbriquées
- [ ] `{:ok, _} | {:error, _}` > exceptions
- [ ] GenServer dans le supervision tree
- [ ] PubSub pour notifications inter-process
- [ ] Validation changeset Ecto avant insert
