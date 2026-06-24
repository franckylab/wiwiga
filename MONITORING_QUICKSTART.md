# 🚀 WIWIGA - Accès Rapide aux Services de Monitoring

## ✅ Services Actifs

### Application Principale
| Service | URL | Port | Identifiants |
|---------|-----|------|--------------|
| **Backend API** | http://localhost:8000 | 8000 | - |
| **PostgreSQL** | localhost:8001 | 8001 | wiwiga_user / wiwiga_password |
| **Redis** | localhost:8002 | 8002 | - |

### Stack de Monitoring
| Service | URL | Port | Identifiants |
|---------|-----|------|--------------|
| **Prometheus** | http://localhost:9090 | 9090 | - |
| **Grafana** | http://localhost:3000 | 3000 | admin / wiwiga_admin |
| **Elasticsearch** | http://localhost:9300 | 9300 | - |
| **Kibana** | http://localhost:5700 | 5700 | - |
| **Node Exporter** | http://localhost:9200 | 9200 | - |
| **Logstash** | - | 5144 (beats), 5500 (tcp) | - |

## 📊 Accès Rapide

### 1. Grafana - Dashboards
```
URL: http://localhost:3000
Login: admin
Password: wiwiga_admin
```

**Datasources pré-configurées:**
- ✅ Prometheus (défaut)
- ✅ Elasticsearch (wiwiga-logs-*)

**Dashboards pré-chargés:**
- ✅ WIWIGA - Backend Overview (métriques système, backend, DB, Redis)

### 2. Prometheus - Métriques
```
URL: http://localhost:9090
```

**Targets configurées:**
- wiwiga_backend (health check)
- postgresql
- redis
- node_exporter (système)
- prometheus (auto-monitoring)

**Exemples de requêtes:**
```promql
# Backend up/down
up{job="wiwiga_backend"}

# CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory used
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes
```

### 3. Kibana - Logs
```
URL: http://localhost:5700
```

**Index pattern:** `wiwiga-logs-*`

**Utilisation:**
1. Aller dans **Discover**
2. Créer l'index pattern `wiwiga-logs-*`
3. Explorer les logs avec filtres:
   - `level: ERROR` - Voir les erreurs
   - `service: wiwiga` - Tous les logs WIWIGA
   - `environment: development` - Filtre par environnement

### 4. Elasticsearch - API
```
URL: http://localhost:9300

# Santé du cluster
curl http://localhost:9300/_cluster/health?pretty

# Lister les index
curl http://localhost:9300/_cat/indices?v

# Rechercher dans les logs
curl -X GET "http://localhost:9300/wiwiga-logs-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": { "match": { "level": "ERROR" } }
}'
```

## 🔧 Commandes Utiles

### Lancer la stack complète
```bash
# Application principale
docker compose up -d

# Stack monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

### Arrêter la stack monitoring
```bash
docker compose -f docker-compose.monitoring.yml down
```

### Vérifier l'état des services
```bash
# Application principale
docker compose ps

# Stack monitoring
docker compose -f docker-compose.monitoring.yml ps
```

### Voir les logs
```bash
# Backend
docker logs wiwiga_backend -f

# Elasticsearch
docker logs wiwiga_elasticsearch -f

# Logstash
docker logs wiwiga_logstash -f

# Kibana
docker logs wiwiga_kibana -f
```

### Redémarrer un service
```bash
docker compose -f docker-compose.monitoring.yml restart <service>
# Ex: restart elasticsearch, restart grafana
```

## 📁 Structure des Fichiers

```
monitoring/
├── prometheus/
│   └── prometheus.yml          # Configuration Prometheus
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml # Datasources auto-configurées
│   │   └── dashboards/
│   │       └── dashboards.yml  # Provisioning dashboards
│   └── dashboards/
│       └── wiwiga-backend-overview.json  # Dashboard personnalisé
├── logstash/
│   ├── config/
│   │   └── logstash.yml        # Config Logstash
│   └── pipeline/
│       └── logstash.conf       # Pipeline log processing
└── MONITORING_GUIDE.md         # Guide détaillé
```

## ⚠️ Notes Importantes

### Espace Disque Elasticsearch
- **Problem**: Elasticsearch nécessite beaucoup d'espace disque
- **Solution**: Watermarks configurés à 95%/97%/98% pour tolérer l'espace limité
- **Monitoring**: Vérifier régulièrement `curl http://localhost:9300/_cluster/health?pretty`

### Ports Modifiés
Les ports ont été changés pour éviter les conflits:
- Elasticsearch: 9300 (au lieu de 9200)
- Kibana: 5700 (au lieu de 5601)
- Node Exporter: 9200 (au lieu de 9100)
- Logstash: 5144/5500 (au lieu de 5044/5000)

### Logstash - Envoi de Logs
Pour envoyer des logs du backend à Logstash:
```elixir
# Dans config/dev.exs (optionnel)
config :logger, :logstash,
  host: 'localhost',
  port: 5500,
  formatter: LoggerJSON.Formatters.BasicLogger
```

Ou via TCP directement:
```bash
echo '{"message":"Test log","level":"info","@timestamp":"2026-06-24T10:00:00Z"}' | nc localhost 5500
```

## 🎯 Prochaines Étapes

1. **Configurer l'envoi de logs** du backend Phoenix vers Logstash
2. **Créer des dashboards Grafana** avancés (business metrics, user analytics)
3. **Configurer des alertes** Prometheus (backend down, DB errors, high latency)
4. **Mettre en place des visualizations Kibana** (error rates, request patterns)
5. **Automatiser les backups** Elasticsearch et Prometheus

## 📞 Support

- Guide complet: `monitoring/MONITORING_GUIDE.md`
- Guide démarrage: `GUIDE_DEMARRAGE_FINAL.md`
- Documentation API: `API_DOCUMENTATION.md`
