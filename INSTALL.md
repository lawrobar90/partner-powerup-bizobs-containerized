# 🚀 BizObs Partner PowerUp - Fresh ACE-box Installation

## Quick Start for Fresh ACE-box Instance

### One-Command Installation

```bash
# Download and run the installation script
curl -sSL https://raw.githubusercontent.com/lawrobar90/partner-powerup-bizobs-containerized/main/start-server.sh | bash
```

### Manual Installation

```bash
# 1. Clone the repository
git clone https://github.com/lawrobar90/partner-powerup-bizobs-containerized.git
cd partner-powerup-bizobs-containerized

# 2. Run the deployment script
./start-server.sh
```

### Alternative Deployment Methods

```bash
# For Kubernetes deployment
./deploy.sh k8s

# For Docker Compose deployment  
./deploy.sh docker

# For local development
npm install && npm start
```

## What Gets Installed

- ✅ **Kubernetes (K3s)** - Container orchestration
- ✅ **Revolutionary Microservices Architecture** - Dynamic service creation
- ✅ **Web Interface** - Customer journey simulation UI
- ✅ **Dynatrace Integration** - Business observability
- ✅ **Health Monitoring** - Comprehensive health checks

## Access URLs (After Installation)

- **Main Application**: `https://bizobs.{training-session-id}.dynatrace.training`
- **Admin Panel**: `https://bizobs.{training-session-id}.dynatrace.training/index-full.html` 
- **Debug Interface**: `https://bizobs.{training-session-id}.dynatrace.training/debug.html`
- **NodePort Access**: `http://{server-ip}:30808`

## Quick Test

```bash
# Test customer journey simulation
curl -X POST 'https://bizobs.{training-session-id}.dynatrace.training/api/journey-simulation/simulate-journey' \
  -H 'Content-Type: application/json' \
  -d '{"companyName":"ACE-Demo","customerId":"test_123"}'
```

## Management Commands

```bash
# View logs
kubectl logs -n bizobs -l app=bizobs-app -f

# Check status  
kubectl get pods -n bizobs

# Restart deployment
kubectl rollout restart deployment bizobs-app -n bizobs

# Remove deployment
kubectl delete namespace bizobs
```

---

**🎯 Perfect for ACE-box demonstrations and Partner PowerUp training sessions!**