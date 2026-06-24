# WIWIGA - Monitoring & Logging Guide

**Version**: 1.0 - Juin 2026  
**Stack**: Prometheus + Grafana + ELK (Elasticsearch, Logstash, Kibana)

---

## 📊 Vue d'Ensemble

Le stack de monitoring WIWIGA comprend :

| Service | Port | Rôle | URL |
|---------|------|------|-----|
| **Prometheus** | 9090 | Collecte métriques | http://localhost:9090 |
| **Grafana** | 3000 | Dashboards visualisation | http://localhost:3000 |
| **Elasticsearch** | 9200 | Stockage logs | http://localhost:9200 |
| **Logstash** | 5044, 5000 | Collecte/transformation logs | - |
| **Kibana** | 5601 | Visualisation logs | http://localhost:5601 |
| **Node Exporter** | 9100 | Métriques système | http://localhost:9100 |

---

## 🚀 Démarrage Rapide

### 1. Lancer le Stack Monitoring

```bash
cd /mnt/DONNEES/projets/wiwiga

# Démarrer tous les services de monitoring
docker compose -f docker-compose.monitoring.yml up -d

# Vérifier que tout tourne
docker compose -f docker-compose.monitoring.yml ps
```

### 2. Accéder aux Interfaces

**Grafana** (Dashboards) :
- URL : http://localhost:3000
- Login : `admin`
- Password : `wiwiga_admin`

**Prometheus** (Métriques brutes) :
- URL : http://localhost:9090
- Interface de requête intégrée

**Kibana** (Logs) :
- URL : http://localhost:5601
- Pas d'authentification (développement)

---

## 📈 Dashboards Grafana

### Dashboards Pré-configurés

1. **WIWIGA Backend Overview**
   - Health check status
   - Response times
   - Request rates
   - Error rates

2. **PostgreSQL Monitoring**
   - Connection pool
   - Query performance
   - Database size
   - Transaction rates

3. **Redis Monitoring**
   - Memory usage
   - Connected clients
   - Command rates
   - Hit/miss ratio

4. **System Resources**
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network traffic

### Importer un Dashboard

1. Aller dans Grafana : http://localhost:3000
2. Cliquer sur "+" → Import
3. Entrer l'ID du dashboard ou uploader un JSON
4. Sélectionner la datasource Prometheus
5. Cliquer sur "Import"

### Dashboards Recommandés (Grafana.com)

- **Node Exporter** : ID `1860`
- **PostgreSQL** : ID `9628`
- **Redis** : ID `763`
- **Docker** : ID `893`

---

## 🔍 Prometheus - Requêtes Utiles

### Backend Health

```promql
# Health check success rate
sum(rate(http_requests_total{job="wiwiga_backend", status="200"}[5m])) 
/ 
sum(rate(http_requests_total{job="wiwiga_backend"}[5m]))
```

### Response Times

```promql
# 95th percentile response time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Error Rates

```promql
# Error rate per minute
rate(http_requests_total{status=~"5.."}[5m])
```

---

## 📝 Kibana - Exploration Logs

### Index Pattern

1. Aller dans Kibana : http://localhost:5601
2. Stack Management → Index Patterns
3. Créer un index pattern : `wiwiga-logs-*`
4. Time field : `@timestamp`

### Requêtes Utiles

**Voir tous les logs backend** :
```
type: wiwiga_backend
```

**Voir les erreurs** :
```
level: ERROR
```

**Voir les logs d'une heure spécifique** :
```
type: wiwiga_backend AND @timestamp:[now-1h TO now]
```

**Recherche full-text** :
```
"wallet" OR "transaction" OR "error"
```

---

## 🔔 Alertes

### Configurer des Alertes Grafana

1. Aller dans Alerting → Alert Rules
2. Créer une nouvelle règle
3. Définir la condition (ex: error rate > 5%)
4. Configurer les notifications (email, Slack, webhook)

### Alertes Recommandées

- **Backend down** : Health check fails 3 times in 5 minutes
- **High error rate** : > 5% errors in 10 minutes
- **Slow responses** : P95 response time > 2s
- **Database connections** : > 80% pool used
- **Disk space** : < 10% free
- **Memory usage** : > 90% used

---

## 🔧 Configuration Avancée

### Backend - Exposer des Métriques Custom

Ajoutez dans `game_hub/config/config.exs` :

```elixir
# Ajouter telemetry pour métriques custom
config :telemetry_poller, :default,
  period: 10_000,
  metrics: [
    {:process_info, event: :backend_memory, name: GameHub.Application, keys: [:memory]},
    {:vm, event: :backend_vm, keys: [:total_memory, :process_count]}
  ]
```

### Logstash - Parser Custom

Modifier `monitoring/logstash/pipeline/logstash.conf` pour ajouter des parsers spécifiques.

### Prometheus - Alertes

Créer `monitoring/prometheus/alerts.yml` :

```yaml
groups:
  - name: wiwiga_alerts
    rules:
      - alert: BackendDown
        expr: up{job="wiwiga_backend"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "WIWIGA Backend is down"
```

---

## 🐛 Dépannage

### Prometheus ne scrape pas le backend

```bash
# Vérifier la connectivité
docker compose -f docker-compose.monitoring.yml exec prometheus wget -qO- http://wiwiga_backend:4001/api/health

# Vérifier la configuration
docker compose -f docker-compose.monitoring.yml exec prometheus cat /etc/prometheus/prometheus.yml
```

### Elasticsearch ne stocke pas les logs

```bash
# Vérifier le statut du cluster
curl http://localhost:9200/_cluster/health?pretty

# Voir les index
curl http://localhost:9200/_cat/indices?v

# Voir les logs Logstash
docker compose -f docker-compose.monitoring.yml logs -f logstash
```

### Grafana ne voit pas Prometheus

```bash
# Vérifier la datasource
curl http://admin:wiwiga_admin@localhost:3000/api/datasources

# Tester la connexion
curl http://localhost:3000/api/health
```

---

## 📊 Métriques Clés à Surveiller

### Backend (Phoenix)

- ✅ Health check status
- ✅ Request rate (req/s)
- ✅ Error rate (%)
- ✅ Response time (P50, P95, P99)
- ✅ Active WebSocket connections
- ✅ ETS memory usage

### PostgreSQL

- ✅ Active connections
- ✅ Query duration
- ✅ Database size
- ✅ Transaction rate
- ✅ Cache hit ratio
- ✅ Deadlocks

### Redis

- ✅ Memory usage
- ✅ Connected clients
- ✅ Commands per second
- ✅ Hit/miss ratio
- ✅ Evicted keys
- ✅ Uptime

### Système

- ✅ CPU usage (%)
- ✅ Memory usage (GB)
- ✅ Disk usage (%)
- ✅ Network I/O (MB/s)
- ✅ Load average

---

## 🎓 Bonnes Pratiques

1. **Rétention des données**
   - Prometheus : 200h par défaut (configurable)
   - Elasticsearch : Rotation quotidienne des index
   - Grafana : Sauvegarde des dashboards

2. **Sécurité**
   - Changer les mots de passe par défaut en production
   - Activer HTTPS
   - Restreindre l'accès aux IPs autorisées
   - Activer l'authentification Elasticsearch

3. **Performance**
   - Ajuster `scrape_interval` selon les besoins
   - Utiliser des recordings rules pour les requêtes complexes
   - Limiter la taille des logs Elasticsearch

4. **Monitoring du Monitoring**
   - Surveiller Prometheus lui-même
   - Alertes sur la disponibilité du stack
   - Backups réguliers des configurations

---

## 📁 Structure des Fichiers

```
monitoring/
├── prometheus/
│   └── prometheus.yml          # Configuration Prometheus
├── grafana/
│   ├── provisioning/           # Datasources auto-config
│   └── dashboards/             # Dashboards JSON
├── logstash/
│   ├── config/
│   │   └── logstash.yml        # Configuration Logstash
│   └── pipeline/
│       └── logstash.conf       # Pipeline de traitement
└── MONITORING_GUIDE.md         # Ce fichier
```

---

## 🚀 Prochaines Étapes

- [ ] Configurer les alertes Slack/Email
- [ ] Créer des dashboards custom métier
- [ ] Mettre en place les backups automatiques
- [ ] Activer HTTPS pour toutes les interfaces
- [ ] Configurer Filebeat pour logs Docker
- [ ] Ajouter des traces distribuées (Jaeger/Zipkin)

---

**Développé avec ❤️ par Franck Arlos CHENDJOU**  
**WIWIGA - Monitoring Stack v1.0**
