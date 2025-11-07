#!/bin/bash

# ==============================================================================
# Snowflake Cortex Agents Slack Bot - SPCS Deployment Script
# ==============================================================================
# This script builds and deploys the Slack bot to Snowpark Container Services
# ==============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
UPDATE_ONLY=false
LOCAL_ONLY=false
SKIP_BUILD=false
CONNECTION_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --update)
            UPDATE_ONLY=true
            shift
            ;;
        --local)
            LOCAL_ONLY=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --connection|-c)
            CONNECTION_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --update           Update existing service (preserves configuration)"
            echo "  --local            Build and test locally only (no SPCS deployment)"
            echo "  --skip-build       Skip Docker build (use existing image)"
            echo "  --connection, -c   Snowflake CLI connection name (uses default if not specified)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh                          # First-time deployment (uses default connection)"
            echo "  ./deploy.sh --update                 # Update existing deployment"
            echo "  ./deploy.sh --local                  # Test locally with Docker"
            echo "  ./deploy.sh --connection my-conn     # Use specific connection"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ==============================================================================
# Configuration
# ==============================================================================
# These values must match the objects created in spcs_setup.sql

# SPCS Configuration
DB_NAME="CORTEX_SLACK_BOT_DB"              # Database created in spcs_setup.sql STEP 1
IMAGE_SCHEMA="IMAGE_SCHEMA"                # Schema for Docker images (STEP 1)
APP_SCHEMA="APP_SCHEMA"                    # Schema for SPCS service objects (STEP 1)
IMAGE_REPO="IMAGE_REPO"                    # Image repository (STEP 2)
COMPUTE_POOL="CORTEX_SLACK_BOT_POOL"       # Compute pool for running service (STEP 3)
SERVICE_NAME="CORTEX_SLACK_BOT_SERVICE"    # SPCS service name
STAGE_NAME="APP_STAGE"                     # Stage for service specs (STEP 6)

# Optional: Warehouse (defined in spcs_setup.sql STEP 7 but not required for deployment)
# WAREHOUSE_NAME="CORTEX_SLACK_BOT_WH"
# Note: SPCS operations (PUT, CREATE SERVICE, ALTER SERVICE) don't require a warehouse.
#       Services run on compute pools. The warehouse is only for manual management queries.

# Connection & Role Configuration
# - If --connection flag is provided, that connection is used
# - If no flag provided, the script automatically uses the default connection (is_default=True)
# - The role is determined by your Snowflake CLI connection profile
# - For initial setup: Use ACCOUNTADMIN or a role with appropriate privileges
# - For ongoing deployment: Use SNOWFLAKE_INTELLIGENCE_ADMIN or role with privileges from STEP 8

# Docker Configuration
IMAGE_NAME="cortex-slack-bot"
IMAGE_TAG="latest"

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required commands exist
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if [[ "$LOCAL_ONLY" == false ]] && ! command -v snow &> /dev/null; then
        missing_deps+=("snowflake-cli (snow)")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Install instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                docker)
                    echo "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                "snowflake-cli (snow)")
                    echo "  - Snowflake CLI: pip install snowflake-cli-labs"
                    ;;
            esac
        done
        exit 1
    fi
}

# Load environment variables
load_env() {
    if [ -f .env ]; then
        print_info "Loading environment variables from .env"
        export $(cat .env | grep -v '^#' | xargs)
    else
        print_warning ".env file not found. Using environment variables."
    fi
}

# ==============================================================================
# Docker Build
# ==============================================================================

build_docker_image() {
    print_header "Building Docker Image"
    
    if [[ "$SKIP_BUILD" == true ]]; then
        print_info "Skipping build (--skip-build flag set)"
        return 0
    fi
    
    print_info "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
    print_info "Platform: linux/amd64 (required for SPCS)"
    
    docker build \
        --platform linux/amd64 \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -f Dockerfile \
        .
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# ==============================================================================
# Local Testing
# ==============================================================================

test_local() {
    print_header "Testing Docker Image Locally"
    
    load_env
    
    print_info "Starting container locally..."
    print_warning "Press Ctrl+C to stop the container"
    
    docker run --rm \
        --platform linux/amd64 \
        -e SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN}" \
        -e SLACK_APP_TOKEN="${SLACK_APP_TOKEN}" \
        -e ACCOUNT="${ACCOUNT}" \
        -e HOST="${HOST}" \
        -e DEMO_USER="${DEMO_USER}" \
        -e DEMO_USER_ROLE="${DEMO_USER_ROLE}" \
        -e WAREHOUSE="${WAREHOUSE}" \
        # -e AGENT_ENDPOINT="${AGENT_ENDPOINT}" \
        -e PAT="${PAT}" \
        "${IMAGE_NAME}:${IMAGE_TAG}"
}

# ==============================================================================
# SPCS Deployment
# ==============================================================================

deploy_to_spcs() {
    print_header "Deploying to Snowpark Container Services"
    
    # Determine connection argument
    local conn_arg=""
    if [ -n "$CONNECTION_NAME" ]; then
        conn_arg="--connection $CONNECTION_NAME"
        print_info "Using Snowflake connection: $CONNECTION_NAME"
    else
        # Get the default connection (is_default=True)
        DEFAULT_CONN=$(snow connection list --format json 2>/dev/null | jq -r '.[] | select(.is_default == true) | .connection_name' 2>/dev/null || echo "")
        if [ -n "$DEFAULT_CONN" ]; then
            CONNECTION_NAME="$DEFAULT_CONN"
            conn_arg="--connection $CONNECTION_NAME"
            print_info "Using default Snowflake connection: $CONNECTION_NAME"
        else
            print_info "Using default Snowflake connection (no explicit name found)"
        fi
    fi
    
    # Get repository URL
    print_info "Getting image repository URL..."
    REPO_URL=$(snow sql $conn_arg -q "
        SHOW IMAGE REPOSITORIES IN SCHEMA ${DB_NAME}.${IMAGE_SCHEMA};
        SELECT \"repository_url\" 
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE \"name\" = '${IMAGE_REPO}';
    " --format json | jq -r '.[1][0]["repository_url"]' 2>/dev/null)
    
    if [ -z "$REPO_URL" ] || [ "$REPO_URL" == "null" ]; then
        print_error "Failed to get repository URL"
        print_info "Make sure you've run spcs_setup.sql first"
        print_info "Check that image repository exists: SHOW IMAGE REPOSITORIES IN SCHEMA ${DB_NAME}.${IMAGE_SCHEMA};"
        exit 1
    fi
    
    print_success "Repository URL: $REPO_URL"
    
    # Docker login to Snowflake registry
    print_info "Logging in to Snowflake registry..."
    
    # Use Snowflake CLI's SPCS image-registry login command
    # This automatically handles Docker authentication
    snow spcs image-registry login $conn_arg
    
    if [ $? -ne 0 ]; then
        print_error "Failed to authenticate with Snowflake registry"
        print_info "Make sure your connection has proper credentials and privileges"
        print_info "Try manually: snow spcs image-registry login $conn_arg"
        exit 1
    fi
    
    print_success "Successfully authenticated with Snowflake registry"
    
    # Tag image
    print_info "Tagging image for Snowflake registry..."
    FULL_IMAGE_PATH="${REPO_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE_PATH"
    
    # Push image
    print_info "Pushing image to Snowflake registry..."
    print_info "This may take several minutes..."
    
    docker push "$FULL_IMAGE_PATH"
    
    if [ $? -eq 0 ]; then
        print_success "Image pushed successfully"
    else
        print_error "Failed to push image"
        exit 1
    fi
    
    # Upload spec file(s)
    print_info "Uploading service specification..."
    
    # Always upload base spec.yaml
    snow sql $conn_arg -q "
        PUT file://spec.yaml @${DB_NAME}.${APP_SCHEMA}.${STAGE_NAME} 
        AUTO_COMPRESS=FALSE 
        OVERWRITE=TRUE;
    " > /dev/null
    
    # Check if spcs-env.yaml exists and upload it
    if [ -f "spcs-env.yaml" ]; then
        print_info "Found spcs-env.yaml - uploading with environment variables..."
        snow sql $conn_arg -q "
            PUT file://spcs-env.yaml @${DB_NAME}.${APP_SCHEMA}.${STAGE_NAME} 
            AUTO_COMPRESS=FALSE 
            OVERWRITE=TRUE;
        " > /dev/null
        SPEC_FILE="spcs-env.yaml"
        print_success "Service specification with environment variables uploaded"
    else
        SPEC_FILE="spec.yaml"
        print_warning "spcs-env.yaml not found - using base spec.yaml"
        print_info "To add environment variables, copy spcs-env-template.yaml to spcs-env.yaml and configure it"
        print_success "Base service specification uploaded"
    fi
    
    # Create or update service
    if [[ "$UPDATE_ONLY" == true ]]; then
        update_service
    else
        create_service
    fi
}

create_service() {
    print_header "Creating SPCS Service"
    
    load_env
    
    # Check if service already exists
    local service_exists=$(snow sql $conn_arg -q "
        SHOW SERVICES LIKE '${SERVICE_NAME}' IN SCHEMA ${DB_NAME}.${APP_SCHEMA};
        SELECT COUNT(*) as cnt FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    " --format json 2>/dev/null | jq -r '.[0].CNT' 2>/dev/null || echo "0")
    
    if [ "$service_exists" != "0" ]; then
        print_warning "Service already exists. Use --update to update it."
        print_info "Current service status:"
        snow sql $conn_arg -q "
            SELECT SYSTEM\$GET_SERVICE_STATUS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}');
        "
        return 0
    fi
    
    print_info "Creating new service with spec: ${SPEC_FILE}"
    
    if [ "$SPEC_FILE" == "spec.yaml" ]; then
        print_warning "Using base spec without environment variables"
        print_info "See QUICKSTART.md for how to add environment variables after deployment"
    fi
    
    snow sql $conn_arg -q "
        USE SCHEMA ${DB_NAME}.${APP_SCHEMA};
        
        CREATE SERVICE IF NOT EXISTS ${SERVICE_NAME}
            IN COMPUTE POOL ${COMPUTE_POOL}
            FROM @${STAGE_NAME}
            SPEC = '${SPEC_FILE}'
            MIN_INSTANCES = 1
            MAX_INSTANCES = 1
            EXTERNAL_ACCESS_INTEGRATIONS = (slack_external_access_integration)
            COMMENT = 'Cortex Agents Slack Bot Service';
    "
    
    if [ $? -eq 0 ]; then
        print_success "Service created successfully"
        print_info "Checking service status..."
        sleep 5
        show_service_status
    else
        print_error "Failed to create service"
        exit 1
    fi
}

update_service() {
    print_header "Updating SPCS Service"
    
    print_info "Suspending service..."
    snow sql $conn_arg -q "
        ALTER SERVICE ${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME} SUSPEND;
    " > /dev/null 2>&1
    
    sleep 3
    
    print_info "Resuming service with new spec: ${SPEC_FILE}..."
    snow sql $conn_arg -q "
        ALTER SERVICE ${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME} 
        FROM @${DB_NAME}.${APP_SCHEMA}.${STAGE_NAME}
        SPEC = '${SPEC_FILE}';
        
        ALTER SERVICE ${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME} RESUME;
    "
    
    if [ $? -eq 0 ]; then
        print_success "Service updated successfully"
        print_info "Waiting for service to start..."
        sleep 5
        show_service_status
    else
        print_error "Failed to update service"
        exit 1
    fi
}

show_service_status() {
    print_header "Service Status"
    
    local conn_arg=""
    if [ -n "$CONNECTION_NAME" ]; then
        conn_arg="--connection $CONNECTION_NAME"
    else
        # Get the default connection (is_default=True)
        DEFAULT_CONN=$(snow connection list --format json 2>/dev/null | jq -r '.[] | select(.is_default == true) | .connection_name' 2>/dev/null || echo "")
        if [ -n "$DEFAULT_CONN" ]; then
            conn_arg="--connection $DEFAULT_CONN"
        fi
    fi
    
    print_info "Service status:"
    snow sql $conn_arg -q "
        SELECT SYSTEM\$GET_SERVICE_STATUS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}');
    "
    
    echo ""
    print_info "Recent logs (last 50 lines):"
    snow sql $conn_arg -q "
        SELECT SYSTEM\$GET_SERVICE_LOGS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}', '0', 'cortex-slack-bot', 50);
    "
    
    echo ""
    print_info "Useful commands:"
    echo "  - View logs: snow sql -q \"SELECT SYSTEM\$GET_SERVICE_LOGS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}', '0', 'cortex-slack-bot', 100);\""
    echo "  - Suspend: snow sql -q \"ALTER SERVICE ${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME} SUSPEND;\""
    echo "  - Resume: snow sql -q \"ALTER SERVICE ${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME} RESUME;\""
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    print_header "Snowflake Cortex Agents Slack Bot Deployment"
    
    # Check dependencies
    check_dependencies
    
    # Build Docker image
    build_docker_image
    
    # Local testing or SPCS deployment
    if [[ "$LOCAL_ONLY" == true ]]; then
        test_local
    else
        deploy_to_spcs
        
        echo ""
        print_success "Deployment complete!"
        echo ""
        print_info "Next steps:"
        echo "  1. Check service status: snow sql -q \"SELECT SYSTEM\$GET_SERVICE_STATUS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}');\""
        echo "  2. View logs: snow sql -q \"SELECT SYSTEM\$GET_SERVICE_LOGS('${DB_NAME}.${APP_SCHEMA}.${SERVICE_NAME}', '0', 'cortex-slack-bot', 100);\""
        echo "  3. Test your Slack bot by sending it a message"
        echo ""
        
        if [ ! -f "spcs-env.yaml" ]; then
            print_warning "Environment variables not configured!"
            echo "  To add credentials:"
            echo "    1. Copy template: cp spcs-env-template.yaml spcs-env.yaml"
            echo "    2. Edit spcs-env.yaml with your credentials"
            echo "    3. Redeploy: ./deploy.sh --update --skip-build"
            echo ""
            echo "  Or see QUICKSTART.md for other options"
        fi
    fi
}

# Run main function
main
