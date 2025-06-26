#!/bin/bash

# SmartKI-Pangolin Deployment Script
# Supports zero-downtime deployments with health checks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="pangolin-full"
NEW_CONTAINER_NAME="pangolin-new"
IMAGE_NAME="fosrl/pangolin:latest"
HEALTH_ENDPOINT="http://localhost:3000/health"
NGINX_CONFIG="/etc/nginx/sites-available/pangolin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]] && ! groups | grep -q docker; then
        error "This script needs to be run as root or by a user in the docker group"
        exit 1
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running"
        exit 1
    fi
    
    # Check if nginx is installed and running
    if ! command -v nginx >/dev/null 2>&1; then
        error "Nginx is not installed"
        exit 1
    fi
    
    if ! systemctl is-active --quiet nginx; then
        error "Nginx is not running"
        exit 1
    fi
    
    # Check current container status
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "Current container '$CONTAINER_NAME' is running"
    else
        warning "Container '$CONTAINER_NAME' is not running"
    fi
    
    success "Pre-deployment checks passed"
}

# Pull latest image
pull_image() {
    log "Pulling latest image: $IMAGE_NAME"
    if docker pull "$IMAGE_NAME"; then
        success "Image pulled successfully"
    else
        error "Failed to pull image"
        exit 1
    fi
}

# Get next available ports for zero-downtime deployment
get_available_ports() {
    local api_port=3001
    local web_port=8081
    
    while netstat -tuln | grep -q ":$api_port "; do
        ((api_port++))
    done
    
    while netstat -tuln | grep -q ":$web_port "; do
        ((web_port++))
    done
    
    echo "$api_port $web_port"
}

# Deploy new container
deploy_new_container() {
    log "Deploying new container..."
    
    # Get available ports
    read -r NEW_API_PORT NEW_WEB_PORT <<< "$(get_available_ports)"
    log "Using ports: API=$NEW_API_PORT, Web=$NEW_WEB_PORT"
    
    # Stop and remove any existing new container
    if docker ps -a -q -f name="$NEW_CONTAINER_NAME" | grep -q .; then
        log "Removing existing '$NEW_CONTAINER_NAME' container"
        docker stop "$NEW_CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$NEW_CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Start new container
    docker run -d \
        --name "$NEW_CONTAINER_NAME" \
        -p "$NEW_API_PORT:3000" \
        -p "$NEW_WEB_PORT:3002" \
        -e NODE_ENV=production \
        -e API_URL="http://localhost:3000" \
        -e SMARTKI_PM_URL="http://192.168.178.186:3100" \
        -e SMARTKI_OBSIDIAN_URL="http://192.168.178.187:3001" \
        --restart=unless-stopped \
        "$IMAGE_NAME"
    
    # Wait for container to start
    log "Waiting for container to start..."
    sleep 10
    
    # Health check
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker exec "$NEW_CONTAINER_NAME" curl -f "http://localhost:3000/health" >/dev/null 2>&1; then
            success "New container is healthy"
            return 0
        fi
        
        log "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 10
        ((attempt++))
    done
    
    error "New container failed health checks"
    return 1
}

# Update nginx configuration
update_nginx_config() {
    log "Updating nginx configuration..."
    
    # Backup current config
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%s)"
    
    # Update ports in nginx config
    sed -i "s/localhost:3000/localhost:$NEW_API_PORT/g" "$NGINX_CONFIG"
    sed -i "s/localhost:8080/localhost:$NEW_WEB_PORT/g" "$NGINX_CONFIG"
    
    # Test nginx configuration
    if nginx -t; then
        # Reload nginx
        systemctl reload nginx
        success "Nginx configuration updated and reloaded"
    else
        error "Nginx configuration test failed"
        # Restore backup
        cp "${NGINX_CONFIG}.backup."* "$NGINX_CONFIG"
        return 1
    fi
}

# Switch to new container
switch_containers() {
    log "Switching to new container..."
    
    # Stop old container
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "Stopping old container '$CONTAINER_NAME'"
        docker stop "$CONTAINER_NAME"
    fi
    
    # Wait a moment
    sleep 5
    
    # Start new container on original ports
    docker stop "$NEW_CONTAINER_NAME"
    
    # Remove old container
    if docker ps -a -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker rm "$CONTAINER_NAME"
    fi
    
    # Rename new container
    docker rename "$NEW_CONTAINER_NAME" "$CONTAINER_NAME"
    
    # Start with original port mapping
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "3000:3000" \
        -p "8080:3002" \
        -e NODE_ENV=production \
        -e API_URL="http://localhost:3000" \
        -e SMARTKI_PM_URL="http://192.168.178.186:3100" \
        -e SMARTKI_OBSIDIAN_URL="http://192.168.178.187:3001" \
        --restart=unless-stopped \
        "$IMAGE_NAME"
    
    # Restore original nginx config
    sed -i "s/localhost:$NEW_API_PORT/localhost:3000/g" "$NGINX_CONFIG"
    sed -i "s/localhost:$NEW_WEB_PORT/localhost:8080/g" "$NGINX_CONFIG"
    
    # Reload nginx
    nginx -t && systemctl reload nginx
    
    success "Container switch completed"
}

# Post-deployment verification
post_deployment_verification() {
    log "Running post-deployment verification..."
    
    # Wait for container to be ready
    sleep 15
    
    # Health checks
    local checks=(
        "http://localhost:3000/health"
        "http://localhost:8080/"
        "http://localhost/"
    )
    
    for check in "${checks[@]}"; do
        if curl -f "$check" >/dev/null 2>&1; then
            success "✅ $check - OK"
        else
            error "❌ $check - FAILED"
            return 1
        fi
    done
    
    # Container status
    if docker ps -f name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
        success "✅ Container is running"
    else
        error "❌ Container is not running properly"
        return 1
    fi
    
    success "All post-deployment checks passed"
}

# Rollback function
rollback() {
    error "Deployment failed, rolling back..."
    
    # Stop new container if it exists
    if docker ps -a -q -f name="$NEW_CONTAINER_NAME" | grep -q .; then
        docker stop "$NEW_CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$NEW_CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Restore nginx config from backup
    if ls "${NGINX_CONFIG}.backup."* >/dev/null 2>&1; then
        cp "${NGINX_CONFIG}.backup."* "$NGINX_CONFIG"
        nginx -t && systemctl reload nginx
    fi
    
    # Ensure original container is running
    if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        log "Starting original container..."
        docker start "$CONTAINER_NAME" >/dev/null 2>&1 || {
            # If start fails, create new container with original image
            docker run -d \
                --name "$CONTAINER_NAME" \
                -p "3000:3000" \
                -p "8080:3002" \
                -e NODE_ENV=production \
                --restart=unless-stopped \
                "$IMAGE_NAME"
        }
    fi
    
    warning "Rollback completed"
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Remove old backup configs (keep last 5)
    find "$(dirname "$NGINX_CONFIG")" -name "$(basename "$NGINX_CONFIG").backup.*" -type f | sort -r | tail -n +6 | xargs -r rm
    
    # Clean up unused Docker images
    docker image prune -f >/dev/null 2>&1 || true
    
    success "Cleanup completed"
}

# Main deployment function
main() {
    log "🚀 Starting SmartKI-Pangolin deployment"
    
    check_permissions
    pre_deployment_checks
    pull_image
    
    if deploy_new_container && update_nginx_config; then
        switch_containers
        
        if post_deployment_verification; then
            cleanup
            success "🎉 Deployment completed successfully!"
            
            # Show final status
            echo
            log "📊 Final Status:"
            docker ps -f name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            curl -s http://localhost/health | jq '.' 2>/dev/null || echo "API Health check OK"
        else
            rollback
            exit 1
        fi
    else
        rollback
        exit 1
    fi
}

# Trap errors and run rollback
trap rollback ERR

# Run main function
main "$@"