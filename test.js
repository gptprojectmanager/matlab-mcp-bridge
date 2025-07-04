#!/usr/bin/env node

const http = require('http');

// Test configuration
const config = {
  host: 'localhost',
  port: process.env.PORT || 8080
};

async function testHealthCheck() {
  console.log('Testing health check endpoint...');
  
  return new Promise((resolve, reject) => {
    const options = {
      hostname: config.host,
      port: config.port,
      path: '/health',
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          console.log('Health check response:', response);
          resolve(response);
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

async function testMCPRequest() {
  console.log('Testing MCP request endpoint...');
  
  const testRequest = {
    jsonrpc: '2.0',
    id: 'test-' + Date.now(),
    method: 'tools/list',
    params: {}
  };

  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(testRequest);
    
    const options = {
      hostname: config.host,
      port: config.port,
      path: '/mcp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          console.log('MCP request response:', response);
          resolve(response);
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

async function testSSEConnection() {
  console.log('Testing SSE endpoint...');
  
  return new Promise((resolve, reject) => {
    const options = {
      hostname: config.host,
      port: config.port,
      path: '/sse',
      method: 'GET',
      headers: {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache'
      }
    };

    const req = http.request(options, (res) => {
      console.log('SSE connected, status:', res.statusCode);
      
      let eventCount = 0;
      
      res.on('data', (chunk) => {
        const data = chunk.toString();
        console.log('SSE data received:', data);
        eventCount++;
        
        // Stop after receiving a few events
        if (eventCount >= 2) {
          req.destroy();
          resolve({ status: 'success', events: eventCount });
        }
      });
      
      res.on('end', () => {
        console.log('SSE connection ended');
        resolve({ status: 'ended', events: eventCount });
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
    
    // Timeout after 5 seconds
    setTimeout(() => {
      req.destroy();
      resolve({ status: 'timeout', events: 0 });
    }, 5000);
  });
}

async function runTests() {
  console.log('Starting MATLAB MCP Bridge tests...\n');
  
  try {
    // Test 1: Health check
    await testHealthCheck();
    console.log('✓ Health check passed\n');
    
    // Test 2: SSE connection
    await testSSEConnection();
    console.log('✓ SSE connection test passed\n');
    
    // Test 3: MCP request
    await testMCPRequest();
    console.log('✓ MCP request test passed\n');
    
    console.log('All tests completed successfully!');
    
  } catch (error) {
    console.error('Test failed:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  runTests();
}

module.exports = {
  testHealthCheck,
  testMCPRequest,
  testSSEConnection
};