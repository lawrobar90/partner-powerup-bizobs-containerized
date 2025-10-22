/**
 * Kubernetes Service Main Entry Point
 * Starts a dynamic service based on command line argument
 */
const { createService } = require('./service-runner.cjs');
const { callService, getServiceNameFromStep, getServicePortFromStep } = require('./child-caller.cjs');

// Get service name from command line arguments
const serviceName = process.argv[2];

if (!serviceName) {
  console.error('❌ Service name is required as first argument');
  console.error('Usage: node k8s-service-main.cjs <ServiceName>');
  process.exit(1);
}

console.log(`[k8s-service-main] Starting service: ${serviceName}`);

// Set process identity immediately
console.log(`[dynamic-step-service] Set process identity to: ${serviceName}`);

// Create service with dynamic routing
createService(serviceName, (app) => {
  console.log(`[k8s-service-main] Mounting routes for service: ${serviceName}`);

  // Universal POST endpoint that accepts any journey step
  app.post('/', async (req, res) => {
    try {
      const { step, stepName, payload } = req.body || {};
      const actualStepName = stepName || step || serviceName;
      
      console.log(`[${serviceName}] Processing step: ${actualStepName}`);
      
      // Simulate the step processing with realistic business logic
      const responseData = {
        success: true,
        stepName: actualStepName,
        serviceName: serviceName,
        companyName: process.env.COMPANY_NAME || 'DefaultCompany',
        domain: process.env.COMPANY_DOMAIN || 'default.com',
        timestamp: new Date().toISOString(),
        processingTime: Math.floor(Math.random() * 200) + 50, // 50-250ms
        traceId: req.headers['x-trace-id'] || req.correlationId,
        correlationId: req.correlationId,
        // Business-specific response based on service type
        businessData: generateBusinessResponse(serviceName, actualStepName, payload)
      };

      // Add some realistic processing delay
      await new Promise(resolve => setTimeout(resolve, responseData.processingTime));

      console.log(`[${serviceName}] ✅ Step ${actualStepName} completed successfully`);
      res.json(responseData);
      
    } catch (error) {
      console.error(`[${serviceName}] ❌ Error processing step:`, error.message);
      res.status(500).json({
        success: false,
        error: error.message,
        serviceName: serviceName,
        timestamp: new Date().toISOString(),
        traceError: true
      });
    }
  });

  // 🔥 CRITICAL: Add /process endpoint that journey simulation expects
  app.post('/process', async (req, res) => {
    try {
      console.log(`[${serviceName}] Processing /process endpoint with payload:`, JSON.stringify(req.body, null, 2));
      
      const payload = req.body || {};
      const stepName = payload.stepName || serviceName;
      
      // Simulate the step processing with realistic business logic
      const responseData = {
        success: true,
        stepName: stepName,
        serviceName: serviceName,
        companyName: payload.companyName || process.env.COMPANY_NAME || 'DefaultCompany',
        domain: payload.domain || process.env.COMPANY_DOMAIN || 'default.com',
        timestamp: new Date().toISOString(),
        processingTime: Math.floor(Math.random() * 200) + 50, // 50-250ms
        traceId: req.headers['x-trace-id'] || payload.correlationId || req.correlationId,
        correlationId: payload.correlationId || req.correlationId,
        journeyId: payload.journeyId,
        customerId: payload.customerId,
        stepIndex: payload.stepIndex,
        totalSteps: payload.totalSteps,
        // Business-specific response based on service type
        businessData: generateBusinessResponse(serviceName, stepName, payload)
      };

      // Add some realistic processing delay
      await new Promise(resolve => setTimeout(resolve, responseData.processingTime));

      console.log(`[${serviceName}] ✅ /process endpoint completed successfully for step: ${stepName}`);
      res.json(responseData);
      
    } catch (error) {
      console.error(`[${serviceName}] ❌ Error in /process endpoint:`, error.message);
      res.status(500).json({
        success: false,
        error: error.message,
        serviceName: serviceName,
        timestamp: new Date().toISOString(),
        traceError: true
      });
    }
  });

  // GET endpoint for testing
  app.get('/', (req, res) => {
    res.json({
      service: serviceName,
      status: 'running',
      pid: process.pid,
      environment: {
        companyName: process.env.COMPANY_NAME || 'DefaultCompany',
        domain: process.env.COMPANY_DOMAIN || 'default.com',
        industryType: process.env.INDUSTRY_TYPE || 'general'
      },
      timestamp: new Date().toISOString(),
      message: `${serviceName} is ready to process requests`
    });
  });
});

/**
 * Generate realistic business response data based on service type
 */
function generateBusinessResponse(serviceName, stepName, payload) {
  const serviceType = serviceName.toLowerCase();
  
  if (serviceType.includes('product') || serviceType.includes('discovery')) {
    return {
      products: [
        { id: 'prod-1', name: 'Premium Widget', price: 99.99 },
        { id: 'prod-2', name: 'Standard Widget', price: 49.99 }
      ],
      recommendations: ['Similar products', 'Customer favorites'],
      searchQuery: payload?.query || 'default search'
    };
  }
  
  if (serviceType.includes('cart') || serviceType.includes('selection')) {
    return {
      cartId: `cart-${Date.now()}`,
      items: [{ productId: 'prod-1', quantity: 1, price: 99.99 }],
      totalAmount: 99.99,
      currency: 'USD'
    };
  }
  
  if (serviceType.includes('checkout') || serviceType.includes('payment')) {
    return {
      transactionId: `txn-${Date.now()}`,
      paymentMethod: 'credit-card',
      amount: 99.99,
      status: 'processed',
      confirmationCode: `CONF-${Math.random().toString(36).substr(2, 8).toUpperCase()}`
    };
  }
  
  if (serviceType.includes('order') || serviceType.includes('confirmation')) {
    return {
      orderId: `order-${Date.now()}`,
      status: 'confirmed',
      estimatedDelivery: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
      trackingNumber: `TRK${Math.random().toString(36).substr(2, 10).toUpperCase()}`
    };
  }
  
  if (serviceType.includes('fulfillment') || serviceType.includes('postpurchase')) {
    return {
      fulfillmentId: `ff-${Date.now()}`,
      shippingStatus: 'preparing',
      warehouse: 'primary',
      estimatedShipping: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString()
    };
  }
  
  // Default response for unknown service types
  return {
    message: `${serviceName} processing completed`,
    data: payload || {},
    processedAt: new Date().toISOString()
  };
}

console.log(`[k8s-service-main] Service ${serviceName} initialization complete`);