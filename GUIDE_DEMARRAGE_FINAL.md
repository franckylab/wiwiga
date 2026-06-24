# 🚀 WIWIGA - Guide de Démarrage Final

**Dernière mise à jour** : 24 Juin 2026  
**Version** : 1.0 - Configuration Consolidée

---

## 📋 Vue d'Ensemble

WIWIGA est une plateforme de jeux en ligne avec :
- **Backend** : Elixir/Phoenix 1.7+ (API REST + WebSocket)
- **Frontend** : Flutter (Web + Android) - *à lancer séparément*
- **Base de données** : PostgreSQL 15
- **Cache** : Redis 7
- **Paiement** : Campay (Mobile Money Cameroun)

---

## 🎯 Configuration Docker Consolidée

### Ports Utilisés

| Service | Port Hôte → Container | URL d'accès |
|---------|----------------------|-------------|
| **Backend API** | 8000 → 4001 | http://localhost:8000 |
| **PostgreSQL** | 8001 → 5432 | localhost:8001 |
| **Redis** | 8002 → 6379 | localhost:8002 |
| **Frontend Flutter** | 8004 | http://localhost:8004 *(à lancer)* |

### Credentials

**PostgreSQL** :
- User : `wiwiga_user`
- Password : `wiwiga_password`
- Database : `wiwiga_dev`

**Redis** : Pas d'authentification (développement)

---

## 🚀 Démarrage Rapide

### 1. Lancer l'Environnement Docker

```bash
cd /mnt/DONNEES/projets/wiwiga

# Démarrer tous les services
docker compose up -d

# Vérifier que tout tourne
docker compose ps
```

**Sortie attendue** :
```
NAME              STATUS                    PORTS
wiwiga_backend    Up                        0.0.0.0:8000->4001/tcp
wiwiga_postgres   Up (healthy)              0.0.0.0:8001->5432/tcp
wiwiga_redis      Up (healthy)              0.0.0.0:8002->6379/tcp
```

### 2. Vérifier la Santé du Système

```bash
# Health check complet
curl http://localhost:8000/api/health | python3 -m json.tool
```

**Réponse attendue** :
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "checks": {
    "database": {"status": "healthy", "latency_ms": 5},
    "redis": {"status": "healthy", "latency_ms": 1}
  },
  "environment": "dev"
}
```

### 3. Tester l'API

```bash
# Liste des jeux disponibles
curl http://localhost:8000/api/games | python3 -m json.tool
```

**Réponse attendue** :
```json
{
  "success": true,
  "data": [{
    "id": "dice",
    "name": "Jeu de Dés",
    "status": "active",
    "min_bet": 100,
    "max_bet": 100000,
    "commission_rate": 0.05
  }]
}
```

---

## 👥 Utilisateurs de Test

Trois utilisateurs sont pré-configurés dans la base :

| Rôle | Téléphone | Nom | Balance | KYC |
|------|-----------|-----|---------|-----|
| **Admin** | +237699999999 | Admin WIWIGA | 10,000 FCFA | ✅ Vérifié |
| **Test** | +237688888888 | Utilisateur Test | 5,000 FCFA | ✅ Vérifié |
| **Limité** | +237677777777 | Utilisateur Limité | 2,000 FCFA | ❌ Non vérifié |

**Note** : Les balances sont en **centimes** (1000000 centimes = 10,000 FCFA)

---

## 📚 Endpoints API Principaux

### Authentification (Public)

```bash
# Envoyer code OTP
curl -X POST http://localhost:8000/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237699999999"}'

# Vérifier OTP et obtenir JWT
curl -X POST http://localhost:8000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237699999999", "otp": "123456"}'
```

### Wallet (JWT requis)

```bash
# Consulter le solde
curl http://localhost:8000/api/wallet/balance \
  -H "Authorization: Bearer <token>"

# Effectuer un dépôt
curl -X POST http://localhost:8000/api/wallet/deposit \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000, "idempotency_key": "unique_123"}'

# Historique des transactions
curl "http://localhost:8000/api/wallet/transactions?page=1&limit=20" \
  -H "Authorization: Bearer <token>"
```

### Jeux (Public + JWT)

```bash
# Liste des jeux (public)
curl http://localhost:8000/api/games

# Détails d'un jeu (public)
curl http://localhost:8000/api/games/dice

# Rejoindre une partie (JWT requis)
curl -X POST http://localhost:8000/api/games/dice/join \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"bet_amount": 5000}'
```

### WebSocket (JWT requis)

```javascript
// Connexion WebSocket
const ws = new WebSocket('ws://localhost:8000/socket/websocket', {
  headers: { 'Authorization': 'Bearer <token>' }
});

ws.onopen = () => {
  console.log('Connecté au WebSocket');
};

ws.onmessage = (event) => {
  console.log('Message reçu:', event.data);
};
```

---

## 🗄️ Base de Données

### Tables Créées (8 migrations)

1. `users` - Utilisateurs
2. `wallet_transactions` - Transactions financières
3. `game_configs` - Configurations des jeux
4. `audit_logs` - Journal d'audit
5. `feature_flags` - Feature flags
6. `responsible_gaming_limits` - Limites jeu responsable
7. `game_timeout_configs` - Configurations timeout jeux
8. `dice_game_results` - Résultats du jeu de dés

### Accéder à PostgreSQL

```bash
# Via psql
docker compose exec postgres psql -U wiwiga_user -d wiwiga_dev

# Voir les tables
\dt

# Voir les users
SELECT phone, name, balance FROM users;

# Quitter
\q
```

### Accéder à Redis

```bash
# Via redis-cli
docker compose exec redis redis-cli

# Tester la connexion
PING
# → PONG

# Voir les clés
KEYS *

# Quitter
QUIT
```

---

## 🛠️ Commandes Utiles

### Logs

```bash
# Tous les services
docker compose logs -f

# Uniquement le backend
docker compose logs -f backend

# 50 dernières lignes
docker compose logs --tail=50 backend
```

### Redémarrage

```bash
# Redémarrer un service
docker compose restart backend

# Arrêter tout
docker compose down

# Arrêter et supprimer les volumes (⚠️ perte de données)
docker compose down -v

# Reconstruire et relancer
docker compose up -d --build
```

### Base de Données

```bash
# Créer la DB (première fois)
docker compose exec backend mix ecto.create

# Exécuter les migrations
docker compose exec backend mix ecto.migrate

# Voir le statut des migrations
docker compose exec backend mix ecto.migrations

# Rollback dernière migration
docker compose exec backend mix ecto.rollback
```

### Monitoring

```bash
# Health checks détaillés
curl http://localhost:8000/api/health
curl http://localhost:8000/api/health/ready
curl http://localhost:8000/api/health/db
curl http://localhost:8000/api/health/redis

# Monitoring complet (script)
./docker-monitor.sh
```

---

## 🎮 Lancer le Frontend Flutter

### Prérequis

```bash
# Installer Flutter (si pas déjà fait)
# Voir: https://flutter.dev/docs/get-started/install
```

### Démarrage

```bash
cd /mnt/DONNEES/projets/wiwiga/wiwiga_app

# Installer les dépendances
flutter pub get

# Lancer en mode développement (port 8004)
flutter run -d chrome --web-port=8004

# Ou build pour production
flutter build web
```

### Configuration

Le frontend se connecte automatiquement au backend sur `http://localhost:8000`.

Pour changer l'URL du backend, modifier :
```
wiwiga_app/lib/core/config/app_config.dart
```

---

## 🐛 Dépannage

### Backend ne démarre pas

```bash
# 1. Vérifier les logs
docker compose logs backend

# 2. Redémarrer
docker compose down backend
docker compose up -d backend

# 3. Reconstruire l'image
docker compose build backend
docker compose up -d backend
```

### Erreur de connexion base de données

```bash
# Vérifier que PostgreSQL est healthy
docker compose ps

# Redémarrer PostgreSQL
docker compose restart postgres

# Vérifier les credentials
docker compose exec postgres psql -U wiwiga_user -d wiwiga_dev -c "SELECT 1;"
```

### Ports déjà utilisés

```bash
# Trouver quel processus utilise un port
lsof -i :8000
lsof -i :8001
lsof -i :8002

# Tuer le processus (si nécessaire)
kill -9 <PID>
```

### Frontend ne se connecte pas au backend

1. Vérifier que le backend tourne : `curl http://localhost:8000/api/health`
2. Vérifier la configuration dans `wiwiga_app/lib/core/config/app_config.dart`
3. Vérifier les logs du frontend dans la console du navigateur

---

## 📁 Structure du Projet

```
wiwiga/
├── docker-compose.yml          # Configuration Docker principale
├── Dockerfile.backend          # Image Docker backend
├── .env.example                # Template variables d'environnement
├── game_hub/                   # Backend Elixir/Phoenix
│   ├── apps/
│   │   ├── game_hub/           # Core business logic
│   │   ├── game_hub_web/       # Interface web API
│   │   └── dice_game/          # Plugin jeu de dés
│   ├── config/
│   │   └── dev.exs             # Configuration dev
│   └── priv/repo/
│       ├── migrations/         # Migrations DB
│       └── seeds.exs           # Données initiales
├── wiwiga_app/                 # Frontend Flutter
│   ├── lib/
│   │   ├── core/               # Config, network, utils
│   │   ├── data/               # Models, repositories
│   │   ├── domain/             # Entities, usecases
│   │   └── presentation/       # Screens, widgets, providers
│   └── pubspec.yaml
├── .qoder/                     # Configuration Qoder
│   ├── AGENTS.md
│   ├── rules/                  # Règles de développement
│   └── skills/                 # Skills spécialisés
└── DOCKER_CONSOLIDATION.md     # Documentation consolidation Docker
```

---

## 🔐 Sécurité - Production

### Variables d'Environnement Requises

```bash
# Copier le template
cp .env.example .env

# Générer des secrets sécurisés
mix phx.gen.secret  # Pour SECRET_KEY_BASE
mix phx.gen.secret  # Pour GUARDIAN_SECRET_KEY

# Remplir .env avec vos valeurs
nano .env
```

### Checklists Production

- [ ] Secrets générés et sécurisés
- [ ] HTTPS activé
- [ ] CORS restreint aux domaines autorisés
- [ ] Rate limiting activé
- [ ] Logs centralisés
- [ ] Backups DB automatisés
- [ ] Monitoring en place (Grafana/Prometheus)

---

## 📊 Monitoring & Métriques

### Health Checks

| Endpoint | Description | Utilisation |
|----------|-------------|-------------|
| `GET /api/health` | Santé globale | Load balancer |
| `GET /api/health/ready` | Prêt au trafic | Orchestration |
| `GET /api/health/db` | Métriques PostgreSQL | Monitoring DB |
| `GET /api/health/redis` | Métriques Redis | Monitoring Cache |

### Métriques Disponibles

- Latence database (ms)
- Latence Redis (ms)
- Connexions PostgreSQL actives
- Mémoire Redis utilisée
- Clients Redis connectés
- Version application
- Environment (dev/prod)

---

## 🎓 Ressources

### Documentation

- [DOCKER_CONSOLIDATION.md](DOCKER_CONSOLIDATION.md) - Détails de la consolidation Docker
- [README.md](README.md) - Documentation générale du projet
- [openapi.yaml](openapi.yaml) - Spécification API complète

### Scripts Utiles

- `docker-monitor.sh` - Monitoring complet des services
- `check-build.sh` - Vérification du build Docker
- `run-docker.sh` - Lancement avec vérifications
- `verify-backend.sh` - Vérification du backend

### Support

- **Email** : contact@wiwiga.com
- **Issues** : GitHub Issues
- **Documentation API** : http://localhost:8000/api/health

---

## ✅ Vérification Finale

Exécutez ce script pour vérifier que tout fonctionne :

```bash
#!/bin/bash
echo "🔍 Vérification WIWIGA..."

# 1. Docker
echo -e "\n📦 Services Docker :"
docker compose ps

# 2. Health Check
echo -e "\n🏥 Health Check :"
curl -s http://localhost:8000/api/health | python3 -m json.tool

# 3. API Games
echo -e "\n🎮 Games API :"
curl -s http://localhost:8000/api/games | python3 -m json.tool

# 4. Database
echo -e "\n🗄️ Database :"
docker compose exec postgres psql -U wiwiga_user -d wiwiga_dev -c "SELECT COUNT(*) as users FROM users;"

# 5. Redis
echo -e "\n📊 Redis :"
docker compose exec redis redis-cli ping

echo -e "\n✅ Vérification terminée !"
```

---

**Développé avec ❤️ par Franck Arlos CHENDJOU**  
**WIWIGA - Plateforme de Jeux avec Paiement Mobile**  
**Version 1.0 - Juin 2026**
