# MATLAB MCP Server Advanced Setup & Startup Script for Windows (PowerShell)
# Requires Administrator privileges
# Features: Auto-installation, Windows Service, Boot startup
# Based on: https://github.com/WilliamCloudQi/matlab-mcp-server

#Requires -RunAsAdministrator

param(
    [string]$MatlabPath = $env:MATLAB_PATH,
    [string]$ServerDir = "$env:USERPROFILE\matlab-mcp-server",
    [string]$ServiceName = "MatlabMCPServer",
    [switch]$InstallService,
    [switch]$UninstallService,
    [switch]$ForceReinstall,
    [switch]$Verbose
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "MATLAB MCP Server Advanced Setup Script" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Function to write colored output
function Write-Status {
    param($Message, $Type = "Info")
    switch ($Type) {
        "Success" { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        "Error"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "Warning" { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        "Progress" { Write-Host "[PROGRESS] $Message" -ForegroundColor Magenta }
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to install Git if not present
function Install-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Status "Git not found. Installing Git..." "Progress"
        try {
            winget install --id Git.Git -e --source winget --silent
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Status "Git installed successfully" "Success"
        } catch {
            Write-Status "Failed to install Git automatically. Please install from https://git-scm.com/" "Error"
            return $false
        }
    } else {
        Write-Status "Git found: $(git --version)" "Success"
    }
    return $true
}

# Function to install Node.js if not present
function Install-NodeJS {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Status "Node.js not found. Installing Node.js..." "Progress"
        try {
            winget install --id OpenJS.NodeJS -e --source winget --silent
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Status "Node.js installed successfully" "Success"
        } catch {
            Write-Status "Failed to install Node.js automatically. Please install from https://nodejs.org/" "Error"
            return $false
        }
    } else {
        $nodeVersion = node --version
        Write-Status "Node.js found: $nodeVersion" "Success"
    }
    return $true
}

# Function to install MATLAB MCP Server
function Install-MatlabMCPServer {
    param($ServerDirectory)
    
    Write-Status "Installing MATLAB MCP Server..." "Progress"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $ServerDirectory)) {
        New-Item -ItemType Directory -Path $ServerDirectory -Force | Out-Null
    }
    
    Set-Location $ServerDirectory
    
    try {
        # Clone the repository
        Write-Status "Cloning MATLAB MCP Server repository..." "Progress"
        git clone https://github.com/WilliamCloudQi/matlab-mcp-server.git .
        
        # Install dependencies
        Write-Status "Installing Node.js dependencies..." "Progress"
        npm install
        
        # Build the server
        Write-Status "Building MATLAB MCP Server..." "Progress"
        npm run build
        
        Write-Status "MATLAB MCP Server installed successfully" "Success"
        return $true
    } catch {
        Write-Status "Failed to install MATLAB MCP Server: $_" "Error"
        return $false
    }
}

# Function to create Windows Service
function Install-MatlabService {
    param($ServiceName, $ServerDirectory, $MatlabPath)
    
    Write-Status "Creating Windows Service: $ServiceName" "Progress"
    
    $servicePath = Join-Path $ServerDirectory "service-wrapper.js"
    
    # Create service wrapper
    $serviceWrapper = @"
const { spawn } = require('child_process');
const path = require('path');

// Set MATLAB_PATH environment variable
process.env.MATLAB_PATH = '$MatlabPath';

console.log('MATLAB MCP Service starting...');
console.log('MATLAB Path:', process.env.MATLAB_PATH);
console.log('Server Directory:', __dirname);

// Start the MATLAB MCP server
const serverProcess = spawn('node', [path.join(__dirname, 'build', 'index.js')], {
    stdio: 'inherit',
    env: process.env
});

serverProcess.on('close', (code) => {
    console.log('MATLAB MCP Server exited with code:', code);
    process.exit(code);
});

serverProcess.on('error', (error) => {
    console.error('Error starting MATLAB MCP Server:', error);
    process.exit(1);
});

// Handle service stop signals
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, stopping MATLAB MCP Server...');
    serverProcess.kill('SIGTERM');
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, stopping MATLAB MCP Server...');
    serverProcess.kill('SIGINT');
});
"@

    Set-Content -Path $servicePath -Value $serviceWrapper
    
    try {
        # Install node-windows for service management
        npm install -g node-windows
        
        # Create service installation script
        $installScriptPath = Join-Path $ServerDirectory "install-service.mjs"
        $installScript = @"
import { Service } from 'node-windows';

// Create a new service object
const svc = new Service({
    name: '$ServiceName',
    description: 'MATLAB MCP Server for cross-platform communication',
    script: '$servicePath',
    nodeOptions: [
        '--max_old_space_size=4096'
    ],
    env: {
        name: 'MATLAB_PATH',
        value: '$MatlabPath'
    }
});

// Listen for the 'install' event, which indicates the process is available as a service
svc.on('install', function() {
    console.log('[SUCCESS] Service installed successfully');
    svc.start();
});

svc.on('start', function() {
    console.log('[SUCCESS] Service started successfully');
});

svc.on('error', function(err) {
    console.error('[ERROR] Service error:', err);
});

// Install the service
console.log('[PROGRESS] Installing service...');
svc.install();
"@

        Set-Content -Path $installScriptPath -Value $installScript
        
        # Run service installation
        Set-Location $ServerDirectory
        node install-service.mjs
        
        Write-Status "Windows Service created and started successfully" "Success"
        return $true
    } catch {
        Write-Status "Failed to create Windows Service: $_" "Error"
        return $false
    }
}

# Function to uninstall service
function Uninstall-MatlabService {
    param($ServiceName, $ServerDirectory)
    
    Write-Status "Removing Windows Service: $ServiceName" "Progress"
    
    try {
        $uninstallScript = @"
import { Service } from 'node-windows';

const svc = new Service({
    name: '$ServiceName',
    script: '$(Join-Path $ServerDirectory "service-wrapper.js")'
});

svc.on('uninstall', function() {
    console.log('[SUCCESS] Service uninstalled successfully');
});

svc.on('error', function(err) {
    console.error('[ERROR] Service error:', err);
});

console.log('[PROGRESS] Uninstalling service...');
svc.uninstall();
"@

        $uninstallScriptPath = Join-Path $ServerDirectory "uninstall-service.mjs"
        Set-Content -Path $uninstallScriptPath -Value $uninstallScript
        
        Set-Location $ServerDirectory
        node uninstall-service.mjs
        
        Write-Status "Windows Service removed successfully" "Success"
        return $true
    } catch {
        Write-Status "Failed to remove Windows Service: $_" "Error"
        return $false
    }
}

# Main execution
try {
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Status "This script requires Administrator privileges" "Error"
        Write-Host "Please run PowerShell as Administrator and try again"
        exit 1
    }

    Write-Status "Running with Administrator privileges" "Success"

    # Handle service uninstallation
    if ($UninstallService) {
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Uninstall-MatlabService -ServiceName $ServiceName -ServerDirectory $ServerDir
        } else {
            Write-Status "Service '$ServiceName' not found" "Warning"
        }
        exit 0
    }

    # Check and install Git
    if (-not (Install-Git)) {
        exit 1
    }

    # Check and install Node.js
    if (-not (Install-NodeJS)) {
        exit 1
    }

    # Set default MATLAB path if not provided
    if (-not $MatlabPath) {
        $possiblePaths = @(
            "E:\MATLAB\bin\matlab.exe",
            "C:\MATLAB\bin\matlab.exe",
            "C:\Program Files\MATLAB\R2023b\bin\matlab.exe",
            "C:\Program Files\MATLAB\R2024a\bin\matlab.exe",
            "C:\Program Files\MATLAB\R2024b\bin\matlab.exe"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $MatlabPath = $path
                break
            }
        }
        
        if (-not $MatlabPath) {
            Write-Status "MATLAB not found in common locations" "Error"
            Write-Host "Please specify MATLAB path with -MatlabPath parameter"
            exit 1
        }
    }

    # Verify MATLAB exists
    if (-not (Test-Path $MatlabPath)) {
        Write-Status "MATLAB not found at: $MatlabPath" "Error"
        exit 1
    }

    Write-Status "MATLAB found at: $MatlabPath" "Success"

    # Check if MATLAB MCP Server exists or needs installation
    $buildPath = Join-Path $ServerDir "build\index.js"
    $needsInstallation = $ForceReinstall -or (-not (Test-Path $buildPath))

    if ($needsInstallation) {
        Write-Status "MATLAB MCP Server not found or reinstall requested" "Info"
        
        # Remove existing directory if force reinstall
        if ($ForceReinstall -and (Test-Path $ServerDir)) {
            Write-Status "Removing existing installation..." "Progress"
            Remove-Item -Path $ServerDir -Recurse -Force
        }
        
        # Install MATLAB MCP Server
        if (-not (Install-MatlabMCPServer -ServerDirectory $ServerDir)) {
            exit 1
        }
    } else {
        Write-Status "MATLAB MCP Server found at: $ServerDir" "Success"
    }

    # Display configuration
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "- MATLAB Path: $MatlabPath"
    Write-Host "- Server Directory: $ServerDir"
    Write-Host "- Service Name: $ServiceName"
    Write-Host "- Build Path: $buildPath"
    Write-Host ""

    # Install or start service
    if ($InstallService) {
        # Check if service already exists
        $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if ($existingService) {
            Write-Status "Service '$ServiceName' already exists" "Warning"
            Write-Status "Current status: $($existingService.Status)" "Info"
            
            if ($existingService.Status -ne "Running") {
                Write-Status "Starting existing service..." "Progress"
                Start-Service -Name $ServiceName
                Write-Status "Service started successfully" "Success"
            }
        } else {
            # Install new service
            if (-not (Install-MatlabService -ServiceName $ServiceName -ServerDirectory $ServerDir -MatlabPath $MatlabPath)) {
                exit 1
            }
        }
        
        Write-Host ""
        Write-Status "Service management commands:" "Info"
        Write-Host "- Start:   Start-Service -Name '$ServiceName'"
        Write-Host "- Stop:    Stop-Service -Name '$ServiceName'"
        Write-Host "- Status:  Get-Service -Name '$ServiceName'"
        Write-Host "- Remove:  .\start-matlab-server.ps1 -UninstallService"
    } else {
        # Run server directly (not as service)
        Write-Status "Starting MATLAB MCP Server directly..." "Progress"
        Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
        Write-Host ""
        
        # Set environment and start server
        $env:MATLAB_PATH = $MatlabPath
        Set-Location $ServerDir
        
        & node "build\index.js"
    }

} catch {
    Write-Status "Unexpected error occurred: $_" "Error"
    exit 1
}

Write-Host ""
Write-Status "Script completed successfully" "Success"