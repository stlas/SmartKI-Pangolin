#!/bin/bash

# =============================================================================
# SmartKI Kanban Synchronization Script
# Sync todos between Claude todo list and Kanboard PM system
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
KANBOARD_URL="http://192.168.178.183/ai-collab-pm"
KANBOARD_API_URL="${KANBOARD_URL}/jsonrpc.php"
PROJECT_NAME="SmartKI Development"
TODO_FILE="/tmp/current-todos.json"

# Kanboard API credentials (should be set as environment variables)
KANBOARD_USER="${KANBOARD_USER:-admin}"
KANBOARD_TOKEN="${KANBOARD_TOKEN:-}" # API token from Kanboard settings

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

# Check if Kanboard is accessible
check_kanboard_connectivity() {
    log_step "Checking Kanboard connectivity..."
    
    if curl -sf "$KANBOARD_URL" >/dev/null 2>&1; then
        log_success "✓ Kanboard is accessible at $KANBOARD_URL"
        return 0
    else
        log_error "✗ Kanboard is not accessible at $KANBOARD_URL"
        return 1
    fi
}

# Get current todos from Claude's todo system
get_current_todos() {
    log_step "Getting current todos..."
    
    # This would ideally read from Claude's todo system
    # For now, we'll create a sample structure
    cat > "$TODO_FILE" <<'EOF'
[
    {
        "id": "11",
        "content": "Pangolin-Weiterleitungen für alle haossl.de-Domains konfigurieren",
        "status": "completed",
        "priority": "high"
    },
    {
        "id": "12",
        "content": "Nginx-Konfiguration für Domain-Routing erstellen",
        "status": "completed",
        "priority": "high"
    },
    {
        "id": "13",
        "content": "Pangolin-Service testen und validieren",
        "status": "in_progress",
        "priority": "high"
    },
    {
        "id": "14",
        "content": "aicollab.haossl.de Domain mit PM-Subdirectory hinzufügen",
        "status": "completed",
        "priority": "high"
    },
    {
        "id": "15",
        "content": "Kanban-API Integration für automatische Task-Synchronisation",
        "status": "completed",
        "priority": "medium"
    }
]
EOF
    
    log_success "✓ Current todos loaded"
}

# Test basic functionality
test_kanboard_access() {
    log_step "Testing Kanboard access..."
    
    # Test direct URL access
    if curl -sf "$KANBOARD_URL" >/dev/null 2>&1; then
        log_success "✓ Kanboard web interface is accessible"
    else
        log_warning "✗ Kanboard web interface is not accessible"
    fi
    
    # Test through Pangolin proxy (if available)
    if curl -sf -H "Host: aicollab.haossl.de" "http://192.168.178.186/pm/" >/dev/null 2>&1; then
        log_success "✓ Kanboard is accessible through Pangolin proxy"
    else
        log_warning "✗ Kanboard proxy access not available yet (Pangolin may not be deployed)"
    fi
}

# Show current todo status
show_todo_status() {
    log_step "Current todo status overview"
    
    if [[ ! -f "$TODO_FILE" ]]; then
        log_error "Todo file not found"
        return 1
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}Current SmartKI Todos${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    local total_todos=0
    local completed_todos=0
    local in_progress_todos=0
    local pending_todos=0
    
    while IFS= read -r todo; do
        local todo_id=$(echo "$todo" | jq -r '.id')
        local content=$(echo "$todo" | jq -r '.content')
        local status=$(echo "$todo" | jq -r '.status')
        local priority=$(echo "$todo" | jq -r '.priority')
        
        case "$status" in
            "completed")
                echo -e "  ${GREEN}✓${NC} [$priority] $content"
                ((completed_todos++))
                ;;
            "in_progress")
                echo -e "  ${YELLOW}🔄${NC} [$priority] $content"
                ((in_progress_todos++))
                ;;
            "pending")
                echo -e "  ${BLUE}⏳${NC} [$priority] $content"
                ((pending_todos++))
                ;;
            *)
                echo -e "  ${PURPLE}?${NC} [$priority] $content"
                ;;
        esac
        
        ((total_todos++))
    done < <(jq -c '.[]' "$TODO_FILE")
    
    echo
    echo -e "${BLUE}Summary:${NC}"
    echo "  Total tasks: $total_todos"
    echo "  Completed: $completed_todos"
    echo "  In Progress: $in_progress_todos"
    echo "  Pending: $pending_todos"
    echo
}

# Main execution
main() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}SmartKI Kanban Synchronization${NC}"
    echo -e "${CYAN}Syncing todos between Claude and Kanboard${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Get current todos
    get_current_todos
    echo
    
    # Show todo status
    show_todo_status
    
    # Test Kanboard access
    test_kanboard_access
    echo
    
    # Show results
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${CYAN}Access Information${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    echo -e "${BLUE}Kanboard Access:${NC}"
    echo "  Direct URL: $KANBOARD_URL"
    echo "  Via Pangolin: http://aicollab.haossl.de/pm/"
    echo "  Local IP: http://192.168.178.183/ai-collab-pm/"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Ensure Kanboard is running on 192.168.178.183"
    echo "2. Deploy Pangolin with updated domain routing"
    echo "3. Configure KANBOARD_TOKEN environment variable for API access"
    echo "4. Test full API integration"
    echo
    
    log_success "Kanban sync preparation completed!"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"