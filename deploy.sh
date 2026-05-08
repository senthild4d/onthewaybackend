#!/bin/bash
# Vibes API - Deployment Script for Production
# This script helps deploy the Vibes API to production server

set -e  # Exit on any error

echo "======================================"
echo "Vibes API - Production Deployment"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're on the server or local machine
if [ -f "/etc/os-release" ]; then
    print_info "Running on server..."
    ON_SERVER=true
else
    print_info "Running on local machine..."
    ON_SERVER=false
fi

# Main deployment menu
echo "Select deployment action:"
echo "1) Fresh deployment (first time)"
echo "2) Update deployment (pull latest code)"
echo "3) Restart services"
echo "4) View logs"
echo "5) Run database migrations"
echo "6) Open Rails console"
echo "7) Check status"
echo "8) Backup database"
echo "9) Exit"
echo ""
read -p "Enter choice [1-9]: " choice

case $choice in
    1)
        print_info "Starting fresh deployment..."
        
        # Check if .env.production exists
        if [ ! -f ".env.production" ]; then
            print_error ".env.production file not found!"
            echo "Please create .env.production from env.production.template"
            echo "Run: cp env.production.template .env.production"
            echo "Then edit .env.production with your values"
            exit 1
        fi
        
        # Check if docker-compose is available
        if ! command -v docker-compose &> /dev/null; then
            print_error "docker-compose not found!"
            echo "Please install Docker and Docker Compose first"
            exit 1
        fi
        
        # Load environment variables
        export $(cat .env.production | xargs)
        
        # Build and start containers
        print_info "Building Docker images..."
        docker-compose -f docker-compose.production.yml build
        
        print_info "Starting containers..."
        docker-compose -f docker-compose.production.yml up -d
        
        # Wait for services to be healthy
        print_info "Waiting for services to be healthy..."
        sleep 10
        
        # Check if services are running
        docker-compose -f docker-compose.production.yml ps
        
        print_info "Deployment complete!"
        echo ""
        echo "Your API should be running on http://localhost:3000"
        echo "Test it with: curl http://localhost:3000/up"
        echo ""
        echo "Next steps:"
        echo "  1. Create admin user (option 6 to open console)"
        echo "  2. Configure Nginx reverse proxy"
        echo "  3. Set up SSL certificate"
        ;;
        
    2)
        print_info "Updating deployment..."
        
        # Pull latest code
        print_info "Pulling latest code from Git..."
        git pull origin main
        
        # Rebuild and restart
        print_info "Rebuilding containers..."
        docker-compose -f docker-compose.production.yml build
        
        print_info "Restarting services..."
        docker-compose -f docker-compose.production.yml down
        docker-compose -f docker-compose.production.yml up -d
        
        # Run migrations
        print_info "Running database migrations..."
        docker-compose -f docker-compose.production.yml exec web rails db:migrate
        
        print_info "Update complete!"
        ;;
        
    3)
        print_info "Restarting services..."
        docker-compose -f docker-compose.production.yml restart
        print_info "Services restarted!"
        ;;
        
    4)
        print_info "Showing logs (Ctrl+C to exit)..."
        docker-compose -f docker-compose.production.yml logs -f web
        ;;
        
    5)
        print_info "Running database migrations..."
        docker-compose -f docker-compose.production.yml exec web rails db:migrate
        print_info "Migrations complete!"
        ;;
        
    6)
        print_info "Opening Rails console..."
        print_warning "Type 'exit' to close console"
        echo ""
        docker-compose -f docker-compose.production.yml exec web rails console
        ;;
        
    7)
        print_info "Checking deployment status..."
        echo ""
        echo "=== Container Status ==="
        docker-compose -f docker-compose.production.yml ps
        echo ""
        echo "=== Health Check ==="
        curl -s http://localhost:3000/up && echo "" || echo "Health check failed!"
        echo ""
        echo "=== Database Connection ==="
        docker-compose -f docker-compose.production.yml exec db pg_isready -U vibes
        echo ""
        ;;
        
    8)
        print_info "Creating database backup..."
        BACKUP_DIR="./db/backups"
        mkdir -p $BACKUP_DIR
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/vibes_production_$TIMESTAMP.sql"
        
        docker-compose -f docker-compose.production.yml exec db pg_dump -U vibes vibes_production > $BACKUP_FILE
        
        if [ -f "$BACKUP_FILE" ]; then
            print_info "Backup created: $BACKUP_FILE"
            echo "Backup size: $(du -h $BACKUP_FILE | cut -f1)"
        else
            print_error "Backup failed!"
        fi
        ;;
        
    9)
        print_info "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid choice!"
        exit 1
        ;;
esac

echo ""
print_info "Done!"

