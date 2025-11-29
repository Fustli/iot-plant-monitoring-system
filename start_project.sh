#!/bin/bash
# =============================================================================
# IoT Plant Monitoring System - Project Startup Script
# =============================================================================
# This script starts all components of the IoT Plant Monitoring System:
# 1. PostgreSQL database (via Docker)
# 2. FastAPI backend server
# 3. Flutter web frontend
#
# Usage:
#   ./start_project.sh              # Start all services
#   ./start_project.sh --seed       # Start all services and seed database
#   ./start_project.sh --reset      # Reset database and seed before starting
#   ./start_project.sh --stop       # Stop all running services
#   ./start_project.sh --debug      # Start in debug mode (foreground, verbose)
#
# Requirements:
#   - Docker and docker-compose
#   - Python 3.12+ with virtual environment
#   - Flutter SDK
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
SERVER_DIR="$PROJECT_ROOT/ServerModule/app"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app"
FLUTTER_CMD="$PROJECT_ROOT/flutter_sdk/flutter/bin/flutter"

# Configuration
BACKEND_PORT=8000
FLUTTER_PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=iot_plant_db
DB_USER=iot_user
DEBUG_MODE=false

# PID file locations
PID_DIR="$PROJECT_ROOT/.pids"
BACKEND_PID_FILE="$PID_DIR/backend.pid"
FLUTTER_PID_FILE="$PID_DIR/flutter.pid"

# Docker compose command (detect which version is available)
DOCKER_COMPOSE=""
SUDO_DOCKER=""

# =============================================================================
# Helper Functions
# =============================================================================

detect_docker_compose() {
    # Check if we need sudo for docker
    if ! docker info &> /dev/null; then
        if sudo docker info &> /dev/null; then
            SUDO_DOCKER="sudo"
            log_info "Docker requires sudo"
        else
            log_error "Cannot connect to Docker daemon. Is Docker running?"
            exit 1
        fi
    fi
    
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="$SUDO_DOCKER docker-compose"
    elif $SUDO_DOCKER docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="$SUDO_DOCKER docker compose"
    else
        log_error "Neither 'docker-compose' nor 'docker compose' is available."
        log_error "Please install Docker Compose."
        exit 1
    fi
    log_info "Using: $DOCKER_COMPOSE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

wait_for_postgres() {
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if $DOCKER_COMPOSE exec -T postgres pg_isready -U "$DB_USER" -d "$DB_NAME" &> /dev/null; then
            log_success "PostgreSQL is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    log_error "PostgreSQL failed to start within ${max_attempts} seconds"
    return 1
}

ensure_pid_dir() {
    mkdir -p "$PID_DIR"
}

# =============================================================================
# Start Functions
# =============================================================================

start_database() {
    log_info "Starting PostgreSQL database..."
    
    cd "$PROJECT_ROOT"
    
    # Check if already running
    if $DOCKER_COMPOSE ps postgres 2>/dev/null | grep -q "Up"; then
        log_warning "PostgreSQL is already running"
    else
        $DOCKER_COMPOSE up -d postgres
        wait_for_postgres
    fi
}

seed_database() {
    local reset_flag=""
    if [ "$1" == "--reset" ]; then
        reset_flag="--reset"
        log_warning "Resetting database before seeding..."
    fi
    
    log_info "Seeding database..."
    cd "$SERVER_DIR"
    
    # Determine which Python to use
    local PYTHON_CMD=""
    if [ -f "$PROJECT_ROOT/venv/bin/python" ]; then
        PYTHON_CMD="$PROJECT_ROOT/venv/bin/python"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    elif command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    fi
    
    $PYTHON_CMD seed_db.py $reset_flag
    log_success "Database seeding complete!"
}

start_backend() {
    log_info "Starting FastAPI backend on port $BACKEND_PORT..."
    
    cd "$SERVER_DIR"
    
    # Check if already running
    if [ -f "$BACKEND_PID_FILE" ] && kill -0 "$(cat "$BACKEND_PID_FILE")" 2>/dev/null; then
        log_warning "Backend is already running (PID: $(cat "$BACKEND_PID_FILE"))"
        return 0
    fi
    
    # Determine which Python/uvicorn to use
    local UVICORN_CMD=""
    if [ -f "$PROJECT_ROOT/venv/bin/uvicorn" ]; then
        UVICORN_CMD="$PROJECT_ROOT/venv/bin/uvicorn"
    elif command -v uvicorn &> /dev/null; then
        UVICORN_CMD="uvicorn"
    else
        log_error "uvicorn not found. Install it with: pip install uvicorn"
        return 1
    fi
    
    if [ "$DEBUG_MODE" = true ]; then
        # Debug mode: run in foreground with verbose output
        log_info "Starting backend in DEBUG mode (foreground)..."
        log_info "Press Ctrl+C to stop"
        log_info "API available at: http://localhost:$BACKEND_PORT"
        log_info "API docs at: http://localhost:$BACKEND_PORT/docs"
        PYTHONPATH="$SERVER_DIR/src:$PYTHONPATH" $UVICORN_CMD main:app --host 0.0.0.0 --port $BACKEND_PORT --reload --log-level debug
    else
        # Normal mode: run in background
        PYTHONPATH="$SERVER_DIR/src:$PYTHONPATH" nohup $UVICORN_CMD main:app --host 0.0.0.0 --port $BACKEND_PORT --reload > "$PROJECT_ROOT/logs/backend.log" 2>&1 &
        local pid=$!
        
        ensure_pid_dir
        echo $pid > "$BACKEND_PID_FILE"
        
        # Wait a moment and check if it started
        sleep 2
        if kill -0 $pid 2>/dev/null; then
            log_success "Backend started (PID: $pid)"
            log_info "Backend logs: $PROJECT_ROOT/logs/backend.log"
            log_info "API available at: http://localhost:$BACKEND_PORT"
            log_info "API docs at: http://localhost:$BACKEND_PORT/docs"
        else
            log_error "Backend failed to start. Check logs at $PROJECT_ROOT/logs/backend.log"
            return 1
        fi
    fi
}

start_flutter() {
    log_info "Starting Flutter web frontend on port $FLUTTER_PORT..."
    
    cd "$FLUTTER_DIR"
    
    # Check if already running
    if [ -f "$FLUTTER_PID_FILE" ] && kill -0 "$(cat "$FLUTTER_PID_FILE")" 2>/dev/null; then
        log_warning "Flutter is already running (PID: $(cat "$FLUTTER_PID_FILE"))"
        return 0
    fi
    
    # Get dependencies
    log_info "Getting Flutter dependencies..."
    $FLUTTER_CMD pub get
    
    if [ "$DEBUG_MODE" = true ]; then
        # Debug mode: run in foreground with verbose output
        log_info "Starting Flutter in DEBUG mode (foreground)..."
        log_info "Press Ctrl+C to stop"
        log_info "Frontend will be available at: http://localhost:$FLUTTER_PORT"
        $FLUTTER_CMD run -d web-server --web-port $FLUTTER_PORT --web-hostname 0.0.0.0
    else
        # Normal mode: run in background
        nohup $FLUTTER_CMD run -d web-server --web-port $FLUTTER_PORT --web-hostname 0.0.0.0 > "$PROJECT_ROOT/logs/flutter.log" 2>&1 &
        local pid=$!
        
        ensure_pid_dir
        echo $pid > "$FLUTTER_PID_FILE"
        
        # Wait for Flutter to compile and start
        log_info "Waiting for Flutter to compile..."
        sleep 10
        
        if kill -0 $pid 2>/dev/null; then
            log_success "Flutter started (PID: $pid)"
            log_info "Flutter logs: $PROJECT_ROOT/logs/flutter.log"
            log_info "Frontend available at: http://localhost:$FLUTTER_PORT"
        else
            log_error "Flutter failed to start. Check logs at $PROJECT_ROOT/logs/flutter.log"
            return 1
        fi
    fi
}

# =============================================================================
# Stop Functions
# =============================================================================

stop_backend() {
    log_info "Stopping backend..."
    
    if [ -f "$BACKEND_PID_FILE" ]; then
        local pid=$(cat "$BACKEND_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            rm -f "$BACKEND_PID_FILE"
            log_success "Backend stopped"
        else
            log_warning "Backend process not found"
            rm -f "$BACKEND_PID_FILE"
        fi
    else
        log_warning "No backend PID file found"
    fi
}

stop_flutter() {
    log_info "Stopping Flutter..."
    
    if [ -f "$FLUTTER_PID_FILE" ]; then
        local pid=$(cat "$FLUTTER_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            rm -f "$FLUTTER_PID_FILE"
            log_success "Flutter stopped"
        else
            log_warning "Flutter process not found"
            rm -f "$FLUTTER_PID_FILE"
        fi
    else
        log_warning "No Flutter PID file found"
    fi
    
    # Also kill any orphaned flutter processes on the port
    pkill -f "flutter.*web-server.*$FLUTTER_PORT" 2>/dev/null || true
}

stop_database() {
    log_info "Stopping PostgreSQL..."
    cd "$PROJECT_ROOT"
    $DOCKER_COMPOSE down
    log_success "PostgreSQL stopped"
}

stop_all() {
    log_info "Stopping all services..."
    stop_flutter
    stop_backend
    stop_database
    log_success "All services stopped"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "============================================================"
    echo "  IoT Plant Monitoring System - Startup Script"
    echo "============================================================"
    echo
    
    # Create logs directory
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Check required commands
    check_command docker
    detect_docker_compose
    
    # Check Python (allow for venv activation)
    if [ -f "$PROJECT_ROOT/venv/bin/python" ]; then
        log_info "Found Python in venv"
    elif command -v python &> /dev/null; then
        log_info "Found system Python"
    elif command -v python3 &> /dev/null; then
        log_info "Found python3"
    else
        log_error "Python is not installed. Please install it first."
        exit 1
    fi
    
    # Check Flutter SDK
    if [ -f "$FLUTTER_CMD" ]; then
        log_info "Found Flutter SDK at: $FLUTTER_CMD"
    else
        log_error "Flutter SDK not found at: $FLUTTER_CMD"
        exit 1
    fi
    
    # Parse arguments
    local seed_db=false
    local reset_db=false
    
    for arg in "$@"; do
        case $arg in
            --seed)
                seed_db=true
                ;;
            --reset)
                seed_db=true
                reset_db=true
                ;;
            --stop)
                stop_all
                exit 0
                ;;
            --debug)
                DEBUG_MODE=true
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --seed    Seed the database after starting"
                echo "  --reset   Reset and reseed the database"
                echo "  --stop    Stop all running services"
                echo "  --debug   Run in debug mode (foreground, verbose output)"
                echo "  --help    Show this help message"
                exit 0
                ;;
            *)
                log_warning "Unknown argument: $arg"
                ;;
        esac
    done
    
    # Start services
    start_database
    
    if [ "$seed_db" = true ]; then
        if [ "$reset_db" = true ]; then
            seed_database --reset
        else
            seed_database
        fi
    fi
    
    start_backend
    
    # In debug mode, backend runs in foreground, so we won't reach here
    # unless user stops it. Skip Flutter in debug mode (run separately)
    if [ "$DEBUG_MODE" = true ]; then
        log_info "Debug mode: Backend stopped. Run Flutter separately if needed."
        exit 0
    fi
    
    start_flutter
    
    echo
    echo "============================================================"
    log_success "All services started successfully!"
    echo "============================================================"
    echo
    echo "Services:"
    echo "  - PostgreSQL:  localhost:$DB_PORT"
    echo "  - Backend API: http://localhost:$BACKEND_PORT"
    echo "  - API Docs:    http://localhost:$BACKEND_PORT/docs"
    echo "  - Frontend:    http://localhost:$FLUTTER_PORT"
    echo
    echo "Logs:"
    echo "  - Backend:  $PROJECT_ROOT/logs/backend.log"
    echo "  - Flutter:  $PROJECT_ROOT/logs/flutter.log"
    echo
    echo "To stop all services: $0 --stop"
    echo
}

main "$@"
