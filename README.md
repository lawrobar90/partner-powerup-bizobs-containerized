# BizObs Partner PowerUp Containerized

🚀 **Revolutionary Microservices Architecture** for Business Observability and Customer Journey Simulation

## Overview

This is the containerized version of the BizObs Partner PowerUp application, featuring:

- **Dynamic Microservices Architecture**: Services are created on-demand based on customer journey steps
- **Kubernetes (K3s) Support**: Native container orchestration with ingress, services, and persistent volumes
- **Docker Compose Support**: Lightweight deployment option
- **Real-time Business Observability**: Dynatrace integration for distributed tracing
- **Interactive UI**: Web interface with journey simulation and service monitoring

## 🎯 Key Features

### Revolutionary Architecture
- ✅ **Dynamic Service Discovery**: Microservices created automatically for each journey step
- ✅ **Port Management**: Intelligent port allocation for 25+ concurrent services
- ✅ **Health Monitoring**: Comprehensive health checks and readiness probes
- ✅ **Distributed Tracing**: Full Dynatrace integration for business observability
- ✅ **Scalable Design**: Kubernetes-native with horizontal pod autoscaling support

### UI Components
- 🌟 **Main Interface**: Customer journey simulation with real-time feedback
- 📊 **Admin Panel**: Service status monitoring and management
- 🔍 **Debug Interface**: Real-time logs and system diagnostics
- 🚀 **"New Customer Journey" Button**: One-click service reset and journey initiation

### API Capabilities
- **Single Journey Simulation**: `/api/journey-simulation/simulate-journey`
- **Multiple Customer Journeys**: `/api/journey-simulation/simulate-multiple-journeys`
- **Service Status Monitoring**: `/api/admin/services/status`
- **Trace Validation**: `/api/admin/trace-validation`
- **Dynamic Service Discovery**: `/api/admin/services`

## 🚀 Quick Start

### Option 1: Kubernetes (K3s) Deployment (Recommended)

```bash
# Clone the repository
git clone https://github.com/lawrobar90/partner-powerup-bizobs-containerized.git
cd partner-powerup-bizobs-containerized

# Deploy to Kubernetes
./deploy.sh k8s

# Or use the traditional start script
./start-server.sh
```

### Option 2: Docker Compose Deployment

```bash
# Deploy with Docker Compose
./deploy.sh docker

# Or manually
docker-compose up -d --build
```

### Option 3: Local Development

```bash
# Install dependencies
npm install

# Start the application
npm start
# or
node server.js
```

## 📁 Project Structure

```
partner-powerup-bizobs-containerized/
├── 📁 k8s/                     # Kubernetes manifests
│   ├── namespace.yaml          # Namespace definition
│   ├── deployment.yaml         # Main application deployment
│   ├── service.yaml           # Service definitions
│   ├── ingress.yaml           # Ingress configuration
│   ├── configmap.yaml         # Environment configuration
│   ├── pvc.yaml              # Persistent volume claims
│   └── rbac.yaml             # Role-based access control
├── 📁 public/                 # Web interface files
│   ├── index.html            # Main UI (🚀 New Customer Journey button)
│   ├── index-full.html       # Admin panel
│   ├── debug.html           # Debug interface
│   └── *.html               # Additional UI components
├── 📁 routes/                # API route handlers
│   ├── journey-simulation.js # Journey simulation endpoints
│   ├── journey.js           # Core journey logic
│   ├── steps.js            # Step management
│   └── serviceProxy.js     # Service proxy layer
├── 📁 services/             # Microservice implementations
│   ├── service-manager.js   # Dynamic service orchestration
│   ├── DataPersistenceService.cjs # Data persistence microservice
│   ├── dynamic-step-service.cjs   # Dynamic step service template
│   └── *.js                # Additional service modules
├── 📁 scripts/             # Deployment and utility scripts
├── server.js              # Main application server
├── Dockerfile             # Container build configuration
├── docker-compose.yml     # Docker Compose configuration
├── deploy.sh             # Universal deployment script
├── start-server.sh       # Kubernetes deployment script
└── package.json          # Node.js dependencies
```

## 🌐 Access URLs

### Production URLs (After Deployment)
- **Main Application**: `https://bizobs.{training-session-id}.dynatrace.training`
- **NodePort Access**: `http://{server-ip}:30808`
- **Admin Panel**: `https://bizobs.{training-session-id}.dynatrace.training/index-full.html`
- **Debug Interface**: `https://bizobs.{training-session-id}.dynatrace.training/debug.html`
- **Health Check**: `https://bizobs.{training-session-id}.dynatrace.training/health`

### Local Development URLs
- **Main Application**: `http://localhost:8080`
- **Admin Panel**: `http://localhost:8080/index-full.html`
- **Debug Interface**: `http://localhost:8080/debug.html`
- **Health Check**: `http://localhost:8080/health`

## 🧪 Testing the Application

### Quick Test Commands

```bash
# Test single customer journey
curl -X POST 'https://bizobs.{training-session-id}.dynatrace.training/api/journey-simulation/simulate-journey' \
  -H 'Content-Type: application/json' \
  -d '{"companyName":"ACE-Demo","customerId":"test_123"}'

# Check application health
curl 'https://bizobs.{training-session-id}.dynatrace.training/health'

# View microservices status
curl 'https://bizobs.{training-session-id}.dynatrace.training/api/admin/services/status'

# Test multiple customer journeys
curl -X POST 'https://bizobs.{training-session-id}.dynatrace.training/api/journey-simulation/simulate-multiple-journeys' \
  -H 'Content-Type: application/json' \
  -d '{"customers":3,"aiJourney":{"companyName":"ACE-Demo","steps":[{"stepName":"Discovery"},{"stepName":"Purchase"}]}}'
```

### UI Testing
1. Open the main application URL in your browser
2. Click **"🚀 New Customer Journey"** to reset services and start a new journey
3. Monitor real-time service creation and journey execution
4. Check the Admin Panel for service status and metrics
5. Use the Debug Interface for troubleshooting

## 🔧 Management Commands

### Kubernetes Management

```bash
# View application logs
kubectl logs -n bizobs -l app=bizobs-app -f

# Check pod status
kubectl get pods -n bizobs

# Check service status
kubectl get services -n bizobs

# Check ingress status
kubectl get ingress -n bizobs

# Scale the application
kubectl scale deployment bizobs-app -n bizobs --replicas=2

# Restart the application
kubectl rollout restart deployment bizobs-app -n bizobs

# Remove the entire deployment
kubectl delete namespace bizobs
```

### Docker Compose Management

```bash
# View logs
docker-compose logs -f

# Check service status
docker-compose ps

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build
```

## 🏗️ Architecture Details

### Dynamic Microservices
The application features a revolutionary architecture where microservices are created dynamically based on customer journey steps:

1. **Service Discovery**: Automatic detection of required services
2. **Port Allocation**: Intelligent port management (4101-4299 range)
3. **Health Monitoring**: Continuous health checks for all services
4. **Load Balancing**: Kubernetes-native service discovery and load balancing

### Supported Journey Steps
- **Discovery Service**: Customer discovery and lead generation
- **Purchase Service**: Transaction processing and order management
- **Data Persistence Service**: Data storage and retrieval
- **Additional Services**: Dynamically created based on journey requirements

### Container Architecture
- **Base Image**: Node.js 18 slim
- **Health Checks**: Built-in curl-based health monitoring
- **Persistent Storage**: Logs and data persistence via PVC
- **Security**: Non-root user execution and minimal attack surface

## 🎯 Business Observability

### Dynatrace Integration
- **Service Naming**: `BizObs-MainServer`, `BizObs-CustomerJourney`
- **Custom Tags**: Environment, company, deployment metadata
- **Distributed Tracing**: Full request flow visibility
- **Business Events**: Customer journey milestone tracking

### Monitoring Capabilities
- Real-time service topology visualization
- Customer journey flow analysis
- Performance bottleneck identification
- Business metric correlation

## 🐛 Troubleshooting

### Common Issues

1. **Pod not starting**:
   ```bash
   kubectl describe pod -n bizobs -l app=bizobs-app
   kubectl logs -n bizobs -l app=bizobs-app
   ```

2. **Service not accessible**:
   ```bash
   kubectl get ingress -n bizobs
   curl -k https://bizobs.{training-session-id}.dynatrace.training/health
   ```

3. **Microservices not creating**:
   - Check the main application logs for service manager output
   - Verify port allocation and availability
   - Test API endpoints manually

### Debug Mode
Enable debug logging by setting:
```bash
export DEBUG=service-manager,journey-sim,port-manager
```

## 📝 Development

### Adding New Journey Steps
1. Create a new service file in `/services/`
2. Register the service in the service manager
3. Add routing in `/routes/steps.js`
4. Update the UI components if needed

### Customizing the UI
- Main interface: `/public/index.html`
- Admin panel: `/public/index-full.html`
- Debug interface: `/public/debug.html`

### API Extensions
Add new endpoints in `/routes/` following the existing pattern:
- Journey simulation: `/routes/journey-simulation.js`
- Admin functions: `/routes/admin.js`
- Service proxy: `/routes/serviceProxy.js`

## 🎉 Success Metrics

After successful deployment, you should see:
- ✅ Application responding on all URLs
- ✅ "🚀 New Customer Journey" button working correctly
- ✅ Dynamic microservices creation on API calls
- ✅ Distributed traces in Dynatrace
- ✅ Health checks passing for all components

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review application logs via kubectl or docker-compose
3. Test individual API endpoints
4. Verify Kubernetes/Docker configuration

---

**🚀 Ready for revolutionary business observability!**