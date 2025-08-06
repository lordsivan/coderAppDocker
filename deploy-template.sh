#!/bin/bash

# Deploy Coder template for static IP workspace
# This script creates/updates the Coder template

set -euo pipefail

TEMPLATE_NAME="static-ip-workspace"
TEMPLATE_DIR="./template"
REGISTRY="${DOCKER_REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-coder-static-ip}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if coder CLI is available
    if ! command -v coder &> /dev/null; then
        log "ERROR: Coder CLI not found. Please install it first."
        log "Visit: https://coder.com/docs/coder-oss/latest/install"
        exit 1
    fi
    
    # Check if logged in to Coder
    if ! coder whoami &> /dev/null; then
        log "ERROR: Not logged in to Coder. Run 'coder login <your-coder-url>'"
        exit 1
    fi
    
    # Check if template directory exists
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log "ERROR: Template directory not found: $TEMPLATE_DIR"
        exit 1
    fi
    
    # Check if ip-map.txt exists in template directory
    if [ ! -f "$TEMPLATE_DIR/ip-map.txt" ]; then
        log "ERROR: ip-map.txt not found in template directory"
        log "Please copy ip-map.txt to $TEMPLATE_DIR/"
        exit 1
    fi
    
    log "Prerequisites check passed!"
}

# Validate template
validate_template() {
    log "Validating Terraform template..."
    
    cd "$TEMPLATE_DIR"
    
    # Initialize Terraform
    if ! terraform init -upgrade &> /dev/null; then
        log "ERROR: Terraform initialization failed"
        exit 1
    fi
    
    # Validate template
    if ! terraform validate; then
        log "ERROR: Template validation failed"
        exit 1
    fi
    
    cd ..
    log "Template validation passed!"
}

# Check if Docker image exists
check_image() {
    local full_image="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    log "Checking Docker image: $full_image"
    
    if docker image inspect "$full_image" &> /dev/null; then
        log "Image found locally: $full_image"
    else
        log "WARNING: Image not found locally: $full_image"
        log "Make sure the image is available in the registry"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Deploy template
deploy_template() {
    log "Deploying template: $TEMPLATE_NAME"
    
    # Check if template already exists
    if coder templates list | grep -q "$TEMPLATE_NAME"; then
        log "Template exists, updating..."
        coder templates push "$TEMPLATE_NAME" \
            --directory "$TEMPLATE_DIR" \
            --var "image_registry=$REGISTRY" \
            --var "image_name=$IMAGE_NAME" \
            --var "image_tag=$IMAGE_TAG" \
            --yes
    else
        log "Creating new template..."
        coder templates create "$TEMPLATE_NAME" \
            --directory "$TEMPLATE_DIR" \
            --var "image_registry=$REGISTRY" \
            --var "image_name=$IMAGE_NAME" \
            --var "image_tag=$IMAGE_TAG"
    fi
    
    log "Template deployment completed!"
}

# Show template info
show_template_info() {
    log "=== Template Information ==="
    coder templates show "$TEMPLATE_NAME" || true
    
    log ""
    log "=== Usage Instructions ==="
    log "1. Access your Coder web UI"
    log "2. Click 'Create Workspace'"
    log "3. Select template: $TEMPLATE_NAME"
    log "4. Configure resources as needed"
    log "5. Create your workspace"
    log ""
    log "Your workspace will get a static IP based on your username from ip-map.txt"
}

# Main execution
main() {
    log "=== Coder Static IP Template Deployment ==="
    log "Template: $TEMPLATE_NAME"
    log "Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    log ""
    
    check_prerequisites
    validate_template
    check_image
    deploy_template
    show_template_info
    
    log "=== Deployment Complete! ==="
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Environment variables:"
        echo "  DOCKER_REGISTRY  Docker registry URL (default: docker.io)"
        echo "  IMAGE_NAME       Docker image name (default: coder-static-ip)"
        echo "  IMAGE_TAG        Docker image tag (default: latest)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Use defaults"
        echo "  DOCKER_REGISTRY=ghcr.io IMAGE_NAME=my-coder $0"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac