# 📡 WIWIGA Backend - Documentation API Complète

**Version:** 1.0  
**Date:** 2026-06-24  
**Base URL:** `http://localhost:4001/api`  
**WebSocket:** `ws://localhost:4001/socket`

---

## 🔐 Authentification

### Header Requis
```
Authorization: Bearer <JWT_TOKEN>
```

### Obtenir Token
1. `POST /api/auth/register` - Créer compte
2. `POST /api/auth/login` - Obtenir JWT

---

## 📋 Endpoints Publics

### Health Check
```http
GET /api/health
```

**Response 200:**
```json
{
  "status": "ok",
  "timestamp": "2026-06-24T10:30:00Z",
  "version": "1.0.0"
}
```

---

## 👤 Authentification

### Register
```http
POST /api/auth/register
Content-Type: application/json

{
  "phone": "+237699999999",
  "name": "Jean Dupont"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "phone": "+237699999999",
    "name": "Jean Dupont",
    "balance": 0,
    "has_verified_kyc": false
  }
}
```

### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "phone": "+237699999999"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "phone": "+237699999999",
      "name": "Jean Dupont"
    }
  }
}
```

---

## 💰 Portefeuille

### Balance
```http
GET /api/users/balance
Authorization: Bearer <TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "balance": 500000,
    "currency": "XAF"
  }
}
```

### Historique Transactions
```http
GET /api/users/transactions?page=1&limit=20
Authorization: Bearer <TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "type": "deposit",
      "amount": 100000,
      "balance_before": 400000,
      "balance_after": 500000,
      "idempotency_key": "webhook_campay_123",
      "inserted_at": "2026-06-24T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "total_pages": 3,
    "has_next": true,
    "has_prev": false
  }
}
```

---

## 🎮 Jeux

### Liste Jeux
```http
GET /api/games
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "dice",
      "name": "Jeu de Dés",
      "description": "Pariez sur la somme des dés",
      "min_bet": 100,
      "max_bet": 1000000,
      "commission_rate": 0.05,
      "status": "active",
      "players_online": 15
    }
  ]
}
```

### Détails Jeu
```http
GET /api/games/dice
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "dice",
    "name": "Jeu de Dés",
    "min_bet": 100,
    "max_bet": 1000000,
    "commission_rate": 0.05,
    "commission_mode": "percentage",
    "config": {
      "min_dice": 1,
      "max_dice": 6,
      "number_of_dice": 2
    }
  }
}
```

### Rejoindre Partie
```http
POST /api/games/dice/join
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "bet_amount": 500
}
```

**Flow:**
1. Vérification ResponsibleGaming (auto-exclusion, limites)
2. Débit portefeuille (ACID transaction)
3. Calcul commission
4. Matchmaking Redis

**Response 202 (en attente):**
```json
{
  "success": true,
  "data": {
    "status": "waiting",
    "message": "En file d'attente...",
    "bet_amount": 500
  }
}
```

**Response 200 (match trouvé):**
```json
{
  "success": true,
  "data": {
    "status": "matched",
    "game_id": "dice_123456_1719230400000",
    "message": "Partie trouvée !",
    "bet_amount": 500,
    "max_commission": 25
  }
}
```

### État Partie
```http
GET /api/games/dice_123456/state
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "game_id": "dice_123456",
    "status": "in_progress",
    "players": ["user_1", "user_2"],
    "game_type": "dice"
  }
}
```

---

## 💳 Paiements

### Initialiser Dépôt
```http
POST /api/payments/initiate
Authorization: Bearer <TOKEN>
Content-Type: application/json

{
  "amount": 100000,
  "provider": "campay",
  "phone": "+237699999999"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "payment_id": "pay_123",
    "amount": 100000,
    "status": "pending",
    "message": "Vérifiez votre téléphone pour confirmer le paiement"
  }
}
```

### Webhook Campay
```http
POST /api/payments/webhook/campay
Content-Type: application/json

{
  "reference": "CAMPAY_123",
  "amount": 100000,
  "from": "+237699999999",
  "status": "SUCCESS"
}
```

**Response 200:**
```json
{
  "success": true
}
```

---

## 🛡️ Admin (Auth + Admin Requis)

### Liste Utilisateurs
```http
GET /api/admin/users?page=1&limit=20
Authorization: Bearer <ADMIN_TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "phone": "+237699999999",
      "name": "Jean Dupont",
      "balance": 500000,
      "is_active": true,
      "has_verified_kyc": true
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```

### Logs d'Audit
```http
GET /api/admin/audit-logs?action=deposit&page=1&limit=50
Authorization: Bearer <ADMIN_TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "action": "deposit",
      "user_id": 1,
      "entity_type": "wallet",
      "changes": {
        "amount": 100000,
        "balance_before": 400000,
        "balance_after": 500000
      },
      "ip_address": "192.168.1.100",
      "inserted_at": "2026-06-24T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 1234,
    "total_pages": 25
  }
}
```

### Feature Flags
```http
POST /api/admin/feature-flags
Authorization: Bearer <ADMIN_TOKEN>
Content-Type: application/json

{
  "flag_name": "new_dice_animation",
  "enabled": true,
  "percentage_rollout": 10,
  "description": "Nouvelle animation de dés"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "flag_name": "new_dice_animation",
    "enabled": true,
    "percentage_rollout": 10
  }
}
```

### Réconciliation Manuelle
```http
POST /api/admin/reconciliation
Authorization: Bearer <ADMIN_TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "status": "completed",
    "checked": 150,
    "mismatched": 0,
    "alerts": [],
    "duration_ms": 2345,
    "executed_at": "2026-06-24T12:00:00Z"
  }
}
```

### Statistiques
```http
GET /api/admin/stats
Authorization: Bearer <ADMIN_TOKEN>
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "total_users": 150,
    "total_transactions": 2345,
    "total_balance": 75000000,
    "active_games": 12,
    "timestamp": "2026-06-24T12:00:00Z"
  }
}
```

---

## 🔌 WebSocket

### Connexion
```javascript
const socket = new WebSocket('ws://localhost:4001/socket');

socket.onopen = () => {
  console.log('Connected');
};

socket.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Event:', data.event, data.payload);
};
```

### Événements

#### Matchmaking
```json
{
  "event": "matchmaking:join",
  "payload": {
    "game_type": "dice",
    "bet_amount": 500
  }
}
```

#### Partie Trouvée
```json
{
  "event": "matchmaking:matched",
  "payload": {
    "game_id": "dice_123456",
    "opponent_id": "user_2",
    "bet_amount": 500
  }
}
```

#### Résultat Dés
```json
{
  "event": "game:dice_rolled",
  "payload": {
    "game_id": "dice_123456",
    "dice_results": [3, 5],
    "total_sum": 8,
    "winner_id": "user_1",
    "payout": 950
  }
}
```

---

## ❌ Format d'Erreurs

### Standard
```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Solde insuffisant pour effectuer cette opération",
    "details": {
      "required": 1000,
      "available": 500
    }
  },
  "timestamp": "2026-06-24T10:30:00Z"
}
```

### Codes d'Erreur

| Code | HTTP | Description |
|------|------|-------------|
| `VALIDATION_ERROR` | 400 | Erreur validation |
| `INSUFFICIENT_FUNDS` | 400 | Solde insuffisant |
| `UNAUTHORIZED` | 401 | Non authentifié |
| `FORBIDDEN` | 403 | Non autorisé |
| `RESPONSIBLE_GAMING_BLOCK` | 403 | Jeu responsable |
| `NOT_FOUND` | 404 | Ressource non trouvée |
| `CONFLICT` | 409 | Conflit |
| `GAME_ALREADY_STARTED` | 409 | Jeu déjà commencé |
| `IDEMPOTENCY_KEY_USED` | 409 | Clé déjà utilisée |
| `SELF_EXCLUDED` | 403 | Auto-exclu |
| `DAILY_LIMIT_REACHED` | 403 | Limite atteinte |

---

## 🔒 Sécurité

### Headers Obligatoires (toutes réponses)
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `Content-Security-Policy: default-src 'self'`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`

### CORS
Origines autorisées :
- `http://localhost:3000`
- `http://localhost:8080`
- `https://wiwiga.com`
- `https://app.wiwiga.com`

---

## 📝 Notes Importantes

### Montants
- **Unité:** Centimes XAF (1 FCFA = 100 centimes)
- **Exemple:** 1000 FCFA = 100000 centimes

### Pagination
- **Défaut:** page=1, limit=20
- **Maximum:** limit=100
- **Toujours incluse** dans réponse

### Idempotence
- **Requis pour:** Webhooks, dépôts, retraits
- **Header:** `Idempotency-Key: <unique_key>`
- **TTL:** 24 heures

### Rate Limiting
- **OTP SMS:** 3 envois/heure
- **Login:** 5 tentatives/15 min
- **API:** 100 req/min

---

## 🧪 Exemples cURL

### Register + Login
```bash
# Register
curl -X POST http://localhost:4001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237699999999", "name": "Test User"}'

# Login
TOKEN=$(curl -X POST http://localhost:4001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone": "+237699999999"}' | jq -r '.data.token')

# Rejoindre jeu
curl -X POST http://localhost:4001/api/games/dice/join \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"bet_amount": 500}'
```

---

**Documentation générée automatiquement - 2026-06-24**  
**WIWIGA Backend API v1.0**
