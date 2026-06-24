#!/bin/bash
# ==================================
# WIWIGA - Monitoring Stack Management Script
# ==================================
# Usage: ./monitor.sh [command]
# Commands: start, stop, status, logs, restart, clean, health

set -e

COMPOSE_FILE="docker-compose.monitoring.yml"
PROJECT_NAME="wiwiga"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_services() {
    if ! docker compose -f $COMPOSE_FILE ps >/dev/null 2>&1; then
        print_error "Docker Compose n'est pas disponible ou le fichier $COMPOSE_FILE est introuvable"
        exit 1
    fi
}

start_monitoring() {
    print_header "LANCEMENT DE LA STACK DE MONITORING"
    check_services
    
    echo ""
    docker compose -f $COMPOSE_FILE up -d
    
    echo ""
    print_success "Stack de monitoring lancée!"
    echo ""
    echo "📊 Services disponibles:"
    echo "  • Prometheus:    http://localhost:9090"
    echo "  • Grafana:       http://localhost:3000 (admin/wiwiga_admin)"
    echo "  • Elasticsearch: http://localhost:9300"
    echo "  • Kibana:        http://localhost:5700"
    echo "  • Node Exporter: http://localhost:9200"
    echo ""
}

stop_monitoring() {
    print_header "ARRÊT DE LA STACK DE MONITORING"
    check_services
    
    docker compose -f $COMPOSE_FILE down
    print_success "Stack de monitoring arrêtée"
}

status_monitoring() {
    print_header "STATUT DE LA STACK DE MONITORING"
    check_services
    
    echo ""
    docker compose -f $COMPOSE_FILE ps
    echo ""
    
    print_header "TEST DE CONNECTIVITÉ"
    echo ""
    
    # Test Prometheus
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        print_success "Prometheus: OK (port 9090)"
    else
        print_error "Prometheus: KO"
    fi
    
    # Test Grafana
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana: OK (port 3000)"
    else
        print_error "Grafana: KO"
    fi
    
    # Test Elasticsearch
    if curl -s http://localhost:9300/_cluster/health | grep -q '"status"'; then
        STATUS=$(curl -s http://localhost:9300/_cluster/health | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")
        if [ "$STATUS" = "green" ]; then
            print_success "Elasticsearch: OK - status $STATUS (port 9300)"
        elif [ "$STATUS" = "yellow" ]; then
            print_warning "Elasticsearch: WARNING - status $STATUS (port 9300)"
        else
            print_error "Elasticsearch: KO - status $STATUS (port 9300)"
        fi
    else
        print_error "Elasticsearch: KO"
    fi
    
    # Test Kibana
    KIBANA_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5700 2>/dev/null || echo "000")
    if [ "$KIBANA_CODE" = "302" ] || [ "$KIBANA_CODE" = "200" ]; then
        print_success "Kibana: OK (port 5700)"
    else
        print_warning "Kibana: En démarrage (HTTP $KIBANA_CODE)"
    fi
    
    # Test Node Exporter
    if curl -s http://localhost:9200/metrics | head -n 1 >/dev/null 2>&1; then
        print_success "Node Exporter: OK (port 9200)"
    else
        print_error "Node Exporter: KO"
    fi
    
    echo ""
}

logs_monitoring() {
    SERVICE=$1
    FOLLOW=${2:-false}
    
    if [ -z "$SERVICE" ]; then
        print_header "LOGS DISPONIBLES"
        echo "Usage: ./monitor.sh logs <service> [follow]"
        echo ""
        echo "Services:"
        echo "  • prometheus"
        echo "  • grafana"
        echo "  • elasticsearch"
        echo "  • kibana"
        echo "  • logstash"
        echo "  • node_exporter"
        echo ""
        echo "Exemples:"
        echo "  ./monitor.sh logs grafana"
        echo "  ./monitor.sh logs elasticsearch follow"
        return
    fi
    
    CONTAINER_NAME="wiwiga_${SERVICE}"
    
    if [ "$FOLLOW" = "follow" ] || [ "$FOLLOW" = "-f" ]; then
        print_header "LOGS EN TEMPS RÉEL - $SERVICE"
        docker logs -f --tail 100 $CONTAINER_NAME
    else
        print_header "DERNIERS LOGS - $SERVICE"
        docker logs --tail 100 $CONTAINER_NAME
    fi
}

restart_monitoring() {
    SERVICE=$1
    
    if [ -z "$SERVICE" ]; then
        print_header "REDÉMARRAGE DE TOUTE LA STACK"
        stop_monitoring
        echo ""
        start_monitoring
    else
        print_header "REDÉMARRAGE DE $SERVICE"
        docker compose -f $COMPOSE_FILE restart $SERVICE
        print_success "$SERVICE redémarré"
    fi
}

clean_monitoring() {
    print_header "NETTOYAGE COMPLET"
    print_warning "Cette opération va supprimer tous les volumes de données!"
    echo ""
    read -p "Êtes-vous sûr? (oui/non): " CONFIRM
    
    if [ "$CONFIRM" = "oui" ]; then
        docker compose -f $COMPOSE_FILE down -v
        print_success "Stack arrêtée et volumes supprimés"
    else
        print_warning "Opération annulée"
    fi
}

health_monitoring() {
    print_header "CHECKUP COMPLET DE SANTÉ"
    echo ""
    
    # Elasticsearch cluster health
    echo -e "${BLUE}📦 Elasticsearch Cluster Health:${NC}"
    curl -s http://localhost:9300/_cluster/health?pretty 2>/dev/null | grep -E "status|number_of_nodes|active_primary_shards" || print_error "Elasticsearch non accessible"
    echo ""
    
    # Prometheus targets
    echo -e "${BLUE}📊 Prometheus Targets:${NC}"
    curl -s http://localhost:9090/api/v1/targets 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for target in data.get('data', {}).get('activeTargets', []):
        status = target.get('health', 'unknown')
        endpoint = target.get('scrapeUrl', target.get('labels', {}).get('instance', 'unknown'))
        job = target.get('labels', {}).get('job', 'unknown')
        if status == 'up':
            print(f'✅ {job}: {endpoint}')
        else:
            print(f'❌ {job}: {endpoint} ({status})')
except:
    print('Impossible de récupérer les targets Prometheus')
" 2>/dev/null || print_warning "Impossible de vérifier les targets Prometheus"
    echo ""
    
    # Grafana datasources
    echo -e "${BLUE}📈 Grafana Datasources:${NC}"
    echo "  Vérifier dans l'interface: http://localhost:3000/connections/datasources"
    echo ""
    
    # Disk usage
    echo -e "${BLUE}💾 Utilisation Disque Elasticsearch:${NC}"
    curl -s http://localhost:9300/_cat/allocation?v 2>/dev/null || print_warning "Impossible de récupérer l'allocation disque"
    echo ""
}

show_help() {
    print_header "WIWIGA MONITORING - AIDE"
    echo ""
    echo "Usage: ./monitor.sh <command> [options]"
    echo ""
    echo "Commandes:"
    echo "  start              Lancer la stack de monitoring"
    echo "  stop               Arrêter la stack de monitoring"
    echo "  status             Voir le statut des services"
    echo "  logs <service>     Voir les logs d'un service (ajouter 'follow' pour temps réel)"
    echo "  restart [service]  Redémarrer toute la stack ou un service spécifique"
    echo "  clean              Nettoyer complètement (supprimer les volumes)"
    echo "  health             Checkup complet de santé"
    echo "  help               Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  ./monitor.sh start"
    echo "  ./monitor.sh status"
    echo "  ./monitor.sh logs elasticsearch"
    echo "  ./monitor.sh logs grafana follow"
    echo "  ./monitor.sh restart prometheus"
    echo "  ./monitor.sh health"
    echo ""
}

# Main
case "${1:-help}" in
    start)
        start_monitoring
        ;;
    stop)
        stop_monitoring
        ;;
    status)
        status_monitoring
        ;;
    logs)
        logs_monitoring "$2" "$3"
        ;;
    restart)
        restart_monitoring "$2"
        ;;
    clean)
        clean_monitoring
        ;;
    health)
        health_monitoring
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Commande inconnue: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
