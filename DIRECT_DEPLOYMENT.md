# Vibes API - Direct Deployment Guide (No Docker)

**Deployment Method:** Direct installation on D4D server  
**Estimated Time:** 45-60 minutes

---

## Overview

This guide deploys the Vibes API directly on your server without Docker:
- Ruby 3.4.4 installed with rbenv
- PostgreSQL 14+ running directly on server
- Rails app managed by systemd
- Nginx as reverse proxy

---

## Prerequisites

- SSH access to D4D server
- Ubuntu 20.04+ or Debian 11+
- Sudo privileges
- GitHub repository: `https://github.com/Digital4design/vibesappbackend`

---

## Step 1: Connect to Server

```bash
ssh user@your-d4d-server.com
```

All remaining commands run on the **server** unless specified otherwise.

---

## Step 2: Update System

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install basic dependencies
sudo apt install -y curl git build-essential libssl-dev libreadline-dev \
  zlib1g-dev autoconf bison libyaml-dev libreadline-dev libncurses5-dev \
  libffi-dev libgdbm-dev
```

---

## Step 3: Install PostgreSQL

```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify it's running
sudo systemctl status postgresql
```

---

## Step 4: Create Database and User

```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL shell, run these commands:
```

In the PostgreSQL prompt:

```sql
-- Create user (replace YOUR_PASSWORD with a strong password)
CREATE USER vibes WITH PASSWORD 'YOUR_STRONG_PASSWORD_HERE';

-- Create production database
CREATE DATABASE vibes_production OWNER vibes;

-- Grant privileges
ALTER USER vibes CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE vibes_production TO vibes;

-- Create additional databases for Rails 8 solid features
CREATE DATABASE vibes_production_cache OWNER vibes;
CREATE DATABASE vibes_production_queue OWNER vibes;
CREATE DATABASE vibes_production_cable OWNER vibes;

GRANT ALL PRIVILEGES ON DATABASE vibes_production_cache TO vibes;
GRANT ALL PRIVILEGES ON DATABASE vibes_production_queue TO vibes;
GRANT ALL PRIVILEGES ON DATABASE vibes_production_cable TO vibes;

-- Exit PostgreSQL
\q
```

**Save your database password!** You'll need it later.

---

## Step 5: Install Ruby with rbenv

```bash
# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Add rbenv to PATH
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Verify rbenv installation
rbenv -v

# Install Ruby 3.4.4
rbenv install 3.4.4

# This will take 5-10 minutes, wait for it to complete

# Set as global Ruby version
rbenv global 3.4.4

# Verify Ruby installation
ruby -v
# Should show: ruby 3.4.4

# Install Bundler
gem install bundler
rbenv rehash
```

---

## Step 6: Clone Repository

```bash
# Create application directory
sudo mkdir -p /var/www/vibes
sudo chown $USER:$USER /var/www/vibes

# Clone repository
cd /var/www/vibes
git clone https://github.com/Digital4design/vibesappbackend.git .

# Or if you need authentication:
# git clone https://YOUR_GITHUB_TOKEN@github.com/Digital4design/vibesappbackend.git .

# Verify files
ls -la
```

---

## Step 7: Install Application Dependencies

```bash
cd /var/www/vibes

# Install gems (this will take a few minutes)
bundle install --deployment --without development test

# Verify installation
bundle list
```

---

## Step 8: Configure Environment Variables

### Generate Secrets First (on local machine)

Open a terminal on your **local machine**:

```bash
cd /Users/rbmadmin/Documents/D4D/vibes
rails secret
```

**Copy the output** - this is your SECRET_KEY_BASE.

### Create .env File (back on server)

```bash
cd /var/www/vibes

# Create .env file
nano .env
```

Paste this content (replace YOUR_VALUES):

```bash
# Database Configuration
VIBES_DATABASE_PASSWORD=YOUR_DATABASE_PASSWORD_HERE
DATABASE_URL=postgresql://vibes:YOUR_DATABASE_PASSWORD_HERE@localhost:5432/vibes_production

# Rails Configuration
RAILS_ENV=production
SECRET_KEY_BASE=YOUR_SECRET_KEY_FROM_RAILS_SECRET
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true

# Server Configuration
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
PORT=3000
```

**Save:** Press `Ctrl+X`, then `Y`, then `Enter`

---

## Step 9: Set Up Database

```bash
cd /var/www/vibes

# Load environment variables
export $(cat .env | xargs)

# Create and migrate database
RAILS_ENV=production bundle exec rails db:create
RAILS_ENV=production bundle exec rails db:migrate

# Verify migration
RAILS_ENV=production bundle exec rails db:migrate:status
```

---

## Step 10: Precompile Assets (if needed)

```bash
cd /var/www/vibes

# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile
```

---

## Step 11: Test the Application

```bash
cd /var/www/vibes

# Load environment
export $(cat .env | xargs)

# Start Rails server (test mode)
RAILS_ENV=production bundle exec rails server -b 0.0.0.0

# You should see: Listening on http://0.0.0.0:3000
```

**In a new SSH session** (keep the server running):

```bash
# Test health endpoint
curl http://localhost:3000/up
# Should return: HTML page with green background

# If it works, go back to first terminal and press Ctrl+C to stop
```

---

## Step 12: Create Systemd Service

Create a systemd service to manage the Rails application:

```bash
sudo nano /etc/systemd/system/vibes.service
```

Paste this content (replace `your_username` with your actual username):

```ini
[Unit]
Description=Vibes API Rails Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=your_username
WorkingDirectory=/var/www/vibes
EnvironmentFile=/var/www/vibes/.env

# Use full path to bundler and rails
ExecStart=/home/your_username/.rbenv/shims/bundle exec puma -C config/puma.rb -e production

# Restart settings
Restart=always
RestartSec=10

# Logging
StandardOutput=append:/var/www/vibes/log/production.log
StandardError=append:/var/www/vibes/log/production.log

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

**Replace `your_username`** with your actual username! Check with: `whoami`

**Save:** Press `Ctrl+X`, then `Y`, then `Enter`

---

## Step 13: Start Application Service

```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable vibes

# Start the service
sudo systemctl start vibes

# Check status
sudo systemctl status vibes

# Should show: Active: active (running)
```

**View logs:**
```bash
# Real-time logs
sudo journalctl -u vibes -f

# Last 50 lines
sudo journalctl -u vibes -n 50

# Or application logs
tail -f /var/www/vibes/log/production.log
```

---

## Step 14: Install and Configure Nginx

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/vibes
```

Paste this configuration (replace `your-domain.com` or use server IP):

```nginx
upstream vibes_app {
    server localhost:3000 fail_timeout=0;
}

server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or server IP
    
    # Logging
    access_log /var/log/nginx/vibes_access.log;
    error_log /var/log/nginx/vibes_error.log;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Client body size
    client_max_body_size 50M;
    
    # Root location
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

**Save:** Press `Ctrl+X`, then `Y`, then `Enter`

### Enable Nginx Site

```bash
# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/vibes /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Should show: syntax is ok, test is successful

# Restart Nginx
sudo systemctl restart nginx
```

---

## Step 15: Configure Firewall

```bash
# Allow HTTP, HTTPS, and SSH
sudo ufw allow 22/tcp   # SSH (IMPORTANT!)
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS

# Enable firewall
sudo ufw --force enable

# Check status
sudo ufw status
```

---

## Step 16: Verify Deployment

### Test from Server

```bash
# Health check
curl http://localhost/up

# Test API
curl -X POST http://localhost/api/v1/auth/register \
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

### Test from Your Local Machine

```bash
# Replace YOUR_SERVER_IP with your server's IP address
curl http://YOUR_SERVER_IP/up

# Test registration
curl -X POST http://YOUR_SERVER_IP/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "test2@vibes.com",
      "password": "Password123",
      "password_confirmation": "Password123",
      "name": "Test User 2",
      "role": "consumer"
    }
  }'
```

---

## Step 17: Create Admin User

```bash
cd /var/www/vibes

# Load environment
export $(cat .env | xargs)

# Open Rails console
RAILS_ENV=production bundle exec rails console

# In console, create admin:
User.create!(
  email: 'admin@vibes.com',
  password: 'ChangeThisPassword123!',
  password_confirmation: 'ChangeThisPassword123!',
  name: 'Admin User',
  role: 'admin'
)

# Verify
User.count

# Exit console
exit
```

---

## Step 18: Set Up SSL (Optional but Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Follow prompts:
# - Enter email address
# - Agree to terms
# - Choose to redirect HTTP to HTTPS (recommended)

# Test auto-renewal
sudo certbot renew --dry-run
```

---

## ✅ Deployment Complete!

Your API is now live at:
- **HTTP:** `http://your-server-ip-or-domain`
- **HTTPS:** `https://your-domain.com` (if SSL configured)

---

## Common Commands

### Application Management

```bash
# Start application
sudo systemctl start vibes

# Stop application
sudo systemctl stop vibes

# Restart application
sudo systemctl restart vibes

# Check status
sudo systemctl status vibes

# View logs (real-time)
sudo journalctl -u vibes -f

# View logs (last 100 lines)
sudo journalctl -u vibes -n 100
```

### Database Operations

```bash
cd /var/www/vibes
export $(cat .env | xargs)

# Run migrations
RAILS_ENV=production bundle exec rails db:migrate

# Open database console
RAILS_ENV=production bundle exec rails dbconsole

# Open Rails console
RAILS_ENV=production bundle exec rails console

# Check database status
RAILS_ENV=production bundle exec rails db:migrate:status
```

### Nginx

```bash
# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# View error logs
sudo tail -f /var/log/nginx/vibes_error.log

# View access logs
sudo tail -f /var/log/nginx/vibes_access.log
```

---

## Updating the Application

When you push new code to GitHub:

```bash
# Stop application
sudo systemctl stop vibes

# Pull latest code
cd /var/www/vibes
git pull origin main

# Install new dependencies (if Gemfile changed)
bundle install --deployment

# Run new migrations
export $(cat .env | xargs)
RAILS_ENV=production bundle exec rails db:migrate

# Precompile assets (if needed)
RAILS_ENV=production bundle exec rails assets:precompile

# Restart application
sudo systemctl start vibes

# Check status
sudo systemctl status vibes
```

---

## Database Backups

### Manual Backup

```bash
# Create backup directory
mkdir -p /var/www/vibes/backups

# Create backup
pg_dump -U vibes -h localhost vibes_production > /var/www/vibes/backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup
ls -lh /var/www/vibes/backups/
```

### Automated Daily Backups

```bash
# Create backup script
sudo nano /usr/local/bin/backup-vibes.sh
```

Paste:

```bash
#!/bin/bash
BACKUP_DIR="/var/www/vibes/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
pg_dump -U vibes -h localhost vibes_production > $BACKUP_DIR/vibes_$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "vibes_*.sql" -mtime +7 -delete

echo "Backup completed: vibes_$DATE.sql"
```

Make executable:

```bash
sudo chmod +x /usr/local/bin/backup-vibes.sh
```

Schedule daily backups:

```bash
# Edit crontab
crontab -e

# Add this line (runs daily at 2 AM):
0 2 * * * /usr/local/bin/backup-vibes.sh
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u vibes -n 50

# Common issues:
# 1. Wrong username in service file
# 2. Missing environment file
# 3. Database connection failed
# 4. Port already in use
```

### Database Connection Error

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Test connection
psql -U vibes -h localhost vibes_production
```

### Port Already in Use

```bash
# Find what's using port 3000
sudo lsof -i :3000

# Kill the process
sudo kill -9 <PID>

# Or restart the service
sudo systemctl restart vibes
```

### Permission Errors

```bash
# Fix ownership
sudo chown -R $USER:$USER /var/www/vibes

# Fix log directory permissions
sudo chmod -R 755 /var/www/vibes/log
sudo chown -R $USER:$USER /var/www/vibes/log
```

### View Detailed Logs

```bash
# Application logs
tail -f /var/www/vibes/log/production.log

# System logs for service
sudo journalctl -u vibes -f

# Nginx logs
sudo tail -f /var/log/nginx/vibes_error.log
```

---

## Security Checklist

After deployment:

- [ ] Strong database password set
- [ ] SECRET_KEY_BASE is unique and secure
- [ ] `.env` file permissions: `chmod 600 .env`
- [ ] SSL certificate installed (HTTPS)
- [ ] Firewall enabled (ufw)
- [ ] SSH key authentication enabled
- [ ] Password SSH login disabled (optional but recommended)
- [ ] Regular backups scheduled
- [ ] CORS updated for specific domains (not `*`)

---

## Performance Tuning (Optional)

### Increase Puma Workers

Edit `.env`:

```bash
WEB_CONCURRENCY=4  # Increase based on CPU cores
RAILS_MAX_THREADS=5
```

Restart:

```bash
sudo systemctl restart vibes
```

### PostgreSQL Connection Pool

Edit `config/database.yml` (already configured):

```yaml
pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

---

## Next Steps

1. **Update CORS** - Edit `config/initializers/cors.rb` for your frontend domain
2. **Monitor Logs** - Watch for errors in first 24 hours
3. **Set Up Monitoring** - Consider tools like New Relic or Datadog
4. **Document Credentials** - Store passwords in password manager
5. **Test All Endpoints** - Verify registration, login, authentication

---

**Your Vibes API is now running in production!** 🚀

**Base URL:** `http://your-server-ip` or `https://your-domain.com`

**Endpoints:**
- Health: `GET /up`
- Register: `POST /api/v1/auth/register`
- Login: `POST /api/v1/auth/login`
- Current User: `GET /api/v1/auth/me`

For questions or issues, check the logs:
```bash
sudo journalctl -u vibes -f
```


