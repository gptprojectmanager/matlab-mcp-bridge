#!/usr/bin/env node

const express = require('express');
const cors = require('cors');
const fs = require('fs');
const { spawn } = require('child_process');
const { Client } = require('ssh2');
const { v4: uuidv4 } = require('uuid');

class MatlabMCPBridge {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 8080;
    this.sshConfig = {
      host: process.env.MATLAB_HOST || '192.168.1.111',
      port: process.env.MATLAB_SSH_PORT || 22,
      username: process.env.MATLAB_SSH_USER || 'samue',
      privateKey: this.loadSSHKey(),
      password: process.env.MATLAB_SSH_PASSWORD || null
    };
    
    this.matlabProcess = null;
    this.sshConnection = null;
    this.pendingRequests = new Map();
    this.isConnected = false;
    
    this.setupExpress();
    this.setupRoutes();
  }

  loadSSHKey() {
    const keyPath = process.env.MATLAB_SSH_KEY_PATH;
    if (keyPath && fs.existsSync(keyPath)) {
      try {
        const key = fs.readFileSync(keyPath);
        console.log(`✅ SSH private key loaded from ${keyPath}`);
        return key;
      } catch (error) {
        console.error(`❌ Failed to load SSH key from ${keyPath}:`, error.message);
        return null;
      }
    }
    console.log('No SSH key path specified, will use password authentication');
    return null;
  }

  setupExpress() {
    this.app.use(cors());
    this.app.use(express.json());
    this.app.use(express.text());
    
    // Logging middleware
    this.app.use((req, res, next) => {
      console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
      next();
    });
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({
        status: 'ok',
        connected: this.isConnected,
        timestamp: new Date().toISOString()
      });
    });

    // SSE endpoint for MCP communication
    this.app.get('/sse', (req, res) => {
      console.log('SSE connection established');
      
      // Set SSE headers
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type'
      });

      // Send initial connection event
      this.sendSSEEvent(res, 'connected', { status: 'ready' });

      // Handle client disconnect
      req.on('close', () => {
        console.log('SSE client disconnected');
        res.end();
      });

      // Keep connection alive
      const keepAlive = setInterval(() => {
        this.sendSSEEvent(res, 'ping', { timestamp: Date.now() });
      }, 30000);

      req.on('close', () => {
        clearInterval(keepAlive);
      });
    });

    // HTTP POST endpoint for MCP requests
    this.app.post('/mcp', async (req, res) => {
      try {
        console.log('Received MCP request:', JSON.stringify(req.body, null, 2));
        
        if (!this.isConnected) {
          // Return a simulated response for testing
          const simulatedResponse = this.getSimulatedResponse(req.body);
          return res.json(simulatedResponse);
        }

        const response = await this.forwardToMatlab(req.body);
        res.json(response);
      } catch (error) {
        console.error('Error processing MCP request:', error);
        res.status(500).json({
          error: 'Internal server error',
          message: error.message
        });
      }
    });

    // WebSocket upgrade for real-time communication (alternative to SSE)
    this.app.get('/ws', (req, res) => {
      res.status(400).json({
        error: 'WebSocket upgrade required',
        message: 'Use WebSocket client to connect to this endpoint'
      });
    });
  }

  getSimulatedResponse(request) {
    // Simulate MATLAB MCP server responses for testing
    const method = request.method;
    
    switch (method) {
      case 'tools/list':
        return {
          jsonrpc: '2.0',
          id: request.id,
          result: {
            tools: [
              {
                name: 'matlab_execute',
                description: 'Execute MATLAB code and return results',
                inputSchema: {
                  type: 'object',
                  properties: {
                    code: { type: 'string', description: 'MATLAB code to execute' }
                  },
                  required: ['code']
                }
              },
              {
                name: 'matlab_script',
                description: 'Generate and save MATLAB script',
                inputSchema: {
                  type: 'object',
                  properties: {
                    filename: { type: 'string', description: 'Script filename' },
                    content: { type: 'string', description: 'Script content' }
                  },
                  required: ['filename', 'content']
                }
              }
            ]
          }
        };
      
      case 'tools/call':
        return {
          jsonrpc: '2.0',
          id: request.id,
          result: {
            content: [
              {
                type: 'text',
                text: 'Simulated MATLAB response: Connection to actual MATLAB server required for real execution'
              }
            ]
          }
        };
      
      default:
        return {
          jsonrpc: '2.0',
          id: request.id,
          error: {
            code: -32601,
            message: `Method '${method}' not found in simulation mode`
          }
        };
    }
  }

  sendSSEEvent(res, event, data) {
    try {
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    } catch (error) {
      console.error('Error sending SSE event:', error);
    }
  }

  async connectToMatlab() {
    console.log('Attempting to connect to MATLAB MCP server...');
    
    try {
      // First try direct network connection
      await this.tryDirectConnection();
    } catch (directError) {
      console.log('Direct connection failed, trying SSH tunnel...');
      try {
        await this.trySSHConnection();
      } catch (sshError) {
        console.error('Both direct and SSH connections failed');
        console.error('Direct error:', directError.message);
        console.error('SSH error:', sshError.message);
        
        // For now, we'll simulate a connection for testing
        console.log('Running in simulation mode for development');
        console.log('Bridge server will start anyway for testing purposes');
        this.isConnected = false; // Keep false but don't exit
      }
    }
  }

  async tryDirectConnection() {
    return new Promise((resolve, reject) => {
      // Try to spawn the MATLAB process directly if on same machine
      // This is a fallback for testing
      setTimeout(() => {
        reject(new Error('Direct connection not available'));
      }, 1000);
    });
  }

  async trySSHConnection() {
    return new Promise((resolve, reject) => {
      this.sshConnection = new Client();
      
      console.log(`Attempting SSH connection to ${this.sshConfig.host}:${this.sshConfig.port}`);
      console.log(`Username: ${this.sshConfig.username}`);
      
      this.sshConnection.on('ready', () => {
        console.log('✅ SSH connection established successfully');
        
        // First test if MATLAB MCP server is already running
        this.sshConnection.exec('netstat -an | findstr :3000', (err, stream) => {
          if (!err) {
            let output = '';
            stream.on('data', (data) => {
              output += data.toString();
            });
            
            stream.on('close', () => {
              if (output.includes(':3000')) {
                console.log('✅ MATLAB MCP server is already running on port 3000');
                this.connectToExistingMatlabServer(resolve, reject);
              } else {
                console.log('Starting MATLAB MCP server...');
                this.startMatlabServer(resolve, reject);
              }
            });
          } else {
            console.log('Starting MATLAB MCP server...');
            this.startMatlabServer(resolve, reject);
          }
        });
      });

      this.sshConnection.on('error', (err) => {
        console.error('❌ SSH connection error:', err.message);
        reject(err);
      });

      // Attempt SSH connection with interactive auth
      const sshConfig = {
        ...this.sshConfig,
        tryKeyboard: true,
        algorithms: {
          kex: ['diffie-hellman-group14-sha256', 'diffie-hellman-group14-sha1', 'diffie-hellman-group1-sha1'],
          cipher: ['aes128-ctr', 'aes192-ctr', 'aes256-ctr', 'aes128-gcm', 'aes256-gcm'],
          hmac: ['hmac-sha2-256', 'hmac-sha2-512', 'hmac-sha1']
        }
      };
      
      this.sshConnection.connect(sshConfig);
    });
  }

  connectToExistingMatlabServer(resolve, reject) {
    // Create a port forward to the existing MATLAB server
    this.sshConnection.forwardOut('127.0.0.1', 0, '127.0.0.1', 3000, (err, stream) => {
      if (err) {
        console.error('❌ Port forwarding failed:', err);
        reject(err);
        return;
      }
      
      console.log('✅ Connected to existing MATLAB MCP server');
      this.matlabProcess = stream;
      this.isConnected = true;
      
      stream.on('data', (data) => {
        this.handleMatlabOutput(data.toString());
      });
      
      stream.on('close', () => {
        console.log('MATLAB server connection closed');
        this.isConnected = false;
      });
      
      resolve();
    });
  }

  startMatlabServer(resolve, reject) {
    // Execute the MATLAB MCP server command via SSH
    const matlabCommand = 'cd C:/Users/samue/matlab-mcp-server && node build/index.js';
    
    this.sshConnection.exec(matlabCommand, {
      env: { 'MATLAB_PATH': 'E:/MATLAB/bin/matlab.exe' }
    }, (err, stream) => {
      if (err) {
        console.error('❌ Failed to start MATLAB server:', err);
        reject(err);
        return;
      }
      
      console.log('✅ MATLAB MCP server started');
      this.matlabProcess = stream;
      this.isConnected = true;
      
      stream.on('data', (data) => {
        this.handleMatlabOutput(data.toString());
      });
      
      stream.stderr.on('data', (data) => {
        console.error('MATLAB stderr:', data.toString());
      });
      
      stream.on('close', (code) => {
        console.log(`MATLAB process exited with code ${code}`);
        this.isConnected = false;
      });
      
      resolve();
    });
  }

  handleMatlabOutput(data) {
    console.log('MATLAB output:', data);
    
    try {
      // Parse JSON-RPC messages from MATLAB
      const lines = data.split('\n').filter(line => line.trim());
      
      for (const line of lines) {
        try {
          const message = JSON.parse(line);
          this.handleMatlabMessage(message);
        } catch (parseError) {
          // Not JSON, might be log output
          console.log('MATLAB log:', line);
        }
      }
    } catch (error) {
      console.error('Error handling MATLAB output:', error);
    }
  }

  handleMatlabMessage(message) {
    console.log('MATLAB message:', message);
    
    // Handle responses to our requests
    if (message.id && this.pendingRequests.has(message.id)) {
      const { resolve } = this.pendingRequests.get(message.id);
      this.pendingRequests.delete(message.id);
      resolve(message);
    }
  }

  async forwardToMatlab(request) {
    if (!this.isConnected || !this.matlabProcess) {
      throw new Error('MATLAB server not connected');
    }

    return new Promise((resolve, reject) => {
      const requestId = request.id || uuidv4();
      const timeoutMs = 30000; // 30 seconds timeout
      
      // Store the request for response matching
      this.pendingRequests.set(requestId, { resolve, reject });
      
      // Set timeout
      const timeout = setTimeout(() => {
        if (this.pendingRequests.has(requestId)) {
          this.pendingRequests.delete(requestId);
          reject(new Error('Request timeout'));
        }
      }, timeoutMs);

      // Send request to MATLAB
      const requestWithId = { ...request, id: requestId };
      const requestString = JSON.stringify(requestWithId) + '\n';
      
      try {
        this.matlabProcess.stdin.write(requestString);
      } catch (error) {
        clearTimeout(timeout);
        this.pendingRequests.delete(requestId);
        reject(error);
      }
    });
  }

  async start() {
    try {
      await this.connectToMatlab();
      
      this.app.listen(this.port, () => {
        console.log(`MATLAB MCP Bridge listening on port ${this.port}`);
        console.log(`Health check: http://localhost:${this.port}/health`);
        console.log(`SSE endpoint: http://localhost:${this.port}/sse`);
        console.log(`MCP endpoint: http://localhost:${this.port}/mcp`);
        console.log(`Connected to MATLAB: ${this.isConnected}`);
      });
      
    } catch (error) {
      console.error('Failed to start bridge:', error);
      process.exit(1);
    }
  }

  async stop() {
    console.log('Shutting down MATLAB MCP Bridge...');
    
    if (this.matlabProcess) {
      this.matlabProcess.kill();
    }
    
    if (this.sshConnection) {
      this.sshConnection.end();
    }
    
    process.exit(0);
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('\nReceived SIGINT, shutting down gracefully...');
  if (global.bridge) {
    await global.bridge.stop();
  } else {
    process.exit(0);
  }
});

process.on('SIGTERM', async () => {
  console.log('\nReceived SIGTERM, shutting down gracefully...');
  if (global.bridge) {
    await global.bridge.stop();
  } else {
    process.exit(0);
  }
});

// Start the bridge
if (require.main === module) {
  const bridge = new MatlabMCPBridge();
  global.bridge = bridge;
  bridge.start().catch(console.error);
}

module.exports = MatlabMCPBridge;