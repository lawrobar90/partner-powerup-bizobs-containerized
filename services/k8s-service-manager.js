import { spawn, exec } from 'child_process';
import path from 'path';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import http from 'http';
import yaml from 'js-yaml';
import * as k8s from '@kubernetes/client-node';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Initialize Kubernetes client
const kc = new k8s.KubeConfig();
kc.loadFromDefault();

const k8sApi = kc.makeApiClient(k8s.AppsV1Api);
const k8sCoreApi = kc.makeApiClient(k8s.CoreV1Api);

// Track deployed Kubernetes services
const deployedServices = {};
const serviceMetadata = {};
const NAMESPACE = 'bizobs';
const SERVICE_PORT = 8080;

/**
 * Check if a Kubernetes service is ready to accept connections
 * @param {string} serviceName - The Kubernetes service name
 * @param {number} timeout - Timeout in milliseconds
 * @returns {Promise<boolean>} - Whether the service is ready
 */
export async function isK8sServiceReady(serviceName, timeout = 30000) {
  return new Promise((resolve) => {
    const start = Date.now();
    
    function checkService() {
      const req = http.request({
        hostname: serviceName,
        port: SERVICE_PORT,
        path: '/health',
        method: 'GET',
        timeout: 2000,
        headers: {
          'Host': `${serviceName}.${NAMESPACE}.svc.cluster.local`
        }
      }, (res) => {
        console.log(`[k8s-service-manager] ✅ Service ${serviceName} is ready`);
        resolve(true);
      });
      
      req.on('error', (err) => {
        if (Date.now() - start < timeout) {
          console.log(`[k8s-service-manager] ⏳ Waiting for ${serviceName} to be ready... (${Math.floor((Date.now() - start) / 1000)}s)`);
          setTimeout(checkService, 3000);
        } else {
          console.log(`[k8s-service-manager] ❌ Service ${serviceName} failed to become ready within ${timeout}ms`);
          resolve(false);
        }
      });
      
      req.on('timeout', () => {
        req.destroy();
        if (Date.now() - start < timeout) {
          setTimeout(checkService, 3000);
        } else {
          resolve(false);
        }
      });
      
      req.end();
    }
    
    checkService();
  });
}

/**
 * Generate Kubernetes deployment manifest for a service
 * @param {string} serviceName - The service name
 * @param {Object} companyContext - Company context metadata
 * @returns {Object} - Kubernetes deployment manifest
 */
function generateDeploymentManifest(serviceName, companyContext) {
  const deploymentName = serviceName.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const labels = {
    app: deploymentName,
    service: serviceName,
    company: (companyContext.companyName || 'default').toLowerCase().replace(/[^a-z0-9-]/g, '-'),
    domain: (companyContext.domain || 'default.com').replace(/[^a-z0-9.-]/g, '-'),
    'journey-id': companyContext.journeyId || 'unknown'
  };

  return {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: deploymentName,
      namespace: NAMESPACE,
      labels: labels,
      annotations: {
        'bizobs.service/original-name': serviceName,
        'bizobs.service/company': companyContext.companyName || 'default',
        'bizobs.service/journey-id': companyContext.journeyId || 'unknown',
        'bizobs.service/created-at': new Date().toISOString()
      }
    },
    spec: {
      replicas: 1,
      selector: {
        matchLabels: {
          app: deploymentName
        }
      },
      template: {
        metadata: {
          labels: labels,
          annotations: {
            'dynatrace.service.name': serviceName,
            'dynatrace.service.company': companyContext.companyName || 'default',
            'dynatrace.service.journey': companyContext.journeyId || 'unknown'
          }
        },
        spec: {
          containers: [{
            name: 'service',
            image: 'bizobs-app:latest',
            imagePullPolicy: 'Never',
            ports: [{
              containerPort: SERVICE_PORT,
              name: 'http'
            }],
            env: [
              { name: 'NODE_ENV', value: 'production' },
              { name: 'PORT', value: SERVICE_PORT.toString() },
              { name: 'SERVICE_NAME', value: serviceName },
              { name: 'COMPANY_NAME', value: companyContext.companyName || 'default' },
              { name: 'COMPANY_DOMAIN', value: companyContext.domain || 'default.com' },
              { name: 'INDUSTRY_TYPE', value: companyContext.industryType || 'general' },
              { name: 'JOURNEY_ID', value: companyContext.journeyId || 'unknown' },
              { name: 'DT_SERVICE_NAME', value: serviceName },
              { name: 'DT_APPLICATION_NAME', value: 'BizObs-CustomerJourney' },
              { name: 'DT_TAGS', value: `app=BizObs service=${serviceName} company=${companyContext.companyName || 'default'} journey=${companyContext.journeyId || 'unknown'}` },
              { name: 'DT_CUSTOM_PROP', value: `service=${serviceName};company=${companyContext.companyName || 'default'};journey=${companyContext.journeyId || 'unknown'}` }
            ],
            command: ['node', 'services/k8s-service-main.cjs'],
            args: [serviceName],
            resources: {
              requests: {
                memory: '128Mi',
                cpu: '100m'
              },
              limits: {
                memory: '256Mi',
                cpu: '200m'
              }
            },
            livenessProbe: {
              httpGet: {
                path: '/health',
                port: SERVICE_PORT
              },
              initialDelaySeconds: 15,
              periodSeconds: 30,
              timeoutSeconds: 5,
              failureThreshold: 3
            },
            readinessProbe: {
              httpGet: {
                path: '/health',
                port: SERVICE_PORT
              },
              initialDelaySeconds: 5,
              periodSeconds: 10,
              timeoutSeconds: 3,
              failureThreshold: 2
            }
          }],
          restartPolicy: 'Always'
        }
      }
    }
  };
}

/**
 * Generate Kubernetes service manifest
 * @param {string} serviceName - The service name
 * @param {Object} companyContext - Company context metadata
 * @returns {Object} - Kubernetes service manifest
 */
function generateServiceManifest(serviceName, companyContext) {
  const deploymentName = serviceName.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const labels = {
    app: deploymentName,
    service: serviceName,
    company: (companyContext.companyName || 'default').toLowerCase().replace(/[^a-z0-9-]/g, '-')
  };

  return {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: deploymentName,
      namespace: NAMESPACE,
      labels: labels,
      annotations: {
        'bizobs.service/original-name': serviceName,
        'bizobs.service/company': companyContext.companyName || 'default',
        'bizobs.service/journey-id': companyContext.journeyId || 'unknown'
      }
    },
    spec: {
      type: 'ClusterIP',
      ports: [{
        port: SERVICE_PORT,
        targetPort: SERVICE_PORT,
        name: 'http'
      }],
      selector: {
        app: deploymentName
      }
    }
  };
}

/**
 * Deploy a service to Kubernetes using the JavaScript client
 * @param {string} serviceName - The service name from Copilot response
 * @param {Object} companyContext - Company context metadata
 * @returns {Promise<Object>} - Service deployment info
 */
export async function deployK8sService(serviceName, companyContext = {}) {
  const deploymentName = serviceName.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  
  console.log(`[k8s-service-manager] 🚀 Deploying ${serviceName} as Kubernetes service...`);
  
  try {
    // Check if service already exists in memory cache
    if (deployedServices[serviceName]) {
      console.log(`[k8s-service-manager] ♻️  Service ${serviceName} already deployed (cached)`);
      return deployedServices[serviceName];
    }

    // Check if deployment actually exists in Kubernetes (for pre-deployed services)
    try {
      const existingDeployment = await k8sApi.readNamespacedDeployment({
        name: deploymentName,
        namespace: NAMESPACE
      });
      
      if (existingDeployment) {
        console.log(`[k8s-service-manager] ♻️  Service ${serviceName} found pre-deployed in Kubernetes`);
        
        // Add to cache for future use
        const serviceInfo = {
          serviceName,
          deploymentName,
          k8sServiceName: deploymentName,
          serviceUrl: `http://${deploymentName}.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}`,
          port: SERVICE_PORT,
          companyContext,
          deployedAt: new Date().toISOString(),
          preDeployed: true
        };
        
        deployedServices[serviceName] = serviceInfo;
        serviceMetadata[serviceName] = companyContext;
        
        console.log(`[k8s-service-manager] ✅ Using pre-deployed service ${serviceName} at ${serviceInfo.serviceUrl}`);
        return serviceInfo;
      }
    } catch (notFoundError) {
      // Deployment doesn't exist yet, continue with normal deployment
      console.log(`[k8s-service-manager] 📝 Service ${serviceName} not found, proceeding with new deployment`);
    }

    // Generate manifests for new deployment
    const deployment = generateDeploymentManifest(serviceName, companyContext);
    const service = generateServiceManifest(serviceName, companyContext);
    
    console.log(`[k8s-service-manager] 📝 Generated manifests for ${serviceName}`);
    console.log(`[k8s-service-manager] 🔍 Debug: NAMESPACE = "${NAMESPACE}", typeof = ${typeof NAMESPACE}`);
    console.log(`[k8s-service-manager] 📋 Deployment manifest namespace:`, deployment.metadata?.namespace);
    console.log(`[k8s-service-manager] 📄 Full deployment manifest:`, JSON.stringify(deployment, null, 2));
    
    try {
      // Create or update deployment (using object-style parameters for reliability)
      console.log(`[k8s-service-manager] 📞 Calling createNamespacedDeployment with object-style params`);
      await k8sApi.createNamespacedDeployment({
        namespace: NAMESPACE,
        body: deployment
      });
      console.log(`[k8s-service-manager] ✅ Created deployment ${deploymentName}`);
    } catch (error) {
      if (error.statusCode === 409) {
        // Deployment already exists, update it
        console.log(`[k8s-service-manager] ♻️  Deployment exists, updating ${deploymentName}`);
        await k8sApi.replaceNamespacedDeployment({
          name: deploymentName,
          namespace: NAMESPACE,
          body: deployment
        });
        console.log(`[k8s-service-manager] ♻️  Updated existing deployment ${deploymentName}`);
      } else {
        throw error;
      }
    }

    try {
      // Create or update service (using object-style parameters) 
      await k8sCoreApi.createNamespacedService({
        namespace: NAMESPACE,
        body: service
      });
      console.log(`[k8s-service-manager] ✅ Created service ${deploymentName}`);
    } catch (error) {
      if (error.statusCode === 409) {
        // Service already exists, update it
        await k8sCoreApi.replaceNamespacedService({
          name: deploymentName,
          namespace: NAMESPACE,
          body: service
        });
        console.log(`[k8s-service-manager] ♻️  Updated existing service ${deploymentName}`);
      } else {
        throw error;
      }
    }
    
    console.log(`[k8s-service-manager] ✅ Deployed ${serviceName} to Kubernetes`);
    
    // Track the deployed service
    const serviceInfo = {
      serviceName,
      deploymentName,
      k8sServiceName: deploymentName,
      serviceUrl: `http://${deploymentName}.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}`,
      port: SERVICE_PORT,
      companyContext,
      deployedAt: new Date().toISOString()
    };
    
    deployedServices[serviceName] = serviceInfo;
    serviceMetadata[serviceName] = companyContext;
    
    // Wait for service to be ready
    console.log(`[k8s-service-manager] ⏳ Waiting for ${serviceName} to be ready...`);
    const isReady = await isK8sServiceReady(deploymentName, 60000);
    
    if (!isReady) {
      console.error(`[k8s-service-manager] ❌ Service ${serviceName} failed to become ready`);
      throw new Error(`Service ${serviceName} failed to become ready`);
    }
    
    console.log(`[k8s-service-manager] 🎉 Service ${serviceName} is ready and accepting requests!`);
    return serviceInfo;
    
  } catch (error) {
    console.error(`[k8s-service-manager] ❌ Failed to deploy ${serviceName}:`, error.message);
    throw error;
  }
}

/**
 * Get service deployment info
 * @param {string} serviceName - The service name
 * @returns {Object|null} - Service info or null if not found
 */
export function getK8sServiceInfo(serviceName) {
  return deployedServices[serviceName] || null;
}

/**
 * Remove a deployed service using the JavaScript client
 * @param {string} serviceName - The service name to remove
 * @returns {Promise<boolean>} - Success status
 */
export async function removeK8sService(serviceName) {
  const serviceInfo = deployedServices[serviceName];
  if (!serviceInfo) {
    console.log(`[k8s-service-manager] ⚠️  Service ${serviceName} not found for removal`);
    return false;
  }
  
  try {
    const deploymentName = serviceInfo.deploymentName;
    
    console.log(`[k8s-service-manager] 🗑️  Removing ${serviceName} from Kubernetes...`);
    
    // Delete deployment
    try {
      await k8sApi.deleteNamespacedDeployment(deploymentName, NAMESPACE);
      console.log(`[k8s-service-manager] ✅ Deleted deployment ${deploymentName}`);
    } catch (error) {
      if (error.statusCode !== 404) {
        console.error(`[k8s-service-manager] Failed to delete deployment ${deploymentName}:`, error.message);
      }
    }

    // Delete service
    try {
      await k8sCoreApi.deleteNamespacedService(deploymentName, NAMESPACE);
      console.log(`[k8s-service-manager] ✅ Deleted service ${deploymentName}`);
    } catch (error) {
      if (error.statusCode !== 404) {
        console.error(`[k8s-service-manager] Failed to delete service ${deploymentName}:`, error.message);
      }
    }
    
    // Remove from tracking
    delete deployedServices[serviceName];
    delete serviceMetadata[serviceName];
    
    console.log(`[k8s-service-manager] ✅ Removed ${serviceName} successfully`);
    return true;
    
  } catch (error) {
    console.error(`[k8s-service-manager] ❌ Failed to remove ${serviceName}:`, error.message);
    return false;
  }
}

/**
 * Cleanup all services for a specific journey
 * @param {string} journeyId - The journey ID
 * @returns {Promise<number>} - Number of services cleaned up
 */
export async function cleanupJourneyServices(journeyId) {
  console.log(`[k8s-service-manager] 🧹 Cleaning up services for journey ${journeyId}...`);
  
  let cleanedCount = 0;
  const servicesToClean = [];
  
  // Find services belonging to this journey
  for (const [serviceName, metadata] of Object.entries(serviceMetadata)) {
    if (metadata.journeyId === journeyId) {
      servicesToClean.push(serviceName);
    }
  }
  
  // Remove services in parallel
  const cleanupPromises = servicesToClean.map(async (serviceName) => {
    try {
      await removeK8sService(serviceName);
      cleanedCount++;
    } catch (error) {
      console.error(`[k8s-service-manager] Failed to cleanup ${serviceName}:`, error.message);
    }
  });
  
  await Promise.all(cleanupPromises);
  
  console.log(`[k8s-service-manager] ✅ Cleaned up ${cleanedCount} services for journey ${journeyId}`);
  return cleanedCount;
}

/**
 * List all deployed services
 * @returns {Object} - All deployed services
 */
export function listDeployedServices() {
  return { ...deployedServices };
}

/**
 * Get service health status
 * @param {string} serviceName - The service name
 * @returns {Promise<Object>} - Health status
 */
export async function getK8sServiceHealth(serviceName) {
  const serviceInfo = deployedServices[serviceName];
  if (!serviceInfo) {
    return { status: 'not-found', serviceName };
  }
  
  try {
    const isReady = await isK8sServiceReady(serviceInfo.deploymentName, 5000);
    return {
      status: isReady ? 'healthy' : 'unhealthy',
      serviceName,
      serviceUrl: serviceInfo.serviceUrl,
      deployedAt: serviceInfo.deployedAt
    };
  } catch (error) {
    return {
      status: 'error',
      serviceName,
      error: error.message
    };
  }
}

export default {
  deployK8sService,
  getK8sServiceInfo,
  removeK8sService,
  cleanupJourneyServices,
  listDeployedServices,
  getK8sServiceHealth,
  isK8sServiceReady
};