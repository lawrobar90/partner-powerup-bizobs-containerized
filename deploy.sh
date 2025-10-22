#!/bin/bash

# BizObs Partner PowerUp Containerized - Complete Deployment Script
# Revolutionary microservices architecture with dynamic service discovery
# Supports Docker Compose, Kubernetes (K3s), and hybrid deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="$(pwd)"
APP_PORT="8080"
NAMESPACE="bizobs"
APP_NAME="bizobs-app"
HEALTH_ENDPOINT="/health"
DEPLOYMENT_MODE="${1:-k8s}"  # k8s, docker, or hybrid

echo -e "${PURPLE}${BOLD}🚀 BizObs Partner PowerUp Containerized Deployment${NC}"
echo -e "${PURPLE}${BOLD}===================================================${NC}"
echo -e "${CYAN}📁 Working Directory: $APP_DIR${NC}"
echo -e "${CYAN}🚀 Deployment Mode: $DEPLOYMENT_MODE${NC}"
echo -e "${CYAN}🌐 Namespace: $NAMESPACE${NC}"
echo -e "${CYAN}🔧 Port: $APP_PORT${NC}"
echo ""

# Print usage if invalid mode
if [[ "$DEPLOYMENT_MODE" != "k8s" && "$DEPLOYMENT_MODE" != "docker" && "$DEPLOYMENT_MODE" != "hybrid" ]]; then
    echo -e "${YELLOW}Usage: $0 [k8s|docker|hybrid]${NC}"
    echo -e "${YELLOW}  k8s    - Deploy to Kubernetes (default)${NC}"
    echo -e "${YELLOW}  docker - Deploy with Docker Compose${NC}"
    echo -e "${YELLOW}  hybrid - Deploy main app to K8s, services to Docker${NC}"
    exit 1
fi

# Function to print step headers
print_step() {
    echo -e "${CYAN}${BOLD}📋 STEP: $1${NC}"
    echo -e "${CYAN}----------------------------------------${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get server IP
get_server_ip() {
    local ip=""
    
    if command_exists hostname; then
        ip=$(hostname -I | awk '{print $1}' | tr -d '\n')
    fi
    
    if [[ -z "$ip" ]]; then
        ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
    fi
    
    if [[ -z "$ip" ]]; then
        ip="localhost"
    fi
    
    echo "$ip"
}

# Function to wait for pod to be ready
wait_for_pod() {
    local max_attempts=60
    local attempt=1
    
    echo -e "${YELLOW}⏳ Waiting for BizObs pod to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        local ready_pods=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$ready_pods" -gt 0 ]; then
            local pod_ready=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$pod_ready" = "True" ]; then
                echo -e "${GREEN}✅ Pod is ready!${NC}"
                return 0
            fi
        fi
        
        printf "${YELLOW}   Attempt $attempt/$max_attempts - waiting 5 seconds...${NC}\n"
        sleep 5
        ((attempt++))
    done
    
    echo -e "${RED}❌ Pod failed to start within expected time${NC}"
    return 1
}

# Function to wait for service to be ready
wait_for_service() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}⏳ Waiting for BizObs service to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Service is ready!${NC}"
            return 0
        fi
        
        printf "${YELLOW}   Attempt $attempt/$max_attempts - waiting 5 seconds...${NC}\n"
        sleep 5
        ((attempt++))
    done
    
    echo -e "${RED}❌ Service failed to start within expected time${NC}"
    return 1
}

print_step "1. Environment Check"
echo "🔍 Checking system requirements..."

# Check Docker
if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker found: $(docker --version)${NC}"
fi

# Check K3s/kubectl for k8s deployments
if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    if ! command_exists kubectl; then
        echo -e "${RED}❌ kubectl is not installed or K3s is not running.${NC}"
        echo -e "${YELLOW}Installing K3s...${NC}"
        curl -sfL https://get.k3s.io | sh -
        
        echo -e "${YELLOW}⏳ Waiting for K3s to be ready...${NC}"
        sleep 30
        
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    else
        echo -e "${GREEN}✅ kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'K3s kubectl')${NC}"
    fi

    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check K3s installation.${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
    fi
fi

# Check Docker Compose for docker deployments
if [[ "$DEPLOYMENT_MODE" == "docker" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose is not installed.${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Docker Compose found${NC}"
    fi
fi

echo ""

print_step "2. Clean Up Previous Deployment"
echo "🧹 Removing any existing deployment..."

if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        echo "   Removing existing Kubernetes resources..."
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        
        echo "   Waiting for namespace cleanup..."
        while kubectl get namespace $NAMESPACE >/dev/null 2>&1; do
            sleep 2
        done
    fi
fi

if [[ "$DEPLOYMENT_MODE" == "docker" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    if docker-compose ps >/dev/null 2>&1 || docker compose ps >/dev/null 2>&1; then
        echo "   Stopping Docker Compose services..."
        (docker-compose down 2>/dev/null || docker compose down 2>/dev/null) || true
    fi
fi

echo -e "${GREEN}✅ Cleanup completed${NC}"
echo ""

print_step "3. Verify Application Files"
echo "📋 Checking application structure..."

if [[ ! -f "server.js" ]]; then
    echo -e "${RED}❌ server.js not found. Please run this script from the project root directory.${NC}"
    exit 1
fi

if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]] && [[ ! -d "k8s" ]]; then
    echo -e "${RED}❌ k8s directory not found. Please ensure Kubernetes manifests exist.${NC}"
    exit 1
fi

if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}❌ Dockerfile not found. Please ensure Dockerfile exists.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Application files verified${NC}"
echo ""

# Kubernetes Deployment
if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    print_step "4. Build and Deploy to Kubernetes"
    echo "🔨 Building Docker image for K3s..."

    # Generate timestamp for unique image tag
    TIMESTAMP=$(date +%s)
    IMAGE_TAG="v${TIMESTAMP}"

    # Build the Docker image with timestamp tag
    echo "   Building image: ${APP_NAME}:${IMAGE_TAG}"
    docker build -t ${APP_NAME}:${IMAGE_TAG} .
    docker tag ${APP_NAME}:${IMAGE_TAG} ${APP_NAME}:latest

    # Import image to K3s
    echo "   Importing image to K3s..."
    docker save ${APP_NAME}:${IMAGE_TAG} | sudo k3s ctr images import -

    echo "☸️  Deploying BizObs to K3s cluster..."
    kubectl apply -f k8s/namespace.yaml
    
    # Wait for namespace to be ready
    echo "   Waiting for namespace to be ready..."
    kubectl wait --for=condition=Ready namespace/$NAMESPACE --timeout=60s || true
    sleep 5
    
    # Apply remaining manifests
    kubectl apply -f k8s/

    echo -e "${GREEN}✅ Kubernetes deployment completed${NC}"
    echo ""

    print_step "5. Pod Health Check"
    wait_for_pod
    echo ""

    print_step "6. Service Health Check"
    SERVER_IP=$(get_server_ip)
    
    # Auto-detect training session ID for URLs
    TRAINING_SESSION_ID=$(kubectl get ingress -A -o yaml 2>/dev/null | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}\.dynatrace\.training' | head -1 | cut -d'.' -f1 || echo "db520973-99cc-4fa8-bf3d-5a128e32e7c5")
    
    EXTERNAL_URL="https://bizobs.${TRAINING_SESSION_ID}.dynatrace.training"
    NODEPORT_URL="http://$SERVER_IP:30808"
    HEALTH_URL="$NODEPORT_URL$HEALTH_ENDPOINT"

    wait_for_service "$HEALTH_URL"
    echo ""
fi

# Docker Compose Deployment
if [[ "$DEPLOYMENT_MODE" == "docker" ]]; then
    print_step "4. Deploy with Docker Compose"
    echo "🐳 Starting Docker Compose deployment..."

    # Check if docker-compose.yml exists, create basic one if not
    if [[ ! -f "docker-compose.yml" ]]; then
        echo "   Creating docker-compose.yml..."
        cat > docker-compose.yml << EOF
version: '3.8'
services:
  bizobs-app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
      - PORT=8080
      - DT_SERVICE_NAME=BizObs-MainServer
      - DT_APPLICATION_NAME=BizObs-CustomerJourney
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF
    fi

    # Start services
    if command_exists docker-compose; then
        docker-compose up -d --build
    else
        docker compose up -d --build
    fi

    echo -e "${GREEN}✅ Docker Compose deployment completed${NC}"
    echo ""

    print_step "5. Service Health Check"
    SERVER_IP=$(get_server_ip)
    DOCKER_URL="http://$SERVER_IP:8080"
    HEALTH_URL="$DOCKER_URL$HEALTH_ENDPOINT"

    wait_for_service "$HEALTH_URL"
    echo ""
fi

# Display final status
print_step "Final Deployment Status"
echo "📊 Checking deployment status..."

if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    echo "   Kubernetes Pod Status:"
    kubectl get pods -n $NAMESPACE -o wide

    echo ""
    echo "   Kubernetes Service Status:"
    kubectl get services -n $NAMESPACE

    echo ""
    echo "   Ingress Status:"
    kubectl get ingress -n $NAMESPACE

    echo ""
    echo "   Recent Pod Logs:"
    kubectl logs -n $NAMESPACE -l app=$APP_NAME --tail=10
fi

if [[ "$DEPLOYMENT_MODE" == "docker" ]]; then
    echo "   Docker Compose Status:"
    if command_exists docker-compose; then
        docker-compose ps
    else
        docker compose ps
    fi
fi

echo ""

print_step "🎉 DEPLOYMENT COMPLETE!"
echo -e "${GREEN}${BOLD}========================${NC}"
echo ""

# Display URLs based on deployment mode
if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    echo -e "${PURPLE}🌐 Kubernetes Application URLs:${NC}"
    echo -e "${GREEN}├─ 🌍 External HTTPS:       ${BLUE}$EXTERNAL_URL${NC}"
    echo -e "${GREEN}├─ 🏠 NodePort Access:      ${BLUE}$NODEPORT_URL${NC}"
    echo -e "${GREEN}├─ 📊 Admin Panel:          ${BLUE}$EXTERNAL_URL/index-full.html${NC}"
    echo -e "${GREEN}├─ 🔍 Debug Interface:      ${BLUE}$EXTERNAL_URL/debug.html${NC}"
    echo -e "${GREEN}└─ ❤️  Health Check:        ${BLUE}$EXTERNAL_URL/health${NC}"
fi

if [[ "$DEPLOYMENT_MODE" == "docker" ]]; then
    echo -e "${PURPLE}🐳 Docker Application URLs:${NC}"
    echo -e "${GREEN}├─ 🌍 Main Application:     ${BLUE}$DOCKER_URL${NC}"
    echo -e "${GREEN}├─ 📊 Admin Panel:          ${BLUE}$DOCKER_URL/index-full.html${NC}"
    echo -e "${GREEN}├─ 🔍 Debug Interface:      ${BLUE}$DOCKER_URL/debug.html${NC}"
    echo -e "${GREEN}└─ ❤️  Health Check:        ${BLUE}$DOCKER_URL/health${NC}"
fi

echo ""
echo -e "${PURPLE}🚀 Revolutionary API Endpoints:${NC}"
if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    BASE_API_URL="$EXTERNAL_URL"
else
    BASE_API_URL="$DOCKER_URL"
fi

echo -e "${GREEN}├─ 🌟 Single Journey:       ${BLUE}POST $BASE_API_URL/api/journey-simulation/simulate-journey${NC}"
echo -e "${GREEN}├─ 👥 Multiple Customers:   ${BLUE}POST $BASE_API_URL/api/journey-simulation/simulate-multiple-journeys${NC}"
echo -e "${GREEN}├─ 📈 Service Status:       ${BLUE}GET $BASE_API_URL/api/admin/services/status${NC}"
echo -e "${GREEN}├─ 🔍 Trace Validation:     ${BLUE}GET $BASE_API_URL/api/admin/trace-validation${NC}"
echo -e "${GREEN}└─ 📊 Service Discovery:    ${BLUE}GET $BASE_API_URL/api/admin/services${NC}"

echo ""
echo -e "${PURPLE}📱 Quick Test Commands:${NC}"
echo -e "${CYAN}# Test customer journey:${NC}"
echo "curl -X POST '$BASE_API_URL/api/journey-simulation/simulate-journey' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"companyName\":\"ACE-Demo\",\"customerId\":\"test_$(date +%s)\"}'"

echo ""
echo -e "${CYAN}# Check application health:${NC}"
echo "curl '$BASE_API_URL/health'"

echo ""
echo -e "${PURPLE}🔧 Management Commands:${NC}"
if [[ "$DEPLOYMENT_MODE" == "k8s" || "$DEPLOYMENT_MODE" == "hybrid" ]]; then
    echo -e "${GREEN}├─ View logs:              ${CYAN}kubectl logs -n $NAMESPACE -l app=$APP_NAME -f${NC}"
    echo -e "${GREEN}├─ Check pods:             ${CYAN}kubectl get pods -n $NAMESPACE${NC}"
    echo -e "${GREEN}├─ Restart deployment:     ${CYAN}kubectl rollout restart deployment $APP_NAME -n $NAMESPACE${NC}"
    echo -e "${GREEN}└─ Remove deployment:      ${CYAN}kubectl delete namespace $NAMESPACE${NC}"
fi

if [[ "$DEPLOYMENT_MODE" == "docker" ]]; then
    echo -e "${GREEN}├─ View logs:              ${CYAN}docker-compose logs -f${NC}"
    echo -e "${GREEN}├─ Check status:           ${CYAN}docker-compose ps${NC}"
    echo -e "${GREEN}├─ Restart services:       ${CYAN}docker-compose restart${NC}"
    echo -e "${GREEN}└─ Stop services:          ${CYAN}docker-compose down${NC}"
fi

echo ""
echo -e "${GREEN}🎉 BizObs Partner PowerUp deployment completed successfully!${NC}"
echo -e "${GREEN}   Revolutionary microservices architecture is ready!${NC}"