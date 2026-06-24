# 🎮 WIWIGA - Plateforme de Jeux avec Paiement Mobile

[![CI/CD](https://github.com/wiwiga/wiwiga/actions/workflows/ci.yml/badge.svg)](https://github.com/wiwiga/wiwiga/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/badge/coverage-78%25-yellowgreen)](https://github.com/wiwiga/wiwiga)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Plateforme de jeux en ligne avec authentification OTP, paiement Mobile Money (Campay), et matchmaking temps réel.

---

## 🚀 Démarrage Rapide

### Prérequis

- **Elixir** 1.15+ et **Erlang/OTP** 26+
- **PostgreSQL** 15+
- **Redis** 7+
- **curl**, **jq**, **openssl** (pour tests)

### Installation

```bash
# 1. Cloner le repository
git clone https://github.com/wiwiga/wiwiga.git
cd wiwiga

# 2. Configurer variables d'environnement
cp .env.example .env
nano .env  # Remplir avec vos valeurs

# 3. Installer dépendances
cd game_hub
mix deps.get

# 4. Créer et migrer base de données
mix ecto.create
mix ecto.migrate

# 5. Insérer données initiales
mix run priv/repo/seeds.exs

# 6. Lancer serveur
mix phx.server
```

**Serveur accessible sur**: http://localhost:4000

---

## 📋 Documentation API

### Swagger/OpenAPI

La documentation complète de l'API est disponible dans [openapi.yaml](openapi.yaml).

**Visualiser avec Swagger UI**:
```bash
# Option 1: En ligne
https://editor.swagger.io/?url=https://raw.githubusercontent.com/wiwiga/wiwiga/main/openapi.yaml

# Option 2: Localement
npm install -g swagger-ui-express
swagger-cli serve openapi.yaml
```

### Endpoints Principaux

| Méthode | Endpoint | Description | Auth |
|---------|----------|-------------|------|
| POST | `/api/auth/send-otp` | Envoyer code OTP | ❌ |
| POST | `/api/auth/verify-otp` | Vérifier OTP + JWT | ❌ |
| GET | `/api/wallet/balance` | Solde utilisateur | ✅ |
| POST | `/api/wallet/deposit` | Dépôt | ✅ |
| POST | `/api/wallet/withdraw` | Retrait | ✅ |
| GET | `/api/wallet/transactions` | Historique | ✅ |
| GET | `/api/games` | Liste jeux | ❌ |
| POST | `/api/games/:id/join` | Rejoindre partie | ✅ |
| POST | `/api/webhooks/campay` | Webhook paiement | 🔐 |

---

## 🧪 Tests

### Exécuter les Tests

```bash
# Tous les tests
cd /mnt/DONNEES/projets/wiwiga
./run_tests.sh --all

# Tests avec coverage
cd game_hub
mix test --cover

# Tests spécifiques
mix test apps/game_hub/test/game_hub/wallet_test.exs
mix test apps/game_hub/test/game_hub/auth_test.exs
mix test apps/game_hub/test/game_hub/integration_test.exs
```

### Tests Webhook Campay

```bash
# Simuler webhook
./test_campay_webhook.sh --all

# Test individuel
./test_campay_webhook.sh --success
./test_campay_webhook.sh --duplicate
```

### Coverage par Module

| Module | Coverage | Tests |
|--------|----------|-------|
| Wallet | 90%+ | 19 |
| Auth | 85%+ | 16 |
| Commission | 85%+ | 18 |
| PaymentWebhook | 80%+ | 15 |
| Matchmaking | 75%+ | 15 |
| GameController | 80%+ | 20 |
| **Intégration** | **-** | **8** |
| **TOTAL** | **~78%** | **111+** |

---

## 🏗️ Architecture

### Stack Technique

- **Backend**: Elixir/Phoenix 1.7+
- **Base de données**: PostgreSQL (Ecto ORM)
- **Cache/Matchmaking**: Redis (Redix)
- **Authentification**: JWT (Guardian)
- **WebSocket**: Phoenix Channels
- **Paiement**: Campay (Mobile Money)

### Structure du Projet

```
wiwiga/
├── game_hub/
│   ├── apps/
│   │   ├── game_hub/           # Core business logic
│   │   │   ├── lib/game_hub/
│   │   │   │   ├── auth.ex
│   │   │   │   ├── wallet.ex
│   │   │   │   ├── matchmaking.ex
│   │   │   │   ├── commission.ex
│   │   │   │   └── env_config.ex
│   │   │   └── test/
│   │   ├── game_hub_web/       # Web interface
│   │   │   ├── lib/game_hub_web/
│   │   │   │   ├── controllers/
│   │   │   │   ├── channels/
│   │   │   │   ├── auth_plug.ex
│   │   │   │   ├── cors_plug.ex
│   │   │   │   └── rate_limiter_plug.ex
│   │   │   └── test/
│   │   └── dice_game/          # Game plugin
│   └── priv/repo/
│       ├── migrations/
│       └── seeds.exs
├── .github/workflows/
│   └── ci.yml                  # CI/CD pipeline
├── .env.example                # Environment template
├── openapi.yaml                # API documentation
├── run_tests.sh                # Test runner
└── test_campay_webhook.sh      # Webhook simulator
```

---

## 🔐 Sécurité

### Features Implémentées

- ✅ **Secrets externalisés** - Variables d'environnement
- ✅ **JWT obligatoire** en production
- ✅ **CORS strict** - Configurable par domaine
- ✅ **Rate limiting** - 100 req/h par IP (Redis)
- ✅ **Transactions ACID** - Verrouillage pessimiste
- ✅ **Idempotence** - Anti-doublon sur toutes opérations
- ✅ **HMAC verification** - Signature webhooks
- ✅ **Health checks** - Monitoring DB + Redis

### Variables Requises Production

```bash
DATABASE_URL=postgresql://...
GUARDIAN_SECRET_KEY=<mix phx.gen.secret>
SECRET_KEY_BASE=<mix phx.gen.secret>
CAMPAY_WEBHOOK_SECRET_KEY=<votre secret>
ALLOWED_ORIGINS=https://yourdomain.com
```

---

## 🚀 Déploiement Production

### 1. Build Release

```bash
cd game_hub
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

### 2. Configurer Environment

```bash
# Créer fichier .env production
cat > .env << EOF
DATABASE_URL=postgresql://user:pass@host:5432/game_hub_prod
GUARDIAN_SECRET_KEY=$(mix phx.gen.secret)
SECRET_KEY_BASE=$(mix phx.gen.secret)
CAMPAY_WEBHOOK_SECRET_KEY=votre_secret_campay
ALLOWED_ORIGINS=https://wiwiga.com
ENABLE_RATE_LIMITING=true
EOF
```

### 3. Démarrer

```bash
source .env
_build/prod/rel/game_hub/bin/game_hub start
```

### 4. Vérifier Health

```bash
curl http://localhost:4000/api/health
curl http://localhost:4000/api/health/ready
```

---

## 📊 Monitoring

### Health Checks

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Santé globale |
| `GET /api/health/ready` | Prêt au trafic |
| `GET /api/health/db` | Métriques PostgreSQL |
| `GET /api/health/redis` | Métriques Redis |

### Métriques Disponibles

- Latence database (ms)
- Latence Redis (ms)
- Connexions PostgreSQL actives
- Mémoire Redis utilisée
- Clients Redis connectés
- Version application
- Environment (dev/prod)

---

## 📖 Guides

### Guides Disponibles

- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Guide complet des tests
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - État du projet
- [PRODUCTION_IMPROVEMENTS.md](PRODUCTION_IMPROVEMENTS.md) - Améliorations production
- [openapi.yaml](openapi.yaml) - Documentation API Swagger

### Exemples d'Utilisation

#### Authentification

```bash
# 1. Envoyer OTP
curl -X POST http://localhost:4000/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237612345678"}'

# 2. Vérifier OTP (remplacer 123456 par code reçu)
curl -X POST http://localhost:4000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237612345678", "otp": "123456"}'

# Réponse: {"data": {"token": "eyJ..."}}
```

#### Wallet

```bash
# Solde
curl http://localhost:4000/api/wallet/balance \
  -H "Authorization: Bearer <token>"

# Dépôt
curl -X POST http://localhost:4000/api/wallet/deposit \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000, "idempotency_key": "unique_123"}'

# Historique
curl http://localhost:4000/api/wallet/transactions?page=1&limit=20 \
  -H "Authorization: Bearer <token>"
```

#### Jeux

```bash
# Liste jeux
curl http://localhost:4000/api/games

# Rejoindre partie
curl -X POST http://localhost:4000/api/games/dice/join \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"bet_amount": 5000}'
```

---

## 🤝 Contribuer

### Workflow

1. Fork le projet
2. Créer branche feature (`git checkout -b feature/amazing-feature`)
3. Commit changements (`git commit -m 'Add amazing feature'`)
4. Push branche (`git push origin feature/amazing-feature`)
5. Ouvrir Pull Request

### CI/CD

GitHub Actions exécute automatiquement:
- ✅ Lint & Compile
- ✅ Tests (PostgreSQL + Redis)
- ✅ Security Audit (Sobelow)
- ✅ Build Release (main uniquement)

---

## 📝 License

Ce projet est sous license MIT. Voir [LICENSE](LICENSE) pour détails.

---

## 📞 Support

- **Documentation**: Voir fichiers `.md` dans repository
- **API Docs**: [openapi.yaml](openapi.yaml)
- **Issues**: GitHub Issues
- **Email**: contact@wiwiga.com

---

## 🎯 Roadmap

### Court Terme
- [ ] Tests de charge (k6)
- [ ] Docker containerization
- [ ] HTTPS nginx configuration
- [ ] Mobile apps (React Native)

### Moyen Terme
- [ ] Monitoring Grafana + Prometheus
- [ ] Centralized logging (ELK)
- [ ] Multi-region deployment
- [ ] Analytics dashboard

### Long Terme
- [ ] Microservices architecture
- [ ] CDN CloudFlare
- [ ] Machine learning (fraud detection)
- [ ] Internationalisation

---

**Développé avec ❤️ par Franck Arlos CHENDJOU**  
**WIWIGA - Plateforme de Jeux avec Paiement Mobile**
