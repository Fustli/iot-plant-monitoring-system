#!/bin/bash
# IoT Plant Monitoring System - Environment Setup Script
# This script helps set up the development environment

set -e

echo "🌱 IoT Plant Monitoring System - Environment Setup"
echo "===================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    
    if [ -f .env.example ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env file${NC}"
        echo "⚠️  Please edit .env with your actual configuration"
    else
        echo -e "${RED}✗ .env.example not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

echo ""
echo "Environment Variables Loaded:"
echo "-----------------------------"

# Load and display key variables
if [ -f .env ]; then
    echo "Database: $(grep POSTGRES_DB_NAME .env | cut -d= -f2)"
    echo "DB User: $(grep POSTGRES_DB_USER .env | cut -d= -f2)"
    echo "Environment: $(grep ENVIRONMENT .env | cut -d= -f2)"
    echo "Debug: $(grep DEBUG .env | cut -d= -f2)"
fi

echo ""
echo "Setup Steps:"
echo "-----------"
echo "1. ✓ Environment file created/loaded"
echo "2. ⏳ Install Python dependencies:"
echo "   pip install -r requirements.txt"
echo "3. ⏳ Install database dependencies:"
echo "   pip install -r db/requirements.txt"
echo "4. ⏳ Set up PostgreSQL database:"
echo "   createdb iot_plant_db"
echo "   createuser iot_user"
echo "5. ⏳ Initialize database schema:"
echo "   python db/scripts/db_manager.py init"
echo "6. ⏳ Seed demo data (optional):"
echo "   python db/scripts/db_manager.py seed"
echo ""
echo -e "${GREEN}Setup preparation complete!${NC}"
echo ""
echo "💡 Tip: You can load env vars with:"
echo "   export \$(cat .env | xargs)"
