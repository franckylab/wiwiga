# 🚀 WIWIGA - GUIDE DE DÉMARRAGE RAPIDE

## Ports configurés

| Service | Port | URL |
|---------|------|-----|
| **Backend API** | 8000 | http://localhost:8000 |
| **Frontend Flutter** | 8001 | http://localhost:8001 |
| **PostgreSQL** | 8002 | localhost:8002 |
| **Redis** | 8003 | localhost:8003 |

---

## Démarrage Backend (Docker)

```bash
cd /mnt/DONNEES/projets/wiwiga/game_hub

# Lancer tous les services (PostgreSQL + Redis + Phoenix)
docker compose up -d

# Voir les logs
docker compose logs -f web

# Arrêter
docker compose down
```

**Vérification :**
```bash
curl http://localhost:8000/api/health
```

---

## Démarrage Frontend (Flutter Web)

```bash
cd /mnt/DONNEES/projets/wiwiga/wiwiga_app

# Installer les dépendances
flutter pub get

# Lancer en mode développement (port 8001)
flutter run -d chrome --web-port=8001
```

**Ou build pour production :**
```bash
flutter build web
# Déployer le contenu de build/web/ sur un serveur
```

---

## Vérification des services

```bash
# PostgreSQL
docker compose exec postgres pg_isready -U wiwiga

# Redis
docker compose exec redis redis-cli ping

# Backend API
curl http://localhost:8000

# Frontend
# Ouvrir http://localhost:8001 dans le navigateur
```

---

## Base de données

```bash
# Créer la base (première fois)
docker compose exec web mix ecto.create

# Exécuter les migrations
docker compose exec web mix ecto.migrate

# Voir le statut des migrations
docker compose exec web mix ecto.migrations

# Rollback dernière migration
docker compose exec web mix ecto.rollback
```

---

## Logs en temps réel

```bash
# Backend
docker compose logs -f web

# PostgreSQL
docker compose logs -f postgres

# Redis
docker compose logs -f redis

# Tous les services
docker compose logs -f
```

---

## Redémarrage complet

```bash
cd /mnt/DONNEES/projets/wiwiga/game_hub

# Arrêter et supprimer tout
docker compose down -v

# Reconstruire et relancer
docker compose up --build -d
```

---

## Accès aux services

- **API Backend:** http://localhost:8000
- **Frontend Web:** http://localhost:8001
- **PostgreSQL:** localhost:8002 (user: wiwiga_user, password: wiwiga_password)
- **Redis:** localhost:8003

---

## Identifiants par défaut

### Super Admin
- **Email:** admin@wiwiga.com
- **Téléphone:** +237699999999
- **Mot de passe:** AdminSecret123!
- **Solde initial:** 10 000 FCFA

### Utilisateur Test
- **Email:** test@wiwiga.com
- **Téléphone:** +237688888888
- **Mot de passe:** Test123456!
- **Solde initial:** 5 000 FCFA

---

## Structure des URLs API

```
POST   http://localhost:8000/api/auth/login         # Envoi OTP
POST   http://localhost:8000/api/auth/verify        # Vérification OTP
GET    http://localhost:8000/api/wallet/balance     # Solde
POST   http://localhost:8000/api/wallet/deposit     # Dépôt
GET    http://localhost:8000/api/games              # Liste des jeux
POST   http://localhost:8000/api/games/join         # Rejoindre file
WS     ws://localhost:8000/socket/websocket         # WebSocket temps réel
```

---

## Dépannage

### Backend ne démarre pas
```bash
docker compose down
docker compose up --build -d
docker compose logs -f web
```

### Erreur de connexion base de données
```bash
# Vérifier que PostgreSQL est healthy
docker compose ps

# Redémarrer PostgreSQL
docker compose restart postgres
```

### Frontend ne se connecte pas au backend
- Vérifier que le backend tourne sur le port 8000
- Vérifier la configuration dans `wiwiga_app/lib/core/config/app_config.dart`
- URL doit être: `http://localhost:8000`

---

## Notes importantes

1. **Docker** doit être installé et en cours d'exécution
2. **Flutter** doit être installé pour le frontend
3. Les ports 8000-8003 doivent être disponibles
4. Premier démarrage : le build Docker prend 2-5 minutes
