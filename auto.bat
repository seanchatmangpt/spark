@echo off
REM Spark DSL Infinite Agentic Loop - Windows Batch Script
REM This is a wrapper for Windows users

echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║              🚀 SPARK DSL INFINITE AGENTIC LOOP 🚀            ║
echo ║                                                               ║
echo ║  Autonomous Domain-Specific Language Generation System        ║
echo ║  Windows Version                                              ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.

REM Check if Elixir is installed
elixir --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Elixir is not installed or not in PATH
    echo Please install Elixir from https://elixir-lang.org/install.html
    pause
    exit /b 1
)

REM Run the Elixir script
elixir auto %*

pause