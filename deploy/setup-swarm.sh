#!/bin/bash

# GenAI Stack - Docker Swarm Cluster Setup Script
# This script sets up a 3-node Docker Swarm cluster for orchestrating the GenAI Stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MANAGER_NODE=""
WORKER_NODE_1=""
WORKER_NODE_2=""
SSH_KEY_PATH=""
DOCKER_COMPOSE_VERSION="2.21.0"

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

# Function to check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v ssh &> /dev/null; then
        print_error "SSH client is required but not installed."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not installed locally."
        exit 1
    fi
    
    print_status "Requirements check passed."
}

# Function to read configuration
read_config() {
    echo "=== Docker Swarm Cluster Setup ==="
    echo "Please provide the following information:"
    echo
    
    read -p "Manager node IP address: " MANAGER_NODE
    read -p "Worker node 1 IP address: " WORKER_NODE_1
    read -p "Worker node 2 IP address: " WORKER_NODE_2
    read -p "SSH key path (default: ~/.ssh/id_rsa): " SSH_KEY_PATH
    
    SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}
    
    echo
    echo "Configuration:"
    echo "Manager Node: $MANAGER_NODE"
    echo "Worker Node 1: $WORKER_NODE_1"
    echo "Worker Node 2: $WORKER_NODE_2"
    echo "SSH Key: $SSH_KEY_PATH"
    echo
    
    read -p "Is this configuration correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Configuration cancelled."
        exit 1
    fi
}

# Function to install Docker on a node
install_docker() {
    local node_ip=$1
    local node_name=$2
    
    print_status "Installing Docker on $node_name ($node_ip)..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$node_ip << 'EOF'
        # Update system
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        # Add user to docker group
        usermod -aG docker $USER
        
        # Configure Docker daemon
        cat > /etc/docker/daemon.json << 'DAEMON_EOF'
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "metrics-addr": "0.0.0.0:9323",
    "experimental": true
}
DAEMON_EOF
        
        # Restart Docker
        systemctl restart docker
        
        # Install Docker Compose
        curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        echo "Docker installation completed on $(hostname)"
EOF
    
    print_status "Docker installation completed on $node_name"
}

# Function to initialize Docker Swarm
init_swarm() {
    print_status "Initializing Docker Swarm on manager node..."
    
    # Initialize swarm on manager node
    SWARM_TOKEN=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$MANAGER_NODE << 'EOF'
        # Initialize swarm
        docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
        
        # Get worker token
        docker swarm join-token worker -q
EOF
    )
    
    if [ -z "$SWARM_TOKEN" ]; then
        print_error "Failed to initialize Docker Swarm or get worker token"
        exit 1
    fi
    
    print_status "Docker Swarm initialized. Worker token: $SWARM_TOKEN"
}

# Function to join workers to swarm
join_workers() {
    print_status "Joining worker nodes to swarm..."
    
    # Join worker node 1
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$WORKER_NODE_1 << EOF
        docker swarm join --token $SWARM_TOKEN $MANAGER_NODE:2377
EOF
    
    # Join worker node 2
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$WORKER_NODE_2 << EOF
        docker swarm join --token $SWARM_TOKEN $MANAGER_NODE:2377
EOF
    
    print_status "Worker nodes joined to swarm"
}

# Function to label nodes
label_nodes() {
    print_status "Labeling nodes for deployment constraints..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$MANAGER_NODE << EOF
        # Label manager node
        docker node update --label-add zone=manager --label-add gpu=false \$(docker node ls --filter role=manager --format "{{.ID}}")
        
        # Label worker nodes
        WORKER_NODES=\$(docker node ls --filter role=worker --format "{{.ID}}")
        WORKER_COUNT=0
        for NODE in \$WORKER_NODES; do
            WORKER_COUNT=\$((WORKER_COUNT + 1))
            if [ \$WORKER_COUNT -eq 1 ]; then
                docker node update --label-add zone=worker1 --label-add gpu=true \$NODE
            else
                docker node update --label-add zone=worker2 --label-add gpu=true \$NODE
            fi
        done
        
        # Display node information
        docker node ls
EOF
    
    print_status "Node labeling completed"
}

# Function to create SSL certificates
create_ssl_certs() {
    print_status "Creating SSL certificates for HTTPS..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$MANAGER_NODE << 'EOF'
        # Create SSL directory
        mkdir -p /opt/genai-stack/nginx/ssl
        
        # Generate self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /opt/genai-stack/nginx/ssl/key.pem \
            -out /opt/genai-stack/nginx/ssl/cert.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
        
        # Set proper permissions
        chmod 600 /opt/genai-stack/nginx/ssl/key.pem
        chmod 644 /opt/genai-stack/nginx/ssl/cert.pem
EOF
    
    print_status "SSL certificates created"
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Setting up monitoring configuration..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$MANAGER_NODE << 'EOF'
        # Create monitoring directories
        mkdir -p /opt/genai-stack/monitoring/grafana/{dashboards,datasources}
        
        # Create Prometheus configuration
        cat > /opt/genai-stack/monitoring/prometheus.yml << 'PROM_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'docker-swarm'
    static_configs:
      - targets: ['manager:9323', 'worker1:9323', 'worker2:9323']
  
  - job_name: 'nginx'
    static_configs:
      - targets: ['load-balancer:8080']
  
  - job_name: 'genai-api'
    static_configs:
      - targets: ['api:8504']
  
  - job_name: 'neo4j'
    static_configs:
      - targets: ['database:7474']
PROM_EOF
        
        # Create Grafana datasource
        cat > /opt/genai-stack/monitoring/grafana/datasources/prometheus.yml << 'GRAFANA_EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
GRAFANA_EOF
        
        echo "Monitoring configuration created"
EOF
    
    print_status "Monitoring configuration completed"
}

# Function to copy application files
copy_files() {
    print_status "Copying application files to manager node..."
    
    # Create directory structure
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no root@$MANAGER_NODE << 'EOF'
        mkdir -p /opt/genai-stack
        cd /opt/genai-stack
EOF
    
    # Copy all necessary files
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r ./* root@$MANAGER_NODE:/opt/genai-stack/
    
    print_status "Application files copied successfully"
}

# Function to display completion message
display_completion() {
    echo
    echo "========================================="
    echo "Docker Swarm Cluster Setup Complete!"
    echo "========================================="
    echo
    echo "Cluster Information:"
    echo "- Manager Node: $MANAGER_NODE"
    echo "- Worker Node 1: $WORKER_NODE_1"
    echo "- Worker Node 2: $WORKER_NODE_2"
    echo
    echo "To deploy the GenAI Stack:"
    echo "1. SSH to manager node: ssh -i $SSH_KEY_PATH root@$MANAGER_NODE"
    echo "2. Navigate to: cd /opt/genai-stack"
    echo "3. Create .env file: cp env.example .env"
    echo "4. Edit .env file with your configuration"
    echo "5. Deploy stack: docker stack deploy -c docker-swarm-stack.yml genai"
    echo
    echo "Access URLs (replace with your domain/IP):"
    echo "- Main Application: https://$MANAGER_NODE"
    echo "- Neo4j Browser: https://$MANAGER_NODE/neo4j"
    echo "- Grafana: https://$MANAGER_NODE/grafana"
    echo "- Prometheus: https://$MANAGER_NODE/prometheus"
    echo
    print_status "Setup completed successfully!"
}

# Main execution
main() {
    check_requirements
    read_config
    
    print_status "Starting Docker Swarm cluster setup..."
    
    # Install Docker on all nodes
    install_docker "$MANAGER_NODE" "Manager"
    install_docker "$WORKER_NODE_1" "Worker-1"
    install_docker "$WORKER_NODE_2" "Worker-2"
    
    # Initialize swarm and join workers
    init_swarm
    join_workers
    label_nodes
    
    # Setup SSL and monitoring
    create_ssl_certs
    deploy_monitoring
    
    # Copy application files
    copy_files
    
    display_completion
}

# Run main function
main "$@"