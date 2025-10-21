# Partner PowerUp - BizObs Containerized

A containerized business observability application for Dynatrace demonstrations, featuring customer journey simulation and distributed tracing.

## 🚀 Quick Start

### Prerequisites
- Docker
- Kubernetes (K3s/K8s)
- kubectl configured

### Deploy to Kubernetes

```bash
# Clone the repository
git clone https://github.com/lawrobar90/partner-powerup-bizobs-containerized.git
cd partner-powerup-bizobs-containerized

# Run the deployment script
./start-server.sh
```

The script will:
- Build the Docker image
- Deploy to Kubernetes with all necessary resources
- Set up external access via ingress
- Show you the access URLs

## 🌐 External Access

The application will be available at:
```
https://bizobs.[TRAINING-SESSION-ID].dynatrace.training/
```

The deployment script automatically detects your training session ID and configures the ingress.

## 📱 Core Features

- **Customer Journey Simulation** - Multi-step business process simulation
- **Dynamic Service Management** - Auto-scaling microservices
- **Business Observability** - Real-time metrics and tracing
- **Smartscape Integration** - Visual service topology
- **RESTful APIs** - Complete API suite for automation

## 🔧 Configuration

### Default Ports
- **Application**: 4000 (internal)
- **Service**: 80 (external via ingress)
- **Health Check**: `/health`

### Environment Variables
```bash
PORT=4000                    # Application port
NODE_ENV=production          # Environment mode
DT_SERVICE_NAME=BizObs-MainServer
DT_APPLICATION_NAME=BizObs-CustomerJourney
```

## 📊 API Endpoints

### Health & Status
```bash
GET /health                           # Application health
GET /api/admin/services/status        # Service status
```

### Journey Simulation
```bash
POST /api/journey-simulation/simulate-journey
POST /api/journey-simulation/simulate-multiple-journeys
```

### Example Usage
```bash
# Single customer journey
curl -X POST 'https://bizobs.[SESSION-ID].dynatrace.training/api/journey-simulation/simulate-journey' \
  -H 'Content-Type: application/json' \
  -d '{"companyName":"ACME-Corp","customerId":"customer_123"}'

# Health check
curl 'https://bizobs.[SESSION-ID].dynatrace.training/health'
```

## 🛠 Development

### Local Development
```bash
npm install
npm start
```

### Docker Build
```bash
docker build -t bizobs-app:latest .
docker run -p 4000:4000 bizobs-app:latest
```

### Kubernetes Deployment
```bash
kubectl apply -f k8s/
```

## 📁 Project Structure

```
├── server.js              # Main application server
├── package.json           # Dependencies and scripts
├── Dockerfile             # Container configuration
├── start-server.sh        # Kubernetes deployment script
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── pvc.yaml
├── routes/                # Express route handlers
├── services/              # Microservice implementations
├── public/                # Static web assets
└── scripts/               # Utility scripts
```

## 🔍 Monitoring & Observability

This application is designed for Dynatrace monitoring and includes:

- **Distributed Tracing** - Full request flow tracking
- **Custom Metrics** - Business KPIs and service metrics
- **Service Topology** - Auto-discovered service relationships
- **Real User Monitoring** - Frontend performance tracking

## 🛡 Production Ready

- **Health Checks** - Kubernetes liveness/readiness probes
- **Resource Limits** - Memory and CPU constraints
- **Persistent Storage** - Logs and data persistence
- **Rolling Updates** - Zero-downtime deployments
- **Auto-scaling** - Horizontal pod autoscaling ready

## 📝 License

This project is part of the Dynatrace Partner PowerUp program.