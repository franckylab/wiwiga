#!/bin/bash
# ==================================
# WIWIGA - Simulateur Webhook Campay
# ==================================
# Usage: ./test_campay_webhook.sh [option]
#
# Options:
#   --success      Simuler paiement réussi
#   --failed       Simuler paiement échoué
#   --duplicate    Simuler doublon (idempotence)
#   --invalid      Simuler signature invalide
#   --user-not-found  Simuler utilisateur inexistant
#   --all          Exécuter tous les tests
#   --help         Afficher cette aide
# ==================================

# Configuration
BASE_URL="http://localhost:4000"
WEBHOOK_URL="${BASE_URL}/api/webhooks/campay"
SECRET="CAMPAY_WEBHOOK_SECRET_KEY"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Fonction pour calculer HMAC SHA256
calculate_hmac() {
    local payload="$1"
    echo -n "$payload" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}'
}

# Construire signature
build_signature() {
    local tx_id="$1"
    local amount="$2"
    local phone="$3"
    local status="$4"
    local idempotency_key="$5"
    
    # Construire payload trié
    local payload="amount=${amount}&idempotency_key=${idempotency_key}&phone=${phone}&status=${status}&transaction_id=${tx_id}"
    
    # Calculer HMAC
    calculate_hmac "$payload"
}

# Test 1: Paiement réussi
test_success_payment() {
    print_header "Test 1: Paiement Réussi"
    
    local tx_id="TX_SUCCESS_$(date +%s)"
    local amount="10000"
    local phone="+237612345678"
    local status="SUCCESS"
    local idempotency_key="test_success_$(date +%s)"
    
    local signature=$(build_signature "$tx_id" "$amount" "$phone" "$status" "$idempotency_key")
    
    local payload=$(cat <<EOF
{
  "transaction_id": "${tx_id}",
  "amount": ${amount},
  "phone": "${phone}",
  "status": "${status}",
  "idempotency_key": "${idempotency_key}",
  "signature": "${signature}"
}
EOF
)
    
    print_info "Payload:"
    echo "$payload" | jq .
    echo ""
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    print_info "HTTP Status: $http_code"
    echo "$body" | jq .
    echo ""
    
    if [ "$http_code" == "200" ]; then
        print_success "Paiement réussi traité correctement"
    else
        print_error "Échec du test"
    fi
}

# Test 2: Paiement échoué
test_failed_payment() {
    print_header "Test 2: Paiement Échoué"
    
    local tx_id="TX_FAILED_$(date +%s)"
    local amount="50000"
    local phone="+237612345678"
    local status="FAILED"
    local idempotency_key="test_failed_$(date +%s)"
    
    local signature=$(build_signature "$tx_id" "$amount" "$phone" "$status" "$idempotency_key")
    
    local payload=$(cat <<EOF
{
  "transaction_id": "${tx_id}",
  "amount": ${amount},
  "phone": "${phone}",
  "status": "${status}",
  "idempotency_key": "${idempotency_key}",
  "signature": "${signature}"
}
EOF
)
    
    print_info "Payload:"
    echo "$payload" | jq .
    echo ""
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    print_info "HTTP Status: $http_code"
    echo "$body" | jq .
    echo ""
    
    if [ "$http_code" == "200" ]; then
        print_success "Paiement échoué géré correctement"
    else
        print_error "Échec du test"
    fi
}

# Test 3: Idempotence (doublon)
test_duplicate_payment() {
    print_header "Test 3: Idempotence (Doublon)"
    
    local tx_id="TX_DUPLICATE_$(date +%s)"
    local amount="15000"
    local phone="+237612345678"
    local status="SUCCESS"
    local idempotency_key="test_duplicate_$(date +%s)"
    
    local signature=$(build_signature "$tx_id" "$amount" "$phone" "$status" "$idempotency_key")
    
    local payload=$(cat <<EOF
{
  "transaction_id": "${tx_id}",
  "amount": ${amount},
  "phone": "${phone}",
  "status": "${status}",
  "idempotency_key": "${idempotency_key}",
  "signature": "${signature}"
}
EOF
)
    
    print_info "Première requête:"
    local response1=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code1=$(echo "$response1" | tail -n1)
    local body1=$(echo "$response1" | head -n-1)
    
    print_info "HTTP Status: $http_code1"
    echo "$body1" | jq .
    echo ""
    
    print_info "Seconde requête (même idempotency_key):"
    local response2=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code2=$(echo "$response2" | tail -n1)
    local body2=$(echo "$response2" | head -n-1)
    
    print_info "HTTP Status: $http_code2"
    echo "$body2" | jq .
    echo ""
    
    if [ "$http_code1" == "200" ] && [ "$http_code2" == "200" ]; then
        print_success "Idempotence respectée"
    else
        print_error "Échec du test d'idempotence"
    fi
}

# Test 4: Signature invalide
test_invalid_signature() {
    print_header "Test 4: Signature Invalide"
    
    local tx_id="TX_INVALID_$(date +%s)"
    local amount="10000"
    local phone="+237612345678"
    local status="SUCCESS"
    local idempotency_key="test_invalid_$(date +%s)"
    
    local payload=$(cat <<EOF
{
  "transaction_id": "${tx_id}",
  "amount": ${amount},
  "phone": "${phone}",
  "status": "${status}",
  "idempotency_key": "${idempotency_key}",
  "signature": "invalid_signature_here"
}
EOF
)
    
    print_info "Payload avec signature invalide:"
    echo "$payload" | jq .
    echo ""
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    print_info "HTTP Status: $http_code"
    echo "$body" | jq .
    echo ""
    
    if [ "$http_code" == "401" ]; then
        print_success "Signature invalide rejetée (401)"
    else
        print_error "Signature invalide non rejetée"
    fi
}

# Test 5: Utilisateur non trouvé
test_user_not_found() {
    print_header "Test 5: Utilisateur Non Trouvé"
    
    local tx_id="TX_NOUSER_$(date +%s)"
    local amount="10000"
    local phone="+237699999999" # Phone inexistant
    local status="SUCCESS"
    local idempotency_key="test_nouser_$(date +%s)"
    
    local signature=$(build_signature "$tx_id" "$amount" "$phone" "$status" "$idempotency_key")
    
    local payload=$(cat <<EOF
{
  "transaction_id": "${tx_id}",
  "amount": ${amount},
  "phone": "${phone}",
  "status": "${status}",
  "idempotency_key": "${idempotency_key}",
  "signature": "${signature}"
}
EOF
)
    
    print_info "Payload (phone inexistant):"
    echo "$payload" | jq .
    echo ""
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    print_info "HTTP Status: $http_code"
    echo "$body" | jq .
    echo ""
    
    if [ "$http_code" == "404" ]; then
        print_success "Utilisateur non trouvé géré (404)"
    else
        print_error "Erreur non gérée correctement"
    fi
}

# Afficher l'aide
show_help() {
    echo "WIWIGA - Simulateur Webhook Campay"
    echo ""
    echo "Usage: ./test_campay_webhook.sh [option]"
    echo ""
    echo "Options:"
    echo "  --success          Simuler paiement réussi"
    echo "  --failed           Simuler paiement échoué"
    echo "  --duplicate        Simuler doublon (idempotence)"
    echo "  --invalid          Simuler signature invalide"
    echo "  --user-not-found   Simuler utilisateur inexistant"
    echo "  --all              Exécuter tous les tests"
    echo "  --help             Afficher cette aide"
    echo ""
    echo "Prérequis:"
    echo "  - Serveur Wiwiga en cours d'exécution sur http://localhost:4000"
    echo "  - curl et jq installés"
    echo "  - openssl pour calcul HMAC"
    echo ""
}

# Main
main() {
    # Vérifier prérequis
    if ! command -v curl &> /dev/null; then
        print_error "curl n'est pas installé"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq n'est pas installé"
        exit 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        print_error "openssl n'est pas installé"
        exit 1
    fi
    
    # Vérifier serveur
    if ! curl -s "${BASE_URL}" > /dev/null 2>&1; then
        print_error "Serveur Wiwiga non accessible sur ${BASE_URL}"
        print_info "Lancez le serveur: cd game_hub && mix phx.server"
        exit 1
    fi
    
    print_success "Serveur Wiwiga détecté sur ${BASE_URL}"
    
    case "${1:---all}" in
        --success)
            test_success_payment
            ;;
        --failed)
            test_failed_payment
            ;;
        --duplicate)
            test_duplicate_payment
            ;;
        --invalid)
            test_invalid_signature
            ;;
        --user-not-found)
            test_user_not_found
            ;;
        --all)
            test_success_payment
            test_failed_payment
            test_duplicate_payment
            test_invalid_signature
            test_user_not_found
            
            print_header "Tous les tests sont terminés"
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
