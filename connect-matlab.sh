#!/bin/bash

# MATLAB MCP Bridge Connection Script
# This script establishes SSH connection to Windows MATLAB server

set -e

# Configuration
MATLAB_HOST="${MATLAB_HOST:-192.168.1.111}"
MATLAB_SSH_PORT="${MATLAB_SSH_PORT:-22}"
MATLAB_SSH_USER="${MATLAB_SSH_USER:-samue}"
LOCAL_PORT="${LOCAL_PORT:-8086}"

echo "MATLAB MCP Bridge Connection Setup"
echo "=================================="
echo "Target: $MATLAB_SSH_USER@$MATLAB_HOST:$MATLAB_SSH_PORT"
echo "Local port: $LOCAL_PORT"
echo ""

# Test connectivity first
echo "Testing connectivity to $MATLAB_HOST..."
if ! ping -c 1 -W 5 "$MATLAB_HOST" > /dev/null 2>&1; then
    echo "❌ Cannot reach $MATLAB_HOST"
    echo "Please check:"
    echo "  1. Windows machine is powered on"
    echo "  2. Network connectivity"
    echo "  3. IP address is correct"
    exit 1
fi

echo "✓ Host is reachable"

# Test SSH port
echo "Testing SSH port $MATLAB_SSH_PORT..."
if ! nc -z -w5 "$MATLAB_HOST" "$MATLAB_SSH_PORT" 2>/dev/null; then
    echo "❌ SSH port $MATLAB_SSH_PORT is not accessible"
    echo "Please check:"
    echo "  1. SSH server is installed and running on Windows"
    echo "  2. Windows firewall allows SSH connections"
    echo "  3. Port $MATLAB_SSH_PORT is correct"
    exit 1
fi

echo "✓ SSH port is accessible"

# Create SSH tunnel
echo "Creating SSH tunnel..."
echo "Local port $LOCAL_PORT will forward to remote MATLAB MCP server"

# SSH command with tunnel
ssh -v -N -L "$LOCAL_PORT:localhost:3000" "$MATLAB_SSH_USER@$MATLAB_HOST" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    &

SSH_PID=$!
echo "SSH tunnel established (PID: $SSH_PID)"
echo "Tunnel: localhost:$LOCAL_PORT -> $MATLAB_HOST:3000"

# Save PID for cleanup
echo "$SSH_PID" > "/tmp/matlab-ssh-tunnel.pid"

echo ""
echo "To test the tunnel:"
echo "  curl http://localhost:$LOCAL_PORT/health"
echo ""
echo "To stop the tunnel:"
echo "  kill $SSH_PID"
echo "  # or"
echo "  pkill -F /tmp/matlab-ssh-tunnel.pid"

# Wait for tunnel to be established
sleep 5

# Test tunnel
echo "Testing tunnel..."
if curl -s -m 5 "http://localhost:$LOCAL_PORT/health" > /dev/null; then
    echo "✓ Tunnel is working"
else
    echo "⚠️ Tunnel may not be working yet"
    echo "  This is normal if MATLAB server is not running on Windows"
fi

echo ""
echo "SSH tunnel is ready!"
echo "Configure your bridge to use: http://localhost:$LOCAL_PORT"