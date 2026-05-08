# Vibes API - Production Deployment Guide

**Version:** 1.0  
**Last Updated:** October 28, 2025

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Server Setup](#server-setup)
3. [Deployment Methods](#deployment-methods)
4. [Environment Configuration](#environment-configuration)
5. [Database Setup](#database-setup)
6. [Deployment Steps](#deployment-steps)
7. [Post-Deployment](#post-deployment)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Local Requirements
- Git access to repository
- SSH access to D4D server
- SSH key configured for server access

### Server Requirements
- Ubuntu 20.04+ or Debian 11+
- Minimum 2GB RAM (4GB recommended)
- 20GB+ disk space
- Root or sudo access
- Domain name pointed to server (optional but recommended)

---

## Server Setup

### 1. Initial Server Connection

```bash
# Test SSH connection
ssh user@your-d4d-server.com

# Update system packages
sudo apt update && sudo apt upgrade -y
```

### 2. Install Required Software

#### Option A: Docker Deployment (Recommended)

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose -y

# Log out and back in for group changes to take effect
exit
```

#### Option B: Direct Deployment

```bash
# Install Ruby dependencies
sudo apt install -y build-essential git curl libssl-dev libreadline-dev \
  zlib1g-dev autoconf bison libyaml-dev libreadline-dev \
  libncurses5-dev libffi-dev libgdbm-dev

# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Add rbenv to PATH
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.4.4
rbenv install 3.4.4
rbenv global 3.4.4

# Verify Ruby installation
ruby -v
# Should show: ruby 3.4.4

# Install Bundler
gem install bundler
```

### 3. Install PostgreSQL

```bash
# Install PostgreSQL 14+
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify PostgreSQL is running
sudo systemctl status postgresql
```

### 4. Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database user
CREATE USER vibes WITH PASSWORD 'your_secure_password_here';

# Create databases
CREATE DATABASE vibes_production OWNER vibes;
CREATE DATABASE vibes_production_cache OWNER vibes;
CREATE DATABASE vibes_production_queue OWNER vibes;
CREATE DATABASE vibes_production_cable OWNER vibes;

# Grant privileges
ALTER USER vibes CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE vibes_production TO vibes;
GRANT ALL PRIVILEGES ON DATABASE vibes_production_cache TO vibes;
GRANT ALL PRIVILEGES ON DATABASE vibes_production_queue TO vibes;
GRANT ALL PRIVILEGES ON DATABASE vibes_production_cable TO vibes;

# Exit psql
\q
```

### 5. Install Nginx (Reverse Proxy)

```bash
# Install Nginx
sudo apt install -y nginx

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## Deployment Methods

### Method 1: Docker Deployment (Recommended)

This uses the included Dockerfile with Thruster for production deployment.

### Method 2: Direct Deployment

Deploy Rails application directly on the server without Docker.

### Method 3: Kamal Deployment

Use Kamal for zero-downtime deployments (already configured in Gemfile).

---

## Environment Configuration

### 1. Generate Secret Keys

On your **local machine**:

```bash
cd /Users/rbmadmin/Documents/D4D/vibes

# Generate secret key base
rails secret

# Save this output, you'll need it for RAILS_MASTER_KEY or SECRET_KEY_BASE
```

### 2. Set Up Rails Credentials

```bash
# Edit credentials (on local machine)
EDITOR="nano" rails credentials:edit

# Add production database password:
# production:
#   database:
#     password: your_secure_password_here
```

### 3. Environment Variables

Create a `.env.production` file on the **server** (you'll upload this):

```bash
# Database Configuration
VIBES_DATABASE_PASSWORD=your_secure_password_here
DATABASE_URL=postgresql://vibes:your_secure_password_here@localhost:5432/vibes_production

# Rails Configuration
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=your_generated_secret_key_here

# Server Configuration
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Optional: If using custom domain
# RAILS_HOSTNAME=api.vibes.com
```

---

## Deployment Steps

### Docker Deployment (Method 1)

#### Step 1: Prepare on Local Machine

```bash
# Navigate to project
cd /Users/rbmadmin/Documents/D4D/vibes

# Ensure you have the latest code
git status
git add .
git commit -m "Prepare for production deployment"
git push origin main
```

#### Step 2: On Server - Clone Repository

```bash
# SSH into server
ssh user@your-d4d-server.com

# Create app directory
mkdir -p /var/www/vibes
cd /var/www/vibes

# Clone repository
git clone https://github.com/Digital4design/vibesappbackend.git .

# Or if you need authentication
git clone https://YOUR_GITHUB_TOKEN@github.com/Digital4design/vibesappbackend.git .
```

#### Step 3: Create Environment File

```bash
# Create .env file
nano .env.production

# Paste your environment variables (see Environment Configuration section)
# Save with Ctrl+X, Y, Enter
```

#### Step 4: Create Docker Compose File

```bash
# Create docker-compose.yml
nano docker-compose.yml
```

Paste this content:

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:80"
    env_file:
      - .env.production
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://vibes:${VIBES_DATABASE_PASSWORD}@host.docker.internal:5432/vibes_production
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: postgres:14-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=vibes
      - POSTGRES_PASSWORD=${VIBES_DATABASE_PASSWORD}
      - POSTGRES_DB=vibes_production
    restart: unless-stopped

volumes:
  postgres_data:
```

#### Step 5: Build and Deploy

```bash
# Build Docker image
docker-compose build

# Start containers
docker-compose up -d

# Check logs
docker-compose logs -f web

# Verify containers are running
docker-compose ps
```

#### Step 6: Run Database Migrations

```bash
# Run migrations
docker-compose exec web rails db:migrate

# Or manually create and migrate
docker-compose exec web rails db:create
docker-compose exec web rails db:migrate
```

---

### Direct Deployment (Method 2)

#### Step 1: Clone and Setup

```bash
# On server
cd /var/www
sudo mkdir vibes
sudo chown $USER:$USER vibes
cd vibes

# Clone repository
git clone https://github.com/Digital4design/vibesappbackend.git .

# Install dependencies
bundle install --deployment --without development test
```

#### Step 2: Configure Environment

```bash
# Create .env file
nano .env

# Add environment variables (see Environment Configuration)
```

#### Step 3: Setup Database

```bash
# Load environment
export $(cat .env | xargs)

# Create and migrate database
RAILS_ENV=production rails db:create
RAILS_ENV=production rails db:migrate
```

#### Step 4: Precompile Assets (if any)

```bash
RAILS_ENV=production rails assets:precompile
```

#### Step 5: Start Application with Systemd

Create systemd service file:

```bash
sudo nano /etc/systemd/system/vibes.service
```

Paste:

```ini
[Unit]
Description=Vibes API Rails Application
After=network.target postgresql.service

[Service]
Type=simple
User=your_username
WorkingDirectory=/var/www/vibes
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/vibes/.env
ExecStart=/home/your_username/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Start the service:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable vibes

# Start service
sudo systemctl start vibes

# Check status
sudo systemctl status vibes
```

---

## Configure Nginx Reverse Proxy

### 1. Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/vibes
```

Paste this configuration:

```nginx
upstream vibes_app {
    server localhost:3000;
}

server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or server IP
    
    # Logging
    access_log /var/log/nginx/vibes_access.log;
    error_log /var/log/nginx/vibes_error.log;
    
    # Client body size
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://vibes_app;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /up {
        proxy_pass http://vibes_app;
        access_log off;
    }
}
```

### 2. Enable Site and Restart Nginx

```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/vibes /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 3. Configure Firewall

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH

# Enable firewall (if not already enabled)
sudo ufw enable

# Check status
sudo ufw status
```

---

## SSL Certificate Setup (Optional but Recommended)

### Using Let's Encrypt (Certbot)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Follow prompts to configure HTTPS redirect

# Test auto-renewal
sudo certbot renew --dry-run
```

After SSL setup, your API will be available at: `https://your-domain.com`

---

## Post-Deployment

### 1. Verify Deployment

```bash
# Test health endpoint
curl http://localhost:3000/up
# Or if using domain: curl https://your-domain.com/up

# Test API endpoints
curl -X POST https://your-domain.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "test@vibes.com",
      "password": "Password123",
      "password_confirmation": "Password123",
      "name": "Test User",
      "role": "consumer"
    }
  }'
```

### 2. Create Admin User

```bash
# If using Docker
docker-compose exec web rails console

# If direct deployment
RAILS_ENV=production rails console

# In console:
User.create!(
  email: 'admin@vibes.com',
  password: 'SecurePassword123!',
  password_confirmation: 'SecurePassword123!',
  name: 'Admin User',
  role: 'admin'
)

exit
```

### 3. Update CORS Configuration

Edit `config/initializers/cors.rb` to allow only your frontend domain:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://your-frontend-domain.com", "https://vibes.com"
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
```

Redeploy after changes:

```bash
# Docker
docker-compose restart web

# Direct deployment
sudo systemctl restart vibes
```

---

## Monitoring & Maintenance

### Check Application Logs

#### Docker Deployment

```bash
# View logs
docker-compose logs -f web

# View specific number of lines
docker-compose logs --tail=100 web
```

#### Direct Deployment

```bash
# Application logs
tail -f /var/www/vibes/log/production.log

# Systemd service logs
sudo journalctl -u vibes -f
```

### Database Backups

```bash
# Create backup script
sudo nano /usr/local/bin/backup-vibes-db.sh
```

Paste:

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/vibes"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump vibes_production > $BACKUP_DIR/vibes_production_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "vibes_production_*.sql" -mtime +7 -delete

echo "Backup completed: vibes_production_$DATE.sql"
```

Make executable and schedule:

```bash
# Make executable
sudo chmod +x /usr/local/bin/backup-vibes-db.sh

# Add to crontab (daily at 2 AM)
sudo crontab -e

# Add this line:
0 2 * * * /usr/local/bin/backup-vibes-db.sh
```

### Monitoring Commands

```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check CPU usage
top

# Check application status
# Docker:
docker-compose ps

# Direct:
sudo systemctl status vibes

# Check database connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'vibes_production';"
```

---

## Updating the Application

### Docker Deployment

```bash
cd /var/www/vibes

# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build
docker-compose up -d

# Run migrations
docker-compose exec web rails db:migrate
```

### Direct Deployment

```bash
cd /var/www/vibes

# Pull latest code
git pull origin main

# Install new dependencies
bundle install --deployment

# Run migrations
RAILS_ENV=production rails db:migrate

# Restart service
sudo systemctl restart vibes
```

---

## Troubleshooting

### Issue 1: Database Connection Failed

**Error:** `could not connect to server: Connection refused`

**Solution:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check connection
sudo -u postgres psql -c "SELECT 1;"
```

### Issue 2: Port Already in Use

**Error:** `Address already in use - bind(2)`

**Solution:**
```bash
# Find process using port 3000
sudo lsof -i :3000

# Kill process
sudo kill -9 <PID>

# Or restart Docker
docker-compose restart
```

### Issue 3: Permission Denied

**Error:** `Permission denied @ dir_s_mkdir`

**Solution:**
```bash
# Fix ownership
sudo chown -R $USER:$USER /var/www/vibes

# Fix permissions
chmod -R 755 /var/www/vibes
```

### Issue 4: Secret Key Base Not Set

**Error:** `SECRET_KEY_BASE is not set`

**Solution:**
```bash
# Generate new secret
rails secret

# Add to .env file
echo "SECRET_KEY_BASE=<generated_secret>" >> .env.production

# Restart application
```

### Issue 5: Migration Failed

**Error:** `PG::UndefinedFunction: ERROR: function gen_random_uuid()`

**Solution:**
```bash
# Enable pgcrypto extension
sudo -u postgres psql vibes_production -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# Retry migration
RAILS_ENV=production rails db:migrate
```

### Check Application Health

```bash
# Test health endpoint
curl http://localhost:3000/up

# Test API endpoint
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test@test.com","password":"Password123","password_confirmation":"Password123","name":"Test","role":"consumer"}}'
```

---

## Security Checklist

- [ ] Strong database passwords set
- [ ] SECRET_KEY_BASE generated and secure
- [ ] CORS configured for specific domains (not `*`)
- [ ] SSL/HTTPS enabled
- [ ] Firewall configured (ufw)
- [ ] Regular database backups scheduled
- [ ] Server security updates enabled
- [ ] SSH key authentication (no password login)
- [ ] Non-root user for application
- [ ] Environment variables not committed to Git

---

## Quick Reference Commands

### Docker

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f web

# Run rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Rebuild
docker-compose build
```

### Direct Deployment

```bash
# Start
sudo systemctl start vibes

# Stop
sudo systemctl stop vibes

# Restart
sudo systemctl restart vibes

# Status
sudo systemctl status vibes

# Logs
tail -f log/production.log

# Console
RAILS_ENV=production rails console

# Migrations
RAILS_ENV=production rails db:migrate
```

---

## Support

For issues or questions:
- **Backend Team:** backend@vibes.com
- **Documentation:** /docs folder in repository
- **Server Logs:** Check `/var/log/nginx/` and application logs

---

**Deployment Complete!** 🚀

Your Vibes API should now be running in production.

**Next Steps:**
1. Update frontend to use production API URL
2. Monitor application logs for first 24 hours
3. Set up monitoring/alerting system (optional)
4. Configure automated backups
5. Plan for scaling if needed


