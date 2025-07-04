@echo off
REM MATLAB MCP Server Startup Script for Windows
REM This script starts the MATLAB MCP server and keeps it running

echo ========================================
echo MATLAB MCP Server Startup Script
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if MATLAB is installed
if not exist "%MATLAB_PATH%" (
    echo ERROR: MATLAB not found at: %MATLAB_PATH%
    echo Please check MATLAB installation or set MATLAB_PATH environment variable
    pause
    exit /b 1
)

REM Set default MATLAB path if not set
if "%MATLAB_PATH%"=="" (
    set "MATLAB_PATH=E:\MATLAB\bin\matlab.exe"
    echo Using default MATLAB path: %MATLAB_PATH%
)

REM Navigate to MATLAB MCP server directory
set "MATLAB_SERVER_DIR=C:\Users\%USERNAME%\matlab-mcp-server"
if not exist "%MATLAB_SERVER_DIR%" (
    echo ERROR: MATLAB MCP server directory not found: %MATLAB_SERVER_DIR%
    echo Please ensure matlab-mcp-server is installed in your home directory
    pause
    exit /b 1
)

cd /d "%MATLAB_SERVER_DIR%"
echo Changed directory to: %CD%

REM Check if build directory exists
if not exist "build\index.js" (
    echo ERROR: MATLAB MCP server build not found
    echo Please ensure matlab-mcp-server is properly installed and built
    pause
    exit /b 1
)

echo.
echo Configuration:
echo - MATLAB Path: %MATLAB_PATH%
echo - Server Path: %MATLAB_SERVER_DIR%
echo - Current Time: %DATE% %TIME%
echo.

REM Start the MATLAB MCP server
echo Starting MATLAB MCP server...
echo Press Ctrl+C to stop the server
echo.

node build\index.js

REM If we reach here, the server has stopped
echo.
echo MATLAB MCP server has stopped.
pause