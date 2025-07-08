#!/bin/bash

# =============================================================================
# SmartKI-Pangolin Domain Routing Deployment Script  
# Deploy reverse proxy configuration for all haossl.de domains
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/home/aicollab/SmartKI-Pangolin"
LOG_FILE="${BASE_DIR}/deployment.log"

# Domain mappings
declare -A DOMAINS=(
    ["AnduinOS.haossl.de"]="192.168.178.181"
    ["haossl.de"]="192.168.178.103"
    ["karakeep.haossl.de"]="192.168.178.145"
    ["homarr.haossl.de"]="192.168.178.141"
    ["notes.haossl.de"]="192.168.178.187"
    ["pangolin.haossl.de"]="192.168.178.186"
    ["pdf.haossl.de"]="192.168.178.171"
    ["pihole.haossl.de"]="192.168.178.143"
    ["pve.haossl.de"]="192.168.178.94"
    ["tandoor.haossl.de"]="192.168.178.140"
    ["aicollab.haossl.de"]="192.168.178.183"
)

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Test connectivity to target services
test_connectivity() {
    log_step "Testing connectivity to target services..."
    
    local success_count=0
    local total_count=${#DOMAINS[@]}
    
    for domain in "${!DOMAINS[@]}"; do
        local ip="${DOMAINS[$domain]}"
        
        if [[ "$domain" == "pve.haossl.de" ]]; then
            # Test Proxmox on port 8006
            if timeout 3 bash -c "</dev/tcp/${ip}/8006" 2>/dev/null; then
                log_success "✓ $domain ($ip:8006) is reachable"
                ((success_count++))
            else
                log_warning "✗ $domain ($ip:8006) is not reachable"
            fi
        else
            # Test standard HTTP port 80
            if timeout 3 bash -c "</dev/tcp/${ip}/80" 2>/dev/null; then
                log_success "✓ $domain ($ip:80) is reachable"
                ((success_count++))
            else
                log_warning "✗ $domain ($ip:80) is not reachable"
            fi
        fi
    done
    
    log_info "Connectivity test: $success_count/$total_count services reachable"
    
    if [[ $success_count -eq 0 ]]; then
        log_error "No target services are reachable. Check network connectivity."
        return 1
    fi
    
    return 0
}

# Create necessary directories
create_directories() {
    log_step "Creating necessary directories..."
    
    local dirs=(
        "${BASE_DIR}/nginx/conf.d"
        "${BASE_DIR}/nginx/ssl"
        "${BASE_DIR}/logs"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        else
            log_info "Directory already exists: $dir"
        fi
    done
}

# Validate nginx configuration
validate_nginx_config() {
    log_step "Validating nginx configuration..."
    
    # Check if nginx is available in Docker
    if docker run --rm -v "${BASE_DIR}/nginx:/etc/nginx:ro" nginx:alpine nginx -t 2>/dev/null; then
        log_success "Nginx configuration is valid"
        return 0
    else
        log_error "Nginx configuration validation failed"
        return 1
    fi
}

# Deploy the stack
deploy_stack() {
    log_step "Deploying SmartKI-Pangolin stack..."
    
    cd "$BASE_DIR"
    
    # Stop existing containers
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        log_info "Stopping existing containers..."
        docker-compose down
    fi
    
    # Pull latest images
    log_info "Pulling latest images..."
    docker-compose pull
    
    # Start the stack
    log_info "Starting Pangolin stack..."
    if docker-compose up -d; then
        log_success "Pangolin stack started successfully"
    else
        log_error "Failed to start Pangolin stack"
        return 1
    fi
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    return 0
}

# Test deployed services
test_deployment() {
    log_step "Testing deployed services..."
    
    # Test nginx health
    if curl -sf http://localhost/nginx-health >/dev/null 2>&1; then
        log_success "✓ Nginx is responding"
    else
        log_warning "✗ Nginx health check failed"
    fi
    
    # Test pangolin app health (if accessible)
    if docker exec pangolin-full curl -sf http://localhost:3000/health >/dev/null 2>&1; then
        log_success "✓ Pangolin app is responding"
    else
        log_warning "✗ Pangolin app health check failed"
    fi
    
    # Test domain routing (sample)
    local test_domain="pangolin.haossl.de"
    if curl -sf -H "Host: $test_domain" http://localhost/ >/dev/null 2>&1; then
        log_success "✓ Domain routing is working for $test_domain"
    else
        log_warning "✗ Domain routing test failed for $test_domain"
    fi
}

# Show deployment status
show_status() {
    log_step "Deployment status overview"
    
    echo
    echo "══════════════════════════════════════════════════════════════════════════════="
    echo -e "${CYAN}SmartKI-Pangolin Domain Routing Status${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════="
    
    # Show container status
    echo -e "${BLUE}Container Status:${NC}"
    docker-compose ps
    echo
    
    # Show configured domains
    echo -e "${BLUE}Configured Domain Mappings:${NC}"
    for domain in "${!DOMAINS[@]}"; do
        ip="${DOMAINS[$domain]}"
        echo -e "  ${GREEN}$domain${NC} → $ip"
    done
    echo
    
    # Show access information
    echo -e "${BLUE}Access Information:${NC}"
    echo "  Pangolin Dashboard: http://192.168.178.186 or http://pangolin.haossl.de"
    echo "  Traefik Dashboard: http://192.168.178.186:8080 (if enabled)"
    echo "  Grafana Monitoring: http://192.168.178.186:3001 (if enabled)"
    echo
    
    # Show next steps
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Configure DNS to point all *.haossl.de domains to 192.168.178.186"
    echo "2. Test domain routing: curl -H 'Host: DOMAIN' http://192.168.178.186/"
    echo "3. Monitor logs: docker-compose logs -f nginx-proxy"
    echo "4. Configure SSL certificates if needed"
    echo
}

# Main execution
main() {
    log "Starting SmartKI-Pangolin Domain Routing Deployment"
    echo "══════════════════════════════════════════════════════════════════════════════="
    echo -e "${CYAN}SmartKI-Pangolin Domain Routing Deployment${NC}"
    echo -e "${CYAN}Setting up reverse proxy for all haossl.de domains${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════="
    echo
    
    # Test connectivity
    test_connectivity
    echo
    
    # Create directories
    create_directories
    echo
    
    # Validate configuration
    validate_nginx_config
    echo
    
    # Deploy stack
    deploy_stack
    echo
    
    # Test deployment
    test_deployment
    echo
    
    # Show status
    show_status
    
    log_success "SmartKI-Pangolin Domain Routing deployment completed!"
    log "Deployment completed at $(date)"
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 130' INT TERM

# Run main function
main "$@"