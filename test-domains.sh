#!/bin/bash

# =============================================================================
# SmartKI-Pangolin Domain Testing Script
# Test all configured domain routing
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
PANGOLIN_IP="192.168.178.186"
TEST_TIMEOUT=5

# Domain mappings
declare -A DOMAINS=(
    ["AnduinOS.haossl.de"]="192.168.178.181"
    ["haossl.de"]="192.168.178.103"
    ["hoarder.haossl.de"]="192.168.178.145"
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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Test single domain
test_domain() {
    local domain="$1"
    local target_ip="$2"
    
    echo -n "Testing $domain → $target_ip: "
    
    # Test with Host header through Pangolin
    local response
    local http_code
    
    response=$(curl -s -w "%{http_code}" -H "Host: $domain" \
                   --connect-timeout $TEST_TIMEOUT \
                   --max-time $TEST_TIMEOUT \
                   "http://$PANGOLIN_IP/" 2>/dev/null || echo "000")
    
    http_code="${response: -3}"
    
    case "$http_code" in
        "200"|"301"|"302"|"304")
            echo -e "${GREEN}✓ OK ($http_code)${NC}"
            return 0
            ;;
        "404")
            echo -e "${YELLOW}⚠ Not Found (404)${NC}"
            return 1
            ;;
        "502"|"503"|"504")
            echo -e "${RED}✗ Service Unavailable ($http_code)${NC}"
            return 1
            ;;
        "000")
            echo -e "${RED}✗ Connection Failed${NC}"
            return 1
            ;;
        *)
            echo -e "${YELLOW}? Unexpected Response ($http_code)${NC}"
            return 1
            ;;
    esac
}

# Test direct connectivity to target
test_direct_connectivity() {
    local domain="$1"
    local target_ip="$2"
    
    echo -n "  Direct $target_ip: "
    
    if [[ "$domain" == "pve.haossl.de" ]]; then
        # Test Proxmox on port 8006
        if timeout $TEST_TIMEOUT bash -c "</dev/tcp/${target_ip}/8006" 2>/dev/null; then
            echo -e "${GREEN}✓ Reachable (8006)${NC}"
            return 0
        else
            echo -e "${RED}✗ Unreachable (8006)${NC}"
            return 1
        fi
    else
        # Test standard HTTP port 80
        if timeout $TEST_TIMEOUT bash -c "</dev/tcp/${target_ip}/80" 2>/dev/null; then
            echo -e "${GREEN}✓ Reachable (80)${NC}"
            return 0
        else
            echo -e "${RED}✗ Unreachable (80)${NC}"
            return 1
        fi
    fi
}

# Test Pangolin services
test_pangolin_services() {
    log_step "Testing Pangolin core services"
    
    # Test nginx
    echo -n "Nginx health: "
    if curl -sf "http://$PANGOLIN_IP/nginx-health" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    # Test pangolin app (if accessible)
    echo -n "Pangolin app: "
    if curl -sf "http://$PANGOLIN_IP:3000/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${YELLOW}⚠ Not accessible externally${NC}"
    fi
    
    # Test pangolin web
    echo -n "Pangolin web: "
    if curl -sf "http://$PANGOLIN_IP:8080/" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${YELLOW}⚠ Not accessible externally${NC}"
    fi
    
    echo
}

# Test DNS resolution (if available)
test_dns_resolution() {
    log_step "Testing DNS resolution"
    
    for domain in "${!DOMAINS[@]}"; do
        echo -n "$domain: "
        
        if command -v nslookup >/dev/null 2>&1; then\n            local resolved_ip\n            resolved_ip=$(nslookup \"$domain\" 2>/dev/null | grep -A1 \"Name:\" | tail -1 | awk '{print $2}' || echo \"\")\n            \n            if [[ -n \"$resolved_ip\" ]]; then\n                if [[ \"$resolved_ip\" == \"$PANGOLIN_IP\" ]]; then\n                    echo -e \"${GREEN}✓ Resolves to $resolved_ip${NC}\"\n                else\n                    echo -e \"${YELLOW}⚠ Resolves to $resolved_ip (expected $PANGOLIN_IP)${NC}\"\n                fi\n            else\n                echo -e \"${RED}✗ No resolution${NC}\"\n            fi\n        else\n            echo -e \"${YELLOW}? DNS tools not available${NC}\"\n        fi\n    done\n    \n    echo\n}\n\n# Main testing function\nrun_tests() {\n    log_step \"Testing domain routing through Pangolin ($PANGOLIN_IP)\"\n    echo\n    \n    local success_count=0\n    local total_count=${#DOMAINS[@]}\n    local connectivity_issues=0\n    \n    for domain in \"${!DOMAINS[@]}\"; do\n        target_ip=\"${DOMAINS[$domain]}\"\n        \n        # Test domain routing\n        if test_domain \"$domain\" \"$target_ip\"; then\n            ((success_count++))\n        fi\n        \n        # Test direct connectivity\n        if ! test_direct_connectivity \"$domain\" \"$target_ip\"; then\n            ((connectivity_issues++))\n        fi\n        \n        echo\n    done\n    \n    return $(( total_count - success_count ))\n}\n\n# Generate test report\ngenerate_report() {\n    local success_count=\"$1\"\n    local total_count=\"$2\"\n    local connectivity_issues=\"$3\"\n    \n    echo \"═══════════════════════════════════════════════════════════════════════════════\"\n    echo -e \"${CYAN}Domain Routing Test Report${NC}\"\n    echo \"═══════════════════════════════════════════════════════════════════════════════\"\n    \n    echo -e \"${BLUE}Results Summary:${NC}\"\n    echo \"  Domain routing tests: $success_count/$total_count successful\"\n    echo \"  Direct connectivity issues: $connectivity_issues\"\n    echo\n    \n    if [[ $success_count -eq $total_count ]]; then\n        log_success \"All domain routing tests passed!\"\n    elif [[ $success_count -gt 0 ]]; then\n        log_warning \"Some domain routing tests failed ($success_count/$total_count passed)\"\n    else\n        log_error \"All domain routing tests failed\"\n    fi\n    \n    echo\n    echo -e \"${BLUE}Troubleshooting Tips:${NC}\"\n    \n    if [[ $connectivity_issues -gt 0 ]]; then\n        echo \"  • $connectivity_issues target services are not reachable directly\"\n        echo \"  • Check if target services are running\"\n        echo \"  • Verify network connectivity between Pangolin and targets\"\n    fi\n    \n    if [[ $success_count -lt $total_count ]]; then\n        echo \"  • Check nginx configuration: docker exec pangolin-nginx nginx -t\"\n        echo \"  • Review nginx logs: docker-compose logs nginx-proxy\"\n        echo \"  • Verify Pangolin is running: docker-compose ps\"\n        echo \"  • Test manual curl: curl -H 'Host: DOMAIN' http://$PANGOLIN_IP/\"\n    fi\n    \n    echo \"  • Check DNS configuration for *.haossl.de → $PANGOLIN_IP\"\n    echo \"  • Monitor real-time logs: docker-compose logs -f nginx-proxy\"\n    echo\n}\n\n# Main execution\nmain() {\n    echo \"═══════════════════════════════════════════════════════════════════════════════\"\n    echo -e \"${CYAN}SmartKI-Pangolin Domain Routing Test${NC}\"\n    echo -e \"${CYAN}Testing all configured domain mappings${NC}\"\n    echo \"═══════════════════════════════════════════════════════════════════════════════\"\n    echo\n    \n    # Test Pangolin services first\n    test_pangolin_services\n    \n    # Test DNS resolution\n    test_dns_resolution\n    \n    # Run domain routing tests\n    local success_count=0\n    local total_count=${#DOMAINS[@]}\n    local connectivity_issues=0\n    \n    for domain in \"${!DOMAINS[@]}\"; do\n        target_ip=\"${DOMAINS[$domain]}\"\n        \n        # Test domain routing\n        if test_domain \"$domain\" \"$target_ip\"; then\n            ((success_count++))\n        fi\n        \n        # Test direct connectivity\n        if ! test_direct_connectivity \"$domain\" \"$target_ip\"; then\n            ((connectivity_issues++))\n        fi\n        \n        echo\n    done\n    \n    # Generate report\n    generate_report \"$success_count\" \"$total_count\" \"$connectivity_issues\"\n    \n    # Exit with appropriate code\n    if [[ $success_count -eq $total_count ]]; then\n        exit 0\n    else\n        exit 1\n    fi\n}\n\n# Handle script interruption\ntrap 'log_error \"Test interrupted\"; exit 130' INT TERM\n\n# Run main function\nmain \"$@\""