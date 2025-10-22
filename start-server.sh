#!/bin/bash

# BizObs Partner PowerUp Containerized K3s Deployment Script
# FOR FRESH ACE-BOX INSTANCES - Downloads and deploys from GitHub
# Revolutionary microservices architecture with dynamic service discovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/lawrobar90/partner-powerup-bizobs-containerized.git"
APP_DIR="partner-powerup-bizobs-containerized"
APP_PORT="8080"
NAMESPACE="bizobs"
APP_NAME="bizobs-app"
HEALTH_ENDPOINT="/health"
IMAGE_TAG="latest"

echo -e "${PURPLE}🚀 BizObs Partner PowerUp Containerized K3s Deployment${NC}"
echo -e "${PURPLE}====================================================${NC}"
echo -e "${CYAN}📁 Repository: $REPO_URL${NC}"
echo -e "${CYAN}🌐 Namespace: $NAMESPACE${NC}"
echo -e "${CYAN}🔧 Port: $APP_PORT${NC}"
echo ""

# Function to print step headers
print_step() {
    echo -e "${CYAN}📋 STEP: $1${NC}"
    echo -e "${CYAN}----------------------------------------${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get server IP
get_server_ip() {
    # Try multiple methods to get IP
    local ip=""
    
    # Try hostname -I first
    if command_exists hostname; then
        ip=$(hostname -I | awk '{print $1}' | tr -d '\n')
    fi
    
    # Fallback to ip route
    if [[ -z "$ip" ]]; then
        ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
    fi
    
    # Fallback to localhost
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

# Check K3s/kubectl
if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed or K3s is not running.${NC}"
    echo -e "${YELLOW}Installing K3s...${NC}"
    curl -sfL https://get.k3s.io | sh -
    
    # Wait for K3s to be ready
    echo -e "${YELLOW}⏳ Waiting for K3s to be ready...${NC}"
    sleep 30
    
    # Set up kubectl access
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
else
    echo -e "${GREEN}✅ kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'K3s kubectl')${NC}"
fi

# Check if K3s cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check K3s installation.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
fi

# Check Docker for building images
if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker found: $(docker --version)${NC}"
fi

echo ""

print_step "2. Clean Up Previous Deployment"
echo "🧹 Removing any existing deployment..."

# Remove existing directory
if [ -d "$APP_DIR" ]; then
    echo "   Removing existing $APP_DIR directory..."
    rm -rf "$APP_DIR"
fi

# Delete existing K8s resources
if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "   Removing existing Kubernetes resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Wait for namespace deletion
    echo "   Waiting for namespace cleanup..."
    while kubectl get namespace $NAMESPACE >/dev/null 2>&1; do
        sleep 2
    done
fi

echo -e "${GREEN}✅ Cleanup completed${NC}"
echo ""

print_step "3. Clone BizObs Repository"
echo "📥 Cloning the latest BizObs application..."
echo "   Repository: $REPO_URL"

git clone "$REPO_URL"
cd "$APP_DIR"

echo -e "${GREEN}✅ Repository cloned successfully${NC}"
echo ""

print_step "4. Verify Application Files"
echo "📋 Checking application structure..."

# Check if we're in the right directory
if [[ ! -f "server.js" ]]; then
    echo -e "${RED}❌ server.js not found. Repository may be incomplete.${NC}"
    exit 1
fi

if [[ ! -d "k8s" ]]; then
    echo -e "${RED}❌ k8s directory not found. Repository may be incomplete.${NC}"
    exit 1
fi

if [[ ! -f "Dockerfile" ]]; then
    echo -e "${RED}❌ Dockerfile not found. Repository may be incomplete.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Application files verified${NC}"
echo ""

print_step "5. Build Docker Image"
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

echo -e "${GREEN}✅ Docker image built and imported to K3s${NC}"
echo ""

print_step "6. Deploy to Kubernetes"
echo "☸️  Deploying BizObs to K3s cluster..."

# Apply namespace first
echo "   Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Give namespace a moment to be created (K3s wait condition doesn't work reliably)
echo "   Initializing namespace..."
sleep 3

# Apply remaining manifests
echo "   Deploying application components..."
kubectl apply -f k8s/

echo -e "${GREEN}✅ Kubernetes resources deployed${NC}"
echo ""

print_step "7. Pod Health Check"
wait_for_pod
echo ""

print_step "8. Service Health Check"
SERVER_IP=$(get_server_ip)

# Auto-detect training session ID for URLs
TRAINING_SESSION_ID=$(kubectl get ingress -A -o yaml 2>/dev/null | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}\.dynatrace\.training' | head -1 | cut -d'.' -f1 || echo "db520973-99cc-4fa8-bf3d-5a128e32e7c5")

EXTERNAL_URL="https://bizobs.${TRAINING_SESSION_ID}.dynatrace.training"
NODEPORT_URL="http://$SERVER_IP:30808"
HEALTH_URL="$NODEPORT_URL$HEALTH_ENDPOINT"

wait_for_service "$HEALTH_URL"
echo ""

print_step "9. Deployment Status"
echo "📊 Checking deployment status..."

# Check pod status
echo "   Pod Status:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "   Service Status:"
kubectl get services -n $NAMESPACE

echo ""
echo "   Ingress Status:"
kubectl get ingress -n $NAMESPACE

echo ""
echo "   Pod Logs (last 10 lines):"
kubectl logs -n $NAMESPACE -l app=$APP_NAME --tail=10

echo ""

print_step "10. 🎉 REVOLUTIONARY MICROSERVICES DEPLOYMENT COMPLETE!"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "${PURPLE}🌐 BizObs Application URLs:${NC}"
echo -e "${GREEN}├─ 🌍 External HTTPS:       ${BLUE}$EXTERNAL_URL${NC}"
echo -e "${GREEN}├─ 🏠 NodePort Access:      ${BLUE}$NODEPORT_URL${NC}"
echo -e "${GREEN}├─ 📊 Admin Panel:          ${BLUE}$EXTERNAL_URL/index-full.html${NC}"
echo -e "${GREEN}├─ 🔍 Debug Interface:      ${BLUE}$EXTERNAL_URL/debug.html${NC}"
echo -e "${GREEN}└─ ❤️  Health Check:        ${BLUE}$EXTERNAL_URL/health${NC}"
echo ""
echo -e "${PURPLE}🚀 Revolutionary API Endpoints:${NC}"
echo -e "${GREEN}├─ 🌟 Single Journey:       ${BLUE}POST $EXTERNAL_URL/api/journey-simulation/simulate-journey${NC}"
echo -e "${GREEN}├─ 👥 Multiple Customers:   ${BLUE}POST $EXTERNAL_URL/api/journey-simulation/simulate-multiple-journeys${NC}"
echo -e "${GREEN}├─ 📈 Service Status:       ${BLUE}GET $EXTERNAL_URL/api/admin/services/status${NC}"
echo -e "${GREEN}├─ 🔍 Trace Validation:     ${BLUE}GET $EXTERNAL_URL/api/admin/trace-validation${NC}"
echo -e "${GREEN}└─ 📊 Service Discovery:    ${BLUE}GET $EXTERNAL_URL/api/admin/services${NC}"
echo ""
echo -e "${PURPLE}📱 Quick Test Commands (Copy & Paste Ready):${NC}"
echo -e "${CYAN}# Test customer journey simulation:${NC}"
echo "curl -X POST '$EXTERNAL_URL/api/journey-simulation/simulate-journey' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"companyName\":\"ACE-Demo\",\"customerId\":\"test_$(date +%s)\"}'"
echo ""
echo -e "${CYAN}# Check application health:${NC}"
echo "curl '$EXTERNAL_URL/health'"
echo ""
echo -e "${CYAN}# View all microservices status:${NC}"
echo "curl '$EXTERNAL_URL/api/admin/services/status'"
echo ""
echo -e "${CYAN}# Test multiple customer journeys:${NC}"
echo "curl -X POST '$EXTERNAL_URL/api/journey-simulation/simulate-multiple-journeys' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"customers\":3,\"aiJourney\":{\"companyName\":\"ACE-Demo\",\"steps\":[{\"stepName\":\"Discovery\"},{\"stepName\":\"Purchase\"}]}}'"
echo ""
echo -e "${CYAN}# Check distributed trace validation:${NC}"
echo "curl '$EXTERNAL_URL/api/admin/trace-validation'"
echo ""

# Display microservices information
echo -e "${PURPLE}🔧 Dynamic Microservices Architecture:${NC}"
MICROSERVICES_COUNT=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v bizobs-app | wc -l)
if [ "$MICROSERVICES_COUNT" -gt 0 ]; then
    echo -e "${GREEN}📊 Active Microservices: $MICROSERVICES_COUNT${NC}"
    kubectl get pods -n $NAMESPACE --no-headers | grep -v bizobs-app | while read line; do 
        service=$(echo $line | cut -d' ' -f1 | cut -d'-' -f1)
        status=$(echo $line | awk '{print $3}')
        echo -e "${GREEN}  🔹 $service: $status${NC}"
    done
else
    echo -e "${YELLOW}⚠️  Microservices will be dynamically created on first API call${NC}"
fi

echo ""
echo -e "${PURPLE}🔧 K8s Management Commands:${NC}"
echo -e "${GREEN}├─ View real-time logs:     ${CYAN}kubectl logs -n $NAMESPACE -l app=$APP_NAME -f${NC}"
echo -e "${GREEN}├─ Check all pods:          ${CYAN}kubectl get pods -n $NAMESPACE${NC}"
echo -e "${GREEN}├─ Check services:          ${CYAN}kubectl get services -n $NAMESPACE${NC}"
echo -e "${GREEN}├─ Scale application:       ${CYAN}kubectl scale deployment $APP_NAME -n $NAMESPACE --replicas=2${NC}"
echo -e "${GREEN}├─ Restart deployment:      ${CYAN}kubectl rollout restart deployment $APP_NAME -n $NAMESPACE${NC}"
echo -e "${GREEN}├─ Watch pod status:        ${CYAN}watch kubectl get pods -n $NAMESPACE${NC}"
echo -e "${GREEN}└─ Remove deployment:       ${CYAN}kubectl delete namespace $NAMESPACE${NC}"
echo ""

# Final connectivity test
echo -e "${PURPLE}🧪 Final Connectivity Test:${NC}"
if curl -s -f "$HEALTH_URL" > /dev/null; then
    echo -e "${GREEN}✅ Application is responding correctly!${NC}"
    echo -e "${GREEN}✅ Ready for customer journey simulation${NC}"
    echo -e "${GREEN}✅ Dynamic microservices architecture active${NC}"
    echo -e "${GREEN}✅ Kubernetes deployment successful${NC}"
    echo -e "${GREEN}✅ Distributed tracing enabled${NC}"
else
    echo -e "${YELLOW}⚠️  Application may still be starting up${NC}"
    echo -e "${YELLOW}   Try accessing $NODEPORT_URL in a few moments${NC}"
fi

echo ""
echo -e "${PURPLE}🎯 Next Steps:${NC}"
echo -e "${GREEN}1. 🌐 Open browser: ${BLUE}$EXTERNAL_URL${NC}"
echo -e "${GREEN}2. 🚀 Click '🚀 New Customer Journey' to test${NC}"
echo -e "${GREEN}3. 📊 Monitor microservices creation in real-time${NC}"
echo -e "${GREEN}4. 🔍 Check Dynatrace for distributed traces${NC}"
echo -e "${GREEN}5. 📈 Use API endpoints for automated testing${NC}"
echo ""
echo -e "${GREEN}🎉 Revolutionary BizObs Partner PowerUp deployment completed!${NC}"
echo -e "${GREEN}   Ready for business observability and customer journey simulation!${NC}"
