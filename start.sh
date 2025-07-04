#!/bin/bash

# MATLAB MCP Bridge Startup Script

echo "Starting MATLAB MCP Bridge..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    exit 1
fi

# Check if npm dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env"
    export $(grep -v '^#' .env | xargs)
fi

# Set default values
export PORT=${PORT:-8080}
export MATLAB_HOST=${MATLAB_HOST:-192.168.1.111}
export MATLAB_SSH_PORT=${MATLAB_SSH_PORT:-22}
export MATLAB_SSH_USER=${MATLAB_SSH_USER:-samue}

echo "Configuration:"
echo "  Port: $PORT"
echo "  MATLAB Host: $MATLAB_HOST"
echo "  SSH Port: $MATLAB_SSH_PORT"
echo "  SSH User: $MATLAB_SSH_USER"
echo ""

# Start the bridge server
echo "Starting bridge server..."
node server.js