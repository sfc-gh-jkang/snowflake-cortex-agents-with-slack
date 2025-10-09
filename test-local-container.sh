#!/bin/bash

# ==============================================================================
# Local Docker Container Testing Script
# ==============================================================================
# This script helps test the Docker container locally before deploying to SPCS
# ==============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IMAGE_NAME="cortex-slack-bot"
IMAGE_TAG="latest"
CONTAINER_NAME="cortex-slack-bot-test"

# Parse arguments
BUILD_IMAGE=false
SHOW_LOGS=false
SHELL_ACCESS=false
STOP_CONTAINER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build|-b)
            BUILD_IMAGE=true
            shift
            ;;
        --logs|-l)
            SHOW_LOGS=true
            shift
            ;;
        --shell|-s)
            SHELL_ACCESS=true
            shift
            ;;
        --stop)
            STOP_CONTAINER=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./test-local-container.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build, -b    Build Docker image before running"
            echo "  --logs, -l     Show container logs"
            echo "  --shell, -s    Open shell in running container"
            echo "  --stop         Stop and remove running container"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./test-local-container.sh --build     # Build and run"
            echo "  ./test-local-container.sh --logs      # View logs"
            echo "  ./test-local-container.sh --shell     # Access container shell"
            echo "  ./test-local-container.sh --stop      # Stop container"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if .env file exists
check_env_file() {
    if [ ! -f .env ]; then
        print_error ".env file not found"
        print_info "Copy .env.example to .env and fill in your credentials"
        exit 1
    fi
}

# Build Docker image
build_image() {
    print_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
    docker build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile .
    
    if [ $? -eq 0 ]; then
        print_success "Image built successfully"
    else
        print_error "Failed to build image"
        exit 1
    fi
}

# Stop existing container
stop_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Stopping existing container..."
        docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
        print_success "Container stopped and removed"
    else
        print_info "No running container found"
    fi
}

# Run container
run_container() {
    check_env_file
    
    # Stop existing container if running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container already running. Stopping it first..."
        stop_container
    fi
    
    print_info "Starting container: $CONTAINER_NAME"
    print_warning "Press Ctrl+C to stop"
    echo ""
    
    # Load .env and run container
    docker run --rm \
        --name "$CONTAINER_NAME" \
        --platform linux/amd64 \
        --env-file .env \
        "${IMAGE_NAME}:${IMAGE_TAG}"
}

# Show container logs
show_logs() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container is not running"
        exit 1
    fi
    
    print_info "Showing logs for $CONTAINER_NAME"
    print_warning "Press Ctrl+C to exit"
    echo ""
    
    docker logs -f "$CONTAINER_NAME"
}

# Open shell in container
open_shell() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container is not running"
        print_info "Start the container first: ./test-local-container.sh"
        exit 1
    fi
    
    print_info "Opening shell in $CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# Main execution
main() {
    if [ "$STOP_CONTAINER" = true ]; then
        stop_container
        exit 0
    fi
    
    if [ "$BUILD_IMAGE" = true ]; then
        build_image
    fi
    
    if [ "$SHOW_LOGS" = true ]; then
        show_logs
        exit 0
    fi
    
    if [ "$SHELL_ACCESS" = true ]; then
        open_shell
        exit 0
    fi
    
    # Default action: run container
    run_container
}

main


