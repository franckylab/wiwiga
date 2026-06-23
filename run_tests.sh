#!/bin/bash
# ==================================
# WIWIGA - Script d'Exécution des Tests
# ==================================
# Usage: ./run_tests.sh [option]
#
# Options:
#   --all          Exécuter tous les tests (défaut)
#   --wallet       Tests Wallet uniquement
#   --auth         Tests Auth uniquement
#   --commission   Tests Commission uniquement
#   --coverage     Tests avec couverture de code
#   --trace        Tests avec logs détaillés
#   --help         Afficher cette aide
# ==================================

set -e

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Chemin vers le projet
PROJECT_DIR="/mnt/DONNEES/projets/wiwiga/game_hub"

# Fonctions
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Vérifier prérequis
check_prerequisites() {
    print_header "Vérification des Prérequis"
    
    # Vérifier PostgreSQL
    if pg_isready -q 2>/dev/null; then
        print_success "PostgreSQL est en cours d'exécution"
    else
        print_error "PostgreSQL n'est pas en cours d'exécution"
        print_info "Lancez: sudo systemctl start postgresql"
        exit 1
    fi
    
    # Vérifier Redis
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        print_success "Redis est en cours d'exécution"
    else
        print_error "Redis n'est pas en cours d'exécution"
        print_info "Lancez: sudo systemctl start redis"
        exit 1
    fi
    
    # Vérifier base de test
    if psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw game_hub_test; then
        print_success "Base de données de test existe"
    else
        print_info "Création de la base de données de test..."
        createdb game_hub_test 2>/dev/null || true
        print_success "Base de données de test créée"
    fi
    
    echo ""
}

# Exécuter migrations de test
run_test_migrations() {
    print_header "Migration Base de Test"
    
    cd "$PROJECT_DIR"
    MIX_ENV=test mix ecto.migrate --quiet 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Migrations de test appliquées"
    else
        print_error "Échec des migrations de test"
        exit 1
    fi
    
    echo ""
}

# Exécuter tous les tests
run_all_tests() {
    print_header "Exécution de Tous les Tests"
    
    cd "$PROJECT_DIR"
    mix test
    
    if [ $? -eq 0 ]; then
        print_success "Tous les tests sont passés !"
    else
        print_error "Certains tests ont échoué"
        exit 1
    fi
}

# Exécuter tests spécifiques
run_wallet_tests() {
    print_header "Tests Wallet (ACID)"
    
    cd "$PROJECT_DIR"
    mix test apps/game_hub/test/game_hub/wallet_test.exs --trace
}

run_auth_tests() {
    print_header "Tests Auth (OTP + JWT)"
    
    cd "$PROJECT_DIR"
    mix test apps/game_hub/test/game_hub/auth_test.exs --trace
}

run_commission_tests() {
    print_header "Tests Commission"
    
    cd "$PROJECT_DIR"
    mix test apps/game_hub/test/game_hub/commission_test.exs --trace
}

# Exécuter avec coverage
run_with_coverage() {
    print_header "Tests avec Couverture de Code"
    
    cd "$PROJECT_DIR"
    mix test --cover
    
    if [ -d "cover" ]; then
        print_success "Rapport de couverture généré dans cover/"
        print_info "Ouvrir: firefox cover/index.html"
    fi
}

# Afficher l'aide
show_help() {
    echo "WIWIGA - Script d'Exécution des Tests"
    echo ""
    echo "Usage: ./run_tests.sh [option]"
    echo ""
    echo "Options:"
    echo "  --all          Exécuter tous les tests (défaut)"
    echo "  --wallet       Tests Wallet uniquement"
    echo "  --auth         Tests Auth uniquement"
    echo "  --commission   Tests Commission uniquement"
    echo "  --coverage     Tests avec couverture de code"
    echo "  --trace        Tests avec logs détaillés"
    echo "  --help         Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  ./run_tests.sh --all"
    echo "  ./run_tests.sh --wallet"
    echo "  ./run_tests.sh --coverage"
    echo ""
}

# Main
main() {
    case "${1:---all}" in
        --all)
            check_prerequisites
            run_test_migrations
            run_all_tests
            ;;
        --wallet)
            check_prerequisites
            run_test_migrations
            run_wallet_tests
            ;;
        --auth)
            check_prerequisites
            run_test_migrations
            run_auth_tests
            ;;
        --commission)
            check_prerequisites
            run_test_migrations
            run_commission_tests
            ;;
        --coverage)
            check_prerequisites
            run_test_migrations
            run_with_coverage
            ;;
        --trace)
            check_prerequisites
            run_test_migrations
            cd "$PROJECT_DIR"
            mix test --trace
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
}

# Exécuter main
main "$@"
