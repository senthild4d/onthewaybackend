# Vibes API - Installation & Setup Guide

**Version:** 1.0  
**Last Updated:** October 13, 2025

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Database Setup](#database-setup)
4. [Configuration](#configuration)
5. [Running the Application](#running-the-application)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)
8. [Deployment](#deployment)

---

## Prerequisites

### Required Software

| Software | Version | Installation |
|----------|---------|--------------|
| **Ruby** | 3.4.4 | [rbenv](https://github.com/rbenv/rbenv) or [RVM](https://rvm.io/) |
| **Rails** | 8.0.3 | Installed via Bundler |
| **PostgreSQL** | 14+ | [Postgres.app](https://postgresapp.com/) (macOS) or [PostgreSQL Downloads](https://www.postgresql.org/download/) |
| **Bundler** | Latest | `gem install bundler` |

### Check Installed Versions

```bash
# Check Ruby version
ruby -v
# Should show: ruby 3.4.4

# Check PostgreSQL
psql --version
# Should show: psql (PostgreSQL) 14.x or higher

# Check if PostgreSQL is running
pg_isready
# Should show: accepting connections
```

---

## Installation Steps

### 1. Clone the Repository

```bash
# Project already exists at: vibes/
cd vibes
```

### 2. Install Ruby Dependencies

```bash
# Install all gems
bundle install
```

**Expected Output:**
```
Bundle complete! 16 Gemfile dependencies, 107 gems now installed.
```

**Installed Gems Include:**
- `rails` (8.0.3) - Framework
- `pg` - PostgreSQL adapter
- `bcrypt` - Password hashing
- `jwt` - JSON Web Tokens
- `rack-cors` - CORS support
- `puma` - Web server

### 3. Verify Installation

```bash
# Check Rails version
rails -v
# Should show: Rails 8.0.3

# Check gems
bundle list | grep -E 'bcrypt|jwt|pg'
# Should show installed versions
```

---

## Database Setup

### 1. Start PostgreSQL

**macOS (Postgres.app):**
```bash
# If using Postgres.app, make sure it's running
# Look for elephant icon in menu bar
```

**macOS (Homebrew):**
```bash
brew services start postgresql@14
```

**Linux:**
```bash
sudo systemctl start postgresql
```

**Verify PostgreSQL is Running:**
```bash
pg_isready
# Output: /tmp:5432 - accepting connections
```

### 2. Create Databases

```bash
# Create development and test databases
rails db:create
```

**Expected Output:**
```
Created database 'vibes_development'
Created database 'vibes_test'
```

**If you get an error:**
```
FATAL: role "your_username" does not exist
```

**Solution:**
```bash
# Create PostgreSQL user (replace with your system username)
createuser -s your_username

# Or create with password
createuser -s -P vibes_user
# Enter password when prompted

# Update config/database.yml if needed
```

### 3. Run Migrations

```bash
# Run all migrations
rails db:migrate
```

**Expected Output:**
```
== 20251013124400 CreateUsers: migrating ======================================
-- enable_extension("pgcrypto")
   -> 0.7290s
-- create_table(:users, {:id=>:uuid})
   -> 0.0101s
-- add_index(:users, :email, {:unique=>true})
   -> 0.0028s
...
== 20251013124400 CreateUsers: migrated (0.7872s) =============================
```

### 4. Verify Database Schema

```bash
# Check current schema
rails db:schema:dump

# View schema
cat db/schema.rb
```

**You should see:**
- `users` table with UUID primary key
- Indexes on email, phone, role, status
- Check constraints for validation

### 5. Seed Initial Data (Optional)

```bash
# Run seeds
rails db:seed
```

**Create Admin User Manually:**
```bash
# Open Rails console
rails console

# Create admin
User.create!(
  email: 'admin@vibes.com',
  password: 'Admin123',
  password_confirmation: 'Admin123',
  name: 'Admin User',
  role: 'admin'
)

# Exit console
exit
```

---

## Configuration

### 1. Environment Variables

Create `.env` file in project root (optional for development):

```bash
# .env
DATABASE_URL=postgresql://localhost/vibes_development
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_here
```

### 2. Database Configuration

Edit `config/database.yml` if needed:

```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: vibes_development
  pool: 5
  # username: your_username  # Uncomment if needed
  # password: your_password  # Uncomment if needed
  # host: localhost
  # port: 5432
```

### 3. CORS Configuration

Already configured in `config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*" # Change in production to specific domains
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
```

**For Production:** Replace `origins "*"` with your frontend domain:
```ruby
origins "https://vibes.com", "https://app.vibes.com"
```

---

## Running the Application

### Start the Server

```bash
# Start Rails server on port 3000
rails server

# Or specify port
rails server -p 3001

# Or with binding to all interfaces
rails server -b 0.0.0.0
```

**Expected Output:**
```
=> Booting Puma
=> Rails 8.0.3 application starting in development
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 7.0.4
* Ruby version: ruby 3.4.4
* Listening on http://127.0.0.1:3000
Use Ctrl-C to stop
```

### Verify Server is Running

```bash
# Health check
curl http://localhost:3000/up

# Should return: <!DOCTYPE html><html><body style="background-color: green"></body></html>
```

### Stop the Server

```
Press Ctrl + C in terminal
```

Or kill process:
```bash
# Find process
lsof -ti:3000

# Kill process
kill $(lsof -ti:3000)

# Or force kill
pkill -f "rails server"
```

---

## Testing

### 1. Manual Testing with cURL

Run the test script:
```bash
# Make executable (first time only)
chmod +x test_auth_api.sh

# Run all tests
./test_auth_api.sh
```

### 2. Manual Testing with Postman/Insomnia

**Import Collection:**

Create a new collection with these requests:

**1. Sign Up:**
- Method: POST
- URL: `http://localhost:3000/api/v1/auth/register`
- Headers: `Content-Type: application/json`
- Body (JSON):
```json
{
  "user": {
    "email": "postman@vibes.com",
    "password": "Password123",
    "password_confirmation": "Password123",
    "name": "Postman User",
    "role": "consumer"
  }
}
```

**2. Sign In:**
- Method: POST
- URL: `http://localhost:3000/api/v1/auth/login`
- Headers: `Content-Type: application/json`
- Body (JSON):
```json
{
  "user": {
    "email": "postman@vibes.com",
    "password": "Password123"
  }
}
```

**3. Get Current User:**
- Method: GET
- URL: `http://localhost:3000/api/v1/auth/me`
- Headers: 
  - `Content-Type: application/json`
  - `Authorization: Bearer YOUR_TOKEN_FROM_LOGIN`

### 3. Testing with Rails Console

```bash
# Open Rails console
rails console

# Create user
user = User.create!(
  email: 'console@vibes.com',
  password: 'Password123',
  name: 'Console User',
  role: 'consumer'
)

# Check user
user.id
user.email
user.role

# Authenticate
user.authenticate('Password123')  # Returns user if correct
user.authenticate('WrongPassword')  # Returns false

# Count users
User.count

# List all users
User.all

# Find user
User.find_by(email: 'console@vibes.com')

# Exit
exit
```

---

## Troubleshooting

### Issue 1: Database Connection Error

**Error:**
```
PG::ConnectionBad: FATAL: database "vibes_development" does not exist
```

**Solution:**
```bash
rails db:create
rails db:migrate
```

---

### Issue 2: PostgreSQL Not Running

**Error:**
```
could not connect to server: Connection refused
```

**Solution:**
```bash
# macOS (Homebrew)
brew services start postgresql@14

# macOS (Postgres.app)
# Open Postgres.app and click "Start"

# Linux
sudo systemctl start postgresql
```

---

### Issue 3: Migration Failed

**Error:**
```
PG::UndefinedFunction: ERROR: function gen_random_uuid() does not exist
```

**Solution:**
```bash
# Open psql
psql vibes_development

# Enable extension manually
CREATE EXTENSION IF NOT EXISTS pgcrypto;

# Exit
\q

# Retry migration
rails db:migrate
```

---

### Issue 4: Gem Installation Errors

**Error:**
```
An error occurred while installing pg (1.5.x), and Bundler cannot continue.
```

**Solution:**
```bash
# Install PostgreSQL development headers
# macOS
brew install postgresql@14

# Ubuntu/Debian
sudo apt-get install libpq-dev

# Then retry
bundle install
```

---

### Issue 5: Port Already in Use

**Error:**
```
Address already in use - bind(2) for "127.0.0.1" port 3000
```

**Solution:**
```bash
# Kill process on port 3000
kill $(lsof -ti:3000)

# Or use different port
rails server -p 3001
```

---

### Issue 6: JWT Secret Key Error

**Error:**
```
SECRET_KEY_BASE is not set
```

**Solution:**
```bash
# Generate new secret key
rails secret

# Copy output and add to credentials
EDITOR="code --wait" rails credentials:edit

# Or set environment variable
export SECRET_KEY_BASE=$(rails secret)
```

---

## Deployment

### Preparing for Production

### 1. Update Database Configuration

Edit `config/database.yml`:
```yaml
production:
  primary:
    adapter: postgresql
    encoding: unicode
    database: vibes_production
    username: <%= ENV['DATABASE_USERNAME'] %>
    password: <%= ENV['DATABASE_PASSWORD'] %>
    host: <%= ENV['DATABASE_HOST'] %>
    port: 5432
    pool: 25
```

### 2. Set Environment Variables

```bash
# Required for production
DATABASE_URL=postgresql://username:password@host:5432/vibes_production
SECRET_KEY_BASE=your_production_secret_key
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
```

### 3. Precompile Assets (if needed)

```bash
RAILS_ENV=production rails assets:precompile
```

### 4. Run Migrations on Production

```bash
RAILS_ENV=production rails db:migrate
```

### 5. Update CORS Origins

Edit `config/initializers/cors.rb`:
```ruby
origins "https://vibes.com", "https://app.vibes.com"
```

---

## Docker Deployment (Optional)

### Dockerfile Already Included

```bash
# Build Docker image
docker build -t vibes-api .

# Run container
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://... \
  -e SECRET_KEY_BASE=... \
  vibes-api
```

---

## Useful Commands

### Database

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Reset database (drops, creates, migrates)
rails db:reset

# Check migration status
rails db:migrate:status

# Open database console
rails dbconsole
```

### Server

```bash
# Start server
rails server

# Start server with specific environment
RAILS_ENV=production rails server

# View routes
rails routes

# View routes for specific controller
rails routes -c auth
```

### Console

```bash
# Open Rails console
rails console

# Open console in sandbox mode (changes rolled back on exit)
rails console --sandbox

# Open console for specific environment
RAILS_ENV=production rails console
```

### Code Quality

```bash
# Run RuboCop (linter)
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Run Brakeman (security scanner)
bundle exec brakeman
```

---

## Project Structure

```
vibes/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb        # Base controller with JWT auth
│   │   └── api/
│   │       └── v1/
│   │           └── auth_controller.rb       # Sign In/Up endpoints
│   ├── models/
│   │   └── user.rb                          # User model
│   └── services/
│       └── json_web_token.rb                # JWT service
├── config/
│   ├── application.rb                       # Application config
│   ├── database.yml                         # Database config
│   ├── routes.rb                            # API routes
│   └── initializers/
│       └── cors.rb                          # CORS config
├── db/
│   ├── migrate/
│   │   └── 20251013124400_create_users.rb  # User table migration
│   ├── schema.rb                            # Current schema
│   └── seeds.rb                             # Seed data
├── Gemfile                                  # Ruby dependencies
├── Gemfile.lock                             # Locked dependencies
├── README.md                                # API documentation
├── INSTALLATION.md                          # This file
├── FRONTEND_API_GUIDE.md                    # Frontend integration guide
├── API_TEST_RESULTS.md                      # Test results
└── test_auth_api.sh                         # Testing script
```

---

## Development Workflow

### 1. Daily Development

```bash
# Pull latest changes (if in Git repo)
git pull

# Install new dependencies (if Gemfile changed)
bundle install

# Run new migrations (if any)
rails db:migrate

# Start server
rails server
```

### 2. Making Changes

```bash
# Generate new model
rails generate model ModelName field:type

# Generate new controller
rails generate controller api/v1/ControllerName

# Create new migration
rails generate migration AddFieldToTable field:type

# Run migrations
rails db:migrate

# Rollback if needed
rails db:rollback
```

### 3. Database Management

```bash
# View database in console
rails dbconsole

# Check database
\dt                    # List tables
\d users              # Describe users table
SELECT * FROM users;  # Query users
\q                    # Quit
```

---

## Environment-Specific Setup

### Development Environment

```bash
# Already configured
# Uses: vibes_development database
# Runs on: http://localhost:3000
```

### Test Environment

```bash
# Setup test database
RAILS_ENV=test rails db:create
RAILS_ENV=test rails db:migrate

# Run tests (when test suite is created)
RAILS_ENV=test rails test
```

### Production Environment

```bash
# Set environment
export RAILS_ENV=production

# Setup database
rails db:create
rails db:migrate

# Start server
rails server -e production
```

---

## Quick Start (TL;DR)

For someone who just cloned the repo:

```bash
# Navigate to project
cd /Users/rbmadmin/Documents/D4D/vibes

# Install dependencies
bundle install

# Create and setup database
rails db:create
rails db:migrate

# Start server
rails server

# Test API (in new terminal)
./test_auth_api.sh
```

**Done!** API is now running on http://localhost:3000

---

## Verification Checklist

After installation, verify everything works:

- [ ] Ruby 3.4.4 installed (`ruby -v`)
- [ ] PostgreSQL 14+ installed and running (`pg_isready`)
- [ ] Gems installed (`bundle list`)
- [ ] Databases created (`rails db:migrate:status`)
- [ ] Migrations run (check schema.rb exists)
- [ ] Server starts without errors (`rails server`)
- [ ] Health check works (`curl http://localhost:3000/up`)
- [ ] Sign Up works (run test_auth_api.sh)
- [ ] Sign In works (run test_auth_api.sh)
- [ ] JWT authentication works (`curl /api/v1/auth/me` with token)

---

## Getting Help

### Common Commands

```bash
# View all rake tasks
rails -T

# View database tasks
rails -T db

# View routes
rails routes

# Check for pending migrations
rails db:migrate:status

# View logs
tail -f log/development.log
```

### Documentation

- **README.md** - API documentation
- **FRONTEND_API_GUIDE.md** - Frontend integration guide
- **API_TEST_RESULTS.md** - Test results
- **/docs** - Project documentation (BRD, schemas, QA docs)

### Support

- **Issues:** Check log/development.log for errors
- **Database:** Check PostgreSQL logs
- **Backend Team:** backend-team@vibes.com

---

## Next Steps After Installation

1. ✅ **API is Ready:** Sign In/Sign Up endpoints working
2. 🔄 **Next Phase:** Onboarding endpoints
3. 🔄 **Coming Soon:** 
   - Venue management
   - Event creation
   - Ticketing system
   - Live streaming

---

**Installation Complete!** 🎉

Your Vibes API is ready for development.

**Test it:**
```bash
./test_auth_api.sh
```

**Start developing:**
```bash
rails server
```

