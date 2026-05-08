# Vibes API - Event Discovery & Ticketing Platform

**Version:** 1.0  
**Ruby:** 3.4.4  
**Rails:** 8.0.3  
**Database:** PostgreSQL with UUID primary keys

---

## Project Setup

### Prerequisites
- Ruby 3.4.4
- PostgreSQL 14+
- Bundler

### Installation

```bash
# Install dependencies
bundle install

# Create and setup database
rails db:create
rails db:migrate

# Start server
rails server
```

Server runs on: http://localhost:3000

---

## Authentication API

### 1. Sign Up (Register)

**Endpoint:** `POST /api/v1/auth/register`

**Request:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "Password123",
    "password_confirmation": "Password123",
    "name": "John Doe",
    "role": "consumer",
    "phone": "+1234567890"
  }
}
```

**Response (201 Created):**
```json
{
  "message": "User created successfully",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "phone": "1234567890",
    "name": "John Doe",
    "role": "consumer",
    "status": "active",
    "preferences": {},
    "created_at": "2025-10-13T12:50:31.330Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Validation Rules:**
- Email: Required, valid format, unique
- Password: Minimum 8 characters, must include letter and number
- Role: `consumer`, `venue_manager`, or `admin` (default: `consumer`)
- Phone: Optional, unique if provided

**Error Response (422):**
```json
{
  "errors": [
    "Email has already been taken",
    "Password is too short (minimum is 8 characters)"
  ]
}
```

---

### 2. Sign In (Login)

**Endpoint:** `POST /api/v1/auth/login`

**Request:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "Password123"
  }
}
```

**Response (200 OK):**
```json
{
  "message": "Login successful",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "consumer",
    "status": "active",
    "preferences": {},
    "created_at": "2025-10-13T12:50:31.330Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Error Responses:**
- **401 Unauthorized:** Invalid email or password
- **403 Forbidden:** Account is disabled

---

### 3. Get Current User

**Endpoint:** `GET /api/v1/auth/me`

**Headers:**
```
Authorization: Bearer YOUR_JWT_TOKEN
```

**Response (200 OK):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "consumer",
    "status": "active",
    "preferences": {},
    "created_at": "2025-10-13T12:50:31.330Z"
  }
}
```

**Error Response (401):**
```json
{
  "error": "Unauthorized"
}
```

---

### 4. Logout

**Endpoint:** `POST /api/v1/auth/logout`

**Note:** With JWT, logout is handled client-side by removing the token. This endpoint is provided for consistency.

**Response (200 OK):**
```json
{
  "message": "Logged out successfully"
}
```

---

## Testing with cURL

### Register a Consumer
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "consumer@vibes.com",
      "password": "Password123",
      "password_confirmation": "Password123",
      "name": "Test Consumer",
      "role": "consumer"
    }
  }'
```

### Register a Venue Manager
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "venue@vibes.com",
      "password": "Password123",
      "password_confirmation": "Password123",
      "name": "Club Zero",
      "role": "venue_manager"
    }
  }'
```

### Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "consumer@vibes.com",
      "password": "Password123"
    }
  }'
```

### Get Current User (with token)
```bash
curl -X GET http://localhost:3000/api/v1/auth/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Database Schema

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20) UNIQUE,
  password_digest VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role VARCHAR(20) NOT NULL DEFAULT 'consumer',
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  CONSTRAINT check_role CHECK (role IN ('consumer', 'venue_manager', 'admin')),
  CONSTRAINT check_status CHECK (status IN ('active', 'disabled')),
  CONSTRAINT check_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);
```

**Indexes:**
- `idx_users_email` (unique)
- `idx_users_phone` (unique, partial)
- `idx_users_role`
- `idx_users_status`
- `idx_users_created_at`

---

## Project Structure

```
vibes/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb (JWT authentication)
│   │   └── api/
│   │       └── v1/
│   │           └── auth_controller.rb (Sign In/Sign Up)
│   ├── models/
│   │   └── user.rb (User model with has_secure_password)
│   └── services/
│       └── json_web_token.rb (JWT encoding/decoding)
├── config/
│   ├── routes.rb (API routes)
│   ├── database.yml (PostgreSQL config)
│   └── initializers/
│       └── cors.rb (CORS configuration)
├── db/
│   ├── migrate/
│   │   └── 20251013124400_create_users.rb
│   └── schema.rb
└── Gemfile (bcrypt, jwt, rack-cors)
```

---

## Security Features

✅ **Password Hashing:** bcrypt with has_secure_password  
✅ **JWT Tokens:** HS256 algorithm, 24-hour expiration  
✅ **Email Validation:** Format and uniqueness checks  
✅ **Password Requirements:** Minimum 8 characters, must include letter and number  
✅ **Role-Based Access:** consumer, venue_manager, admin roles  
✅ **CORS Enabled:** Cross-origin requests allowed  
✅ **UUID Primary Keys:** Globally unique identifiers  
✅ **Database Constraints:** Role, status, and email format validation  

---

## Next Steps

- [ ] Add phone number authentication (SMS OTP)
- [ ] Implement refresh tokens
- [ ] Add password reset functionality
- [ ] Create venues management endpoints
- [ ] Implement events creation and management
- [ ] Add ticketing system
- [ ] Implement live streaming features

---

## Related Documentation

- [BRD](/docs/Vibes_BRD.md)
- [Database Schema](/docs/Vibes_Database_Schema.md)
- [API Specification](/docs/vibes_api_v1.md)
- [Auth QA](/docs/Vibes_Figma_Auth_QA.md)
- [Onboarding QA](/docs/Vibes_Figma_Onboarding_QA.md)
- [Events & Poster QA](/docs/Vibes_Figma_Events_Poster_QA.md)

---

**Built with ❤️ for Vibes Platform**
