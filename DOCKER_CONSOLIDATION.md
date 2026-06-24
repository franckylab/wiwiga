# 🔄 WIWIGA - Docker Consolidation & Port Standardization

**Date**: 24 Juin 2026  
**Type**: Refactoring infrastructure  
**Impact**: Configuration Docker, ports, credentials, documentation

---

## 📋 Résumé des Changements

### 1️⃣ Suppression des Fichiers Obsolètes

**Fichiers supprimés** :
- ❌ `game_hub/docker-compose.yml` (configuration Docker redondante/obsolète)
- ❌ `game_hub/Dockerfile` (Dockerfile alternatif non utilisé)

**Raison** :
- Configuration Docker unique à la racine du projet (meilleure pratique)
- Éviter la confusion entre deux fichiers de configuration différents
- Source de vérité unique pour l'orchestration Docker

---

### 2️⃣ Standardisation des Ports

**Fichier modifié** : `docker-compose.yml` (racine)

| Service | Ancien Port | Nouveau Port | Mapping (hôte:container) |
|---------|-------------|--------------|--------------------------|
| **Backend API** | 4001 | **8000** | `8000:4001` |
| **PostgreSQL** | 5432 | **8001** | `8001:5432` |
| **Redis** | 6379 | **8002** | `8002:6379` |
| **Frontend Flutter** | - | **8004** | N/A (lancé séparément) |

**Important** :
- ✅ Ports **internes** aux containers inchangés (5432, 6379, 4001)
- ✅ Seuls les ports **exposés** sur l'hôte ont changé
- ✅ Communication inter-containers fonctionne toujours sur les ports internes

---

### 3️⃣ Standardisation des Credentials PostgreSQL

| Paramètre | Ancien | Nouveau |
|-----------|--------|---------|
| **User** | `wiwiga` | `wiwiga_user` |
| **Password** | `wiwiga_secret` | `wiwiga_password` |
| **Database** | `game_hub_dev` | `wiwiga_dev` |

**Fichiers impactés** :
- ✅ `docker-compose.yml` (environnement PostgreSQL + DATABASE_URL)
- ✅ `.env.example` (urls de connexion)
- ✅ `docker-monitor.sh` (commandes psql)
- ✅ `STARTUP_GUIDE.md` (documentation)

---

### 4️⃣ Mises à Jour Documentaires

**Fichiers mis à jour** (13 fichiers) :

#### Documentation principale
- ✅ `README.md`
- ✅ `STARTUP_GUIDE.md` (ports, credentials, chemins Docker)
- ✅ `.env.example` (DATABASE_URL, REDIS_URL)
- ✅ `.qoder/AGENTS.md` (structure + config Docker)

#### Documentation Docker
- ✅ `BUILD_SUCCESS.md`
- ✅ `IMPLEMENTATION_COMPLETE_FINAL.md`
- ✅ `SESSION_FINAL_REPORT.md`
- ✅ `DOCKER_QUICKSTART.md`
- ✅ `DOCKER_COMPLETE.md`
- ✅ `DOCKER_SESSION_SUMMARY.md`
- ✅ `DOCKER_BUILD_STATUS.md`
- ✅ `IMPLEMENTATION_COMPLETE.md`

#### Scripts Shell
- ✅ `check-build.sh`
- ✅ `run-docker.sh`
- ✅ `verify-backend.sh`
- ✅ `docker-monitor.sh`

---

## 🎯 Avantages de Cette Consolidation

### ✅ Meilleures Pratiques Appliquées

1. **Single Source of Truth** : Un seul `docker-compose.yml` à la racine
2. **Ports Personnalisés** : Évite les conflits avec d'autres projets locaux
3. **Noms Explicites** : `wiwiga_user` plus clair que `wiwiga`
4. **Documentation Cohérente** : Tous les fichiers reflètent la même configuration
5. **Séparation Hôte/Container** : Ports internes vs exposés clairement distingués

### ✅ Maintenance Simplifiée

- Configuration Docker centralisée
- Moins de fichiers à maintenir
- Documentation uniforme
- Scripts cohérents

---

## 🚀 Comment Utiliser la Nouvelle Configuration

### Démarrage Rapide

```bash
# 1. Aller à la racine du projet
cd /mnt/DONNEES/projets/wiwiga

# 2. Lancer tous les services
docker compose up -d

# 3. Vérifier le status
docker compose ps

# 4. Tester l'API
curl http://localhost:8000/api/health

# 5. Voir les logs
docker compose logs -f backend
```

### Accès aux Services

| Service | URL | Port | Usage |
|---------|-----|------|-------|
| **Backend API** | http://localhost:8000 | 8000 | API REST + WebSocket |
| **Health Check** | http://localhost:8000/api/health | 8000 | Monitoring |
| **WebSocket** | ws://localhost:8000/socket | 8000 | Temps réel |
| **PostgreSQL** | localhost | 8001 | via psql/DBeaver |
| **Redis** | localhost | 8002 | via redis-cli |
| **Frontend** | http://localhost:8004 | 8004 | Flutter web (à lancer) |

### Frontend Flutter

```bash
cd /mnt/DONNEES/projets/wiwiga/wiwiga_app
flutter pub get
flutter run -d chrome --web-port=8004
```

---

## ⚠️ Points d'Attention

### Pour les Développeurs

1. **Ports changés** : Mettre à jour vos configurations IDE/outils
2. **Credentials** : Utiliser `wiwiga_user`/`wiwiga_password`
3. **Base de données** : Nom changé pour `wiwiga_dev`
4. **Anciens fichiers** : `game_hub/docker-compose.yml` n'existe plus

### Migration depuis Ancienne Configuration

```bash
# 1. Arrêter et nettoyer les anciens containers
docker compose down -v

# 2. Supprimer les volumes obsolètes (si nécessaire)
docker volume prune

# 3. Relancer avec nouvelle config
docker compose up -d

# 4. Recréer la base
docker compose exec backend mix ecto.create
docker compose exec backend mix ecto.migrate
```

---

## 📊 Impact sur l'Architecture

```
Avant:
├── docker-compose.yml (racine) → ports 4001/5432/6379
└── game_hub/docker-compose.yml → ports 8000/8002/8003 ❌ REDONDANT

Après:
└── docker-compose.yml (racine) → ports 8000/8001/8002 ✅ UNIQUE
```

### Communication Inter-Containers (Inchangée)

```yaml
# Dans docker-compose.yml, les URLs internes restent:
DATABASE_URL: postgresql://wiwiga_user:wiwiga_password@postgres:5432/wiwiga_dev
REDIS_URL: redis://redis:6379
```

Les containers communiquent entre eux via le réseau Docker interne sur les ports standards (5432, 6379), indépendamment des ports exposés sur l'hôte.

---

## ✅ Vérification Post-Migration

```bash
# 1. Tous les services sont UP
docker compose ps
# → 3 services "Up" et "healthy"

# 2. Backend répond
curl http://localhost:8000/api/health
# → {"status":"healthy",...}

# 3. PostgreSQL accessible
docker compose exec postgres pg_isready -U wiwiga_user
# → accepting connections

# 4. Redis accessible
docker compose exec redis redis-cli ping
# → PONG

# 5. Base de données existe
docker compose exec backend mix ecto.migrations
# → Liste des migrations
```

---

## 📝 Notes Techniques

### Pourquoi ces ports ?

- **8000** : Standard pour les APIs web (proche de 8080)
- **8001** : PostgreSQL (suite logique)
- **8002** : Redis (suite logique)
- **8004** : Frontend Flutter (séparé du backend)

### Pourquoi ces credentials ?

- `wiwiga_user` : Plus explicite que `wiwiga` (qui peut être ambigu)
- `wiwiga_password` : Cohérent avec la naming convention
- `wiwiga_dev` : Nom de base cohérent avec le projet

### Ports internes vs exposés

```
Hôte (votre machine)          Container Docker
      ↓                              ↓
   Port 8000  ──────────────→   Port 4001
   Port 8001  ──────────────→   Port 5432
   Port 8002  ──────────────→   Port 6379

Communication inter-containers:
   backend → postgres:5432 (port interne, pas 8001)
   backend → redis:6379 (port interne, pas 8002)
```

---

## 🎓 Leçons Apprises

1. **Toujours avoir un seul fichier Docker Compose** par projet
2. **Documenter les ports dans un fichier central** (STARTUP_GUIDE.md)
3. **Distinguer clairement ports hôte vs ports container**
4. **Utiliser des noms explicites** pour users et bases de données
5. **Mettre à jour TOUS les fichiers** lors d'un changement de configuration

---

**Statut**: ✅ **COMPLÉTÉ**  
**Validation**: Tous les fichiers mis à jour et vérifiés  
**Prochaines étapes**: Tester avec `docker compose up -d`
