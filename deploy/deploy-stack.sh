#!/bin/bash

# GenAI Stack - Docker Swarm Deployment Script
# This script deploys the GenAI Stack to a Docker Swarm cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="genai"
COMPOSE_FILE="docker-swarm-stack.yml"
ENV_FILE=".env"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to check if running on swarm manager
check_swarm_manager() {
    print_status "Checking if running on Docker Swarm manager..."
    
    if ! docker info | grep -q "Swarm: active"; then
        print_error "Docker Swarm is not active on this node"
        exit 1
    fi
    
    if ! docker node ls &> /dev/null; then
        print_error "This node is not a swarm manager"
        exit 1
    fi
    
    print_status "Running on Docker Swarm manager node"
}

# Function to validate environment file
validate_env_file() {
    print_status "Validating environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Environment file not found. Creating from template..."
        if [ -f "env.example" ]; then
            cp env.example "$ENV_FILE"
            print_warning "Please edit $ENV_FILE with your configuration before deployment"
            exit 1
        else
            print_error "Neither .env nor env.example file found"
            exit 1
        fi
    fi
    
    # Source the environment file
    source "$ENV_FILE"
    
    # Check required variables
    required_vars=("NEO4J_PASSWORD" "LLM" "EMBEDDING_MODEL")
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        print_error "Please configure these variables in $ENV_FILE"
        exit 1
    fi
    
    print_status "Environment validation completed"
}

# Function to build images
build_images() {
    print_status "Building Docker images..."
    
    # Build all custom images
    docker build -t genai-stack/pull-model:latest -f pull_model.Dockerfile .
    docker build -t genai-stack/api:latest -f api.Dockerfile .
    docker build -t genai-stack/bot:latest -f bot.Dockerfile .
    docker build -t genai-stack/pdf-bot:latest -f pdf_bot.Dockerfile .
    docker build -t genai-stack/loader:latest -f loader.Dockerfile .
    docker build -t genai-stack/frontend:latest -f front-end.Dockerfile .
    
    print_status "Docker images built successfully"
}

# Function to create networks
create_networks() {
    print_status "Creating Docker networks..."
    
    # Create overlay network if it doesn't exist
    if ! docker network ls | grep -q "genai_network"; then
        docker network create --driver overlay --attachable genai_network
        print_status "Created genai_network overlay network"
    else
        print_status "genai_network already exists"
    fi
}

# Function to deploy stack
deploy_stack() {
    print_status "Deploying GenAI Stack to Docker Swarm..."
    
    # Deploy the stack
    docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
    
    print_status "Stack deployment initiated"
}

# Function to wait for services
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for services to be running
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local running_services=$(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}}" | wc -l)
        local ready_services=$(docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}} {{.Replicas}}" | grep -c "1/1\|2/2\|3/3" || true)
        
        if [ $running_services -eq $ready_services ] && [ $running_services -gt 0 ]; then
            print_status "All services are ready"
            break
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Timeout waiting for services to be ready"
        print_status "Current service status:"
        docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
    fi
}

# Function to check service health
check_service_health() {
    print_status "Checking service health..."
    
    # Check database health
    local db_health=$(docker service ps ${STACK_NAME}_database --format "{{.CurrentState}}" | head -1)
    if [[ $db_health == *"Running"* ]]; then
        print_status "Database service is running"
    else
        print_warning "Database service health: $db_health"
    fi
    
    # Check API health
    local api_health=$(docker service ps ${STACK_NAME}_api --format "{{.CurrentState}}" | head -1)
    if [[ $api_health == *"Running"* ]]; then
        print_status "API service is running"
    else
        print_warning "API service health: $api_health"
    fi
    
    # Display all service status
    echo
    print_header "=== Service Status ==="
    docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
    echo
}

# Function to display access information
display_access_info() {
    # Get manager node IP
    local manager_ip=$(docker node inspect $(docker node ls --filter role=manager --format "{{.ID}}") --format "{{.Status.Addr}}")
    
    echo
    print_header "========================================="
    print_header "GenAI Stack Deployment Complete!"
    print_header "========================================="
    echo
    echo "Access URLs:"
    echo "- Main Application: https://$manager_ip"
    echo "- Support Bot: https://$manager_ip/bot"
    echo "- PDF Bot: https://$manager_ip/pdf"
    echo "- Loader: https://$manager_ip/loader"
    echo "- API: https://$manager_ip/api"
    echo "- Neo4j Browser: https://$manager_ip/neo4j"
    echo "- Grafana Monitoring: https://$manager_ip/grafana"
    echo "- Prometheus: https://$manager_ip/prometheus"
    echo
    echo "Service Management:"
    echo "- View services: docker service ls"
    echo "- View logs: docker service logs ${STACK_NAME}_<service_name>"
    echo "- Scale service: docker service scale ${STACK_NAME}_<service_name>=<replicas>"
    echo "- Update service: docker service update ${STACK_NAME}_<service_name>"
    echo "- Remove stack: docker stack rm $STACK_NAME"
    echo
    echo "Monitoring:"
    echo "- Stack status: docker stack ps $STACK_NAME"
    echo "- Node status: docker node ls"
    echo "- Service status: docker service ls"
    echo
    print_status "Deployment completed successfully!"
}

# Function to show help
show_help() {
    echo "GenAI Stack Deployment Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -b, --build    Force rebuild of Docker images"
    echo "  -u, --update   Update existing stack"
    echo "  -r, --remove   Remove existing stack"
    echo "  -s, --status   Show stack status"
    echo "  -l, --logs     Show service logs"
    echo
    echo "Examples:"
    echo "  $0                # Deploy stack"
    echo "  $0 --build        # Rebuild images and deploy"
    echo "  $0 --update       # Update existing stack"
    echo "  $0 --remove       # Remove stack"
    echo "  $0 --status       # Show status"
    echo "  $0 --logs api     # Show API service logs"
}

# Function to update stack
update_stack() {
    print_status "Updating GenAI Stack..."
    
    # Rebuild images
    build_images
    
    # Update the stack
    docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
    
    print_status "Stack update completed"
}

# Function to remove stack
remove_stack() {
    print_status "Removing GenAI Stack..."
    
    # Remove the stack
    docker stack rm "$STACK_NAME"
    
    print_status "Stack removed. Note: Volumes are preserved."
    print_status "To remove volumes: docker volume rm genai_neo4j_data genai_prometheus_data genai_grafana_data"
}

# Function to show stack status
show_status() {
    print_header "=== GenAI Stack Status ==="
    echo
    
    if docker stack ls | grep -q "$STACK_NAME"; then
        print_status "Stack is deployed"
        echo
        print_header "Services:"
        docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME"
        echo
        print_header "Tasks:"
        docker stack ps "$STACK_NAME"
    else
        print_warning "Stack is not deployed"
    fi
}

# Function to show service logs
show_logs() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        print_error "Please specify a service name"
        print_status "Available services:"
        docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "{{.Name}}"
        exit 1
    fi
    
    local full_service_name="${STACK_NAME}_${service_name}"
    
    if docker service ls --filter "name=$full_service_name" | grep -q "$full_service_name"; then
        print_status "Showing logs for $full_service_name..."
        docker service logs -f "$full_service_name"
    else
        print_error "Service $full_service_name not found"
        exit 1
    fi
}

# Main execution
main() {
    local build_flag=false
    local update_flag=false
    local remove_flag=false
    local status_flag=false
    local logs_flag=false
    local logs_service=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--build)
                build_flag=true
                shift
                ;;
            -u|--update)
                update_flag=true
                shift
                ;;
            -r|--remove)
                remove_flag=true
                shift
                ;;
            -s|--status)
                status_flag=true
                shift
                ;;
            -l|--logs)
                logs_flag=true
                logs_service="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if we're on a swarm manager
    check_swarm_manager
    
    # Handle different operations
    if [ "$remove_flag" = true ]; then
        remove_stack
        exit 0
    elif [ "$status_flag" = true ]; then
        show_status
        exit 0
    elif [ "$logs_flag" = true ]; then
        show_logs "$logs_service"
        exit 0
    elif [ "$update_flag" = true ]; then
        validate_env_file
        update_stack
        wait_for_services
        check_service_health
        display_access_info
        exit 0
    fi
    
    # Normal deployment
    print_header "=== GenAI Stack Deployment ==="
    
    validate_env_file
    create_networks
    
    if [ "$build_flag" = true ]; then
        build_images
    fi
    
    deploy_stack
    wait_for_services
    check_service_health
    display_access_info
}

# Run main function
main "$@"