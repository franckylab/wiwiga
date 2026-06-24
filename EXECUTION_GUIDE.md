# 🚀 WIWIGA Backend - Guide d'Exécution Complet

**Date:** 2026-06-24  
**Version:** 3.0  
**Statut:** ✅ Prêt pour exécution

---

## 📋 Prérequis

### Option 1: Installation Directe (Recommandé pour développement)

#### Ubuntu/Debian
```bash
# Exécuter script d'installation
sudo bash install-elixir.sh

# Ou manuellement
sudo apt update
sudo apt install -y elixir erlang-dev inotify-tools
```

#### Arch Linux
```bash
sudo pacman -S elixir erlang inotify-tools
```

#### macOS
```bash
brew install elixir
```

### Option 2: Docker (Recommandé pour production)

```bash
# Installer Docker
sudo apt install docker.io docker-compose

# Lancer tout l'environnement
docker-compose up -d
```

---

## 🚀 Exécution - Méthode 1: Directe

### 1. Installer Elixir

```bash
sudo bash install-elixir.sh
```

### 2. Installer Dépendances

```bash
cd game_hub
mix deps.get
```

### 3. Compiler

```bash
mix compile
```

### 4. Configurer Base de Données

#### Installer PostgreSQL

```bash
# Ubuntu/Debian
sudo apt install -y postgresql postgresql-contrib

# Arch Linux
sudo pacman -S postgresql

# macOS
brew install postgresql
```

#### Créer Utilisateur et Base

```bash
# Se connecter à PostgreSQL
sudo -u postgres psql

# Dans psql:
CREATE USER wiwiga WITH PASSWORD 'wiwiga_secret';
CREATE DATABASE game_hub_dev OWNER wiwiga;
CREATE DATABASE game_hub_test OWNER wiwiga;
\q
```

### 5. Configurer Variables d'Environnement

```bash
# Créer fichier .env
cat > game_hub/.env << 'EOF'
DATABASE_URL=postgresql://wiwiga:wiwiga_secret@localhost:5432/game_hub_dev
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=$(mix phx.gen.secret)
PORT=4001
EOF

# Charger variables
source game_hub/.env
```

### 6. Installer Redis

```bash
# Ubuntu/Debian
sudo apt install -y redis-server
sudo systemctl start redis-server

# Arch Linux
sudo pacman -S redis
sudo systemctl start redis

# macOS
brew install redis
brew services start redis
```

### 7. Exécuter Migrations

```bash
cd game_hub
mix ecto.create
mix ecto.migrate
```

### 8. Charger Données Initiales

```bash
mix run priv/repo/seeds.exs
```

### 9. Lancer Serveur

```bash
# Mode développement (avec rechargement auto)
mix phx.server

# Mode production
MIX_ENV=prod mix phx.server
```

### 10. Vérifier

```bash
# Health check
curl http://localhost:4001/api/health

# Register user
curl -X POST http://localhost:4001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237699999999", "name": "Test User"}'
```

---

## 🐳 Exécution - Méthode 2: Docker

### 1. Lancer Tout l'Environnement

```bash
# Build et démarrage
docker-compose up -d

# Voir les logs
docker-compose logs -f backend

# Vérifier santé
curl http://localhost:4001/api/health
```

### 2. Exécuter Commandes dans Container

```bash
# Console Elixir interactive
docker-compose exec backend mix phx.remote

# Exécuter migrations
docker-compose exec backend mix ecto.migrate

# Voir logs
docker-compose exec backend mix phx.server

# Tests
docker-compose exec backend mix test
```

### 3. Arrêter

```bash
# Arrêter services
docker-compose down

# Arrêter et supprimer volumes
docker-compose down -v
```

---

## 🧪 Exécuter Tests

### Tests Unitaires

```bash
cd game_hub
mix test
```

### Tests avec Couverture

```bash
mix deps.add coveralls --only test
mix coveralls.html
# Ouvrir cover/excoveralls.html
```

### Analyse Code

```bash
# Formatage
mix format

# Lint avec Credo
mix deps.add credo --only dev
mix credo --strict
```

---

## 📊 Monitoring

### Console Interactive

```bash
# Connecter à l'application en cours
iex -S mix phx.server

# Ou en production
bin/game_hub remote_console
```

### Vérifier Santé

```bash
# Health check API
curl http://localhost:4001/api/health

# Vérifier processus
mix app.tree

# Voir dépendances
mix deps
```

---

## 🚀 Déploiement Production

### Script Automatisé

```bash
# Exécuter script de déploiement
./deploy.sh

# Ou avec variables
MIX_ENV=prod PORT=4001 ./deploy.sh
```

### Build Release

```bash
cd game_hub

# Environment production
export MIX_ENV=prod

# Compiler
mix deps.get --only prod
mix compile

# Créer release
mix release

# Démarrer
_build/prod/rel/game_hub/bin/game_hub start

# Ou en daemon
_build/prod/rel/game_hub/bin/game_hub daemon
```

---

## 🔧 Dépannage

### Erreur: PostgreSQL Connection Refused

```bash
# Vérifier que PostgreSQL tourne
sudo systemctl status postgresql

# Redémarrer
sudo systemctl restart postgresql
```

### Erreur: Redis Connection Refused

```bash
# Vérifier Redis
redis-cli ping

# Redémarrer
sudo systemctl restart redis-server
```

### Erreur: Port Already in Use

```bash
# Trouver processus utilisant le port
lsof -i :4001

# Tuer processus
kill -9 <PID>
```

### Erreur: Compilation Failed

```bash
# Nettoyer et recompiler
mix deps.clean --all
mix deps.get
mix compile
```

---

## 📡 URLs et Endpoints

### Développement
- **API:** http://localhost:4001/api
- **Health:** http://localhost:4001/api/health
- **WebSocket:** ws://localhost:4001/socket

### Production
- **API:** https://your-domain.com/api
- **Health:** https://your-domain.com/api/health
- **WebSocket:** wss://your-domain.com/socket

---

## 📝 Commandes Utiles

### Base de Données

```bash
# Créer migration
mix ecto.gen.migration add_new_table

# Exécuter migrations
mix ecto.migrate

# Revenir en arrière
mix ecto.rollback

# Reset DB (⚠️ supprime tout)
mix ecto.reset
```

### Release

```bash
# Créer release
mix release

# Version
bin/game_hub version

# Status
bin/game_hub status

# Stop
bin/game_hub stop

# Restart
bin/game_hub restart
```

---

## ✅ Checklist Pré-Production

- [x] Elixir installé (1.15+)
- [x] Erlang/OTP installé (26+)
- [x] PostgreSQL configuré (15+)
- [x] Redis configuré (7+)
- [x] Dépendances installées (`mix deps.get`)
- [x] Code compilé (`mix compile`)
- [x] Migrations exécutées (`mix ecto.migrate`)
- [x] Seeds chargés (`mix run priv/repo/seeds.exs`)
- [x] Tests passés (`mix test`)
- [x] Serveur démarré (`mix phx.server`)
- [x] Health check OK (`curl /api/health`)

---

## 🎯 Prochaines Étapes

1. ✅ Backend fonctionnel
2. ➡️ Développer frontend Flutter
3. ➡️ Tests end-to-end
4. ➡️ Déploiement staging
5. ➡️ Production

---

**WIWIGA Backend - Guide d'Exécution**  
*Version 3.0 - 2026-06-24*
