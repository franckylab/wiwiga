# 🐳 WIWIGA - Guide Docker Complet

**Date:** 2026-06-24  
**Version:** 1.0

---

## 📋 Prérequis

- Docker 20.10+
- Docker Compose V2 (plugin)

### Vérifier installation

```bash
docker --version
docker compose version
```

---

## 🚀 Lancement Rapide

### Option 1: Script Automatisé (Recommandé)

```bash
# Exécuter le script
./run-docker.sh

# Le script fait automatiquement:
# ✅ Build de l'image
# ✅ Lancement PostgreSQL, Redis, Backend
# ✅ Vérification santé des services
# ✅ Exécution migrations
# ✅ Chargement seeds
# ✅ Vérification API
```

### Option 2: Manuel

```bash
# 1. Build
docker compose build

# 2. Lancer services
docker compose up -d

# 3. Voir logs
docker compose logs -f backend

# 4. Migrations (automatique dans docker-compose)
# Voir logs pour confirmation
```

---

## 📊 Monitoring

### Statut Services

```bash
# Voir tous les containers
docker compose ps

# Monitoring détaillé
./docker-monitor.sh
```

### Logs

```bash
# Tous les services
docker compose logs -f

# Backend uniquement
docker compose logs -f backend

# 50 dernières lignes
docker compose logs --tail=50 backend

# PostgreSQL
docker compose logs -f postgres

# Redis
docker compose logs -f redis
```

### Ressources

```bash
# Utilisation CPU/Mémoire
docker stats --filter "name=wiwiga"
```

---

## 🔧 Commandes Utiles

### Console Elixir

```bash
# Se connecter au backend
docker compose exec backend mix phx.remote

# Ou IEx interactif
docker compose exec backend iex -S mix
```

### Base de Données

```bash
# Se connecter à PostgreSQL
docker compose exec postgres psql -U wiwiga -d game_hub_dev

# Voir tables
docker compose exec postgres psql -U wiwiga -d game_hub_dev -c "\dt"

# Exécuter migration
docker compose exec backend mix ecto.migrate

# Revenir en arrière
docker compose exec backend mix ecto.rollback

# Reset DB (⚠️ supprime tout)
docker compose exec backend mix ecto.reset
```

### Redis

```bash
# Se connecter à Redis
docker compose exec redis redis-cli

# Voir toutes les clés
docker compose exec redis redis-cli KEYS '*'

# Voir mémoire
docker compose exec redis redis-cli INFO memory
```

### Tests

```bash
# Exécuter tous les tests
docker compose exec backend mix test

# Tests avec coverage
docker compose exec backend mix coveralls.html

# Un seul fichier test
docker compose exec backend mix test test/game_hub/wallet_test.exs
```

### Code Quality

```bash
# Formatage
docker compose exec backend mix format

# Lint Credo
docker compose exec backend mix credo --strict

# Security Sobelow
docker compose exec backend mix sobelow --config
```

---

## 🔄 Gestion des Services

### Redémarrer

```bash
# Tous les services
docker compose restart

# Backend uniquement
docker compose restart backend
```

### Arrêter

```bash
# Arrêter services (conserve données)
docker compose down

# Arrêter et supprimer volumes
docker compose down -v

# Arrêter et supprimer images
docker compose down --rmi all
```

### Rebuild

```bash
# Rebuild après modifications code
docker compose up -d --build

# Rebuild sans cache
docker compose build --no-cache
docker compose up -d
```

---

## 🐛 Dépannage

### Backend ne démarre pas

```bash
# Voir logs
docker compose logs backend

# Vérifier dépendances
docker compose exec backend mix deps.get

# Recompile
docker compose exec backend mix compile
```

### PostgreSQL inaccessible

```bash
# Vérifier santé
docker compose exec postgres pg_isready -U wiwiga

# Redémarrer
docker compose restart postgres

# Voir logs
docker compose logs postgres
```

### Redis inaccessible

```bash
# Vérifier connexion
docker compose exec redis redis-cli ping

# Redémarrer
docker compose restart redis
```

### Port déjà utilisé

```bash
# Trouver processus
lsof -i :4001
lsof -i :5432
lsof -i :6379

# Tuer processus
kill -9 <PID>
```

### Nettoyer complètement

```bash
# Arrêter et supprimer tout
docker compose down -v --rmi all

# Supprimer volumes orphelins
docker volume prune

# Supprimer images orphelines
docker image prune -a
```

---

## 📁 Volumes Docker

### Persistance données

```bash
# Voir volumes
docker volume ls | grep wiwiga

# PostgreSQL data
docker volume inspect wiwiga_postgres_data

# Redis data
docker volume inspect wiwiga_redis_data

# Supprimer un volume
docker volume rm wiwiga_postgres_data
```

---

## 🌐 URLs et Accès

| Service | URL | Port |
|---------|-----|------|
| **Backend API** | http://localhost:4001/api | 4001 |
| **Health Check** | http://localhost:4001/api/health | 4001 |
| **WebSocket** | ws://localhost:4001/socket | 4001 |
| **PostgreSQL** | localhost | 5432 |
| **Redis** | localhost | 6379 |

---

## 🔒 Variables d'Environnement

### Production

```bash
# Créer fichier .env
cat > .env << EOF
MIX_ENV=prod
DATABASE_URL=postgresql://wiwiga:wiwiga_secret@postgres:5432/game_hub_prod
REDIS_URL=redis://redis:6379
SECRET_KEY_BASE=$(mix phx.gen.secret)
PORT=4001
EOF

# Lancer avec .env
docker compose --env-file .env up -d
```

---

## 📈 Performance

### Optimiser build

```bash
# Utiliser cache
docker compose build

# Build parallèle
docker compose build --parallel

# Voir taille images
docker images | grep wiwiga
```

### Nettoyer régulièrement

```bash
# Supprimer containers arrêtés
docker container prune

# Supprimer images inutilisées
docker image prune

# Nettoyer tout
docker system prune -a
```

---

## ✅ Checklist Vérification

Après lancement :

```bash
# 1. Services actifs
docker compose ps
# → 3 services "Up"

# 2. Health check API
curl http://localhost:4001/api/health
# → {"status":"ok"}

# 3. PostgreSQL
docker compose exec postgres pg_isready -U wiwiga
# → accepting connections

# 4. Redis
docker compose exec redis redis-cli ping
# → PONG

# 5. Logs backend (pas d'erreurs)
docker compose logs backend | grep -i error
# → (vide)
```

---

## 🚀 Déploiement Production

### Build optimisé

```bash
# Environment production
MIX_ENV=prod docker compose build

# Lancer
MIX_ENV=prod docker compose up -d

# Vérifier
docker compose logs -f backend
```

### Blue-Green Deployment

```bash
# Stack verte (actuelle)
docker compose -p wiwiga_green up -d

# Stack bleue (nouvelle)
docker compose -p wiwiga_blue up -d

# Bascule
# (modifier reverse proxy)

# Arrêter ancienne
docker compose -p wiwiga_green down
```

---

## 📝 Fichiers Docker

| Fichier | Description |
|---------|-------------|
| `docker-compose.yml` | Configuration services |
| `Dockerfile.backend` | Image Elixir/Phoenix |
| `.dockerignore` | Exclusions build |
| `run-docker.sh` | Script lancement auto |
| `docker-monitor.sh` | Script monitoring |

---

## 🎯 Prochaines Étapes

1. ✅ Docker configuré
2. ✅ Backend fonctionnel dans container
3. ➡️ Développer frontend Flutter
4. ➡️ Tests end-to-end
5. ➡️ Déploiement production

---

**WIWIGA - Guide Docker**  
*Version 1.0 - 2026-06-24*
