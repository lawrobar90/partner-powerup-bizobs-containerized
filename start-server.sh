#!/bin/bash

# BizObs ACE-box K3s Deployment Script
# Deploys the Partner PowerUp BizObs App using Kubernetes (K3s)
# Alternative to Docker Compose deployment

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
REPO_URL="https://github.com/lawrobar90/Partner-PowerUp-BizObs-App.git"
APP_DIR="Partner-PowerUp-BizObs-App"
APP_PORT="4000"
NAMESPACE="bizobs"
APP_NAME="bizobs-app"
HEALTH_ENDPOINT="/health"

echo -e "${PURPLE}🚀 BizObs ACE-box K3s Deployment Script${NC}"
echo -e "${PURPLE}===========================================${NC}"
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

print_step "4. Create Kubernetes Manifests"
echo "☸️  Creating Kubernetes configuration..."

# Create k8s directory
mkdir -p k8s

# Create Dockerfile (same as Docker Compose version)
cat > Dockerfile << 'EOF'
FROM node:18-slim

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY . .

# Create logs directory
RUN mkdir -p logs

# Expose the application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start the application
CMD ["npm", "start"]
EOF

# Create namespace manifest
cat > k8s/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    app: bizobs
    environment: production
    deployment: acebox
EOF

# Create ConfigMap for environment variables
cat > k8s/configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-config
  namespace: $NAMESPACE
data:
  NODE_ENV: "production"
  PORT: "$APP_PORT"
  DT_SERVICE_NAME: "BizObs-MainServer"
  DT_APPLICATION_NAME: "BizObs-CustomerJourney"
  DT_TAGS: "app=BizObs environment=production company=acebox"
  DT_CUSTOM_PROP: "deployment=acebox;demo=partner-powerup"
EOF

# Create PersistentVolumeClaim for logs
cat > k8s/pvc.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP_NAME}-logs
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF

# Create Deployment manifest
cat > k8s/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
    component: main-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
        component: main-server
    spec:
      containers:
      - name: bizobs
        image: ${APP_NAME}:latest
        imagePullPolicy: Never
        ports:
        - containerPort: $APP_PORT
          name: http
        envFrom:
        - configMapRef:
            name: ${APP_NAME}-config
        volumeMounts:
        - name: logs-volume
          mountPath: /app/logs
        - name: localtime
          mountPath: /etc/localtime
          readOnly: true
        livenessProbe:
          httpGet:
            path: $HEALTH_ENDPOINT
            port: $APP_PORT
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: $HEALTH_ENDPOINT
            port: $APP_PORT
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: logs-volume
        persistentVolumeClaim:
          claimName: ${APP_NAME}-logs
      - name: localtime
        hostPath:
          path: /etc/localtime
      restartPolicy: Always
EOF

# Create Service manifest
cat > k8s/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  type: NodePort
  ports:
  - port: $APP_PORT
    targetPort: $APP_PORT
    nodePort: 30080
    name: http
  selector:
    app: $APP_NAME
EOF

# Auto-detect training session ID for ingress
TRAINING_SESSION_ID=$(kubectl get ingress -A -o yaml 2>/dev/null | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}\.dynatrace\.training' | head -1 | cut -d'.' -f1 || echo "unknown")

# Create Ingress manifest for external access
cat > k8s/ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: bizobs.${TRAINING_SESSION_ID}.dynatrace.training
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${APP_NAME}-service
            port:
              number: 80
EOF

echo -e "${GREEN}✅ Kubernetes manifests created${NC}"
echo ""

print_step "5. Build Docker Image"
echo "🔨 Building Docker image for K3s..."

# Build the Docker image
docker build -t ${APP_NAME}:latest .

# Import image to K3s
echo "   Importing image to K3s..."
docker save ${APP_NAME}:latest | sudo k3s ctr images import -

echo -e "${GREEN}✅ Docker image built and imported to K3s${NC}"
echo ""

print_step "6. Deploy to Kubernetes"
echo "☸️  Deploying BizObs to K3s cluster..."

# Apply all manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

echo -e "${GREEN}✅ Kubernetes resources deployed${NC}"
echo ""

print_step "7. Pod Health Check"
wait_for_pod
echo ""

print_step "8. Service Health Check"
SERVER_IP=$(get_server_ip)
EXTERNAL_URL="https://bizobs.${TRAINING_SESSION_ID}.dynatrace.training"
BASE_URL="http://$SERVER_IP:30080"
HEALTH_URL="$BASE_URL$HEALTH_ENDPOINT"

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
echo "   Pod Logs (last 10 lines):"
kubectl logs -n $NAMESPACE -l app=$APP_NAME --tail=10

echo ""

print_step "10. 🎉 K3S DEPLOYMENT COMPLETE!"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${PURPLE}🌐 BizObs Application URLs:${NC}"
echo -e "${GREEN}├─ 🌍 External Access:    ${BLUE}$EXTERNAL_URL${NC}"
echo -e "${GREEN}├─ 🏠 Internal Access:    ${BLUE}$BASE_URL${NC}"
echo -e "${GREEN}├─ Admin Panel:          ${BLUE}$EXTERNAL_URL/index-full.html${NC}"
echo -e "${GREEN}├─ Health Check:         ${BLUE}$EXTERNAL_URL/health${NC}"
echo -e "${GREEN}└─ Debug Interface:      ${BLUE}$EXTERNAL_URL/debug.html${NC}"
echo ""
echo -e "${PURPLE}🚀 API Endpoints (External):${NC}"
echo -e "${GREEN}├─ Single Journey:     ${BLUE}POST $EXTERNAL_URL/api/journey-simulation/simulate-journey${NC}"
echo -e "${GREEN}├─ Multiple Customers: ${BLUE}POST $EXTERNAL_URL/api/journey-simulation/simulate-multiple-journeys${NC}"
echo -e "${GREEN}├─ Service Status:     ${BLUE}GET $EXTERNAL_URL/api/admin/services/status${NC}"
echo -e "${GREEN}└─ Trace Validation:   ${BLUE}GET $EXTERNAL_URL/api/admin/trace-validation${NC}"
echo ""
echo -e "${PURPLE}📱 Quick Test Commands (Copy & Paste Ready):${NC}"
echo -e "${CYAN}# Test single journey:${NC}"
echo "curl -X POST 'http://$SERVER_IP:30400/api/journey-simulation/simulate-journey' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"companyName\":\"ACE-Demo\",\"customerId\":\"test_123\"}'"
echo ""
echo -e "${CYAN}# Check service health:${NC}"
echo "curl 'http://$SERVER_IP:30400/health'"
echo ""
echo -e "${CYAN}# View service status:${NC}"
echo "curl 'http://$SERVER_IP:30400/api/admin/services/status'"
echo ""
echo -e "${CYAN}# Test multiple customers:${NC}"
echo "curl -X POST 'http://$SERVER_IP:30400/api/journey-simulation/simulate-multiple-journeys' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"customers\":3,\"aiJourney\":{\"companyName\":\"ACE-Demo\",\"steps\":[{\"stepName\":\"Discovery\"},{\"stepName\":\"Purchase\"}]}}'"
echo ""
echo -e "${CYAN}# Check trace validation:${NC}"
echo "curl 'http://$SERVER_IP:30400/api/admin/trace-validation'"
echo ""

# Display access information
if [[ "$SERVER_IP" != "localhost" ]]; then
    echo -e "${PURPLE}🌍 External Access:${NC}"
    echo -e "${GREEN}├─ From your local browser: ${BLUE}http://$SERVER_IP:30400${NC}"
    echo -e "${GREEN}└─ From ACE-box locally:    ${BLUE}http://localhost:30400${NC}"
else
    echo -e "${PURPLE}🏠 Local Access:${NC}"
    echo -e "${GREEN}└─ Browser URL: ${BLUE}http://localhost:30400${NC}"
fi

echo ""
echo -e "${PURPLE}🔧 K8s Management Commands:${NC}"
echo -e "${GREEN}├─ View logs:       ${CYAN}kubectl logs -n $NAMESPACE -l app=$APP_NAME -f${NC}"
echo -e "${GREEN}├─ Check pods:      ${CYAN}kubectl get pods -n $NAMESPACE${NC}"
echo -e "${GREEN}├─ Check services:  ${CYAN}kubectl get services -n $NAMESPACE${NC}"
echo -e "${GREEN}├─ Scale app:       ${CYAN}kubectl scale deployment $APP_NAME -n $NAMESPACE --replicas=2${NC}"
echo -e "${GREEN}├─ Restart app:     ${CYAN}kubectl rollout restart deployment $APP_NAME -n $NAMESPACE${NC}"
echo -e "${GREEN}└─ Remove all:      ${CYAN}kubectl delete namespace $NAMESPACE${NC}"
echo ""

# Final connectivity test
echo -e "${PURPLE}🧪 Final Connectivity Test:${NC}"
if curl -s -f "$HEALTH_URL" > /dev/null; then
    echo -e "${GREEN}✅ Application is responding correctly!${NC}"
    echo -e "${GREEN}✅ Ready for Dynatrace OneAgent monitoring${NC}"
    echo -e "${GREEN}✅ Business observability features active${NC}"
    echo -e "${GREEN}✅ Kubernetes deployment successful${NC}"
else
    echo -e "${YELLOW}⚠️  Application may still be starting up${NC}"
    echo -e "${YELLOW}   Try accessing $BASE_URL in a few moments${NC}"
fi

echo ""
echo -e "${PURPLE}🎯 Next Steps:${NC}"
echo -e "${GREEN}1. Open your browser to: ${BLUE}$BASE_URL${NC}"
echo -e "${GREEN}2. Test customer journey simulation${NC}"
echo -e "${GREEN}3. Check Dynatrace for distributed traces${NC}"
echo -e "${GREEN}4. Monitor business events and service topology${NC}"
echo -e "${GREEN}5. Use kubectl commands for K8s management${NC}"
echo ""
echo -e "${GREEN}🎉 BizObs K3s deployment on ACE-box completed successfully!${NC}"
