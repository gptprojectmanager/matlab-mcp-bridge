# MATLAB MCP Server Startup Script for Windows (PowerShell)
# This script starts the MATLAB MCP server with proper error handling

param(
    [string]$MatlabPath = $env:MATLAB_PATH,
    [string]$ServerDir = "$env:USERPROFILE\matlab-mcp-server",
    [switch]$Verbose
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "MATLAB MCP Server Startup Script" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Function to write colored output
function Write-Status {
    param($Message, $Type = "Info")
    switch ($Type) {
        "Success" { Write-Host "✅ $Message" -ForegroundColor Green }
        "Error"   { Write-Host "❌ $Message" -ForegroundColor Red }
        "Warning" { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "ℹ️ $Message" -ForegroundColor Cyan }
    }
}

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Status "Node.js found: $nodeVersion" "Success"
} catch {
    Write-Status "Node.js is not installed or not in PATH" "Error"
    Write-Host "Please install Node.js from https://nodejs.org/"
    Read-Host "Press Enter to exit"
    exit 1
}

# Set default MATLAB path if not provided
if (-not $MatlabPath) {
    $MatlabPath = "E:\MATLAB\bin\matlab.exe"
    Write-Status "Using default MATLAB path: $MatlabPath" "Warning"
}

# Check if MATLAB exists
if (-not (Test-Path $MatlabPath)) {
    Write-Status "MATLAB not found at: $MatlabPath" "Error"
    Write-Host "Please check MATLAB installation or set MATLAB_PATH environment variable"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Status "MATLAB found at: $MatlabPath" "Success"

# Check if server directory exists
if (-not (Test-Path $ServerDir)) {
    Write-Status "MATLAB MCP server directory not found: $ServerDir" "Error"
    Write-Host "Please ensure matlab-mcp-server is installed in your home directory"
    Read-Host "Press Enter to exit"
    exit 1
}

# Navigate to server directory
Set-Location $ServerDir
Write-Status "Changed directory to: $ServerDir" "Info"

# Check if build exists
$buildPath = Join-Path $ServerDir "build\index.js"
if (-not (Test-Path $buildPath)) {
    Write-Status "MATLAB MCP server build not found at: $buildPath" "Error"
    Write-Host "Please ensure matlab-mcp-server is properly installed and built"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Status "Server build found" "Success"

# Display configuration
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "- MATLAB Path: $MatlabPath"
Write-Host "- Server Path: $ServerDir"
Write-Host "- Current Time: $(Get-Date)"
Write-Host "- Build Path: $buildPath"
Write-Host ""

# Set environment variable
$env:MATLAB_PATH = $MatlabPath

# Start the server
Write-Status "Starting MATLAB MCP server..." "Info"
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

try {
    # Start the Node.js server
    & node "build\index.js"
} catch {
    Write-Status "Error starting MATLAB MCP server: $_" "Error"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Status "MATLAB MCP server has stopped." "Warning"
Read-Host "Press Enter to exit"