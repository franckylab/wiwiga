# 🚀 WIWIGA - Démarrage Rapide Docker

## En 3 Commandes

```bash
# 1. Cloner ou aller dans le projet
cd /mnt/DONNEES/projets/wiwiga

# 2. Lancer tout (build + services + migrations)
./run-docker.sh

# 3. Tester l'API
curl http://localhost:8000/api/health
```

## Monitoring

```bash
# Voir statut et métriques
./docker-monitor.sh

# Voir logs temps réel
docker compose logs -f backend
```

## Console Elixir

```bash
# Se connecter au backend
docker compose exec backend mix phx.remote
```

## URLs

- **API:** http://localhost:8000/api
- **Health:** http://localhost:8000/api/health
- **WebSocket:** ws://localhost:8000/socket

## Arrêter

```bash
docker compose down
```

---

**Pour plus de détails:** Voir [DOCKER_GUIDE.md](DOCKER_GUIDE.md)
