# Vibes API Documentation

**Version:** 1.0  
**Last Updated:** March 2026  
**Base URL:** 
- Development: `http://localhost:3000`
- Production: `https://vibesapp.digital4design.com`

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [New User Flow](#new-user-flow)
4. [Existing User Flow](#existing-user-flow)
5. [Optional Setup](#optional-setup)
6. [Device Management](#device-management)
7. [User Information](#user-information)
8. [Location Services](#location-services)
9. [Search](#search)
10. [Artists](#artists)
11. [Artist Categories](#artist-categories)
12. [Venues](#venues)
13. [Venue Menus](#venue-menus)
14. [Venue Ratings](#venue-ratings)
15. [Events](#events)
16. [Event Categories](#event-categories)
17. [Event Boost](#event-boost)
18. [Event Bookings](#event-bookings)
19. [Food & Bar Ordering](#food--bar-ordering)
20. [Venue Manager Dashboard](#venue-manager-dashboard)
21. [VibeCheck (Post-Event Ratings)](#vibecheck-post-event-ratings)
22. [Event Reviews](#event-reviews)
23. [Map View](#map-view)
23. [Likes](#likes)
24. [User Profile](#user-profile)
25. [Follows & Following](#follows--following)
26. [User Blocking](#user-blocking)
27. [Group Chats](#group-chats)
28. [Chats (One-on-One)](#chats-one-on-one)
29. [Wallets & Payments](#wallets--payments)
30. [Floor Plans](#floor-plans)

---

## Overview

The Vibes API provides a complete platform for event discovery and venue management with support for:
- OTP-based authentication (phone/email)
- Email/password authentication
- Biometric authentication (Face ID/Fingerprint)
- PIN authentication
- Device management
- Location services
- Global search across events, venues, and users
- Artist category management
- Venue management (create, update, list venues)
- Venue PR (assign PR to venue, list PR's venues, stop partnership, search PR users)
- Private/unlisted event invites (share QR with token, validate by_invite, regenerate invite, invite_sharing)
- Event management (business, social, activities, music, etc.)
- Venue ratings (1-5 stars with comments)
- Event bookings/RSVPs
- Event interests (express interest without booking)
- Event reporting (report inappropriate content)
- Likes for events and venues
- User profile management (update name, username, date of birth)
- Email/phone change with OTP verification
- Group chat messaging with real-time WebSocket support
- City-based group chats (automatic membership based on location)
- Account deactivation

### Authentication Flow Summary

**NEW USER:**
1. Check Device → Determine if new user
2. Send OTP (phone or email) → Receive OTP code
3. Verify OTP → Get verification_token
4. Complete Registration → Provide role & name → Get JWT
5. OPTIONAL: Setup Password OR Register Device for Biometric/PIN

**EXISTING USER:**
- Device Registered → Use Biometric (if enabled)
- Device Registered → Use PIN (if enabled)
- Has Password → Use Username/Email/Phone & Password
- Otherwise → Use OTP

### Authentication Header

All authenticated endpoints require a Bearer token:

```
Authorization: Bearer {jwt_token}
```

### Token Expiration

**Persistent Login (Instagram-style):**
- All authentication methods (login, OTP, biometric, PIN) return **long-lived JWT tokens** that are valid for **90 days**
- Once logged in, users stay authenticated for 90 days without needing to re-login
- Tokens remain active until they expire or the user explicitly logs out
- This provides a seamless, persistent login experience similar to Instagram

**Short-lived Tokens:**
- Verification tokens (for OTP registration) expire after 15 minutes
- These are only used during the registration process

---

## New User Flow

### 1. Check Device

**Endpoint:** `POST /api/v1/auth/check_device`

**Description:** Check if device is registered and what authentication methods are available. Determines the appropriate next step based on user and device status.

**Authentication:** None required

**Request Body:**
```json
{
  "device_uuid": "TEST-DEVICE-12345",
  "username": "johndoe"
}
```

**Parameters:**
- `device_uuid` (string, optional): Unique device identifier - **At least one of device_uuid or username must be provided**
- `username` (string, optional): User identifier - can be username, email address, or phone number
  - **Note:** The `username` field is flexible and can accept:
    - Username (e.g., "johndoe")
    - Email address (e.g., "john@example.com")
    - Phone number (e.g., "+1234567890" or "1234567890")
  - The system automatically detects the format and searches accordingly

**Error Responses:**
- **400 Bad Request:** Device UUID or username (can be username, email, or phone) is required (at least one must be provided)

**Response Scenarios:**

#### Scenario 1: New User + New Device (No User Found)
```json
{
  "user_exists": false,
  "device_registered": false,
  "recommended_method": "register_with_otp",
  "message": "User not found. Please register with OTP."
}
```
**Next Step:** Use OTP flow to register new user.

#### Scenario 2: Existing User, Device UUID Not Present for This User
```json
{
  "user_exists": true,
  "device_registered": false,
  "recommended_method": "register_device",
  "message": "Device not registered for this user. Please register device."
}
```
**Next Step:** Register device using `register_device` endpoint.

#### Scenario 3: Existing User with Existing Device
```json
{
  "user_exists": true,
  "device_registered": true,
  "device_has_biometric": true,
  "device_has_pin": false,
  "has_password": true,
  "authentication_methods": ["biometric", "password", "otp"],
  "recommended_method": "biometric"
}
```

**Response Fields (Scenario 3):**
- `user_exists` (boolean): Always `true` for this scenario
- `device_registered` (boolean): Always `true` for this scenario
- `device_has_biometric` (boolean): Whether device has biometric enabled
- `device_has_pin` (boolean): Whether device has PIN enabled
- `has_password` (boolean): Whether user has set up password
- `authentication_methods` (array): Available auth methods (biometric, pin, password, otp)
  - Shows 'biometric' if device has it enabled
  - Shows 'pin' if device has PIN enabled
  - Shows 'password' if user has set up password
  - Shows 'otp' only if user hasn't set up biometric, pin, or password
- `recommended_method` (string): Recommended authentication method (priority: biometric > pin > password > otp)

**Important Notes:**
- **At least one of `device_uuid` or `username` must be provided**
- If user exists but `device_uuid` is not registered for this user, returns `recommended_method: 'register_device'`
- If new user (no record found), returns `recommended_method: 'register_with_otp'`
- If existing user with existing device, returns `authentication_methods` and `recommended_method` for login
- The `username` parameter is flexible and can accept username, email, or phone number
- The system automatically detects the format and searches accordingly

---

### 2. Send OTP (Phone)

**Endpoint:** `POST /api/v1/auth/send_otp`

**Description:** Send OTP to phone number. Works for both new and existing users.

**Authentication:** None required

**Request Body:**
```json
{
  "phone": "+1234567890"
}
```

**Parameters:**
- `phone` (string, required): Phone number (10-15 digits)

**Response:**
```json
{
  "is_new_user": false,
  "otp": "123456",
  "expires_in": "5 minutes",
  "max_attempts": 5,
  "requests_remaining": 4
}
```

**Response Fields:**
- `is_new_user` (boolean): Whether this is a new user
- `otp` (string): OTP code (development only)
- `expires_in` (string): OTP expiration time
- `max_attempts` (integer): Maximum verification attempts
- `requests_remaining` (integer): Remaining OTP requests

---

### 3. Send OTP (Email)

**Endpoint:** `POST /api/v1/auth/send_otp`

**Description:** Send OTP to email address. Works for both new and existing users.

**Authentication:** None required

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Parameters:**
- `email` (string, required): Email address

**Response:**
```json
{
  "is_new_user": false,
  "otp": "123456",
  "expires_in": "5 minutes",
  "max_attempts": 5,
  "requests_remaining": 4
}
```

---

### 4. Verify OTP (New User)

**Endpoint:** `POST /api/v1/auth/verify_otp`

**Description:** Verify OTP code.

**Authentication:** None required

**Request Body:**
```json
{
  "phone": "+1234567890",
  "code": "123456"
}
```

**Parameters:**
- `phone` OR `email` (string, required): Identifier used in send_otp
- `code` (string, required): 6-digit OTP code

**Response for NEW Users:**
```json
{
  "is_new_user": true,
  "verification_token": "verification_token_here"
}
```

**Response for EXISTING Users:**
```json
{
  "is_new_user": false,
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Next Steps:**
- **New users:** Use `verification_token` to complete registration
- **Existing users:** User is logged in, JWT token is returned (valid for 90 days - persistent login)

---

### 5. Complete Registration

**Endpoint:** `POST /api/v1/auth/complete_registration`

**Description:** Complete registration for new users.

**Authentication:** None required

**Request Body:**
```json
{
  "verification_token": "verification_token_here",
  "role": "consumer",
  "name": "John Doe"
}
```

**Parameters:**
- `verification_token` (string, required): Token from verify_otp
- `role` (string, required): User role - `consumer`, `venue_manager`, or `admin`
- `name` (string, required): User's full name

**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "consumer"
  },
  "next_steps": [
    "setup_password",
    "register_device"
  ]
}
```

**Note:** The JWT token is valid for **90 days** (persistent login). Users will remain logged in for 90 days without needing to re-authenticate.

**Next Steps (Optional):**
- Setup password
- Register device for biometric

---

## Existing User Flow

### 1. Login with Username/Email/Phone & Password

**Endpoint:** `POST /api/v1/auth/login`

**Description:** Login with username, email, or phone and password (if user has set up password). Returns a persistent JWT token valid for 90 days (Instagram-style login).

**Authentication:** None required

**Request Body (using username):**
```json
{
  "user": {
    "username": "johndoe",
    "password": "Password123"
  }
}
```

**Request Body (using email):**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "Password123"
  }
}
```

**Request Body (using phone):**
```json
{
  "user": {
    "phone": "+1234567890",
    "password": "Password123"
  }
}
```

**Parameters:**
- `username` OR `email` OR `phone` (string, required): User identifier (only one is required)
- `password` (string, required): User password

**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

---

### 2. Login with OTP

**Description:** Login flow for existing users using OTP (phone or email). Uses the same endpoints as new user registration, but returns JWT token directly for existing users.

**Flow:**
1. Send OTP (phone or email) → `POST /api/v1/auth/send_otp`
2. Verify OTP → `POST /api/v1/auth/verify_otp` → Get JWT token

**Endpoints:**

#### Send OTP (Phone)
**Endpoint:** `POST /api/v1/auth/send_otp`

**Request Body:**
```json
{
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "is_new_user": false,
  "otp": "123456",
  "expires_in": "5 minutes",
  "max_attempts": 5,
  "requests_remaining": 4
}
```

#### Send OTP (Email)
**Endpoint:** `POST /api/v1/auth/send_otp`

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "is_new_user": false,
  "otp": "123456",
  "expires_in": "5 minutes",
  "max_attempts": 5,
  "requests_remaining": 4
}
```

#### Verify OTP
**Endpoint:** `POST /api/v1/auth/verify_otp`

**Request Body (Phone):**
```json
{
  "phone": "+1234567890",
  "code": "123456"
}
```

**Request Body (Email):**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**Response for EXISTING Users:**
```json
{
  "is_new_user": false,
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe"
  },
  "token": "jwt_token_here"
}
```

**Important Notes:**
- For existing users, `verify_otp` returns JWT token directly (no need for `complete_registration`)
- Token is valid for 90 days (Instagram-style persistent login)
- Use the same `send_otp` and `verify_otp` endpoints as new user flow
- The system automatically detects if user exists and returns appropriate response

---

### 3. Login with Biometric

**Endpoint:** `POST /api/v1/auth/authenticate_biometric`

**Description:** Authenticate using device token (biometric). Returns a persistent JWT token valid for 90 days (Instagram-style login).

**Authentication:** None required

**Requirements:**
- Device must be registered
- Biometric must be enabled

**Request Body:**
```json
{
  "device_token": "device_token_here",
  "device_uuid": "TEST-DEVICE-12345"
}
```

**Parameters:**
- `device_token` (string, required): Token from register_device
- `device_uuid` (string, required): Device identifier

**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Mobile Flow:**
1. User opens app
2. App prompts biometric (Face ID/Fingerprint)
3. On success, retrieve device_token from secure storage
4. Call this endpoint
5. Receive JWT token

---

### 4. Login with PIN

**Endpoint:** `POST /api/v1/auth/authenticate_pin`

**Description:** Authenticate using device token and PIN.

**Authentication:** None required

**Requirements:**
- Device must be registered
- PIN must be enabled for the device

**Request Body:**
```json
{
  "device_token": "device_token_here",
  "device_uuid": "TEST-DEVICE-12345",
  "pin": "1234"
}
```

**Parameters:**
- `device_token` (string, required): Token from register_device
- `device_uuid` (string, required): Device identifier
- `pin` (string, required): PIN code (4-6 digits)

**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Mobile Flow:**
1. User opens app
2. App prompts for PIN entry
3. User enters PIN
4. Retrieve device_token from secure storage
5. Call this endpoint with device_token and PIN
6. Receive JWT token

---

## Optional Setup

### 1. Setup Password

**Endpoint:** `POST /api/v1/auth/setup_password`

**Description:** Setup password after OTP registration (optional).

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "password": "Password123",
  "password_confirmation": "Password123"
}
```

**Password Requirements:**
- Minimum 8 characters
- At least one letter
- At least one number

**Response:**
```json
{
  "message": "Password setup successfully"
}
```

**After Setup:**
User can login with email/password

---

### 2. Register Device for Biometric/PIN

**Endpoint:** `POST /api/v1/auth/register_device`

**Description:** Register device for biometric authentication.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "device_uuid": "TEST-DEVICE-12345",
  "device_name": "John's iPhone 15",
  "device_type": "iPhone15,2",
  "platform": "ios",
  "platform_version": "17.0",
  "app_version": "1.0.0",
  "biometric_enabled": true
}
```

**Parameters:**
- `device_uuid` (string, required): Unique device ID (iOS: identifierForVendor)
- `device_name` (string, required): Human-readable name
- `device_type` (string, required): Device model
- `platform` (string, required): `ios` or `android`
- `platform_version` (string, required): OS version
- `app_version` (string, required): App version
- `biometric_enabled` (boolean, required): Whether biometric is enabled

**Response:**
```json
{
  "device_token": "device_token_here",
  "device": {
    "id": "device_id",
    "device_uuid": "TEST-DEVICE-12345",
    "device_name": "John's iPhone 15"
  }
}
```

**Important:**
- `device_token` is only returned ONCE
- **SAVE THIS TOKEN SECURELY**
- iOS: Store in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Android: Store in EncryptedSharedPreferences

---

### 3. Setup PIN

**Endpoint:** `POST /api/v1/auth/devices/{device_id}/setup_pin`

**Description:** Setup PIN authentication for a device.

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Request Body:**
```json
{
  "pin": "1234",
  "pin_confirmation": "1234"
}
```

**Parameters:**
- `pin` (string, required): PIN code (4-6 digits, digits only)
- `pin_confirmation` (string, required): PIN confirmation (must match)

**PIN Requirements:**
- Must be 4-6 digits
- Must contain only digits (0-9)
- PIN and confirmation must match

**Response:**
```json
{
  "message": "PIN setup successfully",
  "device": {
    "id": "device_id",
    "device_name": "John's iPhone 15",
    "pin_enabled": true
  }
}
```

**After Setup:**
User can login with device token + PIN

---

## Device Management

### 1. List My Devices

**Endpoint:** `GET /api/v1/auth/devices`

**Description:** Get all registered devices for current user.

**Authentication:** Bearer token required

**Request Body (JSON):**
```json
{
  "adults_count": 2,
  "children_count": 1,
  "infants_count": 0,
  "pets_count": 1,
  "payment_method": "card",
  "process_payment": true,
  "pre_order": {
    "order_type": "both",
    "time_window_start": "2026-01-27T19:00:00Z",
    "time_window_end": "2026-01-27T19:30:00Z",
    "special_instructions": "Table near the bar please",
    "allergies": "Severe peanut allergy - no cross contamination",
    "tip_amount": 10.00,
    "items": [
      {
        "menu_item_id": "menu_item_uuid",
        "quantity": 2,
        "special_instructions": "No onions, extra cheese",
        "customizations": { "spice_level": "medium" }
      }
    ]
  }
}
```

**Parameters:**
- `adults_count` (integer, optional): Number of attendees age 18+ (default: 1)
- `children_count` (integer, optional): Number of attendees age 2-17 (default: 0)
- `infants_count` (integer, optional): Number of attendees under 2 (default: 0)
- `pets_count` (integer, optional): Number of pets (default: 0)
- `payment_method` (string, optional): Payment method identifier
- `process_payment` (boolean/string, optional): Set to `false` to create booking without charging now
- `pre_order` (object, optional): Optional food/bar pre-order to attach to the booking
  - `order_type` (string, optional): `food`, `bar`, or `both` (default: both)
  - `table_number` (string, optional): Table identifier (if known)
  - `time_window_start` (string, optional): ISO8601 time window start (must be within event time range)
  - `time_window_end` (string, optional): ISO8601 time window end (must be within event time range)
  - `special_instructions` (string, optional): Order notes
  - `allergies` (string, optional): Allergy info
  - `dietary_restrictions` (string, optional): Dietary restrictions
  - `tip_amount` (decimal, optional): Tip amount
  - `tip_percentage` (decimal, optional): Tip percentage
  - `items` (array, required when pre_order present)
    - `menu_item_id` (uuid, required)
    - `quantity` (integer, optional, default: 1)
    - `special_instructions` (string, optional)
    - `customizations` (object, optional)

**Notes:**
- If the event has age-based pricing, booking price is calculated from the counts above.
- If a count is > 0 and the corresponding price is not set on the event, the request fails.
- If `pre_order` is provided, each `menu_item_id` must belong to the event’s active menu and be available.

**Response:**
```json
{
  "devices": [
    {
      "id": "device_id",
      "device_uuid": "TEST-DEVICE-12345",
      "device_name": "John's iPhone 15",
      "platform": "ios",
      "biometric_enabled": true,
      "pin_enabled": false,
      "last_used_at": "2025-10-08T12:00:00Z"
    }
  ]
}
```

---

### 2. Revoke Device

**Endpoint:** `DELETE /api/v1/auth/devices/{device_id}`

**Description:** Revoke a device (removes access).

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID to revoke

**Response:**
```json
{
  "message": "Device revoked successfully"
}
```

---

### 3. Enable Biometric

**Endpoint:** `PATCH /api/v1/auth/devices/{device_id}/enable_biometric`

**Description:** Enable biometric authentication for a device.

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Response:**
```json
{
  "message": "Biometric enabled successfully"
}
```

---

### 4. Disable Biometric

**Endpoint:** `PATCH /api/v1/auth/devices/{device_id}/disable_biometric`

**Description:** Disable biometric authentication for a device.

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Response:**
```json
{
  "message": "Biometric disabled successfully"
}
```

---

### 5. Setup PIN

**Endpoint:** `POST /api/v1/auth/devices/{device_id}/setup_pin`

**Description:** Setup PIN authentication for a device.

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Request Body:**
```json
{
  "pin": "1234",
  "pin_confirmation": "1234"
}
```

**PIN Requirements:**
- Must be 4-6 digits
- Must contain only digits (0-9)
- PIN and confirmation must match

**Response:**
```json
{
  "message": "PIN setup successfully",
  "device": {
    "id": "device_id",
    "device_name": "John's iPhone 15",
    "pin_enabled": true
  }
}
```

---

### 6. Enable PIN

**Endpoint:** `PATCH /api/v1/auth/devices/{device_id}/enable_pin`

**Description:** Enable PIN authentication for a device (sets PIN if not already set).

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Request Body:**
```json
{
  "pin": "1234"
}
```

**Parameters:**
- `pin` (string, required): PIN code (4-6 digits, digits only)

**Response:**
```json
{
  "message": "PIN authentication enabled",
  "device": {
    "id": "device_id",
    "device_name": "John's iPhone 15",
    "pin_enabled": true
  }
}
```

---

### 7. Disable PIN

**Endpoint:** `PATCH /api/v1/auth/devices/{device_id}/disable_pin`

**Description:** Disable PIN authentication for a device.

**Authentication:** Bearer token required

**Path Parameters:**
- `device_id` (string, required): Device ID

**Response:**
```json
{
  "message": "PIN authentication disabled",
  "device": {
    "id": "device_id",
    "device_name": "John's iPhone 15",
    "pin_enabled": false
  }
}
```

---

## User Information

### 1. Get Current User

**Endpoint:** `GET /api/v1/auth/me`

**Description:** Get current authenticated user's information.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "adults_count": 2,
  "children_count": 1,
  "infants_count": 0,
  "pets_count": 0,
  "payment_method": "card",
  "process_payment": true,
  "pre_order": {
    "order_type": "both",
    "time_window_start": "2026-01-27T19:00:00Z",
    "time_window_end": "2026-01-27T19:30:00Z",
    "special_instructions": "Table near the bar please",
    "allergies": "Severe peanut allergy - no cross contamination",
    "tip_amount": 10.00,
    "items": [
      {
        "menu_item_id": "menu_item_uuid",
        "quantity": 2,
        "special_instructions": "No onions, extra cheese",
        "customizations": { "spice_level": "medium" }
      }
    ]
  }
}
```

**Parameters:**
- `adults_count` (integer, optional): Number of attendees age 18+ (default: 1)
- `children_count` (integer, optional): Number of attendees age 2-17 (default: 0)
- `infants_count` (integer, optional): Number of attendees under 2 (default: 0)
- `pets_count` (integer, optional): Number of pets (default: 0)
- `payment_method` (string, optional): Payment method identifier
- `process_payment` (boolean/string, optional): Set to `false` to create booking without charging now
- `pre_order` (object, optional): Optional food/bar pre-order to attach to the booking
  - `order_type` (string, optional): `food`, `bar`, or `both` (default: both)
  - `time_window_start` (string, optional): ISO8601 time window start (must be within event time range)
  - `time_window_end` (string, optional): ISO8601 time window end (must be within event time range)
  - `special_instructions` (string, optional): Order notes
  - `allergies` (string, optional): Allergy info
  - `dietary_restrictions` (string, optional): Dietary restrictions
  - `tip_amount` (decimal, optional): Tip amount
  - `tip_percentage` (decimal, optional): Tip percentage
  - `items` (array, required when pre_order present)
    - `menu_item_id` (uuid, required)
    - `quantity` (integer, optional, default: 1)
    - `special_instructions` (string, optional)
    - `customizations` (object, optional)

**Response:**
```json
{
  "id": "user_id",
  "email": "user@example.com",
  "phone": "+1234567890",
  "name": "John Doe",
  "role": "consumer",
  "status": "active",
  "preferences": {}
}
```

---

### 2. Logout

**Endpoint:** `POST /api/v1/auth/logout`

**Description:** Logout (client-side token removal).

**Authentication:** Bearer token required

**Request Body (optional):**
```json
{
  "reason": "Unable to attend due to emergency",
  "description": "Family emergency and cannot make it."
}
```

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

**Note:** This is primarily for client-side token removal. The server may also invalidate the token depending on implementation.

---

## Location Services

### 1. Get Current Location

**Endpoint:** `GET /api/v1/location`

**Description:** Fetch the current location snapshot for the authenticated user.

**Authentication:** Bearer token required

**Response:**
```json
{
  "location": {
    "lat": 51.5074,
    "lng": -0.1278,
    "formatted_address": "London, UK",
    "place_id": "ChIJdd4hrwug2EcRmSrV3Vo6llI",
    "source": "device",
    "updated_at": "2025-10-08T12:00:00Z"
  }
}
```

---

### 2. Update Device Location

**Endpoint:** `POST /api/v1/location/device`

**Description:** Submit the latest device-derived coordinates and formatted address.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "location": {
    "lat": 51.5074,
    "lng": -0.1278,
    "formatted_address": "London, UK",
    "place_id": "ChIJdd4hrwug2EcRmSrV3Vo6llI"
  }
}
```

**Parameters:**
- `location.lat` (number, required): Latitude
- `location.lng` (number, required): Longitude
- `location.formatted_address` (string, required): Formatted address
- `location.place_id` (string, optional): Google Places ID

**Response:**
```json
{
  "location": {
    "lat": 51.5074,
    "lng": -0.1278,
    "formatted_address": "London, UK",
    "place_id": "ChIJdd4hrwug2EcRmSrV3Vo6llI",
    "source": "device",
    "updated_at": "2025-10-08T12:00:00Z"
  }
}
```

---

### 3. Update Manual Location

**Endpoint:** `POST /api/v1/location/manual`

**Description:** Override the current location with a manually selected address.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "location": {
    "lat": 40.7128,
    "lng": -74.0060,
    "formatted_address": "New York, NY, USA",
    "place_id": "ChIJOwg_06VPwokRYv534QaPC8g"
  }
}
```

**Response:**
```json
{
  "location": {
    "lat": 40.7128,
    "lng": -74.0060,
    "formatted_address": "New York, NY, USA",
    "place_id": "ChIJOwg_06VPwokRYv534QaPC8g",
    "source": "manual",
    "updated_at": "2025-10-08T12:00:00Z"
  }
}
```

---

### 4. Reset Location

**Endpoint:** `POST /api/v1/location/reset`

**Description:** Clear manual overrides and mark the location as device pending.

**Authentication:** Bearer token required

**Response:**
```json
{
  "message": "Location reset successfully",
  "location": {
    "source": "device_pending",
    "updated_at": "2025-10-08T12:00:00Z"
  }
}
```

---

## Search

### Global Search

**Endpoint:** `GET /api/v1/search`

**Description:** Search across events, venues, and users with a single query. Returns results from all specified types.

**Authentication:** Bearer token required

**Query Parameters:**
- `q` or `query` (string, required): Search query
- `types` (array, optional): Types to search. Can include: `events`, `venues`, `users`. Default: `['events', 'venues']`
- `limit` (integer, optional): Number of results per type (default: 10, max: 50)
- `event_category` (string, optional): Filter events by category
- `event_city` (string, optional): Filter events by venue city
- `event_time_filter` (string, optional): Filter events by time (`upcoming`, `live`)
- `venue_city` (string, optional): Filter venues by city
- `venue_country` (string, optional): Filter venues by country

**Response:**
```json
{
  "data": {
    "query": "networking",
    "total_results": 25,
    "counts": {
      "events": 15,
      "venues": 8,
      "users": 2
    },
    "results": {
      "events": [
        {
          "id": "event_id",
          "type": "event",
          "title": "Networking Mixer",
          "description": "Join us for networking",
          "category": "business",
          "starts_at": "2025-12-15T18:00:00Z",
          "ends_at": "2025-12-15T21:00:00Z",
          "status": "published",
          "is_live": false,
          "is_upcoming": true,
          "bookings_count": 45,
          "likes_count": 23,
          "interests_count": 67,
          "followers_count": 67,
          "user_booked": false,
          "user_liked": true,
          "user_interested": true,
          "venue": {
            "id": "venue_id",
            "name": "The Grand Club",
            "city": "London",
            "country": "UK"
          }
        }
      ],
      "venues": [
        {
          "id": "venue_id",
          "type": "venue",
          "name": "Networking Hub",
          "description": "A premier networking venue",
          "city": "London",
          "country": "UK",
          "address": {
            "full_address": "123 Main Street, London, UK"
          },
          "location": {
            "latitude": 51.5074,
            "longitude": -0.1278
          },
          "rating": {
            "average": 4.5,
            "count": 120
          },
          "likes_count": 45,
          "followers_count": 25,
          "user_liked": false,
          "user_following": false,
          "user_rsvp_status": null,
          "interests_count": 25,
          "rsvp_stats": {
            "yes_count": 20,
            "no_count": 2,
            "maybe_count": 3
          }
        }
      ],
      "users": [
        {
          "id": "user_id",
          "type": "user",
          "name": "John Networking",
          "username": "networkingpro",
          "role": "consumer",
          "followers_count": 150,
          "following_count": 75,
          "is_following": false,
          "is_followed_by": true
        }
      ]
    }
  }
}
```

**Usage Examples:**
- Search all: `GET /api/v1/search?q=networking`
- Search only events: `GET /api/v1/search?q=networking&types[]=events`
- Search events and venues: `GET /api/v1/search?q=networking&types[]=events&types[]=venues`
- Search with filters: `GET /api/v1/search?q=networking&event_category=business&venue_city=London`

**Search Fields:**
- **Events**: Searches in title, description, and category
- **Venues**: Searches in name, description, city, and country
- **Users**: Searches in name and username

---

## Artists

List and view artists (users with artist role) who can perform at events.

### 1. List Artists

**Endpoint:** `GET /api/v1/artists`

**Description:** List all users with artist role.

**Authentication:** Bearer token required

**Query Parameters:**
- `search` (string, optional): Search by name or username
- `category_id` (string, optional): Filter by category UUID
- `sort` (string, optional): Sort order - `name`, `newest`, `popular` (default: `name`)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset (default: 0)

**Response:**
```json
{
  "status": 200,
  "data": {
    "artists": [
      {
        "id": "artist_uuid",
        "name": "John Artist",
        "username": "johnartist",
        "role": "artist",
        "bio": "Professional DJ and music producer",
        "avatar_url": "https://...",
        "profile_picture_url": "https://...",
        "followers_count": 1250,
        "following_count": 180,
        "categories": [
          {"id": "cat_uuid", "name": "Electronic"}
        ],
        "is_following": false,
        "created_at": "2025-01-15T10:00:00Z"
      }
    ],
    "pagination": {
      "total": 150,
      "limit": 20,
      "offset": 0,
      "has_more": true
    }
  }
}
```

---

### 2. Get Artist

**Endpoint:** `GET /api/v1/artists/:id`

**Description:** Get detailed information about a specific artist.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "artist": {
      "id": "artist_uuid",
      "name": "John Artist",
      "username": "johnartist",
      "role": "artist",
      "bio": "Professional DJ and music producer",
      "avatar_url": "https://...",
      "profile_picture_url": "https://...",
      "followers_count": 1250,
      "following_count": 180,
      "categories": [
        {"id": "cat_uuid", "name": "Electronic"}
      ],
      "is_following": false,
      "upcoming_events_count": 5,
      "past_events_count": 42,
      "total_events_count": 47,
      "phone": "+1234567890",
      "email": "artist@example.com",
      "created_at": "2025-01-15T10:00:00Z"
    }
  }
}
```

---

### 3. Get Artist Events

**Endpoint:** `GET /api/v1/artists/:id/events`

**Description:** List all events where this artist is performing.

**Authentication:** Bearer token required

**Query Parameters:**
- `filter` (string, optional): `upcoming` or `past`
- `status` (string, optional): Filter by status - `confirmed`, `pending`, `cancelled`
- `limit` (integer, optional): Number of results (default: 20)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "artist_id": "artist_uuid",
    "artist_name": "John Artist",
    "events": [
      {
        "event_artist_id": "event_artist_uuid",
        "event": {
          "id": "event_uuid",
          "title": "Summer Music Festival",
          "starts_at": "2025-12-20T20:00:00Z",
          "ends_at": "2025-12-21T02:00:00Z",
          "venue": {
            "id": "venue_uuid",
            "name": "The Grand Club"
          }
        },
        "schedule": {
          "scheduled_start_at": "2025-12-20T22:00:00Z",
          "scheduled_end_at": "2025-12-20T23:30:00Z",
          "timezone": "UTC",
          "duration_minutes": 90
        },
        "status": "confirmed",
        "description": "Main stage performance",
        "is_live": false,
        "is_upcoming": true,
        "is_past": false
      }
    ],
    "pagination": {
      "total": 10,
      "limit": 20,
      "offset": 0,
      "has_more": false
    }
  }
}
```

---

### 4. Get Artist Categories

**Endpoint:** `GET /api/v1/artists/:id/categories`

**Description:** Get categories assigned to an artist.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "artist_id": "artist_uuid",
    "artist_name": "John Artist",
    "categories": [
      {"id": "cat_uuid_1", "name": "Electronic"},
      {"id": "cat_uuid_2", "name": "House"}
    ]
  }
}
```

---

## Artist Categories

### 1. List Category Groups

**Endpoint:** `GET /api/v1/categories_groups`

**Description:** Fetch all category groups with their nested categories for onboarding.

**Authentication:** None required

**Response:**
```json
{
  "category_groups": [
    {
      "id": "group_id",
      "name": "Music Genres",
      "categories": [
        {
          "id": "category_id",
          "name": "Hip-Hop",
          "slug": "hip-hop"
        },
        {
          "id": "category_id_2",
          "name": "EDM",
          "slug": "edm"
        }
      ]
    }
  ]
}
```

---

### 2. Get My Categories

**Endpoint:** `GET /api/v1/artist/categories`

**Description:** Retrieve all available categories with a `subscribed` flag indicating whether the authenticated user has subscribed to each category.

**Authentication:** Bearer token required

**Response:**
```json
{
  "categories_groups": [
    {
      "id": "group_id",
      "name": "Music Genres",
      "slug": "music-genres",
      "description": "Musical genres and styles",
      "display_order": 0,
      "categories": [
        {
          "id": "category_id",
          "categories_group_id": "group_id",
          "name": "Hip-Hop",
          "slug": "hip-hop",
          "icon_key": "hip-hop",
          "display_order": 0,
          "subscribed": true
        },
        {
          "id": "category_id_2",
          "categories_group_id": "group_id",
          "name": "EDM",
          "slug": "edm",
          "icon_key": "edm",
          "display_order": 1,
          "subscribed": false
        }
      ]
    }
  ],
  "categories": [
    {
      "id": "category_id",
      "categories_group_id": "group_id",
      "name": "Hip-Hop",
      "slug": "hip-hop",
      "icon_key": "hip-hop",
      "display_order": 0,
      "subscribed": true
    },
    {
      "id": "category_id_2",
      "categories_group_id": "group_id",
      "name": "EDM",
      "slug": "edm",
      "icon_key": "edm",
      "display_order": 1,
      "subscribed": false
    }
  ],
  "subscribed_category_ids": ["category_id"]
}
```

**Response Fields:**
- `categories_groups` (array): All category groups with their nested categories
- `categories` (array): Flat list of all categories with subscribed flag
- `subscribed_category_ids` (array): Array of category IDs the user has subscribed to
- `subscribed` (boolean): Whether the authenticated user has subscribed to this category

---

### 3. Replace My Categories

**Endpoint:** `PUT /api/v1/artist/categories`

**Description:** Replace the entire set of selected categories for the authenticated user.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": [
    "category_id_1",
    "category_id_2"
  ],
  "source": "onboarding"
}
```

**Parameters:**
- `category_ids` (array, required): Array of category IDs
- `source` (string, required): Source indicating where this change comes from. Must be non-blank. Common values: `"onboarding"`, `"profile_edit"`

**Response:**
```json
{
  "categories": [
    {
      "id": "category_id_1",
      "name": "Hip-Hop",
      "slug": "hip-hop"
    },
    {
      "id": "category_id_2",
      "name": "EDM",
      "slug": "edm"
    }
  ]
}
```

---

### 4. Add Categories

**Endpoint:** `POST /api/v1/artist/categories/add`

**Description:** Append additional categories without removing existing selections.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": [
    "category_id_3",
    "category_id_4"
  ],
  "source": "profile_edit"
}
```

**Parameters:**
- `category_ids` (array, required): Array of category IDs to add
- `source` (string, optional): Source of the update (e.g., "profile_edit", "onboarding")

**Response:**
```json
{
  "categories": [
    {
      "id": "category_id_1",
      "name": "Hip-Hop",
      "slug": "hip-hop"
    },
    {
      "id": "category_id_3",
      "name": "Rock",
      "slug": "rock"
    },
    {
      "id": "category_id_4",
      "name": "Jazz",
      "slug": "jazz"
    }
  ]
}
```

---

### 5. Remove Categories

**Endpoint:** `POST /api/v1/artist/categories/remove`

**Description:** Remove one or more categories from the authenticated user's selections.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": [
    "category_id_1"
  ]
}
```

**Parameters:**
- `category_ids` (array, required): Array of category IDs to remove

**Response:**
```json
{
  "categories": [
    {
      "id": "category_id_3",
      "name": "Rock",
      "slug": "rock"
    }
  ]
}
```

---

## Venues

### 1. List Venues

**Endpoint:** `GET /api/v1/venues`

**Description:** List all venues with optional filters.

**Authentication:** Bearer token required

**Query Parameters:**
- `city` (string, optional): Filter by city
- `country` (string, optional): Filter by country
- `search` (string, optional): Search by venue name
- `my_venues` (boolean, optional): Show only current user's venues
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "data": {
    "venues": [
      {
        "id": "venue_id",
        "name": "The Grand Club",
        "description": "A premier nightlife destination",
        "address": {
          "address1": "123 Main Street",
          "city": "London",
          "country": "UK",
          "full_address": "123 Main Street, London, UK"
        },
        "location": {
          "latitude": 51.5074,
          "longitude": -0.1278
        },
        "capacity": 500,
        "rating": {
          "average": 4.5,
          "count": 120
        },
        "vibecheck_rate": 4.3,
        "image_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../venue_image.jpg",
        "likes_count": 45,
        "user_liked": false,
        "user_rsvp_status": null,
        "interests_count": 25,
        "followers_count": 120,
        "user_following": false,
        "rsvp_stats": {
          "yes_count": 20,
          "no_count": 2,
          "maybe_count": 3
        },
        "status": "active"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 50,
      "has_more": true
    }
  }
}
```

**Response Fields:**
- `vibecheck_rate`: Average rating from all published vibe checks for events at this venue (null if no vibe checks exist). Calculated from the `overall_rating` field in vibe checks submitted for events hosted at this venue.
- `image_url`: URL to the venue's image (restaurant or pub picture). Null if no image has been uploaded.

---

### 2. Get Venue

**Endpoint:** `GET /api/v1/venues/:id`

**Description:** Get venue details by ID.

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "venue": {
      "id": "venue_id",
      "name": "The Grand Club",
      "description": "A premier nightlife destination",
      "address": {
        "address1": "123 Main Street",
        "city": "London",
        "country": "UK",
        "full_address": "123 Main Street, London, UK"
      },
      "location": {
        "latitude": 51.5074,
        "longitude": -0.1278
      },
      "capacity": 500,
      "rating": {
        "average": 4.5,
        "count": 120
      },
      "vibecheck_rate": 4.3,
      "image_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../venue_image.jpg",
      "likes_count": 45,
      "user_liked": false,
      "user_rsvp_status": null,
      "interests_count": 25,
      "followers_count": 120,
      "user_following": false,
      "rsvp_stats": {
        "yes_count": 20,
        "no_count": 2,
        "maybe_count": 3
      },
      "status": "active",
      "owner": {
        "id": "user_id",
        "name": "John Doe",
        "email": "john@example.com"
      }
    }
  }
}
```

**Response Fields:**
- `vibecheck_rate`: Average rating from all published vibe checks for events at this venue (null if no vibe checks exist). Calculated from the `overall_rating` field in vibe checks.
- `image_url`: URL to the venue's image (restaurant or pub picture). Null if no image has been uploaded.

---

### 3. Create Venue

**Endpoint:** `POST /api/v1/venues`

**Description:** Create a new venue. Requires venue_manager or admin role.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "venue": {
    "name": "The Grand Club",
    "description": "A premier nightlife destination",
    "address1": "123 Main Street",
    "address2": "Suite 100",
    "city": "London",
    "region": "Greater London",
    "country": "UK",
    "postal_code": "SW1A 1AA",
    "latitude": 51.5074,
    "longitude": -0.1278,
    "capacity": 500,
    "contact_email": "info@grandclub.com",
    "contact_phone": "+442012345678"
  }
}
```

**Response:**
```json
{
  "data": {
    "venue": {
      "id": "venue_id",
      "name": "The Grand Club",
      "status": "active"
    }
  },
  "message": "Venue created successfully"
}
```

---

### 4. Update Venue

**Endpoint:** `PATCH /api/v1/venues/:id`

**Description:** Update venue. Only venue owner or admin can update.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "venue": {
    "name": "The Grand Club Updated",
    "description": "Updated description"
  }
}
```

---

### 5. Delete Venue

**Endpoint:** `DELETE /api/v1/venues/:id`

**Description:** Delete venue. Only venue owner or admin can delete.

**Authentication:** Bearer token required

---

### 5.5. Upload Venue Image

**Endpoint:** `POST /api/v1/venues/:id/upload_image`

**Description:** Upload an image for the venue (restaurant or pub picture). Only venue owner or admin can upload images.

**Authentication:** Bearer token required

**Request:**
- Content-Type: `multipart/form-data`
- Body: Form data with `image` file field

**File Requirements:**
- Format: JPEG, PNG, GIF, or WebP
- Max size: 10MB

**Response:**
```json
{
  "status": 200,
  "data": {
    "venue": {
      "id": "venue_id",
      "name": "The Grand Club",
      "image_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../venue_image.jpg",
      ...
    },
    "image_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../venue_image.jpg"
  },
  "message": "Venue image uploaded successfully"
}
```

**Note:** Images can also be uploaded during venue creation or update by including the `image` field in the request body.

---

### 6. RSVP to Venue

**Endpoint:** `POST /api/v1/venues/:id/rsvp`

**Description:** RSVP to a venue or update existing RSVP. Supports yes, no, maybe responses with guest count and notes. Useful for planning visits or expressing interest in visiting a venue.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "rsvp_status": "yes",
  "guest_count": 2,
  "notes": "Planning to visit this weekend"
}
```

**Parameters:**
- `rsvp_status` (string, optional): RSVP status - `yes`, `no`, or `maybe` (default: `yes`)
- `guest_count` (integer, optional): Number of additional guests (default: 0)
- `notes` (string, optional): Optional notes or comments

**Response:**
```json
{
  "status": 201,
  "message": "RSVP updated successfully",
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "yes",
      "guest_count": 2,
      "total_attendees": 3,
      "notes": "Planning to visit this weekend",
      "responded_at": "2025-11-26T08:00:00Z",
      "created_at": "2025-11-26T08:00:00Z"
    },
    "rsvp_stats": {
      "yes_count": 25,
      "no_count": 3,
      "maybe_count": 8,
      "total_interested": 36
    }
  }
}
```

---

### 7. Update Venue RSVP

**Endpoint:** `POST /api/v1/venues/:id/rsvp`

**Description:** Update your existing RSVP for a venue. Can change status from yes to no/maybe or vice versa.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "rsvp_status": "maybe",
  "guest_count": 0,
  "notes": "Might visit next week"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "RSVP updated successfully",
  "data": {
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "maybe",
      "guest_count": 0,
      "total_attendees": 1,
      "notes": "Might visit next week",
      "responded_at": "2025-11-26T08:00:00Z"
    },
    "rsvp_stats": {
      "yes_count": 24,
      "no_count": 3,
      "maybe_count": 9,
      "total_interested": 36
    }
  }
}
```

---

### 8. Remove Venue RSVP

**Endpoint:** `DELETE /api/v1/venues/:id/rsvp`

**Description:** Remove your RSVP from a venue.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "RSVP removed successfully",
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "rsvp": null,
    "rsvp_stats": {
      "yes_count": 24,
      "no_count": 3,
      "maybe_count": 8,
      "total_interested": 35
    }
  }
}
```

---

### 9. Check Venue RSVP Status

**Endpoint:** `GET /api/v1/venues/:id/rsvp/check`

**Description:** Check your RSVP status for a venue. Returns yes, no, maybe, or null if not RSVP'd.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "yes",
      "guest_count": 2,
      "total_attendees": 3,
      "notes": "Planning to visit this weekend",
      "responded_at": "2025-11-26T08:00:00Z"
    },
    "has_rsvp": true,
    "rsvp_stats": {
      "yes_count": 25,
      "no_count": 3,
      "maybe_count": 8,
      "total_interested": 36
    }
  }
}
```

---

### 10. List Venue RSVPs

**Endpoint:** `GET /api/v1/venues/:id/rsvps`

**Description:** List all RSVPs for a venue. Can filter by RSVP status.

**Authentication:** Bearer token required

**Query Parameters:**
- `rsvp_status` (string, optional): Filter by RSVP status (`yes`, `no`, `maybe`)
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "rsvps": [
      {
        "id": "rsvp_uuid",
        "rsvp_status": "yes",
        "guest_count": 2,
        "total_attendees": 3,
        "notes": "Planning to visit this weekend",
        "user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "responded_at": "2025-11-26T08:00:00Z",
        "created_at": "2025-11-26T08:00:00Z"
      }
    ],
    "rsvp_stats": {
      "yes_count": 25,
      "no_count": 3,
      "maybe_count": 8,
      "total_interested": 36
    },
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 36,
      "has_more": true
    }
  }
}
```

---

### 11. Follow Venue

**Endpoint:** `POST /api/v1/venues/:id/follow`

**Description:** Follow a venue to receive updates and show support. The venue owner will receive a notification when someone follows their venue.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 201,
  "message": "Successfully followed venue",
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "is_following": true,
    "followers_count": 121
  }
}
```

**Error Responses:**
- `400 Bad Request`: You are already following this venue
- `404 Not Found`: Venue not found

---

### 12. Unfollow Venue

**Endpoint:** `DELETE /api/v1/venues/:id/follow`

**Description:** Unfollow a venue to stop receiving updates.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Successfully unfollowed venue",
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "is_following": false,
    "followers_count": 120
  }
}
```

**Error Responses:**
- `400 Bad Request`: You are not following this venue
- `404 Not Found`: Venue not found

---

### 13. Check Venue Follow Status

**Endpoint:** `GET /api/v1/venues/:id/follow/check`

**Description:** Check if the current user is following a venue.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "venue_id": "venue_uuid",
    "venue_name": "The Grand Club",
    "is_following": true,
    "followers_count": 120
  }
}
```

---

### 14. List My Followed Venues

**Endpoint:** `GET /api/v1/venues/my_followed`

**Description:** List all venues that the current user is following.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "data": {
    "venues": [
      {
        "id": "venue_uuid",
        "name": "The Grand Club",
        "description": "A premier nightlife destination",
        "address": {
          "address1": "123 Main Street",
          "city": "London",
          "country": "UK",
          "full_address": "123 Main Street, London, UK"
        },
        "location": {
          "latitude": 51.5074,
          "longitude": -0.1278
        },
        "capacity": 500,
        "rating": {
          "average": 4.5,
          "count": 120
        },
        "likes_count": 45,
        "user_liked": false,
        "followers_count": 120,
        "user_following": true,
        "status": "active",
        "owner": {
          "id": "user_id",
          "name": "John Doe",
          "email": "john@example.com"
        },
        "created_at": "2025-11-01T10:00:00Z",
        "updated_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 5,
      "has_more": false
    }
  }
}
```

**Notes:**
- Only returns active venues
- Results are ordered by creation date (newest first)
- Each venue includes full venue details with following status

---

### 15. Venue PR (Public Relations)

Venues can have **one master PR** and **multiple junior PRs**. Roles: `master_pr` or `junior_pr`. Only the venue owner or admin can assign or stop a PR partnership. The same user cannot have more than one active partnership with the same venue.

#### 15.1 Get Venue PR

**Endpoint:** `GET /api/v1/venues/:id/pr`

**Description:** Get the current PRs for a venue: one optional master and a list of juniors.

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "master_pr": {
      "id": "partnership_uuid",
      "user": {
        "id": "user_uuid",
        "username": "pr_username",
        "name": "PR Name",
        "role": "venue_manager",
        "avatar_url": "https://..."
      },
      "role": "master_pr",
      "status": "active",
      "rating": null,
      "created_at": "2026-02-05T10:00:00Z",
      "ended_at": null
    },
    "junior_prs": [
      {
        "id": "partnership_uuid_2",
        "user": { "id": "...", "username": "...", "name": "...", "role": "...", "avatar_url": "..." },
        "role": "junior_pr",
        "status": "active",
        "rating": null,
        "created_at": "2026-02-05T10:00:00Z",
        "ended_at": null
      }
    ],
    "pr_venues": []
  }
}
```

When no PRs are assigned, `master_pr` and `junior_prs` are `null` and `[]` respectively.

---

#### 15.2 Assign PR to Venue

**Endpoint:** `POST /api/v1/venues/:id/pr`

**Description:** Assign a user as PR for the venue. Only venue owner or admin. The venue can have only one active PR; stop the current partnership first if changing.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "user_id": "user_uuid",
  "role": "master_pr"
}
```

**Parameters:**
- `user_id` (string, required): ID of the user to assign as PR
- `role` (string, optional): `master_pr` or `junior_pr` (default: `junior_pr`)

**Behaviour:** One master per venue; assigning a new master ends the previous master. Multiple juniors allowed. The same user cannot be added twice (as master or junior) for the same venue.

**Response:** `201 Created` with `data.pr` (same shape as one entry in Get Venue PR).

**Errors:**
- `422`: Venue already has an active master PR when adding a second master (or) this user is already an active PR for this venue
- `404`: PR user not found

---

#### 15.3 Stop Venue PR Partnership

**Endpoint:** `POST /api/v1/venues/:id/pr/stop_partnership`

**Description:** End a specific PR partnership for the venue. Only venue owner or admin. Sets that partnership's status to `ended` and records `ended_at`.

**Authentication:** Bearer token required

**Request Body (optional):**
```json
{
  "partnership_id": "partnership_uuid"
}
```
- `partnership_id` (string, optional): ID of the partnership to end (from Get Venue PR `master_pr.id` or `junior_prs[].id`). If omitted, the current **master** PR is ended (legacy behaviour).

**Response:** Returns updated PR state after removal:
```json
{
  "data": {
    "master_pr": { ... } or null,
    "junior_prs": [ ... ]
  },
  "message": "Partnership ended successfully"
}
```

**Errors:** `422` if partnership not found or not active for this venue.

---

#### 15.4 Search PR Users

**Endpoint:** `GET /api/v1/venue_pr/search`

**Description:** Search users by username, name, or email to assign as PR (e.g. for "Change PR" / "Enter PR name").

**Authentication:** Bearer token required

**Query Parameters:**
- `q` (string, required): Search query (minimum 2 characters)

**Response:**
```json
{
  "data": {
    "users": [
      {
        "id": "user_uuid",
        "username": "Username22334",
        "name": "PR Name",
        "role": "venue_manager",
        "avatar_url": "https://..."
      }
    ]
  }
}
```

---

#### 15.5 My PR Venues

**Endpoint:** `GET /api/v1/users/me/pr_venues`

**Description:** List venues where the current user is the assigned PR ("My PR" screen).

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "pr_venues": [
      {
        "id": "partnership_uuid",
        "venue": {
          "id": "venue_uuid",
          "name": "Venue Name",
          "city": "London",
          "country": "UK",
          "image_url": "https://..."
        },
        "role": "master_pr",
        "status": "active",
        "created_at": "2026-02-05T10:00:00Z"
      }
    ]
  }
}
```

---

#### 15.6 Get User's PR Venues

**Endpoint:** `GET /api/v1/users/:user_id/pr_venues`

**Description:** List venues associated with a given user as PR (for "PR's Venues and Artists" view).

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "pr": {
      "id": "user_uuid",
      "username": "pr_username",
      "name": "PR Name",
      "role": "venue_manager",
      "avatar_url": "https://..."
    },
    "pr_venues": [
      {
        "id": "partnership_uuid",
        "venue": { "id": "venue_uuid", "name": "Venue Name", "city": "London", "country": "UK", "image_url": null },
        "role": "junior_pr",
        "status": "active",
        "created_at": "2026-02-05T10:00:00Z"
      }
    ]
  }
}
```

---

## Venue Menus

Venue menus allow venues to manage their food and bar offerings. Menus can have multiple categories, and each category can contain multiple items.

### 1. List Venue Menus

**Endpoint:** `GET /api/v1/venues/:venue_id/menus`

**Description:** List all active menus for a venue. Can filter by menu type.

**Authentication:** Bearer token optional (required for creating/updating)

**Query Parameters:**
- `type` (string, optional): Filter by menu type (`food`, `bar`, `both`)

**Response:**
```json
{
  "status": 200,
  "data": {
    "venue": {
      "id": "venue_uuid",
      "name": "The Grand Club"
    },
    "menus": [
      {
        "id": "menu_uuid",
        "venue_id": "venue_uuid",
        "name": "Main Menu",
        "menu_type": "both",
        "description": "Our complete food and beverage menu",
        "is_active": true,
        "available_from": null,
        "available_until": null,
        "available_now": true,
        "categories": [
          {
            "id": "category_uuid",
            "venue_menu_id": "menu_uuid",
            "name": "Appetizers",
            "category_type": "appetizer",
            "description": "Start your meal with our delicious appetizers",
            "display_order": 0,
            "is_active": true,
            "items": [
              {
                "id": "item_uuid",
                "venue_menu_category_id": "category_uuid",
                "name": "Caesar Salad",
                "description": "Fresh romaine lettuce with caesar dressing",
                "price": 12.99,
                "currency": "USD",
                "item_type": "food",
                "image_url": null,
                "is_available": true,
                "dietary_info": {
                  "is_vegetarian": false,
                  "is_vegan": false,
                  "is_gluten_free": false,
                  "contains_alcohol": false
                },
                "allergens": ["dairy", "gluten"],
                "ingredients": "Romaine lettuce, caesar dressing, parmesan, croutons",
                "preparation_time_minutes": 10,
                "display_order": 0,
                "created_at": "2025-12-01T10:00:00Z",
                "updated_at": "2025-12-01T10:00:00Z"
              }
            ],
            "created_at": "2025-12-01T10:00:00Z",
            "updated_at": "2025-12-01T10:00:00Z"
          }
        ],
        "created_at": "2025-12-01T10:00:00Z",
        "updated_at": "2025-12-01T10:00:00Z"
      }
    ]
  }
}
```

---

### 2. Get Venue Menu

**Endpoint:** `GET /api/v1/venues/:venue_id/menus/:id`

**Description:** Get detailed information about a specific menu including all categories and items.

**Authentication:** Bearer token optional

**Response:** Same structure as list menus, but returns a single menu object.

---

### 2c. Get Venue Menu Category

**Endpoint:** `GET /api/v1/venues/:venue_id/menus/:menu_id/categories/:id`

---

### 2d. Get Venue Menu Item

**Endpoint:** `GET /api/v1/venues/:venue_id/menus/:menu_id/items/:id`

---

### 2e. Upload Venue Menu Image

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/image`

**Body:** multipart `image`

---

### 2f. Remove Venue Menu Image

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:menu_id/image`

---

### 2g. Upload Venue Menu Category Image

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/categories/:id/image`

**Body:** multipart `image`

---

### 2h. Remove Venue Menu Category Image

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:menu_id/categories/:id/image`

---

### 2i. Upload Venue Menu Item Image

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/items/:id/image`

**Body:** multipart `image`

---

### 2j. Remove Venue Menu Item Image

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:menu_id/items/:id/image`

---

### 3. Create Venue Menu

**Endpoint:** `POST /api/v1/venues/:venue_id/menus`

**Description:** Create a new menu for a venue. Only venue owners and admins can create menus.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "menu": {
    "name": "Main Menu",
    "menu_type": "both",
    "description": "Our complete food and beverage menu",
    "is_active": true,
    "available_from": "2025-12-01T00:00:00Z",
    "available_until": "2026-12-31T23:59:59Z"
  }
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus menu fields as `menu[name]`, `menu[menu_type]`, `menu[description]`, `menu[is_active]`, `menu[available_from]`, `menu[available_until]`.

**Parameters:**
- `name` (string, required): Menu name
- `menu_type` (string, required): Menu type - `food`, `bar`, or `both`
- `description` (text, optional): Menu description
- `is_active` (boolean, optional): Whether menu is active (default: true)
- `available_from` (datetime, optional): When menu becomes available
- `available_until` (datetime, optional): When menu expires

**Response:**
```json
{
  "status": 201,
  "message": "Venue menu created successfully",
  "data": {
    "menu": {
      "id": "menu_uuid",
      "venue_id": "venue_uuid",
      "name": "Main Menu",
      "menu_type": "both",
      "description": "Our complete food and beverage menu",
      "is_active": true,
      "available_from": "2025-12-01T00:00:00Z",
      "available_until": "2026-12-31T23:59:59Z",
      "available_now": true,
      "categories": [],
      "created_at": "2025-12-01T10:00:00Z",
      "updated_at": "2025-12-01T10:00:00Z"
    }
  }
}
```

---

### 4. Update Venue Menu

**Endpoint:** `PATCH /api/v1/venues/:venue_id/menus/:id`

**Description:** Update an existing menu. Only venue owners and admins can update menus.

**Authentication:** Bearer token required

**Request Body:** Same as create menu, all fields optional.

**Image Upload (optional):** Use multipart/form-data with `image` plus menu fields as `menu[...]`.

---

### 5. Delete Venue Menu

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:id`

**Description:** Delete a menu. Only venue owners and admins can delete menus. This will also delete all associated categories and items.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Venue menu deleted successfully"
}
```

---

### 6. Create Menu Category

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/categories`

**Description:** Create a new category within a menu. Categories help organize menu items.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category": {
    "name": "Appetizers",
    "category_type": "appetizer",
    "description": "Start your meal with our delicious appetizers",
    "display_order": 0,
    "is_active": true
  }
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus category fields as `category[name]`, `category[category_type]`, `category[description]`, `category[display_order]`, `category[is_active]`.

**Parameters:**
- `name` (string, required): Category name
- `category_type` (string, optional): Category type - `food`, `bar`, `drinks`, `dessert`, `appetizer`, `main`, `other`
- `description` (text, optional): Category description
- `display_order` (integer, optional): Display order (default: 0)
- `is_active` (boolean, optional): Whether category is active (default: true)

**Response:**
```json
{
  "status": 201,
  "message": "Menu category created successfully",
  "data": {
    "category": {
      "id": "category_uuid",
      "venue_menu_id": "menu_uuid",
      "name": "Appetizers",
      "category_type": "appetizer",
      "description": "Start your meal with our delicious appetizers",
      "display_order": 0,
      "is_active": true,
      "items": [],
      "created_at": "2025-12-01T10:00:00Z",
      "updated_at": "2025-12-01T10:00:00Z"
    }
  }
}
```

---

### 7. Update Menu Category

**Endpoint:** `PATCH /api/v1/venues/:venue_id/menus/:menu_id/categories/:id`

**Description:** Update an existing category.

**Authentication:** Bearer token required

**Request Body:** Same as create category, all fields optional.

**Image Upload (optional):** Use multipart/form-data with `image` plus category fields as `category[...]`.

---

### 7b. Reorder Menu Categories

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/categories/reorder`

**Description:** Reorder categories by updating `display_order`.

**Request Body:**
```json
{
  "category_ids": ["cat_uuid_1", "cat_uuid_2", "cat_uuid_3"]
}
```

---

### 8. Delete Menu Category

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:menu_id/categories/:id`

**Description:** Delete a category. This will also delete all items in the category.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Menu category deleted successfully"
}
```

---

### 9. Create Menu Item

**Endpoint:** `POST /api/v1/venues/:venue_id/menus/:menu_id/items`

**Description:** Create a new menu item within a category.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "item": {
    "menu_category_id": "category_uuid",
    "name": "Caesar Salad",
    "description": "Fresh romaine lettuce with caesar dressing",
    "price": 12.99,
    "currency": "USD",
    "item_type": "food",
    "image_url": "https://example.com/images/caesar-salad.jpg",
    "is_available": true,
    "is_vegetarian": false,
    "is_vegan": false,
    "is_gluten_free": false,
    "contains_alcohol": false,
    "allergens": ["dairy", "gluten"],
    "ingredients": "Romaine lettuce, caesar dressing, parmesan, croutons",
    "preparation_time_minutes": 10,
    "display_order": 0
  }
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus item fields as `item[menu_category_id]`, `item[name]`, `item[description]`, `item[price]`, `item[currency]`, `item[item_type]`, `item[is_available]`, etc.

**Parameters:**
- `menu_category_id` (uuid, required): ID of the category this item belongs to
- `name` (string, required): Item name
- `description` (text, optional): Item description
- `price` (decimal, required): Item price (must be >= 0)
- `currency` (string, optional): Currency code (default: USD)
- `item_type` (string, optional): Item type - `food`, `drink`, `appetizer`, `main`, `dessert`, `cocktail`, `beer`, `wine`, `non_alcoholic`
- `image_url` (string, optional): URL to item image
- `is_available` (boolean, optional): Whether item is available (default: true)
- `is_vegetarian` (boolean, optional): Whether item is vegetarian
- `is_vegan` (boolean, optional): Whether item is vegan
- `is_gluten_free` (boolean, optional): Whether item is gluten-free
- `contains_alcohol` (boolean, optional): Whether item contains alcohol
- `allergens` (array, optional): List of allergens
- `ingredients` (text, optional): Ingredients list
- `preparation_time_minutes` (integer, optional): Estimated preparation time
- `display_order` (integer, optional): Display order (default: 0)

**Response:**
```json
{
  "status": 201,
  "message": "Menu item created successfully",
  "data": {
    "item": {
      "id": "item_uuid",
      "venue_menu_category_id": "category_uuid",
      "name": "Caesar Salad",
      "description": "Fresh romaine lettuce with caesar dressing",
      "price": 12.99,
      "currency": "USD",
      "item_type": "food",
      "image_url": "https://example.com/images/caesar-salad.jpg",
      "is_available": true,
      "dietary_info": {
        "is_vegetarian": false,
        "is_vegan": false,
        "is_gluten_free": false,
        "contains_alcohol": false
      },
      "allergens": ["dairy", "gluten"],
      "ingredients": "Romaine lettuce, caesar dressing, parmesan, croutons",
      "preparation_time_minutes": 10,
      "display_order": 0,
      "created_at": "2025-12-01T10:00:00Z",
      "updated_at": "2025-12-01T10:00:00Z"
    }
  }
}
```

---

### 10. Update Menu Item

**Endpoint:** `PATCH /api/v1/venues/:venue_id/menus/:menu_id/items/:id`

**Description:** Update an existing menu item.

**Authentication:** Bearer token required

**Request Body:** Same as create item, all fields optional.

**Image Upload (optional):** Use multipart/form-data with `image` plus item fields as `item[...]`.

---

### 11. Delete Menu Item

**Endpoint:** `DELETE /api/v1/venues/:venue_id/menus/:menu_id/items/:id`

**Description:** Delete a menu item.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Menu item deleted successfully"
}
```

---

## Venue Ratings

### 1. List Venue Ratings

**Endpoint:** `GET /api/v1/venues/:venue_id/ratings`

**Description:** List all approved ratings for a venue.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "data": {
    "ratings": [
      {
        "id": "rating_id",
        "rating": 5,
        "comment": "Amazing venue!",
        "user": {
          "id": "user_id",
          "name": "John Doe"
        },
        "published_at": "2025-10-08T12:00:00Z"
      }
    ],
    "summary": {
      "average_rating": 4.5,
      "total_ratings": 120
    }
  }
}
```

---

### 2. Get My Venue Rating

**Endpoint:** `GET /api/v1/venues/:venue_id/ratings/my_rating`

**Description:** Get current user's rating for a venue.

**Authentication:** Bearer token required

---

### 3. Create Venue Rating

**Endpoint:** `POST /api/v1/venues/:venue_id/ratings`

**Description:** Rate a venue (1-5 stars). One rating per user per venue.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "rating": {
    "rating": 5,
    "comment": "Amazing venue with great atmosphere!"
  }
}
```

**Parameters:**
- `rating` (integer, required): Rating from 1 to 5
- `comment` (string, optional): Review comment

---

### 4. Update Venue Rating

**Endpoint:** `PATCH /api/v1/venues/:venue_id/ratings/:id`

**Description:** Update your rating for a venue.

**Authentication:** Bearer token required

---

### 5. Delete Venue Rating

**Endpoint:** `DELETE /api/v1/venues/:venue_id/ratings/:id`

**Description:** Delete your rating for a venue.

**Authentication:** Bearer token required

---

## Events

### 1. List Events

**Endpoint:** `GET /api/v1/events`

**Description:** List events with comprehensive filtering options including distance, date/time, and category filters.

**Authentication:** Bearer token required

**Query Parameters:**

#### Distance Filtering
- `lat` (float, required with `lng`): Latitude for distance calculation
- `lng` (float, required with `lat`): Longitude for distance calculation
- `min_distance` (float, optional): Minimum distance in kilometers
- `max_distance` (float, optional): Maximum distance in kilometers

**Note:** When `lat` and `lng` are provided:
- Results include `distance_km` field in each event
- Results are automatically sorted by distance (nearest first)
- Uses Haversine formula to calculate distance from event/venue location

**Example:** `?lat=40.7128&lng=-74.0060&max_distance=10` (events within 10km of New York)

#### Date & Time Filtering
- `start_date` (datetime, optional): Filter events starting on or after this date/time (ISO 8601)
- `end_date` (datetime, optional): Filter events ending on or before this date/time (ISO 8601)
- `date_from` (datetime, optional): Filter events that occur from this date (must be used with `date_to`)
- `date_to` (datetime, optional): Filter events that occur until this date (must be used with `date_from`)
- `time_from` (integer, optional): Filter by start hour (0-23, e.g., 18 for 6 PM)
- `time_to` (integer, optional): Filter by end hour (0-23, e.g., 23 for 11 PM)
- `time_filter` (string, optional): Predefined time filters
  - `upcoming`: Events starting in the future
  - `past`: Events that have ended
  - `live`: Events currently happening

**Examples:**
- `?date_from=2025-01-01T00:00:00Z&date_to=2025-01-31T23:59:59Z` (events in January 2025)
- `?time_from=18&time_to=23` (events starting between 6 PM and 11 PM)

#### Category Filtering
- `category` (string or array, optional): Legacy single category filter (business, social, activities, music, etc.)
- `category_ids[]` (array, optional): Filter by category IDs (new multiple categories system)
- `category_slugs[]` (array, optional): Filter by category slugs (new multiple categories system)

**Examples:**
- `?category=business`
- `?category_ids[]=uuid1&category_ids[]=uuid2`
- `?category_slugs[]=music&category_slugs[]=nightlife`

#### Other Filters
- `venue_id` (string, optional): Filter by venue
- `status` (string or array, optional): Filter by status (draft, published, canceled, completed). Can pass multiple: `?status[]=published&status[]=draft`
- `owner` (string, optional): Filter by ownership (`me`, `not_me`)
- `my_events` (boolean, optional): Alias for owner filter (`true` = me, `false` = not me)
- `search` (string, optional): Search by title or description
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Ownership Examples:**
- `?owner=me` (events owned by current user)
- `?owner=not_me` (events not owned by current user)
- `?my_events=true` (events owned by current user)

**Response:**
```json
{
  "status": 200,
  "data": {
    "events": [
      {
        "id": "event_id",
        "name": "Networking Mixer",
        "title": "Networking Mixer",
        "description": "Join us for networking",
        "address": "123 Main Street, Suite 100, London, Greater London, SW1A 1AA, UK",
        "start_time": "2025-12-15T18:00:00Z",
        "end_time": "2025-12-15T21:00:00Z",
        "status": "published",
        "category": "business",
        "categories": [
          {
            "id": "category_uuid",
            "name": "Business",
            "slug": "business",
            "source": "manual"
          }
        ],
        "price": 50.00,
        "currency": "USD",
        "is_free": false,
        "visibility": "public",
        "distance_km": 5.23,
        "venue": {
          "id": "venue_id",
          "name": "The Grand Club"
        },
        "posted_by": {
          "id": "user_id",
          "name": "John Doe",
          "username": "johndoe"
        },
        "likes_count": 23,
        "user_liked": true,
        "user_interested": false,
        "user_booked": false,
        "user_rsvp_status": null,
        "user_rsvp_yes_count": 45,
        "user_rsvp_no_count": 5,
        "user_rsvp_maybe_count": 17,
        "user_rsvp_count": 67,
        "user_reports_count": 0,
        "user_reported": false,
        "rating": 4.5,
        "ratings_count": 45,
        "age_restriction": 21,
        "smoking": "2 zones",
        "is_boosted": false,
        "created_at": "2025-11-20T10:00:00Z",
        "updated_at": "2025-11-20T10:00:00Z"
      }
    ],
    "filters_applied": {
      "location": {
        "latitude": 40.7128,
        "longitude": -74.0060
      },
      "distance": {
        "max_km": 10
      },
      "date_range": {
        "from": "2025-01-01T00:00:00Z",
        "to": "2025-01-31T23:59:59Z"
      },
      "time_range": {
        "from": 18,
        "to": 23
      },
      "category_ids": ["category_uuid_1", "category_uuid_2"]
    },
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 50,
      "has_more": true
    }
  }
}
```

**Response Fields:**
- `name` / `title`: Event name
- `description`: Event description
- `address`: Full address (event address or venue address)
- `distance_km`: Distance in kilometers from provided lat/lng (only included when location filtering used)
- `photos`: Array of photo URLs (if any)
- `photos_count`: Number of photos
- `has_photos`: Boolean indicating if event has photos
- `category`: Legacy single category
- `categories`: Array of categories (new multiple categories system)
- `venue.name`: Venue name
- `posted_by`: User who posted the event (venue owner)
  - `id`: User ID
  - `name`: User name
  - `username`: Username
- `likes_count`: Number of users who liked this event
- `user_liked`: Whether the current authenticated user liked this event (boolean)
- `user_interested`: Whether the current authenticated user is interested in this event (boolean)
- `user_booked`: Whether the current authenticated user has booked this event (boolean)
- `user_rsvp_status`: Current user's RSVP status - `yes`, `no`, `maybe`, or `null` if not RSVP'd
- `user_rsvp_yes_count`: Count of users who RSVP'd "yes" (attending)
- `user_rsvp_no_count`: Count of users who RSVP'd "no" (not attending)
- `user_rsvp_maybe_count`: Count of users who RSVP'd "maybe" (maybe attending)
- `user_rsvp_count`: Total count of all RSVPs (yes + no + maybe)
- `user_reports_count`: Number of reports submitted for this event
- `user_reported`: Whether the current authenticated user reported this event (boolean)
- `rating`: Average rating (from ratings or vibe_checks)
- `ratings_count`: Total number of ratings
- `age_restriction`: Minimum age requirement (0-99)
- `smoking`: Smoking policy - `yes`, `no`, `2 zones`, or `private zone`
- `is_boosted`: Whether event has an active boost
- `filters_applied`: Object showing which filters were applied to the query

**Note:** User-specific fields (`user_liked`, `user_interested`, `user_booked`, `user_rsvp_status`, `user_reported`) are only included when the request is authenticated. For unauthenticated requests, these fields will be `null` or `false`.

**Example Requests:**

```bash
# Filter by distance (within 10km)
GET /api/v1/events?lat=40.7128&lng=-74.0060&max_distance=10

# Filter by distance range (5km to 20km)
GET /api/v1/events?lat=40.7128&lng=-74.0060&min_distance=5&max_distance=20

# Filter by date range
GET /api/v1/events?date_from=2025-01-01T00:00:00Z&date_to=2025-01-31T23:59:59Z

# Filter by time of day (events starting between 6 PM and 11 PM)
GET /api/v1/events?time_from=18&time_to=23

# Filter by category IDs
GET /api/v1/events?category_ids[]=uuid1&category_ids[]=uuid2

# Combined filters
GET /api/v1/events?lat=40.7128&lng=-74.0060&max_distance=25&date_from=2025-01-01&category_ids[]=uuid1&time_from=18
```

---

### 2. Get Event Categories

**Endpoint:** `GET /api/v1/events/categories`

**Description:** Get list of available event categories.

**Authentication:** None required

**Response:**
```json
{
  "status": 200,
  "data": {
    "categories": [
      "business",
      "social",
      "activities",
      "music",
      "nightlife",
      "sports",
      "arts",
      "food",
      "education",
      "networking",
      "conference",
      "workshop",
      "festival",
      "concert",
      "party",
      "meetup",
      "exhibition",
      "other"
    ],
    "total_count": 18
  }
}
```

---

### 2a. Check Event Category

**Endpoint:** `GET /api/v1/events/:id/category/check`

**Description:** Check if an event belongs to a specific category.

**Authentication:** Bearer token required

**Query Parameters:**
- `category` (string, required): Category name to check

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Summer Music Festival",
    "event_category": "music",
    "check_category": "music",
    "belongs_to_category": true,
    "valid_category": true,
    "all_categories": [
      "business",
      "social",
      "activities",
      "music",
      "nightlife",
      "sports",
      "arts",
      "food",
      "education",
      "networking",
      "conference",
      "workshop",
      "festival",
      "concert",
      "party",
      "meetup",
      "exhibition",
      "other"
    ]
  }
}
```

---

### 2b. Get Events by Category

**Endpoint:** `GET /api/v1/events/categories/:category/events`

**Description:** Get all events in a specific category with filtering options.

**Authentication:** Bearer token required

**Query Parameters:**
- All standard event filtering parameters are supported:
  - `status` (string or array): Filter by status
  - `time_filter` (string): Filter by time (upcoming, past, live, today, this_week, this_month)
  - `city` (string): Filter by city
  - `country` (string): Filter by country
  - `start_date` (datetime): Filter events starting from this date
  - `end_date` (datetime): Filter events ending before this date
  - `max_age_restriction` (integer): Maximum age restriction
  - `search` (string): Search by title or description
  - `sort_by` (string): Sort field (starts_at, created_at, title, bookings_count, likes_count, interests_count)
  - `sort_order` (string): Sort order (asc, desc)
  - `limit` (integer): Number of results (default: 20, max: 100)
  - `offset` (integer): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "category": "music",
    "events": [
      {
        "id": "event_uuid",
        "title": "Summer Music Festival",
        "category": "music",
        "starts_at": "2025-12-01T18:00:00Z",
        "status": "published"
      }
    ],
    "total_count": 25,
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 25,
      "has_more": true
    }
  }
}
```

---

### 2c. Filter Events by Category (in List Events)

**Endpoint:** `GET /api/v1/events`

**Description:** List events with category filtering. You can filter by one or multiple categories.

**Authentication:** Bearer token required

**Query Parameters:**
- `category` (string or array): Filter by category. Can pass multiple:
  - Single: `?category=music`
  - Multiple: `?category[]=music&category[]=festival&category[]=concert`

**Example Requests:**
- Get all music events: `GET /api/v1/events?category=music`
- Get music and festival events: `GET /api/v1/events?category[]=music&category[]=festival`
- Get music events in London: `GET /api/v1/events?category=music&city=London`
- Get upcoming music events: `GET /api/v1/events?category=music&time_filter=upcoming`

**Response:**
```json
{
  "data": {
    "categories": [
      "business",
      "social",
      "activities",
      "music",
      "nightlife",
      "sports",
      "arts",
      "food",
      "education",
      "networking",
      "conference",
      "workshop",
      "festival",
      "concert",
      "party",
      "meetup",
      "exhibition",
      "other"
    ]
  }
}
```

---

### 3. Get Venue Events

**Endpoint:** `GET /api/v1/venues/:venue_id/events`

**Description:** List all events for a specific venue.

**Authentication:** Bearer token required

**Query Parameters:**
- `status` (string, optional): Filter by status
- `category` (string, optional): Filter by category
- `time_filter` (string, optional): upcoming, past, live

---

### 3a. Get last used address (event creation)

**Endpoint:** `GET /api/v1/venues/:venue_id/events/last_address`

**Description:** Returns address fields to pre-fill when creating a new event for this venue. If the venue has at least one event with any stored location override (address lines, city, region, postal code, country, or coordinates), the response uses the **most recently updated** such event. Otherwise it returns the **venue’s default** address from the venue profile.

**Authentication:** Bearer token required

**Authorization:** Same as create event — `venue_manager` or `admin` only.

**Response (`data`):**
- `source`: `last_event` | `venue_default`
- `event_id`: UUID of the event used when `source` is `last_event`, otherwise `null`
- `address`: object with `address1`, `address2`, `city`, `region`, `postal_code`, `country`, `latitude`, `longitude`, `full_address` (same shape as optional override fields on create/update event)

**Example:**
```json
{
  "data": {
    "source": "last_event",
    "event_id": "uuid-of-prior-event",
    "address": {
      "address1": "123 Side Street",
      "address2": null,
      "city": "London",
      "region": null,
      "postal_code": "SW1A 1AA",
      "country": "UK",
      "latitude": 51.5014,
      "longitude": -0.1419,
      "full_address": "123 Side Street, London, SW1A 1AA, UK"
    }
  }
}
```

---

### 4. Get Event

**Endpoint:** `GET /api/v1/events/:id`

**Description:** Get detailed event information including full venue details, booking status, and optional attendee list.

**Authentication:** Bearer token required

**Query Parameters:**
- `include_attendees` (boolean, optional): Include recent attendees list (default: false)
- `attendees_limit` (integer, optional): Number of attendees to include (default: 10, max: 50)

**Response:**
```json
{
  "data": {
    "event": {
      "id": "event_id",
      "name": "Networking Mixer",
      "title": "Networking Mixer",
      "description": "Join us for an evening of networking and drinks",
      "address": "456 Event Street, Outdoor Area, New York, NY, 10001, USA",
      "start_date_time": "2025-12-15T18:00:00Z",
      "end_date_time": "2025-12-15T21:00:00Z",
      "rsvp_minimum_time": 24,
      "artists": [
        {
          "id": "event_artist_id",
          "artist_id": "artist_id",
          "name": "DJ John",
          "username": "djjohn",
          "time": {
            "scheduled_start_at": "2025-12-15T19:00:00Z",
            "scheduled_end_at": "2025-12-15T20:30:00Z",
            "timezone": "America/New_York"
          },
          "status": "confirmed"
        }
      ],
      "likes_count": 23,
      "user_liked": true,
      "user_interested": true,
      "user_booked": false,
      "user_rsvp_status": "yes",
      "user_rsvp_yes_count": 45,
      "user_rsvp_no_count": 5,
      "user_rsvp_maybe_count": 17,
      "user_rsvp_count": 67,
      "user_reports_count": 0,
      "user_reported": false,
      "joined_count": 67,
      "bookings_count": 45,
      "interests_count": 67,
      "category": "business",
      "status": "published",
      "visibility": "public",
      "price": 25.00,
      "currency": "USD",
      "is_free": false,
      "photos": [
        "https://example.com/images/event1.jpg",
        "https://example.com/images/event2.jpg"
      ],
      "photos_count": 2,
      "has_photos": true,
      "dress_code": "Smart casual. No sportswear or flip-flops.",
      "age_restriction": 21,
      "smoking": "2 zones",
      "custom_categories": [
        {
          "id": "custom_category_uuid",
          "event_id": "event_uuid",
          "name": "VIP Access",
          "description": "VIP section with premium seating",
          "created_at": "2025-12-18T10:00:00Z",
          "updated_at": "2025-12-18T10:00:00Z"
        }
      ],
      "cancellation_policy_info": "Cancellations allowed up to 24 hours before event",
      "cancellation_policy_enabled": true,
      "cancellation_deadline_hours": 24,
      "cancellation_fee_percentage": 10.0,
      "venue": {
        "id": "venue_id",
        "name": "The Grand Club"
      },
      "posted_by": {
        "id": "user_id",
        "name": "John Doe",
        "username": "johndoe"
      },
      "rating": 4.5,
      "ratings_count": 45,
      "created_at": "2025-10-15T10:00:00Z",
      "updated_at": "2025-11-01T12:00:00Z"
    }
  }
}
```

**Response Fields:**
- `name` / `title`: Event name
- `description`: Event description
- `address`: Full event address
- `start_date_time`: Event start date and time
- `end_date_time`: Event end date and time
- `photos`: Array of photo URLs (if any)
- `photos_count`: Number of photos
- `has_photos`: Boolean indicating if event has photos
- `rsvp_minimum_time`: Minimum hours before event for RSVP/cancellation deadline
- `artists`: List of artists performing at the event
  - `name`: Artist name
  - `time`: Artist performance time
    - `scheduled_start_at`: Artist start time
    - `scheduled_end_at`: Artist end time
    - `timezone`: Timezone
- `likes_count`: Number of users who liked this event
- `user_liked`: Whether the current authenticated user liked this event (boolean)
- `user_interested`: Whether the current authenticated user is interested in this event (boolean)
- `user_booked`: Whether the current authenticated user has booked this event (boolean)
- `user_rsvp_status`: Current user's RSVP status - `yes`, `no`, `maybe`, or `null` if not RSVP'd
- `user_rsvp_yes_count`: Count of users who RSVP'd "yes" (attending)
- `user_rsvp_no_count`: Count of users who RSVP'd "no" (not attending)
- `user_rsvp_maybe_count`: Count of users who RSVP'd "maybe" (maybe attending)
- `user_rsvp_count`: Total count of all RSVPs (yes + no + maybe)
- `user_reports_count`: Number of reports submitted for this event
- `user_reported`: Whether the current authenticated user reported this event (boolean)
- `joined_count`: Number of users who joined (bookings + interests)
- `bookings_count`: Number of confirmed bookings
- `interests_count`: Number of event interests

**Note:** User-specific fields (`user_liked`, `user_interested`, `user_booked`, `user_rsvp_status`, `user_reported`) are only included when the request is authenticated. For unauthenticated requests, these fields will be `null` or `false`.

**Private and unlisted events — invite metadata:** When `visibility` is `private` or `unlisted`, the event detail includes an `invite` object:

```json
"invite": {
  "sharing": "creator_and_guests",
  "can_share": true
}
```

- `sharing`: `creator_only` (only host / venue owner / admin may use share endpoints) or `creator_and_guests` (also booked users, RSVP users, and listed artists).
- `can_share`: Whether the current user is allowed to call `GET .../share_qr` and receive invite tokens (computed server-side).

Set `invite_sharing` on create or update via `event.invite_sharing`.

---

### 5. Get Event Share QR Code

**Endpoint:** `GET /api/v1/events/:id/share_qr`

**Description:** Returns a QR code (JSON with base64 PNG, or raw PNG) for sharing the event.

**Authentication:**
- **Public** events (`visibility: public`): **Optional** — works without a token.
- **Private** or **unlisted** events: **Required** — Bearer token. The user must be allowed to share (`can_share` from event detail). If not authorized, returns `401` or `403`.

**Query Parameters:**
- `size` (integer, optional): QR image size in pixels (default: 300, max: 1000)
- `format` (string, optional): `json` (default) or `image` for direct PNG

**Response (JSON):**
- `qr_code`: Base64-encoded PNG bytes (string)
- `qr_image_url`: URL to fetch the same QR as PNG (for private events, send `Authorization` when requesting this URL)
- `event_url`: Deep link, e.g. `vibes://events/{id}` (public) or `vibes://events/{id}?invite={token}` (private/unlisted)
- `invite` (private/unlisted only): `invite_token`, `invite_sharing`, `invite_api_url` (`GET /api/v1/events/by_invite?token=...`), `invite_deep_link`
- `event`: Summary event object

The QR encodes JSON including `type`, `event_id`, `url`, and for private/unlisted `invite_token`.

**Usage:**
- JSON: `GET /api/v1/events/:id/share_qr`
- PNG: `GET /api/v1/events/:id/share_qr?format=image&size=300`

---

### 5a. Validate event invite (public)

**Endpoint:** `GET /api/v1/events/by_invite`

**Description:** Validates a secret invite token for a **published** event. No authentication. Use when opening a shared link or deep link before the user logs in.

**Query Parameters:**
- `token` (string, required): Invite token from `share_qr` / `invite.invite_token` or the `invite` query on the deep link

**Response:** Minimal preview: `event_id`, `title`, `starts_at`, `ends_at`, `timezone`, `visibility`, `venue` (id, name, city, country).

**Errors:** `400` if `token` missing; `404` if invalid or event not published.

---

### 5b. Regenerate event invite

**Endpoint:** `POST /api/v1/events/:id/regenerate_invite`

**Description:** Issues a **new** invite token and invalidates all previous invite links and QR payloads. Only for **private** or **unlisted** events.

**Authentication:** Bearer token required

**Authorization:** Event creator, venue owner, or admin only.

**Response:** Same invite fields as in `share_qr` (`invite_token`, `invite_api_url`, `invite_deep_link`, `invite_sharing`).

**Errors:** `403` if not host/owner/admin; `422` if event is not private/unlisted.

---

### 6. Create Event

**Endpoint:** `POST /api/v1/venues/:venue_id/events`

**Description:** Create a new event for a venue. Requires venue_manager or admin role.

**Authentication:** Bearer token required

**Request Body (JSON with URLs):**
```json
{
  "event": {
    "title": "Networking Mixer",
    "description": "Join us for an evening of networking and drinks",
    "category": "business",
    "starts_at": "2025-12-15T18:00:00Z",
    "ends_at": "2025-12-15T21:00:00Z",
    "timezone": "America/New_York",
    "status": "draft",
    "visibility": "public",
    "invite_sharing": "creator_and_guests",
    "age_restriction": 21,
    "smoking": "2 zones",
    "price": 25.00,
    "currency": "USD",
    "is_free": false,
    "age_price": {
      "adult_price": 50.00,
      "child_price": 30.00,
      "infant_price": 0.00,
      "pet_price": 0.00
    },
    "pre_booking_price": 20.00,
    "pre_booking_deadline": "2025-12-10T23:59:59Z",
    "id_required": true,
    "id_requirement_description": "Valid government-issued ID required for entry",
    "dress_code": "Smart casual. No sportswear or flip-flops.",
    "restrictions": "No outside food or beverages. No photography without permission.",
    "access_instructions": "Enter through the main entrance. Check-in at reception desk.",
    "address1": "456 Event Street",
    "address2": "Outdoor Area",
    "city": "New York",
    "region": "NY",
    "postal_code": "10001",
    "country": "USA",
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "photo_urls": [
    "https://example.com/images/event1.jpg",
    "https://example.com/images/event2.jpg"
  ]
}
```

**Request Body (Multipart/Form-Data for File Uploads):**
```
Content-Type: multipart/form-data

event[title]: Networking Mixer
event[description]: Join us for an evening of networking and drinks
event[category]: business
event[starts_at]: 2025-12-15T18:00:00Z
event[ends_at]: 2025-12-15T21:00:00Z
event[timezone]: America/New_York
event[status]: draft
event[visibility]: public
event[age_restriction]: 21
event[price]: 25.00
event[currency]: USD
event[is_free]: false
poster: [poster.jpg]   ← Upload poster/cover image (optional)
photos[]: [file1.jpg]  ← Upload image file
photos[]: [file2.jpg]  ← Upload image file
```

**How File Upload Works:**
1. Upload image files via `multipart/form-data`
2. Files are stored on your server (Active Storage)
3. **Public URLs are automatically generated**
4. URLs are returned in the `photos` array in all responses

**Example Response:**
```json
{
  "poster_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../poster.jpg",
  "has_poster": true,
  "photos": [
    "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../uploaded1.jpg",
    "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../uploaded2.jpg"
  ],
  "photos_count": 2,
  "has_photos": true
}
```

**Parameters:**
- `title` (string, required): Event title
- `description` (string, optional): Event description
- `category` (string, optional): Event category
- `starts_at` (datetime, required): Event start time (ISO 8601)
- `ends_at` (datetime, required): Event end time (ISO 8601)
- `timezone` (string, required): IANA timezone identifier
- `status` (string, optional): draft, published, canceled, completed (default: draft)
- `visibility` (string, optional): public, private, unlisted (default: public)
- `age_restriction` (integer, optional): Minimum age requirement (0-99)
- `smoking` (string, optional): Smoking policy - one of: `yes`, `no`, `2 zones`, `private zone`
- **Pricing (optional):**
  - `price` (decimal, optional): Regular ticket price (default: 0.0)
  - `currency` (string, optional): Currency code (default: USD)
  - `is_free` (boolean, optional): Whether event is free (default: true)
  - **Age-based pricing (optional):**
    - `age_price` (object, optional):
      - `adult_price` (decimal, optional): Age 18+ price per person
      - `child_price` (decimal, optional): Age 2-17 price per person
      - `infant_price` (decimal, optional): Age under 2 price per person
      - `pet_price` (decimal, optional): Price per pet
    - When any age price is set (> 0), the event is treated as paid and bookings use age counts to calculate price
  - `pre_booking_price` (decimal, optional): Early bird/pre-booking price
  - `pre_booking_deadline` (datetime, optional): Deadline for pre-booking price
- **Private Event Restrictions (optional):**
  - `id_required` (boolean, optional): Whether ID is required for entry (default: false)
  - `id_requirement_description` (text, optional): Description of ID requirements
  - `dress_code` (text, optional): Dress code requirements
  - `restrictions` (text, optional): General restrictions and rules
  - `access_instructions` (text, optional): Instructions for accessing the event
- **Cancellation Policy (optional):**
  - `cancellation_policy_enabled` (boolean, optional): Enable booking cancellation policy (default: false)
  - `cancellation_deadline_hours` (integer, optional): Hours before event when free cancellation ends (e.g., 24, 48, 72)
  - `cancellation_fee_percentage` (decimal, optional): Percentage charged as fee after deadline (0-100, e.g., 20 = 20% fee)
- **Location Override (optional):** If provided, these fields override the venue's location:
  - `address1` (string, optional): Street address line 1
  - `address2` (string, optional): Street address line 2
  - `city` (string, optional): City
  - `region` (string, optional): State/Province/Region
  - `postal_code` (string, optional): Postal/ZIP code
  - `country` (string, optional): Country
  - `latitude` (decimal, optional): Latitude (-90 to 90)
  - `longitude` (decimal, optional): Longitude (-180 to 180)
- **Poster/Cover Image (optional):**
  
  **🖼️ Upload Poster File** (Recommended)
  - Use `multipart/form-data` content type
  - Send file as `poster` (single file)
  - File is uploaded → Stored on your server → **Public URL automatically generated**
  - **Response includes:** `poster_url` with public URL and `has_poster: true`
  - Max 10MB
  - Supported formats: JPEG, PNG, GIF, WebP
  
  **🔗 External Poster URL** (Alternative)
  - `event[poster_url]` (string, optional): External URL for poster image
  - For images **already hosted elsewhere** (S3, Cloudinary, CDN, etc.)
  - **Use this when:** Poster is already on external storage
  
  **Note:** Use either file upload OR URL, not both. File upload takes priority.

- **Photos (optional):**
  
  **📤 Upload Image Files** (Primary Method - Recommended)
  - Use `multipart/form-data` content type
  - Send files as `photos[]` (array of files)
  - Files are uploaded → Stored on your server → **Public URLs automatically generated**
  - **Response includes:** Public URLs in `photos` array (e.g., `https://vibesapp.digital4design.com/rails/active_storage/blobs/.../image.jpg`)
  - Max 10 files, each max 10MB
  - Supported formats: JPEG, PNG, GIF, WebP
  - **Use this when:** Uploading images from device/app
  
  **🔗 External Image URLs** (Advanced - Optional)
  - `photo_urls` (array of strings, optional): Array of external image URLs
  - For images **already hosted elsewhere** (S3, Cloudinary, CDN, etc.)
  - Example: `["https://s3.amazonaws.com/bucket/image1.jpg", "https://cdn.example.com/image2.jpg"]`
  - URLs stored as-is and returned in `photos` array
  - **Use this when:** Images are already on external storage and you just want to reference them
  - **Note:** You can combine with file uploads, but total cannot exceed 10 photos

**Private Event Access:**
- Private events (`visibility: "private"`) are only visible to:
  - Venue owner
  - Admin users
  - Users who have booked the event
  - Users who have RSVP'd/interested in the event
  - Artists performing at the event
- Users without access will receive a 403 Forbidden error when trying to view private events

**Invite sharing (`invite_sharing` on `event`):** For private or unlisted events, controls who may call `GET /api/v1/events/:id/share_qr` and receive invite tokens:
- `creator_only`: Only event creator, venue owner, or admin.
- `creator_and_guests` (default): Same as above, plus users with a booking, an RSVP, or artists listed on the event.

**Note:** If location override fields are not provided, the event will use the venue's address and location. This is useful for events at different locations than the venue (e.g., outdoor events, pop-ups, etc.).

---

### 6. Update Event

**Endpoint:** `PATCH /api/v1/events/:id`

**Description:** Update event. Only venue owner or admin can update. All event fields can be updated, including location override fields.

**Authentication:** Bearer token required

**Request Body:** Same as Create Event. All fields are optional for updates.

**Poster Updates:**
- **Upload New Poster:** Use `multipart/form-data` and send file as `poster`
  - File uploaded → Stored → **Public URL generated automatically**
  - Replaces existing poster if one exists
- **Update Poster URL:** Send `event[poster_url]` with new external URL
- **Remove Poster:** Send `remove_poster: true` to remove existing poster

**Photo Updates:**
- **Upload New Files:** Use `multipart/form-data` and send files as `photos[]` array
  - Files uploaded → Stored → **Public URLs generated automatically** → URLs returned in response
- **Add External URLs:** Send `photo_urls` as JSON array (optional - for images already hosted elsewhere)
- **Remove Uploaded Photos:** Send `remove_photo_ids` array with Active Storage blob IDs
- **Remove External URLs:** Update `photo_urls` array (remove URLs you don't want)
- Max 10 photos total (uploaded files + external URLs combined)
- **All URLs** (from uploads + external) are combined and returned in `photos` array

**Note:** To remove location override and use venue location, set location override fields to `null` or omit them.

---

### 6a. Upload Event Photos

**Endpoint:** `POST /api/v1/events/:id/photos`

**Description:** Upload multiple image files to an event. Files are stored and public URLs are generated automatically.

**Authentication:** Bearer token required

**Request Body (multipart/form-data):**
```
photos[]: [image1.jpg]
photos[]: [image2.jpg]
photos[]: [image3.jpg]
```

**Parameters:**
- `photos[]` (array of files, required): Image files to upload
  - Max 10 photos total per event
  - Each file max 10MB
  - Supported formats: JPEG, PNG, GIF, WebP

**Response:**
```json
{
  "status": 200,
  "message": "3 photo(s) uploaded successfully",
  "data": {
    "event": {
      "id": "event_id",
      "photos": [
        "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../image1.jpg",
        "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../image2.jpg",
        "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../image3.jpg"
      ],
      "photos_count": 3,
      "has_photos": true
    },
    "uploaded_count": 3,
    "total_photos": 3
  }
}
```

**Error Responses:**
- **400 Bad Request:** At least one photo file is required
- **400 Bad Request:** Cannot upload more than 10 photos total
- **403 Forbidden:** You do not have permission to upload photos to this event

---

### 6b. Remove Event Photo

**Endpoint:** `DELETE /api/v1/events/:id/photos/:photo_id`

**Description:** Remove a photo from an event.

**Authentication:** Bearer token required

**Parameters:**
- `photo_id` (string, required): Active Storage blob ID (get from event.photos array)

**Response:**
```json
{
  "status": 200,
  "message": "Photo removed successfully",
  "data": {
    "event": {
      "id": "event_id",
      "photos": [...],
      "photos_count": 2
    }
  }
}
```

---

### 7. Publish Event

**Endpoint:** `POST /api/v1/events/:id/publish`

**Description:** Publish an event (changes status from draft to published).

**Authentication:** Bearer token required

---

### 8. Cancel Event

**Endpoint:** `POST /api/v1/events/:id/cancel`

**Description:** Cancel an event.

**Authentication:** Bearer token required

---

### 9. Delete Event

**Endpoint:** `DELETE /api/v1/events/:id`

**Description:** Delete event. Only venue owner or admin can delete.

**Authentication:** Bearer token required

---

## Event Categories

Events can have multiple categories (similar to artist categories). This allows for better event discovery and filtering.

### 10. List Event Categories (with subscribed flag)

**Endpoint:** `GET /api/v1/events/:id/categories`

**Description:** Get ALL categories with subscribed flag for an event (like artist categories). Returns all available categories, with `subscribed: true` for categories assigned to this event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Networking Mixer",
    "legacy_category": "business",
    "categories_groups": [
      {
        "id": "group_uuid",
        "name": "Event Types",
        "slug": "event-types",
        "description": "Types of events",
        "display_order": 0,
        "categories": [
          {
            "id": "category_uuid",
            "categories_group_id": "group_uuid",
            "name": "Business",
            "slug": "business",
            "icon_key": "briefcase",
            "display_order": 0,
            "subscribed": true
          },
          {
            "id": "category_uuid_2",
            "categories_group_id": "group_uuid",
            "name": "Music",
            "slug": "music",
            "icon_key": "music",
            "display_order": 1,
            "subscribed": false
          }
        ]
      }
    ],
    "categories": [
      {
        "id": "category_uuid",
        "categories_group_id": "group_uuid",
        "name": "Business",
        "slug": "business",
        "icon_key": "briefcase",
        "display_order": 0,
        "subscribed": true
      },
      {
        "id": "category_uuid_2",
        "categories_group_id": "group_uuid",
        "name": "Music",
        "slug": "music",
        "icon_key": "music",
        "display_order": 1,
        "subscribed": false
      }
    ],
    "subscribed_category_ids": ["category_uuid"]
  }
}
```

**Response Fields:**
- `event_id`: Event UUID
- `event_title`: Event title
- `legacy_category`: Original single category field (for backward compatibility)
- `categories_groups`: Categories organized by group, each category has `subscribed` flag
- `categories`: Flat list of ALL categories with `subscribed` flag (true/false)
- `subscribed_category_ids`: Array of category UUIDs that are assigned to this event
- `subscribed`: Boolean - `true` if category is assigned to event, `false` otherwise

---

### 11. Replace Event Categories

**Endpoint:** `PUT /api/v1/events/:id/categories`

**Description:** Replace all categories for an event. Removes existing categories and adds new ones.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": ["category_uuid_1", "category_uuid_2", "category_uuid_3"],
  "source": "manual"
}
```

**Parameters:**
- `category_ids` (array of strings, required): Array of category UUIDs to assign
- `source` (string, optional): Source of assignment - `manual`, `auto`, `system` (default: `manual`)

**Response:**
```json
{
  "status": 200,
  "message": "Categories updated successfully",
  "data": {
    "event_id": "event_uuid",
    "categories": [
      {"id": "category_uuid_1", "name": "Business", "slug": "business", "source": "manual"},
      {"id": "category_uuid_2", "name": "Networking", "slug": "networking", "source": "manual"},
      {"id": "category_uuid_3", "name": "Social", "slug": "social", "source": "manual"}
    ],
    "category_ids": ["category_uuid_1", "category_uuid_2", "category_uuid_3"]
  }
}
```

**Note:** Only venue owner or admin can manage event categories.

---

### 12. Add Event Categories

**Endpoint:** `POST /api/v1/events/:id/categories/add`

**Description:** Add categories to an event without removing existing ones.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": ["category_uuid_1", "category_uuid_2"],
  "source": "manual"
}
```

**Parameters:**
- `category_ids` (array of strings, required): Array of category UUIDs to add
- `source` (string, optional): Source of assignment (default: `manual`)

**Response:**
```json
{
  "status": 200,
  "message": "2 category(ies) added",
  "data": {
    "event_id": "event_uuid",
    "added_category_ids": ["category_uuid_1", "category_uuid_2"],
    "skipped_category_ids": [],
    "categories": [...],
    "category_ids": [...]
  }
}
```

**Response Fields:**
- `added_category_ids`: Categories that were successfully added
- `skipped_category_ids`: Categories that were already assigned (not duplicated)

---

### 13. Remove Event Categories

**Endpoint:** `POST /api/v1/events/:id/categories/remove`

**Description:** Remove categories from an event.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "category_ids": ["category_uuid_1"]
}
```

**Parameters:**
- `category_ids` (array of strings, required): Array of category UUIDs to remove

**Response:**
```json
{
  "status": 200,
  "message": "1 category(ies) removed",
  "data": {
    "event_id": "event_uuid",
    "removed_category_ids": ["category_uuid_1"],
    "not_found_category_ids": [],
    "categories": [...],
    "category_ids": [...]
  }
}
```

**Response Fields:**
- `removed_category_ids`: Categories that were successfully removed
- `not_found_category_ids`: Categories that were not assigned to the event

---

## Event Custom Categories

Events can have custom categories specific to each event. These are different from the standard category system and allow venue managers to add event-specific tags or labels with custom names and descriptions.

### 1. List Event Custom Categories

**Endpoint:** `GET /api/v1/events/:event_id/custom_categories`

**Description:** List all custom categories for an event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "custom_categories": [
      {
        "id": "custom_category_uuid",
        "event_id": "event_uuid",
        "name": "VIP Access",
        "description": "VIP section with premium seating and service",
        "created_at": "2025-12-18T10:00:00Z",
        "updated_at": "2025-12-18T10:00:00Z"
      },
      {
        "id": "custom_category_uuid_2",
        "event_id": "event_uuid",
        "name": "Live Music",
        "description": "Live band performance throughout the event",
        "created_at": "2025-12-18T10:05:00Z",
        "updated_at": "2025-12-18T10:05:00Z"
      }
    ]
  }
}
```

### 2. Create Event Custom Categories

**Endpoint:** `POST /api/v1/events/:event_id/custom_categories`

**Description:** Add multiple custom categories to an event. Each category name must be unique per event.

**Authentication:** Bearer token required (venue manager or admin)

**Request Body:**
```json
{
  "custom_categories": [
    {
      "name": "VIP Access",
      "description": "VIP section with premium seating and service"
    },
    {
      "name": "Live Music",
      "description": "Live band performance throughout the event"
    },
    {
      "name": "Outdoor Area",
      "description": "Access to outdoor terrace and garden"
    }
  ]
}
```

**Parameters:**
- `custom_categories` (array, required): Array of custom category objects
  - `name` (string, required): Category name (must be unique per event, max 255 characters)
  - `description` (text, optional): Category description

**Response:**
```json
{
  "status": 201,
  "message": "3 custom categories created",
  "data": {
    "event_id": "event_uuid",
    "created": [
      {
        "id": "custom_category_uuid",
        "event_id": "event_uuid",
        "name": "VIP Access",
        "description": "VIP section with premium seating and service",
        "created_at": "2025-12-18T10:00:00Z",
        "updated_at": "2025-12-18T10:00:00Z"
      },
      {
        "id": "custom_category_uuid_2",
        "event_id": "event_uuid",
        "name": "Live Music",
        "description": "Live band performance throughout the event",
        "created_at": "2025-12-18T10:00:00Z",
        "updated_at": "2025-12-18T10:00:00Z"
      },
      {
        "id": "custom_category_uuid_3",
        "event_id": "event_uuid",
        "name": "Outdoor Area",
        "description": "Access to outdoor terrace and garden",
        "created_at": "2025-12-18T10:00:00Z",
        "updated_at": "2025-12-18T10:00:00Z"
      }
    ],
    "errors": null,
    "total_custom_categories": 3
  }
}
```

**Error Response (if some fail):**
```json
{
  "status": 201,
  "message": "2 custom categories created, 1 failed",
  "data": {
    "event_id": "event_uuid",
    "created": [...],
    "errors": [
      {
        "category": {"name": "Duplicate Name", "description": "..."},
        "errors": ["Name has already been taken"]
      }
    ],
    "total_custom_categories": 2
  }
}
```

### 3. Update Event Custom Category

**Endpoint:** `PATCH /api/v1/events/:event_id/custom_categories/:id`

**Description:** Update a custom category's name or description.

**Authentication:** Bearer token required (venue manager or admin)

**Request Body:**
```json
{
  "custom_category": {
    "name": "Updated VIP Access",
    "description": "Updated description for VIP section"
  }
}
```

**Parameters:**
- `name` (string, optional): Updated category name (must remain unique per event if changed)
- `description` (text, optional): Updated description

**Response:**
```json
{
  "status": 200,
  "message": "Custom category updated successfully",
  "data": {
    "custom_category": {
      "id": "custom_category_uuid",
      "event_id": "event_uuid",
      "name": "Updated VIP Access",
      "description": "Updated description for VIP section",
      "created_at": "2025-12-18T10:00:00Z",
      "updated_at": "2025-12-18T10:05:00Z"
    }
  }
}
```

### 4. Delete Event Custom Category

**Endpoint:** `DELETE /api/v1/events/:event_id/custom_categories/:id`

**Description:** Delete a single custom category from an event.

**Authentication:** Bearer token required (venue manager or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Custom category deleted successfully"
}
```

### 5. Delete Multiple Event Custom Categories

**Endpoint:** `DELETE /api/v1/events/:event_id/custom_categories`

**Description:** Delete multiple custom categories from an event.

**Authentication:** Bearer token required (venue manager or admin)

**Query Parameters:**
- `custom_category_ids[]` (array, required): Array of custom category IDs to delete

**Example:**
```
DELETE /api/v1/events/:event_id/custom_categories?custom_category_ids[]=uuid1&custom_category_ids[]=uuid2
```

**Response:**
```json
{
  "status": 200,
  "message": "2 custom categories deleted",
  "data": {
    "event_id": "event_uuid",
    "deleted_ids": ["uuid1", "uuid2"],
    "not_found_ids": [],
    "total_custom_categories": 1
  }
}
```

**Notes:**
- Custom categories are event-specific and not shared across events
- Each custom category name must be unique per event
- Custom categories are automatically included in event detail responses
- Only venue owners or admins can manage custom categories

---

## Event Boost

Boost your events to reach more users. Event boosting allows venue managers to promote events with specific targeting options.

### Performance Goals

- **page_views**: Maximize the number of users who view your event page
- **link_clicks**: Maximize the number of clicks on your event links  
- **daily_reach**: Maximize daily reach among unique users in your target audience

### Targeting Options

- **Age Range**: Target users within specific age brackets (13-120)
- **Gender**: Target all genders, male, female, or other
- **Geo-Fencing**: Target users within a specific geographic radius

### 1. Get Performance Goal Options

**Endpoint:** `GET /api/v1/events/boost/performance_goals`

**Description:** Get available performance goal options for boosting events.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "performance_goals": [
      {
        "value": "page_views",
        "label": "Page Views",
        "description": "Maximize the number of users who view your event page"
      },
      {
        "value": "link_clicks",
        "label": "Link Clicks",
        "description": "Maximize the number of clicks on your event links"
      },
      {
        "value": "daily_reach",
        "label": "Daily Reach",
        "description": "Maximize daily reach among unique users in your target audience"
      }
    ]
  }
}
```

### 2. Get Targeting Options

**Endpoint:** `GET /api/v1/events/boost/targeting_options`

**Description:** Get available targeting options for event boosting.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "genders": [
      { "value": "all", "label": "All Genders" },
      { "value": "male", "label": "Male" },
      { "value": "female", "label": "Female" },
      { "value": "other", "label": "Other" }
    ],
    "age_range": {
      "min": 13,
      "max": 120,
      "default_min": 18,
      "default_max": 65
    },
    "geo_fence": {
      "min_radius_km": 1,
      "max_radius_km": 500,
      "default_radius_km": 10
    }
  }
}
```

### 3. List Event Boosts

**Endpoint:** `GET /api/v1/events/:id/boosts`

**Description:** List all boosts for an event.

**Authentication:** Bearer token required (venue manager or admin)

**Query Parameters:**
- `limit` (optional): Number of results to return (default: 20, max: 100)
- `offset` (optional): Number of results to skip for pagination

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "boosts": [
      {
        "id": "boost_uuid",
        "event_id": "event_uuid",
        "performance_goal": "page_views",
        "status": "active",
        "starts_at": "2025-01-01T10:00:00Z",
        "ends_at": "2025-01-15T10:00:00Z",
        "timezone": "UTC",
        "target_audience": {
          "age_range": { "min": 18, "max": 35 },
          "gender": "all",
          "location": {
            "latitude": 40.7128,
            "longitude": -74.006,
            "radius_km": 25.0,
            "address": "New York, NY",
            "city": "New York",
            "region": "NY",
            "country": "USA"
          }
        },
        "is_running": true,
        "is_scheduled": false,
        "created_at": "2025-01-01T09:00:00Z",
        "updated_at": "2025-01-01T09:00:00Z"
      }
    ],
    "active_boost": { ... },
    "is_boosted": true,
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 1,
      "has_more": false
    }
  }
}
```

### 4. Create Event Boost

**Endpoint:** `POST /api/v1/events/:id/boost`

**Description:** Create a new boost for an event. Only one active or pending boost is allowed per event.

**Authentication:** Bearer token required (venue manager or admin)

**Request Body:**
```json
{
  "boost": {
    "performance_goal": "page_views",
    "starts_at": "2025-01-01T10:00:00Z",
    "ends_at": "2025-01-15T10:00:00Z",
    "timezone": "America/New_York",
    "target_age_min": 18,
    "target_age_max": 35,
    "target_gender": "all",
    "geo_fence_address": "Times Square",
    "geo_fence_city": "New York",
    "geo_fence_region": "NY",
    "geo_fence_country": "USA",
    "geo_fence_latitude": 40.7580,
    "geo_fence_longitude": -73.9855,
    "geo_fence_radius_km": 25.0,
    "daily_budget": 50.00,
    "total_budget": 500.00,
    "currency": "USD",
    "notes": "Campaign for New Year event"
  }
}
```

**Parameters:**
- `performance_goal` (string, required): One of `page_views`, `link_clicks`, `daily_reach`
- `starts_at` (datetime, required): When the boost campaign starts
- `ends_at` (datetime, required): When the boost campaign ends
- `timezone` (string, optional): Timezone for scheduling (default: UTC)
- `target_age_min` (integer, optional): Minimum target age (default: 18)
- `target_age_max` (integer, optional): Maximum target age (default: 65)
- `target_gender` (string, optional): One of `all`, `male`, `female`, `other` (default: all)
- `geo_fence_address` (string, optional): Target location address
- `geo_fence_city` (string, optional): Target city
- `geo_fence_region` (string, optional): Target region/state
- `geo_fence_country` (string, optional): Target country
- `geo_fence_latitude` (decimal, optional): Center latitude for geo-fence
- `geo_fence_longitude` (decimal, optional): Center longitude for geo-fence
- `geo_fence_radius_km` (decimal, optional): Radius in kilometers (1-500, default: 10)
- `daily_budget` (decimal, optional): Daily spending limit
- `total_budget` (decimal, optional): Total campaign budget
- `currency` (string, optional): Currency code (default: USD)
- `notes` (text, optional): Internal notes about the boost

**Response:**
```json
{
  "status": 201,
  "message": "Boost created successfully",
  "data": {
    "boost": {
      "id": "boost_uuid",
      "event_id": "event_uuid",
      "performance_goal": "page_views",
      "status": "draft",
      "created_by": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "schedule": {
        "starts_at": "2025-01-01T10:00:00Z",
        "ends_at": "2025-01-15T10:00:00Z",
        "timezone": "America/New_York",
        "duration_days": 14,
        "days_remaining": 14
      },
      "targeting": {
        "age_range": { "min": 18, "max": 35 },
        "gender": "all",
        "geo_fence": {
          "latitude": 40.7580,
          "longitude": -73.9855,
          "radius_km": 25.0,
          "address": "Times Square",
          "city": "New York",
          "region": "NY",
          "country": "USA"
        }
      },
      "budget": {
        "daily_budget": 50.00,
        "total_budget": 500.00,
        "currency": "USD",
        "amount_spent": 0.00,
        "budget_remaining": 500.00,
        "budget_spent_percentage": 0.00,
        "is_budget_exhausted": false
      },
      "performance": {
        "impressions": 0,
        "page_views": 0,
        "link_clicks": 0,
        "unique_reach": 0,
        "click_through_rate": 0.00,
        "cost_per_click": 0.00,
        "cost_per_view": 0.00
      },
      "status_details": {
        "status": "draft",
        "approved_at": null,
        "paused_at": null,
        "completed_at": null,
        "rejected_at": null,
        "cancelled_at": null,
        "rejection_reason": null,
        "can_edit": true,
        "can_cancel": true
      },
      "notes": "Campaign for New Year event",
      "metadata": {},
      "created_at": "2025-01-01T09:00:00Z",
      "updated_at": "2025-01-01T09:00:00Z"
    },
    "event": { ... }
  }
}
```

### 5. Get Boost Details

**Endpoint:** `GET /api/v1/events/:id/boost/:boost_id`

**Description:** Get detailed information about a specific boost.

**Authentication:** Bearer token required (venue manager or admin)

**Response:** Same as create boost response.

### 6. Update Boost

**Endpoint:** `PATCH /api/v1/events/:id/boost/:boost_id`

**Description:** Update boost settings. Only boosts in `draft` or `rejected` status can be edited.

**Authentication:** Bearer token required (venue manager or admin)

**Request Body:** Same parameters as create boost.

**Response:**
```json
{
  "status": 200,
  "message": "Boost updated successfully",
  "data": {
    "boost": { ... }
  }
}
```

### 7. Submit Boost for Review

**Endpoint:** `POST /api/v1/events/:id/boost/:boost_id/submit`

**Description:** Submit a draft boost for review. After approval, the boost will become active.

**Authentication:** Bearer token required (venue manager or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Boost submitted for review",
  "data": {
    "boost": { ... }
  }
}
```

### 8. Pause Boost

**Endpoint:** `POST /api/v1/events/:id/boost/:boost_id/pause`

**Description:** Pause an active boost. Paused boosts stop running but can be resumed.

**Authentication:** Bearer token required (venue manager or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Boost paused successfully",
  "data": {
    "boost": { ... }
  }
}
```

### 9. Resume Boost

**Endpoint:** `POST /api/v1/events/:id/boost/:boost_id/resume`

**Description:** Resume a paused boost.

**Authentication:** Bearer token required (venue manager or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Boost resumed successfully",
  "data": {
    "boost": { ... }
  }
}
```

### 10. Cancel Boost

**Endpoint:** `DELETE /api/v1/events/:id/boost/:boost_id`

**Description:** Cancel a boost. Cannot cancel completed, cancelled, or rejected boosts.

**Authentication:** Bearer token required (venue manager or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Boost cancelled successfully",
  "data": {
    "boost": { ... }
  }
}
```

### Boost Status Flow

```
draft → pending_review → active → completed
                      ↓         ↓
                   rejected   paused → active (resume)
                      ↓         ↓
                   cancelled  cancelled
```

### Event Response with Boost Info

When fetching event details, boost information is included:

```json
{
  "event": {
    "id": "event_uuid",
    "title": "New Year Party",
    "is_boosted": true,
    "active_boost": {
      "id": "boost_uuid",
      "performance_goal": "page_views",
      "status": "active",
      "is_running": true,
      ...
    },
    "boosts_count": 2,
    ...
  }
}
```

---

## Event Bookings

### 1. Book Event

**Endpoint:** `POST /api/v1/events/:event_id/bookings`

**Description:** Book/RSVP to an event. One booking per user per event.

**Authentication:** Bearer token required

**Notes:**
- All events (free and paid) create a booking with status `created` (awaiting venue/brand approval).
- Venue/brand must approve via approve_booking to change status to `confirmed`.
- Optional `table_number` can be provided to assign a table during booking creation.
- Optional `promo_code` can be provided to apply a discount.

**Response:**
```json
{
  "data": {
    "booking": {
      "id": "booking_id",
      "status": "created",
      "user": {
        "id": "user_id",
        "name": "John Doe"
      },
      "created_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Event booked successfully"
}
```

---

### 2. Get My Booking

**Endpoint:** `GET /api/v1/events/:event_id/bookings/my_booking`

**Description:** Get current user's booking for an event.

**Authentication:** Bearer token required

---

### 3. Get Booking Details

**Endpoint:** `GET /api/v1/bookings/:id`

**Description:** Get detailed booking information including event, venue, and pre-order details.

**Authentication:** Bearer token required (booking owner, venue owner, or admin)

**Response:**
```json
{
  "data": {
    "booking": {
      "id": "booking_id",
      "status": "confirmed",
      "payment_status": "paid",
      "payment_type": "full",
      "paid_amount": 45.0,
      "remaining_amount": 0.0,
      "payment_progress_percentage": 100.0,
      "fully_paid": true,
      "partially_paid": false,
      "price": 45.0,
      "total_price": 103.6,
      "table_number": "A12",
      "promo_code": "SAVE10",
      "original_price": 50.0,
      "discount_amount": 5.0,
      "attendees": {
        "adults_count": 2,
        "children_count": 1,
        "infants_count": 0,
        "pets_count": 0
      },
      "event": {
        "id": "event_id",
        "title": "Networking Mixer",
        "starts_at": "2025-12-15T18:00:00Z",
        "ends_at": "2025-12-15T22:00:00Z",
        "venue": {
          "id": "venue_id",
          "name": "The Grand Club",
          "address": "123 Main St, City, State"
        }
      },
      "preorder": {
        "has_preorder": true,
        "items_count": 3,
        "total_amount": 58.60
      }
    }
  }
}
```

---

### 4. Booking QR Code

**Endpoint:** `GET /api/v1/bookings/:id/share_qr`

**Description:** Get QR code for a booking (use for check-in or sharing).

**Authentication:** Bearer token required (booking owner, venue owner, or admin)

**Query Parameters:**
- `size` (integer, optional): QR size (default: 300, max: 1000)
- `format` (string, optional): Set to `image` to return PNG directly

---

### 5. List My Bookings

**Endpoint:** `GET /api/v1/bookings/my_bookings`

**Description:** List all bookings for current user.

**Authentication:** Bearer token required

**Query Parameters:**
- `status` (string, optional): created, confirmed, canceled, checked_in
- `time_filter` (string, optional): upcoming, past
- `limit` (integer, optional): Number of results
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "data": {
    "bookings": [
      {
        "id": "booking_id",
        "status": "confirmed",
        "event": {
          "id": "event_id",
          "title": "Networking Mixer",
          "starts_at": "2025-12-15T18:00:00Z",
          "venue": {
            "id": "venue_id",
            "name": "The Grand Club"
          }
        }
      }
    ]
  }
}
```

---

### 4. List Event Bookings

**Endpoint:** `GET /api/v1/events/:event_id/bookings`

**Description:** List all bookings for an event. Only venue owner or admin can access.

**Authentication:** Bearer token required

**Query Parameters:**
- `status` (string, optional): Filter by status (created, confirmed, canceled, checked_in)
- `limit` (integer, optional): Number of results
- `offset` (integer, optional): Pagination offset

---

### 5. Assign Table (Seat Selection)

**Endpoint:** `POST /api/v1/bookings/:id/assign_table`

**Description:** Assign a table number to a booking after seat selection (webview).

**Authentication:** Bearer token required (booking owner, venue owner, or admin)

**Request Body:**
```json
{
  "table_number": "A12"
}
```

---

### 6a. Update Pre-order (Cart)

**Endpoint:** `PATCH /api/v1/bookings/:id/preorder`

**Description:** Update the pre-order attached to a booking (cart-style). This **replaces the full items list**. To add/remove items, send the complete updated list from the client.

**Authentication:** Bearer token required (booking owner or admin)

**Notes:**
- Only allowed while the pre-order is `pending` and `payment_status` is `pending`.
- If no preorder exists yet, this creates one for the booking.
- Updating the pre-order automatically recalculates the **booking's `total_price`** (base booking price + all related pre-order orders).

**Request Body:**
```json
{
  "pre_order": {
    "order_type": "both",
    "time_window_start": "2026-01-27T19:00:00Z",
    "time_window_end": "2026-01-27T19:30:00Z",
    "special_instructions": "Table near the bar please",
    "allergies": "Severe peanut allergy - no cross contamination",
    "tip_amount": 10.00,
    "items": [
      {
        "menu_item_id": "menu_item_id",
        "quantity": 2,
        "special_instructions": "No onions, extra cheese",
        "customizations": { "spice_level": "medium" }
      }
    ]
  }
}
```

---

### 7. Update Booking Details (Counts & Notes)

**Endpoint:** `PATCH /api/v1/bookings/:id`

**Description:** Update booking details such as notes, table number, and attendee counts. When attendee counts change and no payment has started yet, the booking price is recalculated from event pricing.

**Authentication:** Bearer token required (booking owner, venue owner, or admin)

**Request Body:**
```json
{
  "booking": {
    "notes": "Birthday celebration, please arrange cake.",
    "table_number": "A5",
    "adults_count": 3,
    "children_count": 1,
    "infants_count": 0,
    "pets_count": 0
  }
}
```

**Rules:**
- You may send any subset of the fields above.
- If any of the count fields are present, the API:
  - Builds the new counts (using existing values where omitted).
  - Validates that all counts are ≥ 0 and the total > 0.
  - **Only allows changes while `payment_status` is `pending`**. If payment has already started (`partial`/`paid`), it returns `400`.
  - Recalculates `price` based on event pricing and updates the attendee counts and price together.

**Response:**
Same as **Get Booking Details**, including updated `price`, `total_price`, counts, and payment information.

---

### 8. Get Booking Payment Details

**Endpoint:** `GET /api/v1/bookings/:id/payment_details`

**Description:** Returns a dedicated payment view for a booking, including base price, discounts, promo code, pre-booking information, pre-order totals, and current payment status/progress. Use this endpoint to drive the "booking payment" screen in the app.

**Authentication:** Bearer token required (booking owner, venue owner, or admin)

**Response:**
```json
{
  "data": {
    "payment_details": {
      "booking_id": "booking_uuid",
      "event": {
        "id": "event_uuid",
        "title": "Networking Mixer",
        "starts_at": "2026-02-20T18:00:00Z",
        "ends_at": "2026-02-20T22:00:00Z",
        "currency": "USD",
        "has_pre_booking": true,
        "pre_booking_active": true,
        "pre_booking_price": 50.0,
        "pre_booking_deadline": "2026-02-18T23:59:59Z",
        "current_price": 50.0
      },
      "pricing": {
        "original_price": 100.0,
        "discount_amount": 20.0,
        "promo_code": "WELCOME20",
        "booking_price": 80.0,
        "preorder_total": 35.0,
        "total_with_preorders": 115.0
      },
      "payment": {
        "currency": "USD",
        "payment_status": "partial",
        "payment_type": "pre_payment",
        "paid_amount": 40.0,
        "remaining_amount": 40.0,
        "payment_progress_percentage": 50.0,
        "fully_paid": false,
        "partially_paid": true,
        "requires_payment": true,
        "is_free": false,
        "paid_at": "2026-02-10T19:25:00Z"
      }
    }
  }
}
```

**Client usage:**
- Use `pricing` to show original price, discount, final booking price, and how pre-orders affect the total.
- Use `event.has_pre_booking`, `event.pre_booking_active`, and `event.current_price` to decide whether to show a pre-booking vs normal pricing UI.
- Use `payment` to drive progress bars and "pay remaining" actions.

---

### 6b. Add Pre-order Item

**Endpoint:** `POST /api/v1/bookings/:id/preorder/items`

**Description:** Add a single item to the pre-order cart (quantity is added if item already exists).

**Authentication:** Bearer token required (booking owner or admin)

**Request Body:**
```json
{
  "item": {
    "menu_item_id": "menu_item_id",
    "quantity": 2,
    "special_instructions": "No onions",
    "customizations": { "spice_level": "medium" }
  }
}
```

---

### 6c. Update Pre-order Item

**Endpoint:** `PATCH /api/v1/bookings/:id/preorder/items/:item_id`

**Description:** Update quantity or notes for a specific pre-order item.

**Authentication:** Bearer token required (booking owner or admin)

**Request Body:**
```json
{
  "quantity": 3,
  "special_instructions": "Extra cheese"
}
```

---

### 6d. Remove Pre-order Item

**Endpoint:** `DELETE /api/v1/bookings/:id/preorder/items/:item_id`

**Description:** Remove a specific item from the pre-order cart.

**Authentication:** Bearer token required (booking owner or admin)

---

### 6. Pay Booking

**Endpoint:** `POST /api/v1/bookings/:id/pay`

**Description:** Process payment for a booking. On success, booking status becomes `confirmed`.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "payment_method": "credit_card",
  "provider": "stripe"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Payment processed successfully",
  "data": {
    "booking": {
      "id": "booking_uuid",
      "status": "confirmed",
      "payment_status": "paid",
      "price": 50.00,
      "currency": "USD"
    }
  }
}
```

---

### 6b. Create Payment Intent for Booking (Stripe - Flutter)

**Endpoint:** `POST /api/v1/bookings/:id/create_payment_intent`

**Description:** Create a Stripe Payment Intent specifically for a booking. This endpoint is designed for Flutter app integration and supports **partial payments, pre-payments, full payments, and overpayments**. Returns a `client_secret` that can be used with Stripe Flutter SDK.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "provider": "stripe",
  "payment_type": "full"
}
```

**Parameters:**
- `provider` (string, optional): Payment provider name (default: stripe)
- `amount` (decimal, optional): Payment amount. If not provided, defaults to remaining amount (full payment)
- `payment_type` (string, optional): Payment type - `pre_payment`, `partial`, `full`, or `overpayment`. If not provided, automatically determined based on amount:
  - If `amount >= remaining`: `full` or `overpayment` (if amount > remaining)
  - If `amount < remaining`: `partial`
- `customer_id` (string, optional): Stripe customer ID (advanced/off-session use only)
- `payment_method_id` (string, optional): Stripe payment method ID **only if you pass a real `pm_...` from Stripe SDK**. For standard mobile flows, omit this and let the client confirm using `client_secret`.

**Payment Types:**

1. **Pre-payment (`pre_payment`)**: Deposit before full booking confirmation
   - Amount can be less than booking price
   - Useful for securing a booking with a deposit

2. **Partial Payment (`partial`)**: Paying part of the remaining amount
   - Amount must be less than remaining amount
   - Booking status remains `created` or `confirmed` with `payment_status: partial`
   - Can make multiple partial payments until fully paid

3. **Full Payment (`full`)**: Paying exactly the remaining amount
   - Amount must match remaining amount (within 1 cent tolerance)
   - Booking status updated to `confirmed` and `payment_status: paid`
   - Default if amount not provided

4. **Overpayment (`overpayment`)**: Paying more than booking price
   - Amount must be greater than remaining amount
   - Useful when including pre-orders or additional items
   - Booking marked as fully paid, excess tracked separately

**Response:**
```json
{
  "status": 201,
  "message": "Payment intent created successfully",
  "data": {
    "payment_intent_id": "pi_1234567890",
    "client_secret": "pi_1234567890_secret_abc123",
    "transaction_id": "transaction_uuid",
    "booking_id": "booking_uuid",
    "amount": 50.00,
    "currency": "USD",
    "payment_type": "full",
    "booking_price": 100.00,
    "remaining_amount": 0.00,
    "current_paid_amount": 50.00,
    "original_price": 100.00,
    "discount_amount": 0.00,
    "promo_code": null,
    "status": "requires_payment_method"
  }
}
```

**Usage Flow (Flutter):**
1. User creates a booking (status: `created`, payment_status: `pending`, paid_amount: `0`)
2. Call this endpoint to create Payment Intent (specify `amount` and `payment_type` if needed)
3. Use `client_secret` with Stripe Flutter SDK to process payment
4. Stripe SDK handles 3D Secure if needed
5. Backend receives webhook (`payment_intent.succeeded`) and automatically:
   - Updates transaction status to `completed`
   - Updates booking `paid_amount` (cumulative)
   - Updates booking `payment_status` (`partial` or `paid`)
   - Updates booking status to `confirmed` if fully paid

**Partial Payment Example:**
```json
{
  "amount": 25.00,
  "payment_type": "partial"
}
```
- Booking price: $100
- Current paid: $0
- This payment: $25
- After payment: `paid_amount: 25.00`, `payment_status: partial`, `remaining_amount: 75.00`

**Pre-payment Example:**
```json
{
  "amount": 20.00,
  "payment_type": "pre_payment"
}
```
- Booking price: $100
- Deposit: $20
- After payment: `paid_amount: 20.00`, `payment_status: partial`, `remaining_amount: 80.00`

**Errors:**
- `400`: Booking is already fully paid
- `400`: Cannot pay for canceled booking
- `400`: This booking is free and does not require payment
- `400`: Invalid payment_type
- `400`: Partial payment amount must be less than remaining amount
- `400`: Full payment amount must match remaining amount
- `400`: Overpayment amount must be greater than remaining amount
- `404`: Booking not found
- `400`: Provider not found or inactive

**Notes:**
- Payment Intent is automatically linked to the booking via reference
- Booking currency is used automatically
- `paid_amount` tracks cumulative payments (can exceed `price` for overpayments)
- `remaining_amount` = `price` - `paid_amount` (minimum 0)
- Multiple payments can be made until booking is fully paid
- When fully paid (`paid_amount >= price`), booking status automatically updated to `confirmed`
- You can optionally call `/payments/confirm_intent` for immediate confirmation

---

### 7. Get Cancellation Info

**Endpoint:** `GET /api/v1/bookings/:id/cancellation_info`

**Description:** Preview cancellation details including refund amount and fees before canceling.

**Authentication:** Bearer token required

**Response:**
```json
{
  "success": true,
  "data": {
    "cancellation_info": {
      "can_cancel": true,
      "refund_amount": 40.0,
      "cancellation_fee": 10.0,
      "original_price": 50.0,
      "currency": "USD",
      "policy": {
        "enabled": true,
        "deadline_hours": 24,
        "deadline": "2025-12-09T20:00:00Z",
        "fee_percentage": 20.0,
        "within_free_cancellation_window": false,
        "past_deadline": true
      }
    }
  }
}
```

**Notes:**
- `can_cancel`: Whether the booking can be canceled
- `refund_amount`: Amount that will be refunded (after fees)
- `cancellation_fee`: Fee charged for late cancellation
- `policy.deadline_hours`: Hours before event when free cancellation ends
- `policy.fee_percentage`: Percentage charged as fee after deadline
- `within_free_cancellation_window`: If true, full refund available

---

### 6. Request Cancellation

**Endpoint:** `POST /api/v1/bookings/:id/request_cancellation`

**Description:** Request booking cancellation. For paid events, requires venue manager approval.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "reason": "Unable to attend due to emergency"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Cancellation request submitted. Waiting for venue approval.",
  "data": {
    "booking": {
      "id": "booking-id",
      "status": "confirmed",
      "cancellation_requested": true,
      "cancellation_requested_at": "2025-12-08T15:30:00Z"
    },
    "cancellation_info": {
      "status": "pending_approval",
      "requested_at": "2025-12-08T15:30:00Z",
      "refund_amount": 40.00,
      "cancellation_fee": 10.00
    }
  }
}
```

**Note:** Free events are auto-approved. Paid events need venue manager approval.

---

### 7. Cancel Booking (Direct)

**Endpoint:** `POST /api/v1/bookings/:id/cancel`

**Description:** Cancel booking. Free events canceled immediately. Paid events redirect to request_cancellation.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Booking canceled successfully",
  "data": {
    "booking": {
      "id": "booking_id",
      "status": "canceled",
      "canceled_at": "2025-12-10T14:00:00Z",
      "refund_amount": 40.0,
      "cancellation_fee": 10.0,
      "price": 50.0,
      "currency": "USD",
      "payment_status": "refunded"
    },
    "refund": {
      "refund_amount": 40.0,
      "cancellation_fee": 10.0,
      "original_price": 50.0,
      "currency": "USD",
      "refund_processed": true
    }
  }
}
```

**Cancellation Flow:**
1. **User requests cancellation** → `POST /bookings/:id/request_cancellation`
2. **Venue manager reviews** → `GET /venues/:id/manager/events/:id/pending_cancellations`
3. **Manager approves OR rejects** → Refund processed or request denied
4. **User notified** → Via push notification

**Cancellation Policy:**
- Free events: Auto-approved
- Paid events: Requires venue approval
- Refund based on cancellation policy (time before event)

---

### 8. Check In Attendee

**Endpoint:** `POST /api/v1/bookings/:id/check_in`

**Description:** Check in an attendee. Only venue owner or admin can check in.

**Authentication:** Bearer token required

---

## Food & Bar Ordering

Order food and drinks at events with support for special instructions, allergies notes, tips, and split bill.

### 1. View Event Menu

**Endpoint:** `GET /api/v1/events/:event_id/menus`

**Description:** Get available food and bar menus for an event.

**Authentication:** Bearer token required (optional for public events)

**Query Parameters:**
- `type` (string, optional): Filter by 'food' or 'bar'

**Response:**
```json
{
  "data": {
    "event": {
      "id": "event_id",
      "title": "Concert Night"
    },
    "menus": [
      {
        "id": "menu_id",
        "name": "Dinner Menu",
        "menu_type": "food",
        "available_now": true,
        "categories": [
          {
            "id": "category_id",
            "name": "Appetizers",
            "items": [
              {
                "id": "item_id",
                "name": "Bruschetta",
                "description": "Toasted bread with tomatoes",
                "price": 12.50,
                "currency": "USD",
                "dietary_info": {
                  "is_vegetarian": true,
                  "is_vegan": false,
                  "is_gluten_free": false,
                  "contains_alcohol": false
                },
                "allergens": ["gluten", "dairy"],
                "preparation_time_minutes": 15
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

### 1b. Get Event Menu

**Endpoint:** `GET /api/v1/events/:event_id/menus/:menu_id`

---

### 1c. Get Event Menu Category

**Endpoint:** `GET /api/v1/events/:event_id/menus/:menu_id/categories/:id`

---

### 1d. Get Event Menu Item

**Endpoint:** `GET /api/v1/events/:event_id/menus/:menu_id/items/:id`

---

### 1e. Upload Event Menu Image

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/image`

**Body:** multipart `image`

---

### 1f. Remove Event Menu Image

**Endpoint:** `DELETE /api/v1/events/:event_id/menus/:menu_id/image`

---

### 1g. Upload Event Menu Category Image

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/categories/:id/image`

**Body:** multipart `image`

---

### 1h. Remove Event Menu Category Image

**Endpoint:** `DELETE /api/v1/events/:event_id/menus/:menu_id/categories/:id/image`

---

### 1i. Upload Event Menu Item Image

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/items/:id/image`

**Body:** multipart `image`

---

### 1j. Remove Event Menu Item Image

**Endpoint:** `DELETE /api/v1/events/:event_id/menus/:menu_id/items/:id/image`

---

### 2. Create Event Menu

**Endpoint:** `POST /api/v1/events/:event_id/menus`

**Description:** Create a menu for a specific event.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "name": "Event Dinner Menu",
  "menu_type": "food",
  "description": "Dinner menu for this event",
  "is_active": true
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus menu fields as `menu[name]`, `menu[menu_type]`, `menu[description]`, `menu[is_active]`, `menu[available_from]`, `menu[available_until]`.

---

### 3. Create Event Menu Category

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/categories`

**Description:** Create a category under an event menu.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "name": "Appetizers",
  "category_type": "appetizer",
  "description": "Start your meal with appetizers",
  "display_order": 0,
  "is_active": true
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus category fields as `category[name]`, `category[category_type]`, `category[description]`, `category[display_order]`, `category[is_active]`.

---

### 3b. Reorder Event Menu Categories

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/categories/reorder`

**Description:** Reorder categories by updating `display_order`.

**Request Body:**
```json
{
  "category_ids": ["cat_uuid_1", "cat_uuid_2", "cat_uuid_3"]
}
```

---

### 4. Create Event Menu Item

**Endpoint:** `POST /api/v1/events/:event_id/menus/:menu_id/items`

**Description:** Create an item under an event menu category.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "menu_category_id": "menu-category-id",
  "name": "Caesar Salad",
  "description": "Fresh romaine lettuce with caesar dressing",
  "price": 12.99,
  "currency": "USD",
  "item_type": "food",
  "is_available": true
}
```

**Image Upload (optional):** Use multipart/form-data with `image` plus item fields as `item[menu_category_id]`, `item[name]`, `item[description]`, `item[price]`, `item[currency]`, `item[item_type]`, `item[is_available]`, etc.

---

### 5. Place Order

**Endpoint:** `POST /api/v1/events/:event_id/orders`

**Description:** Place food/bar order with special instructions, allergies notes, and tip.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "order_type": "both",
  "time_window_start": "2026-01-27T19:00:00Z",
  "time_window_end": "2026-01-27T19:30:00Z",
  "special_instructions": "Table near the bar please",
  "allergies": "Severe peanut allergy - no cross contamination",
  "dietary_restrictions": "Vegetarian",
  "tip_amount": 10.00,
  "tip_percentage": 15,
  "items": [
    {
      "menu_item_id": "item-uuid",
      "quantity": 2,
      "special_instructions": "No onions, extra cheese"
    }
  ]
}
```

**Parameters:**
- `order_type` (string, required): 'food', 'bar', or 'both'
- `time_window_start` (string, optional): ISO8601 time window start (must be within event time range)
- `time_window_end` (string, optional): ISO8601 time window end (must be within event time range)
- `special_instructions` (string, optional): General order instructions
- `allergies` (string, optional): **Important allergy information for kitchen/bar**
- `dietary_restrictions` (string, optional): Dietary preferences
- `tip_amount` (decimal, optional): Tip amount in currency
- `tip_percentage` (decimal, optional): Tip as percentage

**Note:** `menu_item_id` can be an event menu item id or a venue menu item id. If a venue menu item is used, the system auto-syncs venue menus into event menus.
- `items` (array, required): Array of order items
  - `menu_item_id` (uuid, required): Menu item ID
  - `quantity` (integer, required): Quantity (must be > 0)
  - `special_instructions` (string, optional): Per-item instructions

**Response:**
```json
{
  "status": 201,
  "message": "Order placed successfully",
  "data": {
    "order": {
      "id": "order_id",
      "order_number": "ORD-20251203-A1B2",
      "status": "pending",
      "order_type": "both",
      "time_window_start": "2026-01-27T19:00:00Z",
      "time_window_end": "2026-01-27T19:30:00Z",
      "subtotal": 45.00,
      "tax": 3.60,
      "tip_amount": 10.00,
      "total_amount": 58.60,
      "special_instructions": "Table near the bar please",
      "allergies": "Severe peanut allergy",
      "items": [...]
    }
  }
}
```

---

### 3. Get My Orders

**Endpoint:** `GET /api/v1/orders/my_orders`

**Description:** List all orders for current user.

**Authentication:** Bearer token required

**Query Parameters:**
- `event_id` (uuid, optional): Filter by event
- `status` (string, optional): Filter by status
- `limit` (integer, optional): Results per page (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

---

### 4. Add Tip

**Endpoint:** `POST /api/v1/orders/:id/add_tip`

**Description:** Add or update tip amount for an order.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "tip_amount": 15.00
}
```

---

### 5. Split Bill

**Endpoint:** `POST /api/v1/orders/:id/split`

**Description:** Split bill evenly among multiple participants. Supports both registered users and guests.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "participants": [
    { "user_id": "user-uuid-1" },
    { "user_id": "user-uuid-2" },
    {
      "name": "Guest Friend",
      "email": "guest@example.com",
      "phone": "+1234567890"
    }
  ]
}
```

**Parameters:**
- `participants` (array, required): Array of 2+ participants
  - For registered users: `{ "user_id": "uuid" }`
  - For guests: `{ "name": "...", "email": "...", "phone": "..." }`

**Response:**
```json
{
  "status": 200,
  "message": "Bill split created successfully",
  "data": {
    "order": {
      "total_amount": 60.00,
      "is_split_bill": true,
      "split_count": 3
    },
    "splits": [
      {
        "id": "split-1",
        "participant": {
          "id": "user-1",
          "name": "John Doe"
        },
        "split_amount": 20.00,
        "payment_status": "pending"
      },
      {
        "id": "split-2",
        "participant": {
          "name": "Guest Friend",
          "email": "guest@example.com"
        },
        "split_amount": 20.00,
        "payment_status": "pending"
      }
    ]
  }
}
```

**Tip:** Use `GET /api/v1/users/search?query=...` to find user IDs to include in `participants`.

---

### 6. List Split Participants

**Endpoint:** `GET /api/v1/orders/:id/splits`

**Description:** List all users/guests sharing the bill and their contribution amounts.

**Authentication:** Bearer token required (order owner, split participant, venue owner, or admin)

**Response:**
```json
{
  "status": 200,
  "data": {
    "order": {
      "id": "order_id",
      "order_number": "ORD-20251203-A1B2",
      "total_amount": 60.00,
      "currency": "USD",
      "is_split_bill": true,
      "split_count": 3
    },
    "splits": [
      {
        "id": "split-1",
        "participant": {
          "id": "user-1",
          "name": "John Doe"
        },
        "split_amount": 20.00,
        "payment_status": "pending"
      }
    ]
  }
}
```

---

### 7. Update Split Amounts (Full Replace)

**Endpoint:** `PATCH /api/v1/orders/:id/splits`

**Description:** Update contribution amounts for all participants. **Must send all splits**, and the sum must equal the order total.

**Authentication:** Bearer token required (order owner or admin)

**Request Body:**
```json
{
  "splits": [
    { "id": "split-1", "split_amount": 25.00 },
    { "id": "split-2", "split_amount": 20.00 },
    { "id": "split-3", "split_amount": 15.00 }
  ]
}
```

---

### 8. Pay Split

**Endpoint:** `POST /api/v1/orders/:id/splits/:split_id/pay`

**Description:** Pay individual portion of a split bill.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "payment_method": "credit_card",
  "provider": "stripe"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Payment processed successfully",
  "data": {
    "split": {
      "id": "split_id",
      "split_amount": 20.00,
      "payment_status": "paid",
      "paid_at": "2025-12-03T12:00:00Z"
    },
    "order": {
      "payment_status": "paid"
    }
  }
}
```

**Note:** When all splits are paid, order `payment_status` updates to 'paid'.

---

### 7. Cancel Order

**Endpoint:** `POST /api/v1/orders/:id/cancel`

**Description:** Cancel a pending order.

**Authentication:** Bearer token required

---

### 9. Generate QR Code for Split

**Endpoint:** `POST /api/v1/orders/:id/split_qr`

**Description:** Generate QR code for bill splitting. Friends scan the QR code to join the split.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "max_participants": 5
}
```

**Parameters:**
- `max_participants` (integer, optional): Maximum number of people who can join (default: unlimited)

**Response:**
```json
{
  "status": 200,
  "message": "QR code generated. Share with friends to split the bill.",
  "data": {
    "qr_code": {
      "id": "qr-uuid",
      "token": "abc123token",
      "qr_url": "https://vibes.app/split/abc123token",
      "qr_data": {
        "token": "abc123token",
        "order_number": "ORD-20251203-A1B2",
        "total_amount": 60.00,
        "current_participants": 1,
        "max_participants": 5,
        "expires_at": "2025-12-03T13:30:00Z"
      },
      "expires_at": "2025-12-03T13:30:00Z"
    }
  }
}
```

**How it works:**
1. You generate QR code
2. Friends scan QR code
3. They're added to the split automatically
4. Bill divided evenly among all who scanned
5. Each person pays their portion

---

### 10. Join Split via QR Code

**Endpoint:** `POST /api/v1/orders/join_split/:qr_token`

**Description:** Join a bill split by scanning QR code.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "You've joined the split! Your share is 20.00 USD",
  "data": {
    "order": {
      "order_number": "ORD-20251203-A1B2",
      "total_amount": 60.00,
      "is_split_bill": true
    },
    "your_split": {
      "id": "split-uuid",
      "split_amount": 20.00,
      "payment_status": "pending"
    }
  }
}
```

---

### 10. Call Waiter

**Endpoint:** `POST /api/v1/events/:event_id/call_waiter`

**Description:** Call waiter for assistance. Only waiters within event geofence (100m radius) receive notifications.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "call_type": "assistance",
  "message": "Need extra napkins",
  "table_number": "A12",
  "location_description": "Near the bar",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "order_id": "order-uuid"
}
```

**Parameters:**
- `call_type` (string, required): 'assistance', 'order_help', 'bill_request', 'complaint', 'emergency'
- `message` (string, optional): Additional message
- `table_number` (string, optional): Table number
- `location_description` (string, optional): Where you are
- `latitude` (decimal, optional): Your current latitude
- `longitude` (decimal, optional): Your current longitude
- `order_id` (uuid, optional): Related order if applicable

**Response:**
```json
{
  "status": 201,
  "message": "Waiter called successfully. Nearby staff have been notified.",
  "data": {
    "waiter_call": {
      "id": "call-uuid",
      "call_type": "assistance",
      "status": "pending",
      "table_number": "A12",
      "time_waiting": 0
    },
    "nearby_staff_notified": 3
  }
}
```

**Geofence Logic:**
- Only waiters within 100 meters of event location receive notification
- Waiters must be on 'active' status
- Waiters must have location tracking enabled
- System uses lat/long to calculate distance

---

## Venue Manager Dashboard

Venue owner/manager endpoints for managing operations, staff, and viewing analytics.

### 1. Dashboard Summary (All Venues)

**Endpoint:** `GET /api/v1/venue_manager/dashboard_summary`

**Description:** Overview of all your venues with key metrics.

**Authentication:** Bearer token required (venue_manager or admin role)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "total_venues": 3,
    "total_events": 24,
    "upcoming_events": 8,
    "active_bookings": 156,
    "venues": [
      {
        "id": "venue-1",
        "name": "The Grand Club",
        "city": "New York",
        "total_events": 12,
        "upcoming_events": 5,
        "active_staff": 8
      }
    ]
  }
}
```

---

### 2. Venue Dashboard

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/dashboard`

**Description:** Detailed dashboard for a single venue with today's stats and pending items.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "data": {
    "venue": {
      "id": "venue-id",
      "name": "The Grand Club"
    },
    "today": {
      "events_count": 3,
      "bookings_count": 45,
      "orders_count": 23,
      "revenue": 1250.50
    },
    "pending_attention": {
      "waiter_calls": 2,
      "pending_orders": 5
    },
    "revenue_30_days": {
      "total": 15000.00,
      "from_bookings": 10000.00,
      "from_orders": 5000.00
    },
    "upcoming_events": [...]
  }
}
```

---

### 3. Analytics

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/analytics`

**Description:** Analytics and performance metrics for specified period.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `period` (integer, optional): Number of days to analyze (default: 30)

**Response:**
```json
{
  "data": {
    "period_days": 30,
    "events": {
      "total": 24,
      "published": 20,
      "draft": 3,
      "canceled": 1
    },
    "bookings": {
      "total": 450,
      "confirmed": 420,
      "checked_in": 380,
      "revenue": 12500.00
    },
    "orders": {
      "total": 340,
      "completed": 320,
      "revenue": 8500.00,
      "average_order_value": 26.56
    },
    "top_menu_items": [
      {
        "menu_item_id": "item-id",
        "name": "Margherita Pizza",
        "quantity_sold": 85,
        "revenue": 1530.00
      }
    ]
  }
}
```

---

### 4. Revenue Report

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/revenue_report`

**Description:** Detailed revenue report for specified date range.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `start_date` (date, optional): Start date (YYYY-MM-DD)
- `end_date` (date, optional): End date (YYYY-MM-DD)

**Response:**
```json
{
  "data": {
    "period": {
      "start_date": "2025-11-01",
      "end_date": "2025-11-30",
      "days": 30
    },
    "revenue": {
      "bookings": 12500.00,
      "food_bar": 8500.00,
      "total": 21000.00
    },
    "bookings": {
      "count": 450,
      "revenue": 12500.00,
      "average_value": 27.78
    },
    "orders": {
      "count": 340,
      "revenue": 8500.00,
      "average_value": 25.00,
      "total_tips": 850.00
    }
  }
}
```

---

### 5. List Staff

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/staff`

**Description:** List all staff members for venue.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "data": {
    "staff": [
      {
        "id": "staff-1",
        "user": {
          "id": "user-1",
          "name": "John Waiter",
          "email": "john@venue.com",
          "phone": "+1234567890"
        },
        "role": "waiter",
        "status": "active",
        "on_shift": true,
        "receives_notifications": true,
        "last_location_update": "2025-12-03T12:30:00Z",
        "shift_start_at": "2025-12-03T18:00:00Z",
        "shift_end_at": "2025-12-04T02:00:00Z"
      }
    ]
  }
}
```

---

### 6. Add Staff

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/staff`

**Description:** Add staff member to venue.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "email": "newstaff@venue.com",
  "role": "waiter"
}
```

**Roles:**
- `waiter` - Wait staff
- `bartender` - Bar staff
- `chef` - Kitchen staff
- `manager` - Venue manager
- `host` - Host/hostess

---

### 7. Update Staff

**Endpoint:** `PATCH /api/v1/venues/:venue_id/manager/staff/:id`

**Description:** Update staff member details.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "status": "on_break",
  "shift_start_at": "2025-12-03T18:00:00Z",
  "shift_end_at": "2025-12-04T02:00:00Z",
  "receives_notifications": true
}
```

**Status:**
- `active` - Working and available
- `on_break` - On break
- `off_duty` - Not working
- `inactive` - No longer employed

---

### 8. Tables Overview

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/tables_overview`

**Description:** View all tables with their current orders, payment status, and service status.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Query Parameters:**
- `event_id` (uuid, optional): Filter by specific event

**Response:**
```json
{
  "data": {
    "tables": [
      {
        "table_number": "A12",
        "status": "waiting_payment",
        "total_amount": 125.50,
        "paid_amount": 75.00,
        "unpaid_amount": 50.50,
        "has_pending_orders": false,
        "has_unpaid_orders": true,
        "orders": [
          {
            "id": "order-1",
            "order_number": "ORD-20251203-A1B2",
            "status": "completed",
            "payment_status": "paid",
            "total_amount": 75.00,
            "ordered_at": "2025-12-03T19:30:00Z"
          },
          {
            "id": "order-2",
            "order_number": "ORD-20251203-C3D4",
            "status": "completed",
            "payment_status": "pending",
            "total_amount": 50.50,
            "is_split_bill": true,
            "ordered_at": "2025-12-03T20:15:00Z"
          }
        ]
      },
      {
        "table_number": "B5",
        "status": "in_service",
        "total_amount": 45.00,
        "paid_amount": 0,
        "unpaid_amount": 45.00,
        "has_pending_orders": true,
        "has_unpaid_orders": true,
        "orders": [...]
      }
    ],
    "summary": {
      "total_tables": 25,
      "available": 10,
      "occupied": 8,
      "in_service": 5,
      "waiting_payment": 2,
      "total_revenue": 2500.00,
      "pending_revenue": 850.00
    }
  }
}
```

**Table Status:**
- `available` - No active orders
- `occupied` - Has completed orders, all paid
- `in_service` - Has orders being prepared
- `waiting_payment` - Has unpaid orders

---

### 9. Table Details

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/table/:table_number`

**Description:** Get detailed information for a specific table including all orders and current booking.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Response:**
```json
{
  "data": {
    "table_number": "A12",
    "booking": {
      "id": "booking-id",
      "user": {
        "id": "user-id",
        "name": "John Doe"
      },
      "checked_in_at": "2025-12-03T19:00:00Z"
    },
    "orders": [
      {
        "id": "order-id",
        "order_number": "ORD-20251203-A1B2",
        "status": "completed",
        "payment_status": "split",
        "total_amount": 60.00,
        "is_split_bill": true,
        "customer": {
          "name": "John Doe"
        },
        "items": [
          {
            "name": "Pizza",
            "quantity": 2,
            "price": 36.00
          }
        ],
        "splits": [
          {
            "participant": "John Doe",
            "amount": 20.00,
            "payment_status": "paid"
          },
          {
            "participant": "Jane Smith",
            "amount": 20.00,
            "payment_status": "paid"
          },
          {
            "participant": "Bob Wilson",
            "amount": 20.00,
            "payment_status": "pending"
          }
        ],
        "ordered_at": "2025-12-03T19:30:00Z",
        "time_elapsed": 45
      }
    ],
    "summary": {
      "total_orders": 2,
      "active_orders": 0,
      "total_amount": 125.00,
      "paid_amount": 75.00,
      "unpaid_amount": 50.00,
      "payment_status": "unpaid"
    }
  }
}
```

---

### 10. Assign Table to Booking

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/tables/:table_number/assign_booking`

**Description:** Assign a table number to a booking.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Request Body:**
```json
{
  "booking_id": "booking-uuid"
}
```

---

### 10a. Orders Tables (Paid / In Progress / Unpaid)

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/orders`

**Description:** Orders tab: list tables grouped by payment state.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Query Parameters:**
- `event_id` (uuid, optional): Filter by specific event

**Response:**
```json
{
  "data": {
    "tables": {
      "paid": [
        {
          "table_number": "A12",
          "status": "occupied",
          "total_amount": 120.00,
          "paid_amount": 120.00,
          "unpaid_amount": 0.00,
          "orders": [...]
        }
      ],
      "in_progress": [
        {
          "table_number": "B5",
          "status": "in_service",
          "total_amount": 45.00,
          "paid_amount": 0.00,
          "unpaid_amount": 45.00,
          "orders": [...]
        }
      ],
      "unpaid": [
        {
          "table_number": "C2",
          "status": "waiting_payment",
          "total_amount": 60.00,
          "paid_amount": 20.00,
          "unpaid_amount": 40.00,
          "orders": [...]
        }
      ]
    },
    "summary": {
      "total_tables": 3,
      "paid_tables": 1,
      "in_progress_tables": 1,
      "unpaid_tables": 1
    }
  }
}
```

---

### 10b. Pre-Orders Tables (Booked)

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/preorders`

**Description:** Pre-orders tab: list tables with bookings (confirmed/checked_in).

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Query Parameters:**
- `event_id` (uuid, optional): Filter by specific event

**Response:**
```json
{
  "data": {
    "tables": [
      {
        "table_number": "A12",
        "status": "checked_in",
        "bookings": [
          {
            "id": "booking-id",
            "status": "checked_in",
            "payment_status": "paid",
            "table_number": "A12",
            "user": {
              "id": "user-id",
              "name": "John Doe"
            }
          }
        ]
      }
    ],
    "summary": {
      "total_tables": 1,
      "total_bookings": 1,
      "checked_in_tables": 1
    }
  }
}
```

---

### 10c. Waiting Waiter Tables (In Progress)

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/waiting_waiter`

**Description:** Waiting waiter tab: list tables with waiter calls in progress and details.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Query Parameters:**
- `event_id` (uuid, optional): Filter by specific event
- `status` (string, optional): pending, acknowledged, in_progress, completed, canceled (default: in_progress)

**Response:**
```json
{
  "data": {
    "tables": [
      {
        "table_number": "A12",
        "calls": [
          {
            "id": "call-id",
            "call_type": "assistance",
            "status": "in_progress",
            "table_number": "A12",
            "message": "Need extra napkins"
          }
        ],
        "orders": [...],
        "booking": {
          "id": "booking-id",
          "status": "checked_in",
          "payment_status": "paid",
          "table_number": "A12"
        }
      }
    ],
    "summary": {
      "total_tables": 1,
      "total_calls": 1,
      "status_filter": "in_progress"
    }
  }
}
```

---

### 11. Live Orders (Kitchen/Bar Display)

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/live_orders`

**Description:** Get active orders grouped by status for kitchen/bar display screens.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Response:**
```json
{
  "data": {
    "orders": {
      "pending": [
        {
          "id": "order-1",
          "order_number": "ORD-20251203-A1B2",
          "status": "pending",
          "order_type": "food",
          "total_amount": 45.00,
          "customer": {
            "name": "John Doe",
            "table_number": "A12"
          },
          "items": [
            {
              "name": "Margherita Pizza",
              "quantity": 2,
              "special_instructions": "No olives, extra cheese"
            }
          ],
          "special_instructions": "Please rush",
          "allergies": "Peanut allergy",
          "ordered_at": "2025-12-03T12:00:00Z",
          "time_elapsed": 3
        }
      ],
      "confirmed": [...],
      "preparing": [...],
      "ready": [...]
    },
    "stats": {
      "total_active": 12,
      "pending_count": 3,
      "preparing_count": 5,
      "ready_count": 4
    }
  }
}
```

**Use Case:** Kitchen/bar display showing orders in real-time with timers.

---

### 9. Update Order Status

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/orders/:order_id/update_status`

**Description:** Update order status (for kitchen/bar staff).

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Request Body:**
```json
{
  "status": "preparing"
}
```

**Valid Status Transitions:**
```
pending → confirmed → preparing → ready → delivered → completed
```

**Response:**
```json
{
  "status": 200,
  "message": "Order status updated to preparing",
  "data": {
    "order": {
      "id": "order-id",
      "status": "preparing",
      "order_number": "ORD-20251203-A1B2"
    }
  }
}
```

---

### 10. Active Waiter Calls

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/active_calls`

**Description:** View all active customer assistance calls.

**Authentication:** Bearer token required (venue owner, staff, or admin)

**Response:**
```json
{
  "data": {
    "calls": [
      {
        "id": "call-1",
        "call_type": "assistance",
        "status": "pending",
        "customer": {
          "id": "user-id",
          "name": "Jane Smith"
        },
        "table_number": "B5",
        "location": "Near the bar",
        "message": "Need extra napkins",
        "time_waiting": 2,
        "created_at": "2025-12-03T12:28:00Z"
      }
    ],
    "stats": {
      "total_active": 5,
      "pending": 3,
      "in_progress": 2,
      "emergency": 0
    }
  }
}
```

---

### 11. View Event Participants

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/events/:event_id/participants`

**Description:** View all participants (bookings) for an event with their status and VibeCheck ratings.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `status` (string, optional): Filter by booking status (confirmed, checked_in, canceled)

**Response:**
```json
{
  "data": {
    "event": {
      "id": "event-id",
      "title": "Concert Night",
      "starts_at": "2025-12-10T20:00:00Z",
      "status": "published"
    },
    "participants": [
      {
        "id": "booking-id",
        "user": {
          "id": "user-id",
          "name": "John Doe",
          "email": "john@example.com",
          "phone": "+1234567890"
        },
        "status": "confirmed",
        "table_number": "A12",
        "checked_in_at": null,
        "payment_status": "paid",
        "cancellation_requested": false,
        "vibe_check_submitted": false,
        "created_at": "2025-12-01T10:00:00Z"
      }
    ],
    "stats": {
      "total": 50,
      "confirmed": 45,
      "checked_in": 30,
      "canceled": 5,
      "pending_cancellations": 2
    }
  }
}
```

---

### 12. Pending Cancellations

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/events/:event_id/pending_cancellations`

**Description:** View all pending cancellation requests requiring approval.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "data": {
    "pending_cancellations": [
      {
        "id": "booking-id",
        "user": {
          "id": "user-id",
          "name": "Jane Smith",
          "email": "jane@example.com"
        },
        "cancellation_requested_at": "2025-12-08T15:30:00Z",
        "cancellation_reason": "Unable to attend due to emergency",
        "refund_amount": 40.00,
        "cancellation_fee": 10.00,
        "booking_price": 50.00
      }
    ]
  }
}
```

---

### 13. Approve Cancellation

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/events/:event_id/bookings/:booking_id/approve_cancellation`

**Description:** Approve a cancellation request and process refund.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Cancellation approved and refund processed",
  "data": {
    "booking": {
      "status": "canceled",
      "cancellation_approved": true,
      "refund_amount": 40.00
    }
  }
}
```

---

### 14. Reject Cancellation

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/events/:event_id/bookings/:booking_id/reject_cancellation`

**Description:** Reject a cancellation request.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "rejection_reason": "Cancellation window has passed"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Cancellation request rejected",
  "data": {
    "booking": {
      "cancellation_requested": false,
      "cancellation_approved": false
    }
  }
}
```

---

### 18. List All Bookings

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/bookings`

**Description:** List all bookings for all events at this venue with comprehensive filtering and search capabilities.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `status` (string, optional): Filter by booking status (`confirmed`, `canceled`, `checked_in`)
- `payment_status` (string, optional): Filter by payment status (`pending`, `paid`, `failed`, `refunded`)
- `event_id` (string, optional): Filter by specific event
- `search` (string, optional): Search by user name, email, or booking ID
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "bookings": [
      {
        "id": "booking-uuid",
        "booking_id": "booking-uuid",
        "status": "confirmed",
        "payment_status": "paid",
        "price": 50.0,
        "currency": "USD",
        "payment_method": "stripe",
        "paid_at": "2025-12-01T10:00:00Z",
        "table_number": "A12",
        "seats": "Table A12",
        "notes": null,
        "user": {
          "id": "user-uuid",
          "name": "John Doe",
          "username": "johndoe",
          "email": "john@example.com",
          "phone": "+1234567890",
          "avatar_url": "https://..."
        },
        "event": {
          "id": "event-uuid",
          "title": "Concert Night",
          "starts_at": "2025-12-10T20:00:00Z",
          "ends_at": "2025-12-11T02:00:00Z",
          "address": "123 Main St, City, Country"
        },
        "guests": {
          "total": 4,
          "guest_count": 3,
          "breakdown": "3 guest(s)"
        },
        "preorder": {
          "has_preorder": true,
          "items_count": 5,
          "total_amount": 100.0,
          "orders": [
            {
              "id": "order-uuid",
              "order_number": "ORD-12345",
              "status": "completed",
              "payment_status": "paid",
              "total_amount": 100.0,
              "items": [
                {
                  "name": "Burger",
                  "quantity": 2,
                  "price": 20.0
                }
              ]
            }
          ]
        },
        "cancellation": {
          "requested": false,
          "requested_at": null,
          "reason": null,
          "approved": null,
          "approved_at": null,
          "rejected_reason": null
        },
        "checked_in_at": null,
        "created_at": "2025-12-01T10:00:00Z",
        "updated_at": "2025-12-01T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 150,
      "has_more": true
    },
    "stats": {
      "total": 150,
      "confirmed": 120,
      "canceled": 20,
      "checked_in": 80,
      "pending_payment": 10,
      "paid": 140
    }
  }
}
```

---

### 19. Get Booking Details

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/bookings/:booking_id`

**Description:** Get detailed booking information including user details, payment status, guests, seats, preorders, and cancellation information.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "data": {
    "booking": {
      "id": "booking-uuid",
      "booking_id": "booking-uuid",
      "status": "confirmed",
      "payment_status": "paid",
      "payment_type": "full",
      "paid_amount": 50.0,
      "remaining_amount": 0.0,
      "payment_progress_percentage": 100.0,
      "fully_paid": true,
      "partially_paid": false,
      "price": 50.0,
      "currency": "USD",
      "payment_method": "stripe",
      "paid_at": "2025-12-01T10:00:00Z",
      "table_number": "A12",
      "seats": "Table A12",
      "notes": "Special dietary requirements",
      "user": {
        "id": "user-uuid",
        "name": "John Doe",
        "username": "johndoe",
        "email": "john@example.com",
        "phone": "+1234567890",
        "avatar_url": "https://..."
      },
      "event": {
        "id": "event-uuid",
        "title": "Concert Night",
        "starts_at": "2025-12-10T20:00:00Z",
        "ends_at": "2025-12-11T02:00:00Z",
        "address": "123 Main St, City, Country"
      },
      "guests": {
        "total": 4,
        "guest_count": 3,
        "breakdown": "3 guest(s)"
      },
      "preorder": {
        "has_preorder": true,
        "items_count": 5,
        "total_amount": 100.0,
        "orders": [...]
      },
      "cancellation": {...},
      "checked_in_at": null,
      "payment_details": {
        "transaction_id": "transaction-uuid",
        "refund_amount": null,
        "cancellation_fee": null
      },
      "vibe_check": {
        "submitted": false
      },
      "created_at": "2025-12-01T10:00:00Z",
      "updated_at": "2025-12-01T10:00:00Z"
    }
  }
}
```

---

### 20. Approve Booking

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/bookings/:booking_id/approve`

**Description:** Approve a booking (confirm it). Changes booking status to 'confirmed'.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "message": "Booking approved successfully",
  "data": {
    "booking": {
      "id": "booking-uuid",
      "status": "confirmed",
      ...
    }
  }
}
```

---

### 21. Block Booking

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/bookings/:booking_id/block`

**Description:** Block a booking and add user to blocklist. This action cancels the booking if it's confirmed and adds the user to the venue's blocklist.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "reason": "Booking blocked by venue manager",
  "description": "User violated event rules",
  "incident_type": "behavior",
  "is_permanent": false,
  "blocked_until": "2026-01-01T00:00:00Z"
}
```

**Incident Types:**
- `no_show` - Didn't show up
- `late_cancellation` - Canceled too late
- `behavior` - Bad behavior
- `fraud` - Fraudulent activity
- `other` - Other reason

**Response:**
```json
{
  "status": 200,
  "message": "Booking blocked and user added to blocklist",
  "data": {
    "booking": {
      "id": "booking-uuid",
      "status": "canceled",
      ...
    },
    "blocklist": {
      "id": "blocklist-uuid",
      "user": {...},
      "reason": "Booking blocked by venue manager",
      "is_permanent": false,
      "blocked_until": "2026-01-01T00:00:00Z"
    }
  }
}
```

---

### 22. Cancel Booking (Manager)

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/bookings/:booking_id/cancel`

**Description:** Cancel a booking (venue manager initiated). Processes refund if booking was paid.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "reason": "Canceled by venue manager"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Booking canceled successfully",
  "data": {
    "booking": {
      "id": "booking-uuid",
      "status": "canceled",
      "canceled_at": "2025-12-08T15:00:00Z",
      ...
    }
  }
}
```

---

### 23. List Event RSVPs

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/events/:event_id/rsvps`

**Description:** List all RSVPs for an event with filtering and search capabilities.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `rsvp_status` (string, optional): Filter by RSVP status (`yes`, `no`, `maybe`)
- `search` (string, optional): Search by user name or email
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "event": {
      "id": "event-uuid",
      "title": "Concert Night",
      "starts_at": "2025-12-10T20:00:00Z"
    },
    "rsvps": [
      {
        "id": "rsvp-uuid",
        "user": {
          "id": "user-uuid",
          "name": "Jane Smith",
          "username": "janesmith",
          "email": "jane@example.com",
          "phone": "+1234567890",
          "avatar_url": "https://..."
        },
        "rsvp_status": "yes",
        "guest_count": 2,
        "total_attendees": 3,
        "notes": "Looking forward to it!",
        "responded_at": "2025-12-01T10:00:00Z",
        "created_at": "2025-12-01T10:00:00Z",
        "has_booking": true
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 100,
      "has_more": true
    },
    "stats": {
      "total": 100,
      "yes": 80,
      "no": 10,
      "maybe": 10
    }
  }
}
```

---

### 24. Approve RSVP

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/events/:event_id/rsvps/:user_id/approve`

**Description:** Approve an RSVP (convert to booking if needed). Updates RSVP status to 'yes' and creates a booking if it doesn't exist.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "message": "RSVP approved successfully",
  "data": {
    "rsvp": {
      "id": "rsvp-uuid",
      "rsvp_status": "yes",
      ...
    },
    "booking": {
      "id": "booking-uuid",
      "status": "confirmed",
      ...
    }
  }
}
```

---

### 25. Block RSVP

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/events/:event_id/rsvps/:user_id/block`

**Description:** Block an RSVP and add user to blocklist. Updates RSVP status to 'no' and cancels any existing booking.

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "reason": "RSVP blocked by venue manager",
  "description": "User violated event rules",
  "incident_type": "behavior",
  "is_permanent": false,
  "blocked_until": "2026-01-01T00:00:00Z"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "RSVP blocked and user added to blocklist",
  "data": {
    "rsvp": {
      "id": "rsvp-uuid",
      "rsvp_status": "no",
      ...
    },
    "blocklist": {
      "id": "blocklist-uuid",
      "user": {...},
      "reason": "RSVP blocked by venue manager",
      ...
    }
  }
}
```

---

### 26. Cancel RSVP

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/events/:event_id/rsvps/:user_id/cancel`

**Description:** Cancel an RSVP. Updates RSVP status to 'no' and cancels any existing booking.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "message": "RSVP canceled successfully",
  "data": {
    "rsvp": {
      "id": "rsvp-uuid",
      "rsvp_status": "no",
      ...
    }
  }
}
```

---

### 15. Blocklist Reasons

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/blocklist/reasons`

**Description:** List available reasons for blocking a user with mapped incident types.

**Authentication:** Bearer token required (venue owner or admin)

**Response:**
```json
{
  "status": 200,
  "data": {
    "reasons": [
      { "key": "intrusive_behavior", "label": "Intrusive behavior", "incident_type": "behavior" },
      { "key": "no_show_without_notice", "label": "No-show without notice", "incident_type": "no_show" },
      { "key": "rude_behavior", "label": "Rude behavior", "incident_type": "behavior" },
      { "key": "booking_abuse", "label": "Booking abuse", "incident_type": "fraud" },
      { "key": "violation_event_rules", "label": "Violation of event rules", "incident_type": "behavior" },
      { "key": "non_payment", "label": "Non-payment", "incident_type": "fraud" },
      { "key": "other", "label": "Other reasons", "incident_type": "other" }
    ],
    "incident_types": ["no_show", "late_cancellation", "behavior", "fraud", "other"]
  }
}
```

---

### 16. Venue Blocklist

**Endpoint:** `GET /api/v1/venues/:venue_id/manager/blocklist`

**Description:** View venue's blocklist.

**Authentication:** Bearer token required (venue owner or admin)

**Query Parameters:**
- `filter` (string, optional): 'active', 'expired', 'permanent'

**Response:**
```json
{
  "data": {
    "blocklists": [
      {
        "id": "blocklist-id",
        "user": {
          "id": "user-id",
          "name": "Bad Customer",
          "email": "bad@example.com"
        },
        "reason": "Multiple no-shows",
        "incident_type": "no_show",
        "is_permanent": true,
        "active": true,
        "blocked_by": {
          "id": "manager-id",
          "name": "Manager Name"
        },
        "created_at": "2025-12-01T10:00:00Z"
      }
    ],
    "stats": {
      "total": 15,
      "active": 12,
      "permanent": 8
    }
  }
}
```

---

### 17. Add to Blocklist

**Endpoint:** `POST /api/v1/venues/:venue_id/manager/blocklist/:user_id`

**Description:** Block a user from venue (e.g., after cancellation, no-show, or bad behavior).

**Authentication:** Bearer token required (venue owner or admin)

**Request Body:**
```json
{
  "reason": "Multiple cancellations",
  "description": "User has canceled 3 bookings within last month",
  "incident_type": "late_cancellation",
  "related_booking_id": "booking-uuid",
  "is_permanent": false,
  "blocked_until": "2026-01-01T00:00:00Z"
}
```

**Incident Types:**
- `no_show` - Didn't show up
- `late_cancellation` - Canceled too late
- `behavior` - Bad behavior
- `fraud` - Fraudulent activity
- `other` - Other reason

**Response:**
```json
{
  "status": 201,
  "message": "User added to blocklist",
  "data": {
    "blocklist": {
      "id": "blocklist-id",
      "user": {...},
      "reason": "Multiple cancellations",
      "is_permanent": false,
      "blocked_until": "2026-01-01T00:00:00Z",
      "time_remaining_hours": 720
    }
  }
}
```

---

### 18. Remove from Blocklist

**Endpoint:** `DELETE /api/v1/venues/:venue_id/manager/blocklist/:id`

**Description:** Remove user from blocklist.

**Authentication:** Bearer token required (venue owner or admin)

---

## VibeCheck (Post-Event Ratings)

### 1. Submit VibeCheck

**Endpoint:** `POST /api/v1/events/:event_id/vibe_checks`

**Description:** Submit post-event rating/review. Only available after event has ended and if you attended.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "overall_rating": 5,
  "atmosphere_rating": 5,
  "music_rating": 4,
  "crowd_rating": 4,
  "service_rating": 5,
  "value_rating": 4,
  "review": "Amazing event! Great vibes and music.",
  "highlights": "DJ was incredible, crowd was energetic",
  "lowlights": "Drinks were a bit expensive",
  "would_return": true,
  "would_recommend": true
}
```

**Parameters:**
- `overall_rating` (integer, required): 1-5 stars
- `atmosphere_rating` (integer, optional): 1-5 stars
- `music_rating` (integer, optional): 1-5 stars
- `crowd_rating` (integer, optional): 1-5 stars
- `service_rating` (integer, optional): 1-5 stars
- `value_rating` (integer, optional): 1-5 stars
- `review` (text, optional): Written review
- `highlights` (text, optional): What was good
- `lowlights` (text, optional): What could improve
- `would_return` (boolean, optional): Would attend again
- `would_recommend` (boolean, optional): Would recommend to friends

**Response:**
```json
{
  "status": 201,
  "message": "VibeCheck submitted successfully",
  "data": {
    "vibe_check": {
      "id": "vibecheck-id",
      "overall_rating": 5,
      "ratings": {
        "atmosphere": 5,
        "music": 4,
        "crowd": 4,
        "service": 5,
        "value": 4,
        "average": 4.4
      },
      "review": "Amazing event!",
      "would_return": true,
      "would_recommend": true
    }
  }
}
```

---

### 2. View Event VibeChecks

**Endpoint:** `GET /api/v1/events/:event_id/vibe_checks`

**Description:** View all VibeChecks for an event.

**Authentication:** Optional

**Query Parameters:**
- `min_rating` (integer, optional): Filter by minimum rating

**Response:**
```json
{
  "data": {
    "event": {
      "id": "event-id",
      "title": "Concert Night",
      "vibe_check_rating": 4.5,
      "vibe_checks_count": 42
    },
    "vibe_checks": [
      {
        "id": "vibecheck-id",
        "overall_rating": 5,
        "ratings": {...},
        "review": "Amazing event!",
        "user": {
          "id": "user-id",
          "name": "John Doe"
        },
        "helpful_count": 12,
        "created_at": "2025-12-11T10:00:00Z"
      }
    ]
  }
}
```

---

### 3. My VibeChecks

**Endpoint:** `GET /api/v1/vibe_checks/my_checks`

**Description:** View your submitted VibeChecks.

**Authentication:** Bearer token required

---

## Event Reviews

Event reviews allow users to rate and review events with a 1-5 star rating (displayed as 1-10 scale) and optional comments. Reviews are separate from VibeChecks - reviews can be submitted anytime, while VibeChecks are post-event detailed ratings.

### 1. List Event Reviews

**Endpoint:** `GET /api/v1/events/:event_id/reviews`

**Description:** Get all approved reviews for an event. Shows reviewer information, rating (out of 10), and comments.

**Authentication:** Not required

**Query Parameters:**
- `min_rating` (integer, optional): Filter by minimum rating (1-5)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "event": {
      "id": "event_id",
      "title": "Concert Night",
      "average_rating": 4.5,
      "reviews_count": 25
    },
    "reviews": [
      {
        "id": "review_id",
        "rating": 4,
        "rating_out_of_10": 8.0,
        "comment": "Amazing event! Great music and atmosphere.",
        "moderation_status": "approved",
        "published_at": "2026-02-09T10:00:00Z",
        "user": {
          "id": "user_id",
          "name": "John Doe",
          "username": "johndoe",
          "avatar_url": "https://vibesapp.digital4design.com/rails/active_storage/blobs/.../avatar.jpg"
        },
        "event": {
          "id": "event_id",
          "title": "Concert Night",
          "name": "Concert Night"
        },
        "created_at": "2026-02-09T10:00:00Z",
        "updated_at": "2026-02-09T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  }
}
```

**Response Fields:**
- `rating`: Rating on 1-5 scale (stored in database)
- `rating_out_of_10`: Rating converted to 1-10 scale for display (e.g., 4 → 8.0)
- `comment`: Review text/comment
- `user`: Reviewer information (id, name, username, avatar_url)
- `event`: Event information (id, title, name)

---

### 2. Get Single Review

**Endpoint:** `GET /api/v1/events/:event_id/reviews/:id`

**Description:** Get a specific review by ID.

**Authentication:** Not required

**Response:**
```json
{
  "status": 200,
  "data": {
    "review": {
      "id": "review_id",
      "rating": 5,
      "rating_out_of_10": 10.0,
      "comment": "Best event ever!",
      "user": {
        "id": "user_id",
        "name": "Jane Smith",
        "username": "janesmith",
        "avatar_url": "https://..."
      },
      "event": {
        "id": "event_id",
        "title": "Concert Night"
      },
      "created_at": "2026-02-09T10:00:00Z"
    }
  }
}
```

---

### 3. Get My Review

**Endpoint:** `GET /api/v1/events/:event_id/reviews/my_review`

**Description:** Get your review for an event (if you've reviewed it).

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "review": {
      "id": "review_id",
      "rating": 4,
      "rating_out_of_10": 8.0,
      "comment": "Great event!",
      "user": {...},
      "event": {...},
      "created_at": "2026-02-09T10:00:00Z"
    }
  }
}
```

If no review exists:
```json
{
  "status": 200,
  "message": "You have not reviewed this event yet",
  "data": {
    "review": null
  }
}
```

---

### 4. Create Review

**Endpoint:** `POST /api/v1/events/:event_id/reviews`

**Description:** Create a review for an event. One review per user per event.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "review": {
    "rating": 4,
    "comment": "Amazing event! Great music and atmosphere. Will definitely attend again."
  }
}
```

**Parameters:**
- `rating` (integer, required): Rating from 1-5 stars
- `comment` (text, optional): Review comment/text

**Response:**
```json
{
  "status": 201,
  "message": "Review created successfully",
  "data": {
    "review": {
      "id": "review_id",
      "rating": 4,
      "rating_out_of_10": 8.0,
      "comment": "Amazing event!",
      "user": {
        "id": "user_id",
        "name": "John Doe",
        "username": "johndoe",
        "avatar_url": "https://..."
      },
      "event": {
        "id": "event_id",
        "title": "Concert Night"
      },
      "created_at": "2026-02-09T10:00:00Z"
    }
  }
}
```

**Errors:**
- `400`: You have already reviewed this event. Use update to modify your review.
- `422`: Validation errors (invalid rating, etc.)

---

### 5. Update Review

**Endpoint:** `PATCH /api/v1/events/:event_id/reviews/:id`

**Description:** Update your own review for an event.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "review": {
    "rating": 5,
    "comment": "Updated: Even better than I thought!"
  }
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Review updated successfully",
  "data": {
    "review": {
      "id": "review_id",
      "rating": 5,
      "rating_out_of_10": 10.0,
      "comment": "Updated: Even better than I thought!",
      "updated_at": "2026-02-09T11:00:00Z"
    }
  }
}
```

**Errors:**
- `403`: You can only modify your own reviews
- `404`: Review not found

---

### 6. Delete Review

**Endpoint:** `DELETE /api/v1/events/:event_id/reviews/:id`

**Description:** Delete your own review for an event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Review deleted successfully"
}
```

**Errors:**
- `403`: You can only modify your own reviews
- `404`: Review not found

---

### Notes

- **Rating Scale**: Reviews are stored with a 1-5 scale but displayed as 1-10 in the API response (`rating_out_of_10` field)
- **One Review Per User**: Each user can only create one review per event. To change it, use the update endpoint.
- **Moderation**: Reviews go through moderation (`pending`, `approved`, `rejected`). Only approved reviews are shown in listings.
- **Event Response**: Event responses now include:
  - `reviews_count`: Total number of approved reviews
  - `average_rating_out_of_10`: Average rating converted to 1-10 scale
  - `rating`: Average rating (1-5 scale)
  - `ratings_count`: Total ratings count (includes both reviews and vibe checks)

---

## Map View

Map view endpoints for displaying venues and events on a map. Returns coordinates and essential information optimized for map rendering.

### Get Filter Options

**Endpoint:** `GET /api/v1/maps/filter_options`

**Description:** Get available filter options for the map view. Returns categories, time filters, statuses, radius options, and sort options.

**Authentication:** Not required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "categories": [
      "business",
      "social",
      "activities",
      "music",
      "sports",
      "arts",
      "food",
      "education",
      "health",
      "technology"
    ],
    "time_filters": [
      { "value": "today", "label": "Today" },
      { "value": "this_week", "label": "This Week" },
      { "value": "this_month", "label": "This Month" },
      { "value": "upcoming", "label": "Upcoming" },
      { "value": "live", "label": "Live Now" },
      { "value": "past", "label": "Past Events" }
    ],
    "event_statuses": [
      { "value": "published", "label": "Published" },
      { "value": "live", "label": "Live" },
      { "value": "completed", "label": "Completed" }
    ],
    "radius_options": [
      { "value": 1, "label": "1 km" },
      { "value": 5, "label": "5 km" },
      { "value": 10, "label": "10 km" },
      { "value": 25, "label": "25 km" },
      { "value": 50, "label": "50 km" },
      { "value": 100, "label": "100 km" }
    ],
    "sort_options": [
      { "value": "distance", "label": "Distance" },
      { "value": "date", "label": "Date" },
      { "value": "popularity", "label": "Popularity" },
      { "value": "rating", "label": "Rating" }
    ]
  }
}
```

---

### Get Map Data (Venues & Events)

**Endpoint:** `GET /api/v1/maps`

**Description:** Get venues and events with coordinates for map display. Supports bounding box filtering, radius search, and various filters.

**Authentication:** Bearer token optional (required for private events)

**Query Parameters:**

**Bounding Box Filter:**
- `north` (decimal): North latitude boundary
- `south` (decimal): South latitude boundary
- `east` (decimal): East longitude boundary
- `west` (decimal): West longitude boundary

**Radius Search:**
- `center_latitude` (decimal): Center point latitude
- `center_longitude` (decimal): Center point longitude
- `radius_km` (decimal, optional): Search radius in kilometers (default: 10)

**General Filters:**
- `city` (string, optional): Filter by city
- `country` (string, optional): Filter by country
- `search` (string, optional): Search venues/events by name/title
- `limit` (integer, optional): Max number of results (default: 100, max: 500)

**Display Filters:**
- `show_venues` (boolean, optional): Show venues on map (default: true)
- `show_events` (boolean, optional): Show events on map (default: true)

**Event-Specific Filters:**
- `event_status` (string, optional): Filter events by status (published, live, etc.)
- `time_filter` (string, optional): Filter events by time (upcoming, past, live, today, this_week, this_month)
- `category` (string, optional): Filter events by category (can be multiple: `category=business&category=social`)
- `start_date` (datetime, optional): Filter events starting from this date
- `end_date` (datetime, optional): Filter events ending before this date
- `max_age_restriction` (integer, optional): Maximum age restriction for events

**Popularity & Quality Filters:**
- `min_rating` (decimal, optional): Minimum rating (0-5) for venues
- `min_bookings` (integer, optional): Minimum number of bookings for events
- `min_likes` (integer, optional): Minimum number of likes for venues/events

**Sorting:**
- `sort_by` (string, optional): Sort by `date`, `popularity`, or `rating` (default: date)
- `sort_order` (string, optional): Sort order `asc` or `desc` (default: asc)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "venues": [
      {
        "id": "venue_uuid",
        "type": "venue",
        "name": "The Grand Club",
        "coordinates": {
          "latitude": 18.4655,
          "longitude": -66.1057
        },
        "address": {
          "city": "San Juan",
          "country": "Puerto Rico",
          "full_address": "123 Main St, San Juan, PR 00901"
        },
        "rating": {
          "average": 4.5,
          "count": 25
        },
        "likes_count": 150,
        "status": "active"
      }
    ],
    "events": [
      {
        "id": "event_uuid",
        "type": "event",
        "title": "Networking Mixer",
        "coordinates": {
          "latitude": 18.4655,
          "longitude": -66.1057
        },
        "starts_at": "2025-12-01T19:00:00Z",
        "ends_at": "2025-12-01T23:00:00Z",
        "status": "published",
        "category": "business",
        "is_live": false,
        "is_upcoming": true,
        "address": {
          "city": "San Juan",
          "country": "Puerto Rico",
          "full_address": "123 Main St, San Juan, PR 00901"
        },
        "venue": {
          "id": "venue_uuid",
          "name": "The Grand Club"
        },
        "bookings_count": 45,
        "likes_count": 120,
        "interests_count": 200
      }
    ],
    "bounds": {
      "north": 18.5000,
      "south": 18.4000,
      "east": -66.0500,
      "west": -66.1500,
      "center": {
        "latitude": 18.4500,
        "longitude": -66.1000
      }
    },
    "metadata": {
      "venues_count": 10,
      "events_count": 25,
      "total_markers": 35
    }
  }
}
```

**Usage Examples:**

1. **Get all venues and events:**
   ```
   GET /api/v1/maps?limit=100
   ```

2. **Filter by bounding box (map viewport):**
   ```
   GET /api/v1/maps?north=18.5&south=18.4&east=-66.05&west=-66.15
   ```

3. **Search within radius:**
   ```
   GET /api/v1/maps?center_latitude=18.4655&center_longitude=-66.1057&radius_km=5
   ```

4. **Filter by city and upcoming events:**
   ```
   GET /api/v1/maps?city=San Juan&time_filter=upcoming
   ```

5. **Search with filters:**
   ```
   GET /api/v1/maps?search=networking&category=business&event_status=published
   ```

6. **Filter by popularity and rating:**
   ```
   GET /api/v1/maps?min_rating=4.0&min_bookings=10&sort_by=popularity
   ```

7. **Show only events (hide venues):**
   ```
   GET /api/v1/maps?show_venues=false&time_filter=upcoming
   ```

8. **Filter by age restriction:**
   ```
   GET /api/v1/maps?max_age_restriction=21&category=social
   ```

**Notes:**
- Only venues and events with valid coordinates are returned
- Events use their own coordinates if available, otherwise venue coordinates
- Bounding box and radius search can be combined with other filters
- The `bounds` object is calculated from all returned items and can be used to fit the map view
- Venues are filtered to active status only
- Events default to published/live status unless otherwise specified

---

## Likes

**Important:** Likes are different from RSVP/Interests:
- **Likes**: Simple like/unlike action - just shows appreciation for an event (like a Facebook like)
- **RSVP/Interests**: RSVP with status (yes/no/maybe), guest count, and notes - indicates attendance intent

Use **Likes** when you just want to show you like an event.  
Use **RSVP/Interests** when you want to indicate you're attending, not attending, or maybe attending.

---

### 1. Toggle Event Like

**Endpoint:** `PUT /api/v1/events/:event_id/likes/toggle`  
**Alternative:** `PATCH /api/v1/events/:event_id/likes/toggle`

**Description:** Toggle like/unlike for an event. If the event is already liked, it will be unliked. If not liked, it will be liked. This is a single endpoint that handles both actions.

**Authentication:** Bearer token required

**Response (When Liking):**
```json
{
  "data": {
    "liked": true,
    "like": {
      "id": "like_id",
      "user": {
        "id": "user_id",
        "name": "John Doe"
      },
      "created_at": "2025-10-08T12:00:00Z"
    },
    "likes_count": 24
  },
  "message": "Liked successfully",
  "status": "ok"
}
```

**Response (When Unliking):**
```json
{
  "data": {
    "liked": false,
    "likes_count": 23
  },
  "message": "Unliked successfully",
  "status": "ok"
}
```

**Note:** The old `POST /api/v1/events/:event_id/likes` and `DELETE /api/v1/events/:event_id/likes` endpoints are still available for backward compatibility, but the toggle endpoint is recommended for new implementations.

---

### 2. Check Event Like

**Endpoint:** `GET /api/v1/events/:event_id/likes/check`

**Description:** Check if current user has liked an event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "liked": true,
    "likes_count": 23
  }
}
```

---

### 3. List Event Likes

**Endpoint:** `GET /api/v1/events/:event_id/likes`

**Description:** List all users who liked an event.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results
- `offset` (integer, optional): Pagination offset

---

## Event Interests & RSVP

There are **three separate ways** users can interact with events:

1. **Like** - Simple like/unlike (showing appreciation) - See "Event Likes" section
2. **Interest** - Simple "I'm interested" (boolean, no RSVP status) - This section
3. **RSVP/Join** - Full RSVP with status (yes/no/maybe), guest count, and notes - This section

**Important:** 
- **Like** is separate from Interest and RSVP
- **Interest** is a simple boolean - just shows you're interested
- **RSVP/Join** includes attendance status (yes/no/maybe), guest count, and notes
- Users can have both Interest and RSVP, but typically use one or the other
- If a user has RSVP, they cannot mark simple Interest (must remove RSVP first)
- If a user marks Interest and then RSVPs, the Interest is converted to RSVP

---

## Event Interest (Simple Boolean Interest)

Simple interest system - users can mark that they're interested in an event without providing RSVP status.

### 1. Toggle Interest (Recommended)

**Endpoint:** `POST /api/v1/events/:event_id/interests/toggle`

**Description:** Toggle simple interest in an event (mark if not interested, remove if interested). This is the recommended endpoint as it combines mark and remove into a single API call. Returns the new interest state.

**Authentication:** Bearer token required

**Request Body:** None (or empty JSON `{}`)

**Response (Interest Marked - 200 OK):**
```json
{
  "success": true,
  "message": "Interest marked successfully",
  "data": {
    "interested": true,
    "interest": {
      "id": "interest_uuid",
      "created_at": "2025-11-26T08:00:00Z"
    },
    "interests_count": 25
  },
  "status": "ok"
}
```

**Response (Interest Removed - 200 OK):**
```json
{
  "success": true,
  "message": "Interest removed successfully",
  "data": {
    "interested": false,
    "interest": null,
    "interests_count": 24
  },
  "status": "ok"
}
```

**Error Response (If user already has RSVP):**
```json
{
  "success": false,
  "message": "You already have an RSVP for this event. Remove RSVP first to toggle simple interest.",
  "status": "bad_request"
}
```

---

### 2. Mark Interest (Legacy)

**Endpoint:** `POST /api/v1/events/:event_id/interests`

**Description:** Mark simple interest in an event (boolean - no RSVP status). This is different from RSVP which includes attendance status. **Note:** Use the Toggle Interest endpoint instead for better UX.

**Authentication:** Bearer token required

**Request Body:** None (or empty JSON `{}`)

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Interest marked successfully",
  "data": {
    "interest": {
      "id": "interest_uuid",
      "interested": true,
      "created_at": "2025-11-26T08:00:00Z"
    },
    "interests_count": 25
  },
  "status": "created"
}
```

**Error Response (If user already has RSVP):**
```json
{
  "success": false,
  "message": "You already have an RSVP for this event. Remove RSVP first to mark simple interest.",
  "status": "bad_request"
}
```

---

### 3. Remove Interest (Legacy)

**Endpoint:** `DELETE /api/v1/events/:event_id/interests`

**Description:** Remove simple interest from an event. **Note:** Use the Toggle Interest endpoint instead for better UX.

**Authentication:** Bearer token required

**Response:**
```json
{
  "success": true,
  "message": "Interest removed successfully",
  "data": {
    "interests_count": 24
  },
  "status": "ok"
}
```

---

### 4. Check Interest Status

**Endpoint:** `GET /api/v1/events/:event_id/interests/check`

**Description:** Check if current user has marked simple interest in the event.

**Authentication:** Bearer token required

**Response (Has Interest):**
```json
{
  "success": true,
  "data": {
    "interested": true
  },
  "status": "ok"
}
```

**Response (No Interest):**
```json
{
  "success": true,
  "data": {
    "interested": false
  },
  "status": "ok"
}
```

---

### 5. List Event Interests

**Endpoint:** `GET /api/v1/events/:event_id/interests`

**Description:** List all users who have marked simple interest (not RSVP) in an event.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Networking Mixer",
    "interests": [
      {
        "id": "interest_uuid",
        "user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "created_at": "2025-11-26T08:00:00Z"
      }
    ],
    "interests_count": 25,
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  },
  "status": "ok"
}
```

---

## Event RSVP (Full RSVP with Status)

RSVP (Répondez s'il vous plaît) system for events. Users can respond to event invitations with yes, no, or maybe. RSVP is different from booking - it's free and doesn't require payment, while booking may require payment for paid events.

### RSVP Status Types

- **yes**: User is attending the event
- **no**: User is not attending the event
- **maybe**: User is interested but not confirmed

### 1. RSVP to Event (Join/RSVP)

**Endpoint:** `POST /api/v1/events/:event_id/rsvp`

**Description:** RSVP to an event or update existing RSVP. Supports yes, no, maybe responses with guest count and notes. This is the "Join" or "RSVP" functionality - different from "Like" which is just showing appreciation.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "rsvp_status": "yes",
  "guest_count": 1,
  "notes": "Looking forward to it!"
}
```

**Parameters:**
- `rsvp_status` (string, optional): RSVP status - `yes`, `no`, or `maybe` (default: `yes`)
- `guest_count` (integer, optional): Number of additional guests (default: 0)
- `notes` (string, optional): Optional notes or comments

**Response (New RSVP - 201 Created):**
```json
{
  "success": true,
  "message": "RSVP updated successfully",
  "data": {
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "yes",
      "guest_count": 1,
      "total_attendees": 2,
      "notes": "Looking forward to it!",
      "responded_at": "2025-11-26T08:00:00Z",
      "created_at": "2025-11-26T08:00:00Z"
    },
    "rsvp_stats": {
      "yes_count": 45,
      "no_count": 5,
      "maybe_count": 10,
      "total_count": 60
    }
  },
  "status": "created"
}
```

**Response (Updated RSVP - 200 OK):**
```json
{
  "success": true,
  "message": "RSVP updated successfully",
  "data": {
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "yes",
      "guest_count": 1,
      "total_attendees": 2,
      "notes": "Looking forward to it!",
      "responded_at": "2025-11-26T08:00:00Z",
      "created_at": "2025-11-26T08:00:00Z"
    },
    "rsvp_stats": {
      "yes_count": 45,
      "no_count": 5,
      "maybe_count": 10,
      "total_count": 60
    }
  },
  "status": "ok"
}
```

### 1b. Approve RSVP (User)

**Endpoint:** `POST /api/v1/events/:event_id/rsvp/approve`

**Description:** User-level RSVP approval (intent only). Sets RSVP status to `yes` without creating a booking.

**Authentication:** Bearer token required

**Request Body (optional):**
```json
{
  "guest_count": 1,
  "notes": "Looking forward to it!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "RSVP approved successfully",
  "data": {
    "rsvp": {
      "id": "rsvp_uuid",
      "rsvp_status": "yes",
      "guest_count": 1,
      "total_attendees": 2,
      "notes": "Looking forward to it!",
      "responded_at": "2025-11-26T08:00:00Z",
      "created_at": "2025-11-26T08:00:00Z"
    },
    "rsvp_stats": {
      "yes_count": 46,
      "no_count": 5,
      "maybe_count": 10,
      "total_count": 61
    }
  },
  "status": "ok"
}
```

---

### 2. Remove RSVP (Unjoin)

**Endpoint:** `DELETE /api/v1/events/:event_id/rsvp`

**Description:** Remove your RSVP from an event (unjoin).

**Authentication:** Bearer token required

**Response:**
```json
{
  "success": true,
  "message": "RSVP removed successfully",
  "data": {
    "rsvp_stats": {
      "yes_count": 44,
      "no_count": 5,
      "maybe_count": 10,
      "total_count": 59
    }
  },
  "status": "ok"
}
```

---

### 3. Check RSVP Status

**Endpoint:** `GET /api/v1/events/:event_id/rsvp/check`

**Description:** Check your RSVP status for an event. Returns yes, no, maybe, or null if not RSVP'd.

**Authentication:** Bearer token required

**Response (With RSVP):**
```json
{
  "success": true,
  "data": {
    "has_rsvp": true,
      "rsvp_status": "yes",
      "guest_count": 1,
      "total_attendees": 2,
      "notes": "Looking forward to it!",
      "responded_at": "2025-11-26T08:00:00Z"
    },
  "status": "ok"
}
```

**Response (No RSVP):**
```json
{
  "success": true,
  "data": {
    "has_rsvp": false,
    "rsvp_status": null,
    "guest_count": null,
    "total_attendees": null,
    "notes": null,
    "responded_at": null
  },
  "status": "ok"
}
```

---

### 4. List Event RSVPs

**Endpoint:** `GET /api/v1/events/:event_id/rsvp`

**Description:** List all RSVPs for an event. Can filter by RSVP status.

**Authentication:** Bearer token required

**Query Parameters:**
- `rsvp_status` (string, optional): Filter by RSVP status (`yes`, `no`, `maybe`)
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Networking Mixer",
    "rsvps": [
      {
        "id": "rsvp_uuid",
        "user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "rsvp_status": "yes",
        "guest_count": 1,
        "total_attendees": 2,
        "notes": "Looking forward to it!",
        "responded_at": "2025-11-26T08:00:00Z",
        "created_at": "2025-11-26T08:00:00Z"
      }
    ],
    "rsvp_stats": {
      "yes_count": 45,
      "no_count": 5,
      "maybe_count": 10,
      "total_count": 60
    },
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 60,
      "has_more": true
    }
  },
  "status": "ok"
}
```

---

### RSVP vs Booking

**RSVP:**
- Free - no payment required
- Expresses interest/attendance intent
- Supports yes/no/maybe responses
- Can include guest count
- Can add notes

**Booking:**
- May require payment for paid events
- Confirmed reservation
- Required for paid events
- Can be checked in at event
- Linked to payment transactions

**Usage:**
- Use RSVP for free events or to express interest
- Use Booking for paid events or when payment is required
- Users can both RSVP and Book the same event

---

## Creating an Artist

Before linking an artist to an event, you need to create a user with the `artist` role. Artists are regular users with `role: 'artist'`.

### Register User as Artist

**Option 1: Register with Email/Password**

**Endpoint:** `POST /api/v1/auth/register`

**Request Body:**
```json
{
  "user": {
    "email": "artist@example.com",
    "phone": "+1234567890",
    "password": "Password123",
    "password_confirmation": "Password123",
    "name": "John Artist",
    "username": "johnartist",
    "role": "artist"
  }
}
```

**Option 2: Register with OTP Flow**

```bash
# Step 1: Send OTP
POST /api/v1/auth/send_otp
{
  "phone": "+1234567890"
}

# Step 2: Verify OTP
POST /api/v1/auth/verify_otp
{
  "phone": "+1234567890",
  "otp": "123456"
}

# Step 3: Complete registration with artist role
POST /api/v1/auth/complete_registration
{
  "verification_token": "token_from_step_2",
  "name": "John Artist",
  "username": "johnartist",
  "role": "artist"
}
```

**Important Notes:**
- The `role` must be set during registration (`consumer`, `artist`, `venue_manager`, or `admin`)
- The role cannot be changed via the regular user update endpoint
- Only admins can change user roles directly in the database
- Once you have the artist user ID, you can link them to events

---

## Event Artists

### 1. List Event Artists

**Endpoint:** `GET /api/v1/events/:event_id/artists`

**Description:** List all artists scheduled for an event with their time slots.

**Authentication:** Bearer token required

**Query Parameters:**
- `status` (string, optional): Filter by status (`confirmed`, `pending`, `cancelled`)

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Summer Music Festival",
    "artists": [
      {
        "id": "event_artist_uuid",
        "event_id": "event_uuid",
        "artist": {
          "id": "artist_user_uuid",
          "name": "John Artist",
          "username": "johnartist",
          "role": "artist",
          "avatar_url": null
        },
        "schedule": {
          "scheduled_start_at": "2025-12-01T20:00:00Z",
          "scheduled_end_at": "2025-12-01T21:30:00Z",
          "timezone": "UTC",
          "duration_minutes": 90,
          "duration_hours": 1.5
        },
        "display_order": 1,
        "description": "Opening act performance",
        "status": "confirmed",
        "is_live": false,
        "is_upcoming": true,
        "is_past": false,
        "created_at": "2025-11-20T10:00:00Z",
        "updated_at": "2025-11-20T10:00:00Z"
      }
    ]
  }
}
```

---

### 2. Get Event Artist

**Endpoint:** `GET /api/v1/events/:event_id/artists/:id`

**Description:** Get details of a specific artist's schedule for an event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_artist": {
      "id": "event_artist_uuid",
      "event_id": "event_uuid",
      "artist": {
        "id": "artist_user_uuid",
        "name": "John Artist",
        "username": "johnartist",
        "role": "artist",
        "avatar_url": null
      },
      "schedule": {
        "scheduled_start_at": "2025-12-01T20:00:00Z",
        "scheduled_end_at": "2025-12-01T21:30:00Z",
        "timezone": "UTC",
        "duration_minutes": 90,
        "duration_hours": 1.5
      },
      "display_order": 1,
      "description": "Opening act performance",
      "status": "confirmed",
      "is_live": false,
      "is_upcoming": true,
      "is_past": false
    }
  }
}
```

---

### 3. Add Artist to Event

**Endpoint:** `POST /api/v1/events/:event_id/artists`

**Description:** Add an artist to an event with a scheduled time slot. Only venue owner or admin can add artists.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "event_artist": {
    "scheduled_start_at": "2025-12-01T20:00:00Z",
    "scheduled_end_at": "2025-12-01T21:30:00Z",
    "timezone": "UTC",
    "display_order": 1,
    "description": "Opening act performance",
    "status": "confirmed"
  },
  "artist_id": "artist_user_uuid"
}
```

**Parameters:**
- `artist_id` (string, required): ID of the artist user (must have artist role)
- `event_artist.scheduled_start_at` (datetime, required): When the artist's performance starts
- `event_artist.scheduled_end_at` (datetime, required): When the artist's performance ends
- `event_artist.timezone` (string, optional): Timezone (defaults to event timezone)
- `event_artist.display_order` (integer, optional): Order for display (defaults to end of list)
- `event_artist.description` (string, optional): Description of the performance
- `event_artist.status` (string, optional): Status - `confirmed`, `pending`, or `cancelled` (default: `confirmed`)

**Response:**
```json
{
  "status": 201,
  "message": "Artist added to event successfully",
  "data": {
    "event_artist": {
      "id": "event_artist_uuid",
      "event_id": "event_uuid",
      "artist": {
        "id": "artist_user_uuid",
        "name": "John Artist",
        "username": "johnartist",
        "role": "artist"
      },
      "schedule": {
        "scheduled_start_at": "2025-12-01T20:00:00Z",
        "scheduled_end_at": "2025-12-01T21:30:00Z",
        "timezone": "UTC",
        "duration_minutes": 90,
        "duration_hours": 1.5
      },
      "display_order": 1,
      "description": "Opening act performance",
      "status": "confirmed"
    }
  }
}
```

**Validation Rules:**
- Artist must have `artist` role
- Artist cannot be added twice to the same event
- Scheduled times must be within event start/end times
- Scheduled end time must be after start time

**Complete Flow Example:**
1. Register a user with `role: "artist"` using `/api/v1/auth/register` or OTP flow
2. Get the artist user ID from the registration response
3. Link the artist to an event using this endpoint with the `artist_id`
4. The artist will appear in the event's artists list and in event details

---

### 4. Update Artist Schedule

**Endpoint:** `PATCH /api/v1/events/:event_id/artists/:id`

**Description:** Update an artist's schedule for an event.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "event_artist": {
    "scheduled_start_at": "2025-12-01T20:15:00Z",
    "scheduled_end_at": "2025-12-01T21:45:00Z",
    "display_order": 1,
    "description": "Updated opening act performance"
  }
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Artist schedule updated successfully",
  "data": {
    "event_artist": {
      "id": "event_artist_uuid",
      "schedule": {
        "scheduled_start_at": "2025-12-01T20:15:00Z",
        "scheduled_end_at": "2025-12-01T21:45:00Z",
        "duration_minutes": 90
      },
      "display_order": 1,
      "description": "Updated opening act performance"
    }
  }
}
```

---

### 5. Remove Artist from Event

**Endpoint:** `DELETE /api/v1/events/:event_id/artists/:id`

**Description:** Remove an artist from an event.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Artist removed from event successfully"
}
```

---

### 6. Cancel Artist Schedule

**Endpoint:** `POST /api/v1/events/:event_id/artists/:id/cancel`

**Description:** Cancel an artist's schedule (marks as cancelled but keeps in event).

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Artist schedule cancelled successfully",
  "data": {
    "event_artist": {
      "id": "event_artist_uuid",
      "status": "cancelled"
    }
  }
}
```

---

### 7. Confirm Artist Schedule

**Endpoint:** `POST /api/v1/events/:event_id/artists/:id/confirm`

**Description:** Confirm an artist's schedule (changes status from pending to confirmed).

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Artist schedule confirmed successfully",
  "data": {
    "event_artist": {
      "id": "event_artist_uuid",
      "status": "confirmed"
    }
  }
}
```

---

### 8. Bulk Add Artists (Transactional - All or Nothing)

**Endpoint:** `POST /api/v1/events/:event_id/artists/bulk`

**Description:** Add multiple artists to an event at once using a transactional approach. **If ANY artist fails validation or cannot be added, NONE of the artists will be added.** All artists must succeed for the operation to complete. Only venue owner or admin can add artists.

**Authentication:** Bearer token required

**Request Body (Simple - uses event times as default schedule):**
```json
{
  "artist_ids": ["artist_uuid_1", "artist_uuid_2", "artist_uuid_3"]
}
```

**Request Body (Detailed - with custom schedules):**
```json
{
  "artists": [
    {
      "artist_id": "artist_uuid_1",
      "scheduled_start_at": "2025-12-01T20:00:00Z",
      "scheduled_end_at": "2025-12-01T21:00:00Z",
      "description": "Opening act",
      "status": "confirmed"
    },
    {
      "artist_id": "artist_uuid_2",
      "scheduled_start_at": "2025-12-01T21:00:00Z",
      "scheduled_end_at": "2025-12-01T23:00:00Z",
      "description": "Main performance",
      "status": "pending"
    }
  ]
}
```

**Parameters (for detailed format):**
- `artist_id` (string, required): ID of the artist user
- `scheduled_start_at` (datetime, optional): Performance start time (defaults to event start)
- `scheduled_end_at` (datetime, optional): Performance end time (defaults to event end)
- `timezone` (string, optional): Timezone (defaults to event timezone)
- `display_order` (integer, optional): Order for display (auto-assigned if not provided)
- `description` (string, optional): Description of the performance
- `status` (string, optional): `confirmed`, `pending`, or `cancelled` (default: `pending`)

**Response (Success - All Artists Added):**
```json
{
  "success": true,
  "message": "Successfully added 3 artist(s) to event",
  "data": {
    "event_id": "event_uuid",
    "event_title": "My Event",
    "artists": [
      {
        "id": "event_artist_uuid_1",
        "event_id": "event_uuid",
        "artist": {
          "id": "artist_uuid_1",
          "name": "Artist One",
          "username": "artist1",
          "role": "artist"
        },
        "schedule": {
          "scheduled_start_at": "2025-12-01T20:00:00Z",
          "scheduled_end_at": "2025-12-01T21:00:00Z",
          "timezone": "UTC",
          "duration_minutes": 60
        },
        "display_order": 0,
        "status": "confirmed"
      }
    ],
    "count": 3
  },
  "status": "created"
}
```

**Response (Failure - Validation Errors, No Artists Added):**
```json
{
  "success": false,
  "message": "Validation failed for one or more artists. No artists were added.",
  "status": "bad_request",
  "data": {
    "errors": [
      {
        "index": 0,
        "artist_id": "invalid_uuid",
        "error": "Artist not found"
      },
      {
        "index": 2,
        "artist_id": "artist_uuid_2",
        "error": "Artist already added to event"
      }
    ]
  }
}
```

**Response (Failure - Save Error, No Artists Added):**
```json
{
  "success": false,
  "message": "Failed to add one or more artists. No artists were added.",
  "status": "unprocessable_entity",
  "data": {
    "error": {
      "index": 1,
      "artist_id": "artist_uuid_2",
      "error": "Validation failed: Scheduled start time cannot be before event start time"
    }
  }
}
```

**Important Notes:**
- **Transactional Behavior:** If any artist fails validation or cannot be saved, the entire operation is rolled back and NO artists are added
- **Single Response:** You will receive either a success response (all artists added) or an error response (no artists added)
- **No Partial Success:** Unlike previous versions, this endpoint does not support partial success - it's all or nothing

---

### 9. Bulk Remove Artists

**Endpoint:** `DELETE /api/v1/events/:event_id/artists/bulk`

**Description:** Remove multiple artists from an event at once. Only venue owner or admin can remove artists.

**Authentication:** Bearer token required

**Request Body (by artist user IDs):**
```json
{
  "artist_ids": ["artist_uuid_1", "artist_uuid_2"]
}
```

**Request Body (by event_artist IDs):**
```json
{
  "event_artist_ids": ["event_artist_uuid_1", "event_artist_uuid_2"]
}
```

**Response:**
```json
{
  "status": 200,
  "message": "2 artist(s) removed successfully",
  "data": {
    "event_id": "event_uuid",
    "removed_count": 2,
    "removed": [
      { "artist_id": "artist_uuid_1" },
      { "artist_id": "artist_uuid_2" }
    ],
    "errors": []
  }
}
```

**Note:** Event responses now include an `artists` array with all confirmed artists and their schedules. Artists are ordered by `display_order` and `scheduled_start_at`.

---

## Event Posts

Users can create posts with photos within events. Posts are visible to all users who have access to the event.

### 1. List Event Posts

**Endpoint:** `GET /api/v1/events/:event_id/posts`

**Description:** Get all posts for an event, ordered by most recent first.

**Authentication:** Bearer token required

**Query Parameters:**
- `user_id` (string, optional): Filter posts by specific user
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "event_id": "event_uuid",
    "event_title": "Summer Music Festival",
    "posts": [
      {
        "id": "post_uuid",
        "event_id": "event_uuid",
        "user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe",
          "role": "consumer",
          "avatar_url": null
        },
        "content": "Having an amazing time at the festival! 🎵",
        "photos": [
          "https://example.com/rails/active_storage/blobs/.../photo1.jpg",
          "https://example.com/rails/active_storage/blobs/.../photo2.jpg"
        ],
        "photos_count": 2,
        "has_photos": true,
        "likes_count": 15,
        "user_liked": false,
        "status": "active",
        "created_at": "2025-11-26T10:00:00Z",
        "updated_at": "2025-11-26T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 45,
      "has_more": true
    }
  }
}
```

---

### 2. Get Event Post

**Endpoint:** `GET /api/v1/events/:event_id/posts/:id`

**Description:** Get a specific post by ID.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "post": {
      "id": "post_uuid",
      "event_id": "event_uuid",
      "user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe",
        "role": "consumer"
      },
      "content": "Having an amazing time at the festival! 🎵",
      "photos": [
        "https://example.com/rails/active_storage/blobs/.../photo1.jpg"
      ],
      "photos_count": 1,
      "has_photos": true,
      "likes_count": 15,
      "user_liked": false,
      "status": "active",
      "created_at": "2025-11-26T10:00:00Z"
    }
  }
}
```

---

### 3. Create Event Post

**Endpoint:** `POST /api/v1/events/:event_id/posts`

**Description:** Create a new post in an event. Users can post if they are booked, interested, or are the venue owner. Posts can include text content and/or photos.

**Authentication:** Bearer token required

**Request Body (multipart/form-data):**
```
event_post[content]: "Having an amazing time at the festival! 🎵"
photos[]: [file1.jpg]
photos[]: [file2.jpg]
```

**Parameters:**
- `event_post[content]` (string, optional): Text content (max 5000 characters)
- `photos[]` (file array, optional): Up to 10 photos, each max 10MB

**Note:** Post must have either content or photos (or both).

**Response:**
```json
{
  "status": 201,
  "message": "Post created successfully",
  "data": {
    "post": {
      "id": "post_uuid",
      "event_id": "event_uuid",
      "user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "content": "Having an amazing time at the festival! 🎵",
      "photos": [
        "https://example.com/rails/active_storage/blobs/.../photo1.jpg"
      ],
      "photos_count": 1,
      "has_photos": true,
      "likes_count": 0,
      "user_liked": false,
      "status": "active",
      "created_at": "2025-11-26T10:00:00Z"
    }
  }
}
```

**Validation Rules:**
- User must be booked, interested, venue owner, or admin to post
- Post must have content or photos (or both)
- Maximum 10 photos per post
- Each photo must be less than 10MB
- Content maximum 5000 characters

---

### 4. Update Event Post

**Endpoint:** `PATCH /api/v1/events/:event_id/posts/:id`

**Description:** Update your own post. Can update content and add/remove photos.

**Authentication:** Bearer token required

**Request Body (multipart/form-data):**
```
event_post[content]: "Updated content"
photos[]: [new_photo.jpg]
remove_photo_ids[]: "photo_blob_id_1"
```

**Parameters:**
- `event_post[content]` (string, optional): Updated text content
- `photos[]` (file array, optional): New photos to add
- `remove_photo_ids[]` (string array, optional): IDs of photos to remove

**Response:**
```json
{
  "status": 200,
  "message": "Post updated successfully",
  "data": {
    "post": {
      "id": "post_uuid",
      "content": "Updated content",
      "photos": [
        "https://example.com/rails/active_storage/blobs/.../new_photo.jpg"
      ],
      "photos_count": 1
    }
  }
}
```

---

### 5. Delete Event Post

**Endpoint:** `DELETE /api/v1/events/:event_id/posts/:id`

**Description:** Delete your own post (soft delete).

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Post deleted successfully"
}
```

---

### 6. Like Event Post

**Endpoint:** `POST /api/v1/events/:event_id/posts/:id/like`

**Description:** Like a post.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Post liked successfully",
  "data": {
    "post": {
      "id": "post_uuid",
      "likes_count": 16,
      "user_liked": true
    }
  }
}
```

---

### 7. Unlike Event Post

**Endpoint:** `DELETE /api/v1/events/:event_id/posts/:id/like`

**Description:** Unlike a post.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Post unliked successfully",
  "data": {
    "post": {
      "id": "post_uuid",
      "likes_count": 15,
      "user_liked": false
    }
  }
}
```

**Note:** Event posts are included in event responses. The event model has `posts_count` and `recent_posts` methods available.

---

## Event Reporting

Users can report events for inappropriate content, spam, or violations. Reports are reviewed by administrators.

### 1. Report Event

**Endpoint:** `POST /api/v1/events/:id/report`

**Description:** Report an event for inappropriate content or violations.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "reason": "spam",
  "description": "This event appears to be spam"
}
```

**Parameters:**
- `reason` (string, required): Reason for reporting. Must be one of:
  - `spam`: Spam or promotional content
  - `inappropriate`: Inappropriate content
  - `misleading`: Misleading information
  - `duplicate`: Duplicate event
  - `violence`: Violent content
  - `harassment`: Harassment or bullying
  - `other`: Other reason
- `description` (string, optional): Additional details about the report

**Response:**
```json
{
  "data": {
    "report_id": "report_id",
    "event_id": "event_id",
    "event_title": "Networking Mixer",
    "reason": "spam",
    "status": "pending",
    "created_at": "2025-11-20T10:00:00Z"
  },
  "message": "Event reported successfully. Our team will review it shortly."
}
```

**Note:** Users cannot report their own events. One report per user per event.

---

### 2. Check Report Status

**Endpoint:** `GET /api/v1/events/:id/reports/check`

**Description:** Check if current user has reported an event and view report status.

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "event_id": "event_id",
    "reported": true,
    "report": {
      "id": "report_id",
      "reason": "spam",
      "status": "pending",
      "created_at": "2025-11-20T10:00:00Z"
    },
    "reports_count": 3
  }
}
```

---

### 3. Get Report Reasons

**Endpoint:** `GET /api/v1/events/report_reasons`

**Description:** Get list of available report reasons.

**Authentication:** None required

**Response:**
```json
{
  "data": {
    "reasons": [
      {
        "value": "spam",
        "label": "Spam"
      },
      {
        "value": "inappropriate",
        "label": "Inappropriate"
      },
      {
        "value": "misleading",
        "label": "Misleading"
      },
      {
        "value": "duplicate",
        "label": "Duplicate"
      },
      {
        "value": "violence",
        "label": "Violence"
      },
      {
        "value": "harassment",
        "label": "Harassment"
      },
      {
        "value": "other",
        "label": "Other"
      }
    ]
  }
}
```

---

### 4. List My Reports (User)

**Endpoint:** `GET /api/v1/reporting/my_reports`

**Description:** Get all reports submitted by the current user.

**Authentication:** Bearer token required

**Query Parameters:**
- `status` (string, optional): Filter by status (pending, reviewed, resolved, dismissed)
- `sort_by` (string, optional): Sort field (created_at, updated_at). Default: created_at
- `sort_order` (string, optional): Sort order (asc, desc). Default: desc
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "data": {
    "reports": [
      {
        "id": "report_id",
        "event": {
          "id": "event_id",
          "title": "Networking Mixer",
          "venue": {
            "id": "venue_id",
            "name": "The Grand Club"
          }
        },
        "reason": "spam",
        "description": "This event appears to be spam",
        "status": "pending",
        "created_at": "2025-11-20T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 5,
      "has_more": false
    }
  }
}
```

---

### 5. List All Reports (Admin)

**Endpoint:** `GET /api/v1/reporting`

**Description:** Get all event reports. Admin only.

**Authentication:** Bearer token required (Admin role)

**Query Parameters:**
- `status` (string, optional): Filter by status (pending, reviewed, resolved, dismissed)
- `reason` (string, optional): Filter by reason
- `event_id` (string, optional): Filter by event
- `sort_by` (string, optional): Sort field (created_at, updated_at). Default: created_at
- `sort_order` (string, optional): Sort order (asc, desc). Default: desc
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "data": {
    "reports": [
      {
        "id": "report_id",
        "event": {
          "id": "event_id",
          "title": "Networking Mixer",
          "venue": {
            "id": "venue_id",
            "name": "The Grand Club"
          }
        },
        "reporter": {
          "id": "user_id",
          "name": "John Doe",
          "username": "johndoe"
        },
        "reason": "spam",
        "description": "This event appears to be spam",
        "status": "pending",
        "created_at": "2025-11-20T10:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 15,
      "has_more": false
    }
  }
}
```

---

### 6. Get Report Details (Admin)

**Endpoint:** `GET /api/v1/reporting/:id`

**Description:** Get detailed information about a specific report. Admin only.

**Authentication:** Bearer token required (Admin role)

**Response:**
```json
{
  "data": {
    "report": {
      "id": "report_id",
      "event": {
        "id": "event_id",
        "title": "Networking Mixer",
        "venue": {
          "id": "venue_id",
          "name": "The Grand Club"
        }
      },
      "reporter": {
        "id": "user_id",
        "name": "John Doe",
        "username": "johndoe"
      },
      "reason": "spam",
      "description": "This event appears to be spam",
      "status": "pending",
      "reviewed_by": null,
      "admin_notes": null,
      "reviewed_at": null,
      "created_at": "2025-11-20T10:00:00Z",
      "updated_at": "2025-11-20T10:00:00Z"
    }
  }
}
```

---

### 7. Review Report (Admin)

**Endpoint:** `PATCH /api/v1/reporting/:id/review`

**Description:** Review and update the status of a report. Admin only.

**Authentication:** Bearer token required (Admin role)

**Request Body:**
```json
{
  "status": "resolved",
  "admin_notes": "Event has been reviewed and removed"
}
```

**Parameters:**
- `status` (string, required): New status (pending, reviewed, resolved, dismissed)
- `admin_notes` (string, optional): Admin notes about the review

**Response:**
```json
{
  "data": {
    "report": {
      "id": "report_id",
      "status": "resolved",
      "reviewed_by": {
        "id": "admin_id",
        "name": "Admin User",
        "username": "admin"
      },
      "admin_notes": "Event has been reviewed and removed",
      "reviewed_at": "2025-11-20T15:00:00Z"
    }
  },
  "message": "Report reviewed successfully"
}
```

---

### 4. Toggle Venue Like

**Endpoint:** `PUT /api/v1/venues/:venue_id/likes/toggle`  
**Alternative:** `PATCH /api/v1/venues/:venue_id/likes/toggle`

**Description:** Toggle like/unlike for a venue. If the venue is already liked, it will be unliked. If not liked, it will be liked. This is a single endpoint that handles both actions.

**Authentication:** Bearer token required

**Response (When Liking):**
```json
{
  "data": {
    "liked": true,
    "like": {
      "id": "like_id",
      "user": {
        "id": "user_id",
        "name": "John Doe"
      },
      "created_at": "2025-10-08T12:00:00Z"
    },
    "likes_count": 45
  },
  "message": "Liked successfully",
  "status": "ok"
}
```

**Response (When Unliking):**
```json
{
  "data": {
    "liked": false,
    "likes_count": 44
  },
  "message": "Unliked successfully",
  "status": "ok"
}
```

**Note:** The old `POST /api/v1/venues/:venue_id/likes` and `DELETE /api/v1/venues/:venue_id/likes` endpoints are still available for backward compatibility, but the toggle endpoint is recommended for new implementations.

---

### 5. Check Venue Like

**Endpoint:** `GET /api/v1/venues/:venue_id/likes/check`

**Description:** Check if current user has liked a venue.

**Authentication:** Bearer token required

---

### 6. List Venue Likes

**Endpoint:** `GET /api/v1/venues/:venue_id/likes`

**Description:** List all users who liked a venue.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results
- `offset` (integer, optional): Pagination offset

---

## User Profile

### 1. Get My Profile

**Endpoint:** `GET /api/v1/users/me`

**Description:** Get current user's profile information.

**Authentication:** Bearer token required

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "avatar_url": "/rails/active_storage/blobs/...",
      "bio": "Music lover and event enthusiast",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  }
}
```

**User Object Fields:**
- `id`: Unique user identifier
- `email`: User's email address (null if unlinked)
- `phone`: User's phone number (null if unlinked)
- `username`: Unique username
- `name`: User's display name
- `date_of_birth`: User's date of birth
- `role`: User role (consumer, artist, venue_manager, admin)
- `status`: Account status (active, disabled)
- `avatar_url`: Profile picture URL (null if not set)
- `bio`: User biography/description (null if not set)
- `preferences`: User preferences JSON object
- `created_at`: Account creation timestamp
- `updated_at`: Last update timestamp

---

### 2. Update Profile

**Endpoint:** `PATCH /api/v1/users/me`

**Description:** Update user profile (name, username, date_of_birth). Email and phone require separate OTP verification endpoints.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "user": {
    "name": "John Doe",
    "username": "johndoe",
    "date_of_birth": "1990-01-15"
  }
}
```

**Parameters:**
- `name` (string, optional): User's full name
- `username` (string, optional): Unique username (3-30 characters, alphanumeric and underscores only)
- `date_of_birth` (date, optional): Date of birth (YYYY-MM-DD format, cannot be in the future)

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Profile updated successfully"
}
```

---

### 3. Upload Profile Picture

**Endpoint:** `POST /api/v1/users/me/upload_profile_picture`

**Description:** Upload profile picture image file. The system stores the file and returns a generated URL.

**Authentication:** Bearer token required

**Content-Type:** `multipart/form-data`

**Request:**
- **Field name:** `profile_picture` (or `image` or `file`)
- **File type:** Image file (JPEG, PNG, GIF, WebP)
- **Max size:** 5MB

**Response:**
```json
{
  "status": 200,
  "message": "Profile picture uploaded successfully",
  "data": {
    "user": {
      "id": "user_id",
      "name": "John Doe",
      "avatar_url": "https://your-domain.com/rails/active_storage/blobs/.../profile.jpg"
    },
    "profile_picture_url": "https://your-domain.com/rails/active_storage/blobs/.../profile.jpg",
    "avatar_url": "https://your-domain.com/rails/active_storage/blobs/.../profile.jpg"
  }
}
```

**Error Responses:**
```json
{
  "status": 400,
  "message": "Profile picture file is required",
  "data": null
}
```

```json
{
  "status": 400,
  "message": "Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed",
  "data": null
}
```

```json
{
  "status": 400,
  "message": "File size too large. Maximum size is 5MB",
  "data": null
}
```

**How to use:**
- Mobile: Send as `multipart/form-data` with file from camera/gallery
- Web: Use `<input type="file">` and `FormData`
- Postman: Use form-data body with file field

---

### 4. Change Email (Request OTP)

**Endpoint:** `POST /api/v1/users/me/change_email`

**Description:** Request email change. OTP will be sent to the new email address. Use verify_email_change endpoint to complete the change.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "email": "newemail@example.com"
}
```

**Parameters:**
- `email` (string, required): New email address (must be different from current email)

**Response:**
```json
{
  "status": 200,
  "message": "OTP sent to new email address",
  "data": {
    "verification_token": "jwt_token_here",
    "email": "newemail@example.com",
    "otp": "123456",
    "expires_in": "15 minutes",
    "message": "OTP sent to new email. Use verify_email_change endpoint to complete."
  }
}
```

**Note:** 
- Save the `verification_token` from the response. You'll need it along with the OTP code to complete the email change.
- `otp` field is included in response for **testing only**. This will be removed in production.

---

### 4. Verify Email Change

**Endpoint:** `POST /api/v1/users/me/verify_email_change`

**Description:** Verify OTP code to complete email change.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "verification_token": "jwt_token_from_change_email_response",
  "otp_code": "123456"
}
```

**Parameters:**
- `verification_token` (string, required): Token received from change_email endpoint
- `otp_code` (string, required): 6-digit OTP code sent to new email

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": "newemail@example.com",
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Email updated successfully"
}
```

---

### 5. Change Phone (Request OTP)

**Endpoint:** `POST /api/v1/users/me/change_phone`

**Description:** Request phone change. OTP will be sent to the new phone number. Use verify_phone_change endpoint to complete the change.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "phone": "+1234567890"
}
```

**Parameters:**
- `phone` (string, required): New phone number (must be different from current phone, 10-15 digits)

**Response:**
```json
{
  "status": 200,
  "message": "OTP sent to new phone number",
  "data": {
    "verification_token": "jwt_token_here",
    "phone": "1234567890",
    "otp": "123456",
    "expires_in": "15 minutes",
    "message": "OTP sent to new phone. Use verify_phone_change endpoint to complete."
  }
}
```

**Note:** 
- Save the `verification_token` from the response. You'll need it along with the OTP code to complete the phone change.
- `otp` field is included in response for **testing only**. This will be removed in production.

---

### 6. Verify Phone Change

**Endpoint:** `POST /api/v1/users/me/verify_phone_change`

**Description:** Verify OTP code to complete phone change.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "verification_token": "jwt_token_from_change_phone_response",
  "otp_code": "123456"
}
```

**Parameters:**
- `verification_token` (string, required): Token received from change_phone endpoint
- `otp_code` (string, required): 6-digit OTP code sent to new phone

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Phone number updated successfully"
}
```

---

### 7. Unlink Email Address

**Endpoint:** `POST /api/v1/users/me/unlink_email`

**Description:** Unlink email address from user account. This allows users to remove their email while maintaining phone-based authentication.

**Authentication:** Bearer token required

**Requirements:**
- User must have a phone number linked to the account
- Email must be currently linked to the account

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": null,
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "avatar_url": "/rails/active_storage/blobs/...",
      "bio": "User bio",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Email address unlinked successfully"
}
```

**Error Responses:**
- `400 Bad Request`: If user doesn't have a phone number or email is not linked

**Note:** Users must maintain at least one contact method (phone or email) for account security.

---

### 8. Unlink Phone Number

**Endpoint:** `POST /api/v1/users/me/unlink_phone`

**Description:** Unlink phone number from user account. This allows users to remove their phone while maintaining email-based authentication.

**Authentication:** Bearer token required

**Requirements:**
- User must have an email address linked to the account
- Phone must be currently linked to the account

**Response:**
```json
{
  "data": {
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "phone": null,
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "avatar_url": "/rails/active_storage/blobs/...",
      "bio": "User bio",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-10-08T12:00:00Z"
    }
  },
  "message": "Phone number unlinked successfully"
}
```

**Error Responses:**
- `400 Bad Request`: If user doesn't have an email or phone is not linked

**Note:** Users must maintain at least one contact method (phone or email) for account security.

---

### 9. Deactivate Account

**Endpoint:** `POST /api/v1/users/me/deactivate`

**Description:** Deactivate user account. Sets user status to 'disabled' and creates a deactivation record for analytics and history tracking. Deactivated accounts cannot log in.

**Authentication:** Bearer token required

**Request Body (optional):**
```json
{
  "reason": "Privacy and security issues",
  "additional_feedback": "More detailed explanation about privacy concerns..."
}
```

**Parameters:**
- `reason` (string, optional): Reason for account deactivation
- `additional_feedback` (text, optional): Additional detailed feedback

**Available Reasons:**
- "I am leaving temporarily"
- "Privacy and security issues"
- "Having trouble getting started"
- "I have multiple accounts"
- "Other reason"

**Response:**
```json
{
  "message": "Account deactivated successfully",
  "data": {
    "deactivation": {
      "reason": "Privacy and security issues",
      "deactivated_at": "2025-12-03T18:00:00Z"
    }
  }
}
```

**Note:** 
- After deactivation, the user will not be able to authenticate
- Creates a `UserDeactivation` record for complete history tracking
- Deactivation reason and feedback are stored separately for analytics
- Full deactivation history is maintained even after reactivation
- To reactivate, use the reactivate endpoint or contact support

---

### 10. Reactivate Account

**Endpoint:** `POST /api/v1/users/me/reactivate`

**Description:** Reactivate a deactivated user account. Sets user status back to 'active' and records the reactivation in the deactivation history.

**Authentication:** Bearer token required (must be from a deactivated account)

**Request Body (optional):**
```json
{
  "reactivated_by": "user",
  "notes": "Changed my mind, want to stay"
}
```

**Parameters:**
- `reactivated_by` (string, optional): Who reactivated the account ('user', 'admin', or admin user_id). Default: 'user'
- `notes` (text, optional): Notes about the reactivation

**Response:**
```json
{
  "message": "Account reactivated successfully",
  "data": {
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "phone": "1234567890",
      "username": "johndoe",
      "name": "John Doe",
      "date_of_birth": "1990-01-15",
      "role": "consumer",
      "status": "active",
      "avatar_url": "/rails/active_storage/blobs/...",
      "bio": "Music lover and event enthusiast",
      "preferences": {},
      "created_at": "2025-10-08T12:00:00Z",
      "updated_at": "2025-12-03T18:00:00Z"
    }
  }
}
```

**Error Responses:**
- `400 Bad Request`: If account is not deactivated

**Note:**
- Previous deactivation record is updated with reactivation timestamp
- Deactivation history is preserved for analytics
- Users can deactivate and reactivate multiple times
- Each deactivation/reactivation cycle is tracked separately

---

### 5. Search Users

**Endpoint:** `GET /api/v1/users/search`

**Description:** Search for users by name or username.

**Authentication:** Bearer token required

**Query Parameters:**
- `q` (string, required): Search query (searches in name and username)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "users": [
      {
        "id": "user_uuid",
        "username": "johndoe",
        "name": "John Doe",
        "role": "consumer",
        "avatar_url": null
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 5,
      "has_more": false
    }
  }
}
```

---

### 6. Get User Profile

**Endpoint:** `GET /api/v1/users/:id`

**Description:** Get another user's profile with stats and follow status.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "user": {
      "id": "user_uuid",
      "username": "johndoe",
      "name": "John Doe",
      "role": "consumer",
      "avatar_url": null,
      "bio": null,
      "date_of_birth": "1990-01-15",
      "stats": {
        "followers_count": 150,
        "following_count": 75,
        "events_created": 5,
        "venues_owned": 2,
        "bookings_count": 30
      },
      "is_following": false,
      "is_followed_by": true,
      "is_me": false,
      "created_at": "2025-01-01T00:00:00Z"
    }
  }
}
```

---

### 7. Get User Share QR Code

**Endpoint:** `GET /api/v1/users/:id/share_qr`

**Description:** Generate a QR code image for sharing a user profile. Similar to event share QR codes, this allows users to share their profile easily by scanning the QR code.

**Authentication:** Bearer token optional (not required to view/share profiles)

**Query Parameters:**
- `size` (integer, optional): QR code image size in pixels (default: 300, min: 100, max: 1000)
- `format` (string, optional): Response format - `json` (default) or `image` for direct PNG file

**Response (JSON format - default):**
```json
{
  "status": 200,
  "data": {
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "qr_image_url": "https://vibesapp.digital4design.com/api/v1/users/user_uuid/share_qr?format=image&size=300",
    "user_url": "vibes://users/user_uuid",
    "user": {
      "id": "user_uuid",
      "username": "johndoe",
      "name": "John Doe",
      "role": "consumer",
      "avatar_url": "https://..."
    }
  }
}
```

**Response (Image format):**
- Returns direct PNG image with `Content-Type: image/png`
- File name: `user_{user_id}_qr.png`

**Usage Examples:**
- Get as JSON: `GET /api/v1/users/:id/share_qr`
- Get as image: `GET /api/v1/users/:id/share_qr?format=image`
- Get larger QR: `GET /api/v1/users/:id/share_qr?size=500`

**Notes:**
- The QR code contains a deep link URL: `vibes://users/:id`
- Users can scan this QR code to directly open/view the user's profile in the Vibes app
- Useful for in-person profile sharing, business cards, or social events

---

## Follows & Following

Users can follow other users regardless of their role (consumer, artist, venue_manager, admin). Artists are users with the "artist" role and can be followed just like any other user. When you follow a user, they receive a notification.

### 1. Follow User (or Artist)

**Endpoint:** `POST /api/v1/users/:user_id/follow`

**Description:** Follow a user or artist. Works for any user role. Creates a notification for the followed user.

**Authentication:** Bearer token required

**Examples:**
- Follow a consumer: `POST /api/v1/users/{consumer_user_id}/follow`
- Follow an artist: `POST /api/v1/users/{artist_user_id}/follow`
- Follow a venue manager: `POST /api/v1/users/{venue_manager_user_id}/follow`

**Response:**
```json
{
  "status": 201,
  "message": "Successfully followed user",
  "data": {
    "follower": {
      "id": "current_user_uuid",
      "name": "Current User",
      "username": "currentuser",
      "role": "consumer",
      "avatar_url": null
    },
    "following": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "artist",
      "avatar_url": null
    },
    "is_following": true
  }
}
```

**Error Responses:**
- `400 Bad Request`: You cannot follow yourself
- `400 Bad Request`: You are already following this user
- `404 Not Found`: User not found

---

### 2. Unfollow User

**Endpoint:** `DELETE /api/v1/users/:user_id/follow`

**Description:** Unfollow a user.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Successfully unfollowed user",
  "data": {
    "follower": {
      "id": "current_user_uuid",
      "name": "Current User",
      "username": "currentuser",
      "role": "consumer"
    },
    "following": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "consumer"
    },
    "is_following": false
  }
}
```

---

### 3. Check Follow Status

**Endpoint:** `GET /api/v1/users/:user_id/follow/check`

**Description:** Check if you are following a user and if they are following you.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "user": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "consumer"
    },
    "is_following": true,
    "is_followed_by": false
  }
}
```

---

### 4. Get My Following

**Endpoint:** `GET /api/v1/users/me/following`

**Description:** Get list of users you are following. Can filter by role to get only artists, consumers, etc.

**Authentication:** Bearer token required

**Query Parameters:**
- `role` (string, optional): Filter by user role (`consumer`, `artist`, `venue_manager`, `admin`)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Examples:**
- Get all users you're following: `GET /api/v1/users/me/following`
- Get only artists you're following: `GET /api/v1/users/me/following?role=artist`
- Get only consumers you're following: `GET /api/v1/users/me/following?role=consumer`

**Response:**
```json
{
  "status": 200,
  "data": {
    "following": [
      {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe",
        "role": "artist",
        "avatar_url": null
      },
      {
        "id": "user_uuid_2",
        "name": "Jane Smith",
        "username": "janesmith",
        "role": "consumer",
        "avatar_url": null
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 75,
      "has_more": true
    }
  }
}
```

---

### 5. Get My Followers

**Endpoint:** `GET /api/v1/users/me/followers`

**Description:** Get list of users following you. Can filter by role to see only artists, consumers, etc.

**Authentication:** Bearer token required

**Query Parameters:**
- `role` (string, optional): Filter by user role (`consumer`, `artist`, `venue_manager`, `admin`)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Examples:**
- Get all followers: `GET /api/v1/users/me/followers`
- Get only artist followers: `GET /api/v1/users/me/followers?role=artist`
- Get only consumer followers: `GET /api/v1/users/me/followers?role=consumer`

**Response:**
```json
{
  "status": 200,
  "data": {
    "followers": [
      {
        "id": "user_uuid",
        "name": "Jane Doe",
        "username": "janedoe",
        "role": "artist",
        "avatar_url": null
      },
      {
        "id": "user_uuid_2",
        "name": "Bob Johnson",
        "username": "bobjohnson",
        "role": "consumer",
        "avatar_url": null
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 150,
      "has_more": true
    }
  }
}
```

---

### How to Follow Artists

**To follow an artist:**

1. **Find the artist's user ID** - Artists are users with `role: "artist"`. You can find them using:
   - `GET /api/v1/artists` - List all artists
   - `GET /api/v1/artists/:id` - Get artist details (includes user ID)
   - `GET /api/v1/search?q=artistname&types[]=users` - Search for users/artists

2. **Follow the artist** - Use the artist's user ID:
   ```
   POST /api/v1/users/{artist_user_id}/follow
   ```

3. **Check follow status**:
   ```
   GET /api/v1/users/{artist_user_id}/follow/check
   ```

4. **List artists you're following**:
   ```
   GET /api/v1/users/me/following?role=artist
   ```

**Example Flow:**
```bash
# 1. Search for an artist
GET /api/v1/search?q=DJ%20Mike&types[]=users

# 2. Follow the artist (using their user ID from search results)
POST /api/v1/users/{artist_user_id}/follow

# 3. Get list of all artists you're following
GET /api/v1/users/me/following?role=artist&limit=50
```

**Note:** The same endpoints work for following any user regardless of role. Artists are just users with the "artist" role, so there's no separate "follow artist" endpoint - use the standard user follow endpoints.

---

## User Blocking

Users can block other users (including artists) to prevent them from seeing your content and to hide their content from you. When you block a user:

- **Events**: Events created by blocked users (venue owners) are hidden from your feed
- **Event Posts**: Posts from blocked users are hidden from event feeds
- **Live Events**: Live events from blocked users are excluded from live event listings
- **Search**: Blocked users may appear in search results but their content is filtered

**Note:** Blocking is one-way. If User A blocks User B, User A won't see User B's content, but User B can still see User A's content (unless User B also blocks User A).

### 1. Block User (or Artist)

**Endpoint:** `POST /api/v1/users/:user_id/block`

**Description:** Block a user or artist. Works for any user role. Once blocked, their content will be hidden from your feed.

**Authentication:** Bearer token required

**Examples:**
- Block a consumer: `POST /api/v1/users/{consumer_user_id}/block`
- Block an artist: `POST /api/v1/users/{artist_user_id}/block`
- Block a venue manager: `POST /api/v1/users/{venue_manager_user_id}/block`

**Response:**
```json
{
  "status": 201,
  "message": "User blocked successfully",
  "data": {
    "blocker": {
      "id": "current_user_uuid",
      "name": "Current User",
      "username": "currentuser",
      "role": "consumer",
      "avatar_url": null
    },
    "blocked": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "artist",
      "avatar_url": null
    },
    "is_blocked": true
  }
}
```

**Error Responses:**
- `400 Bad Request`: You cannot block yourself
- `400 Bad Request`: You have already blocked this user
- `404 Not Found`: User not found

---

### 2. Unblock User

**Endpoint:** `DELETE /api/v1/users/:user_id/block`

**Description:** Unblock a user. Their content will become visible again in your feed.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "User unblocked successfully",
  "data": {
    "blocker": {
      "id": "current_user_uuid",
      "name": "Current User",
      "username": "currentuser",
      "role": "consumer"
    },
    "blocked": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "consumer"
    },
    "is_blocked": false
  }
}
```

**Error Responses:**
- `400 Bad Request`: You have not blocked this user
- `404 Not Found`: User not found

---

### 3. Check Block Status

**Endpoint:** `GET /api/v1/users/:user_id/block/check`

**Description:** Check if you have blocked a user and if they have blocked you.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "user": {
      "id": "user_uuid",
      "name": "John Doe",
      "username": "johndoe",
      "role": "consumer"
    },
    "is_blocked": true,
    "is_blocked_by": false
  }
}
```

---

### 4. List My Blocked Users

**Endpoint:** `GET /api/v1/users/me/blocked`

**Description:** Get list of all users you have blocked.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "blocked_users": [
      {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe",
        "role": "artist",
        "avatar_url": null
      },
      {
        "id": "user_uuid_2",
        "name": "Jane Smith",
        "username": "janesmith",
        "role": "consumer",
        "avatar_url": null
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 5,
      "has_more": false
    }
  }
}
```

---

### Content Filtering

When a user is blocked, the following content is automatically filtered:

1. **Events**: Events created by blocked users (as venue owners) are excluded from:
   - Event listings (`GET /api/v1/events`)
   - Live event feeds
   - Search results (events from blocked users)

2. **Event Posts**: Posts from blocked users are excluded from:
   - Event post feeds (`GET /api/v1/events/:event_id/posts`)
   - Post listings

3. **Live Events**: Live events from blocked users are automatically filtered from live event listings.

**Note:** The filtering happens automatically - you don't need to do anything special. Once you block a user, their content will be hidden from your view.

---

## Notifications

### 1. List Notifications

**Endpoint:** `GET /api/v1/notifications`

**Description:** Get list of notifications. Can filter by read status and type.

**Authentication:** Bearer token required

**Query Parameters:**
- `read` (boolean, optional): Filter by read status (true/false)
- `type` (string, optional): Filter by notification type (follow, event_invite, event_reminder, booking_confirmed, booking_cancelled, event_updated, event_cancelled, message, group_chat_invite, rating, like, comment, system)
- `limit` (integer, optional): Number of results (default: 20, max: 100)
- `offset` (integer, optional): Pagination offset

**Response:**
```json
{
  "status": 200,
  "data": {
    "notifications": [
      {
        "id": "notification_uuid",
        "notification_type": "follow",
        "title": "New Follower",
        "message": "John Doe started following you",
        "metadata": {
          "follower_id": "user_uuid",
          "follower_name": "John Doe",
          "follower_username": "johndoe"
        },
        "read": false,
        "read_at": null,
        "created_at": "2025-11-26T10:00:00Z"
      }
    ],
    "unread_count": 5,
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  }
}
```

---

### 2. Get Notification

**Endpoint:** `GET /api/v1/notifications/:id`

**Description:** Get a specific notification by ID.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "notification": {
      "id": "notification_uuid",
      "notification_type": "follow",
      "title": "New Follower",
      "message": "John Doe started following you",
      "metadata": {
        "follower_id": "user_uuid",
        "follower_name": "John Doe",
        "follower_username": "johndoe"
      },
      "read": false,
      "read_at": null,
      "created_at": "2025-11-26T10:00:00Z"
    }
  }
}
```

---

### 3. Get Unread Count

**Endpoint:** `GET /api/v1/notifications/unread_count`

**Description:** Get count of unread notifications.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "unread_count": 5
  }
}
```

---

### 4. Mark Notification as Read

**Endpoint:** `POST /api/v1/notifications/:id/read`

**Description:** Mark a notification as read.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Notification marked as read",
  "data": {
    "notification": {
      "id": "notification_uuid",
      "read": true,
      "read_at": "2025-11-26T10:05:00Z"
    }
  }
}
```

---

### 5. Mark Notification as Unread

**Endpoint:** `POST /api/v1/notifications/:id/unread`

**Description:** Mark a notification as unread.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Notification marked as unread",
  "data": {
    "notification": {
      "id": "notification_uuid",
      "read": false,
      "read_at": null
    }
  }
}
```

---

### 6. Mark All Notifications as Read

**Endpoint:** `POST /api/v1/notifications/mark_all_read`

**Description:** Mark all notifications as read.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "All notifications marked as read",
  "data": {
    "marked_count": 5
  }
}
```

---

### 7. Delete Notification

**Endpoint:** `DELETE /api/v1/notifications/:id`

**Description:** Delete a notification.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Notification deleted successfully"
}
```

---

### 8. Clear All Notifications

**Endpoint:** `DELETE /api/v1/notifications/clear_all`

**Description:** Delete all notifications.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "All notifications cleared",
  "data": {
    "deleted_count": 25
  }
}
```

---

## Group Chats

Group chat messaging with real-time WebSocket support via ActionCable. Users are automatically added to city-based group chats when they set their location.

### 1. List Group Chats

**Endpoint:** `GET /api/v1/group_chats`

**Description:** Get list of user's group chats. Includes city-based groups based on user's location.

**Authentication:** Bearer token required

**Query Parameters:**
- `include_city_groups` (boolean, optional): Include city-based groups for user's location (default: true)
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "group_chats": [
      {
        "id": "group_chat_uuid",
        "name": "San Juan, Puerto Rico",
        "description": "Local group chat for San Juan, Puerto Rico",
        "created_by": {
          "id": "user_uuid",
          "name": "Admin User",
          "username": "admin"
        },
        "status": "active",
        "is_city_based": true,
        "city": "San Juan",
        "country": "Puerto Rico",
        "member_count": 150,
        "is_member": true,
        "unread_count": 5,
        "last_message_at": "2025-11-26T08:00:00Z",
        "created_at": "2025-11-20T12:00:00Z",
        "updated_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 5,
      "has_more": false
    }
  }
}
```

---

### 2. Get Group Chat Details

**Endpoint:** `GET /api/v1/group_chats/:id`

**Description:** Get detailed information about a specific group chat including members.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "name": "My Group Chat",
      "description": "A group chat for friends",
      "created_by": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "status": "active",
      "is_city_based": false,
      "city": null,
      "country": null,
      "member_count": 10,
      "is_member": true,
      "unread_count": 2,
      "last_message_at": "2025-11-26T08:00:00Z",
      "members": [
        {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe",
          "role": "admin",
          "joined_at": "2025-11-20T12:00:00Z"
        }
      ],
      "created_at": "2025-11-20T12:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 3. Create Group Chat

**Endpoint:** `POST /api/v1/group_chats`

**Description:** Create a new group chat. Optionally add initial members.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "group_chat": {
    "name": "My Group Chat",
    "description": "A group chat for friends"
  },
  "member_ids": ["user_uuid_1", "user_uuid_2"]
}
```

**Parameters:**
- `group_chat.name` (string, optional): Group chat name
- `group_chat.description` (string, optional): Group chat description
- `member_ids` (array, optional): Array of user IDs to add as initial members

**Response:**
```json
{
  "status": 201,
  "message": "Group chat created successfully",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "name": "My Group Chat",
      "description": "A group chat for friends",
      "created_by": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "status": "active",
      "is_city_based": false,
      "member_count": 3,
      "is_member": true,
      "unread_count": 0,
      "members": [...],
      "created_at": "2025-11-26T08:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 4. Update Group Chat

**Endpoint:** `PATCH /api/v1/group_chats/:id`

**Description:** Update group chat details. Only admins can update.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "group_chat": {
    "name": "Updated Group Chat Name",
    "description": "Updated description"
  }
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Group chat updated successfully",
  "data": {
    "group_chat": {...}
  }
}
```

---

### 5. Archive Group Chat

**Endpoint:** `DELETE /api/v1/group_chats/:id`

**Description:** Archive a group chat. Only admins can archive.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Group chat archived successfully"
}
```

---

### 6. List Group Chat Members

**Endpoint:** `GET /api/v1/group_chats/:id/members`

**Description:** List all members of a group chat with pagination, filtering, and search functionality.

**Authentication:** Bearer token required (must be a member of the group chat)

**Query Parameters:**
- `role` (string, optional): Filter by role (`owner`, `admin`, `member`)
- `search` (string, optional): Search by name or username
- `limit` (integer, optional): Number of results per page (default: 50, max: 200)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "group_chat_id": "group_chat_uuid",
    "group_chat_name": "My Group Chat",
    "members": [
      {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe",
        "avatar_url": "https://...",
        "role": "member",
        "joined_at": "2025-11-20T12:00:00Z"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  },
  "status": "ok"
}
```

---

### 7. Get Available Users to Add

**Endpoint:** `GET /api/v1/group_chats/:id/available_users`

**Description:** Get list of users that can be added to the group chat (excludes current members). Supports search, role filtering, and relationship filtering. Only admins can access this endpoint.

**Authentication:** Bearer token required (must be an admin of the group chat)

**Query Parameters:**
- `search` (string, optional): Search by name or username
- `role` (string, optional): Filter by user role (e.g., `consumer`, `artist`, `venue_manager`)
- `filter` (string, optional): Filter by relationship:
  - `following` - Only users that current user is following
  - `followers` - Only users that follow current user
  - `mutual` - Only mutual follows (users you follow who also follow you)
- `limit` (integer, optional): Number of results per page (default: 50, max: 200)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "group_chat_id": "group_chat_uuid",
    "group_chat_name": "My Group Chat",
    "available_users": [
      {
        "id": "user_uuid",
        "name": "Jane Doe",
        "username": "janedoe",
        "avatar_url": "https://...",
        "role": "consumer",
        "bio": "User bio",
        "is_following": true,
        "is_followed_by": false
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 150,
      "has_more": true
    }
  },
  "status": "ok"
}
```

**Example Requests:**
- Get all available users: `GET /api/v1/group_chats/:id/available_users`
- Search for users: `GET /api/v1/group_chats/:id/available_users?search=john`
- Get only users you're following: `GET /api/v1/group_chats/:id/available_users?filter=following`
- Get mutual follows: `GET /api/v1/group_chats/:id/available_users?filter=mutual&limit=20`

---

### 8. Add Member to Group Chat

**Endpoint:** `POST /api/v1/group_chats/:id/add_member`

**Description:** Add a user to the group chat. Only admins can add members.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "user_id": "user_uuid",
  "role": "member"
}
```

**Parameters:**
- `user_id` (string, required): User ID to add
- `role` (string, optional): Role for the member (default: "member", options: "admin", "member")

**Response:**
```json
{
  "status": 200,
  "message": "Member added successfully",
  "data": {
    "group_chat": {...}
  }
}
```

---

### 9. Remove Member from Group Chat

**Endpoint:** `DELETE /api/v1/group_chats/:id/remove_member`

**Description:** Remove a user from the group chat. Only admins can remove members.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "user_id": "user_uuid"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Member removed successfully",
  "data": {
    "group_chat": {...}
  }
}
```

---

### 10. List Group Chat Messages

**Endpoint:** `GET /api/v1/group_chats/:group_chat_id/messages`

**Description:** Get messages from a group chat. Messages are ordered oldest first for chat history. Automatically marks messages as read for the current user.

**Authentication:** Bearer token required

**Query Parameters:**
- `limit` (integer, optional): Number of results per page (default: 50, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)
- `message_type` (string, optional): Filter by message type (text, image, video, audio, location)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "name": "My Group Chat"
    },
    "messages": [
      {
        "id": "message_uuid",
        "user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "content": "Hello, everyone!",
        "message_type": "text",
        "reply_to": null,
        "deleted": false,
        "created_at": "2025-11-26T08:00:00Z",
        "updated_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 100,
      "has_more": true
    }
  }
}
```

---

### 11. Get Group Chat Message

**Endpoint:** `GET /api/v1/group_chats/:group_chat_id/messages/:id`

**Description:** Get a specific message from a group chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "message": {
      "id": "message_uuid",
      "user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "content": "Hello, everyone!",
      "message_type": "text",
      "reply_to": null,
      "deleted": false,
      "created_at": "2025-11-26T08:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 12. Send Message to Group Chat

**Endpoint:** `POST /api/v1/group_chats/:group_chat_id/messages`

**Description:** Send a message to a group chat. Message is automatically broadcast via WebSocket to all subscribers.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "message": {
    "content": "Hello, everyone!",
    "message_type": "text",
    "reply_to_id": null
  }
}
```

**Parameters:**
- `message.content` (string, required): Message content
- `message.message_type` (string, optional): Message type (default: "text", options: "text", "image", "video", "audio", "location")
- `message.reply_to_id` (string, optional): UUID of message to reply to

**Response:**
```json
{
  "status": 201,
  "message": "Message sent successfully",
  "data": {
    "message": {
      "id": "message_uuid",
      "user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "content": "Hello, everyone!",
      "message_type": "text",
      "reply_to": null,
      "deleted": false,
      "created_at": "2025-11-26T08:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

**Note:** The message is automatically broadcast via WebSocket to all subscribers of the group chat channel. See [WebSocket Usage Documentation](../vibes/docs/WEBSOCKET_USAGE.md) for details.

---

### 13. Delete Group Chat Message

**Endpoint:** `DELETE /api/v1/group_chats/:group_chat_id/messages/:id`

**Description:** Delete (soft delete) a message. Users can only delete their own messages, admins can delete any message.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Message deleted successfully"
}
```

**Note:** The deletion is automatically broadcast via WebSocket to all subscribers.

---

### City-Based Group Chats

When a user sets their location (via device or manual location update), the system automatically:

1. Extracts the city and country from the location
2. Finds or creates a city-based group chat for that location
3. Adds the user as a member of the city-based group chat
4. Adds the user to groups for all venues in that city

City-based group chats appear in the group chat list with `is_city_based: true` and are sorted to appear first in the list.

---

### 6. Leave Group Chat

**Endpoint:** `POST /api/v1/group_chats/:id/leave`

**Description:** Leave a group chat. Group chat owner cannot leave (must transfer ownership or delete group).

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Left group chat successfully"
}
```

---

### 7. Mute/Unmute Group Chat

**Endpoints:** 
- `POST /api/v1/group_chats/:id/mute`
- `POST /api/v1/group_chats/:id/unmute`

**Description:** Mute or unmute notifications for a group chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Group chat muted",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "is_muted": true
    }
  }
}
```

---

### 8. Pin/Unpin Group Chat

**Endpoints:**
- `POST /api/v1/group_chats/:id/pin`
- `POST /api/v1/group_chats/:id/unpin`

**Description:** Pin or unpin a group chat to the top of the list.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Group chat pinned",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "is_pinned": true
    }
  }
}
```

---

### 9. Star/Unstar Group Chat

**Endpoints:**
- `POST /api/v1/group_chats/:id/star`
- `POST /api/v1/group_chats/:id/unstar`

**Description:** Star (save) or unstar a group chat for quick access.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Group chat starred",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "is_starred": true
    }
  }
}
```

---

### 14. Archive/Unarchive Group Chat

**Endpoints:**
- `POST /api/v1/group_chats/:id/archive`
- `POST /api/v1/group_chats/:id/unarchive`

**Description:** Archive or unarchive a group chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Group chat archived",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "status": "archived"
    }
  }
}
```

---

### 15. Get Group Chat Invite QR Code

**Endpoint:** `GET /api/v1/group_chats/:id/invite_qr`

**Description:** Get QR code for group chat invite. Returns base64 encoded PNG image.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANS...",
    "invite_code": "ABC12345",
    "invite_url": "https://your-domain.com/join/ABC12345"
  }
}
```

---

### 16. Get Group Chat Invite URL

**Endpoint:** `GET /api/v1/group_chats/:id/invite_url`

**Description:** Get invite URL and code for sharing the group chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "invite_code": "ABC12345",
    "invite_url": "https://your-domain.com/join/ABC12345"
  }
}
```

---

### 17. Regenerate Group Chat Invite Code

**Endpoint:** `POST /api/v1/group_chats/:id/regenerate_invite`

**Description:** Regenerate invite code and QR code. Only admins/owners can regenerate.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Invite code regenerated successfully",
  "data": {
    "invite_code": "XYZ98765",
    "invite_url": "https://your-domain.com/join/XYZ98765"
  }
}
```

---

### 18. Join Group Chat by Invite Code

**Endpoint:** `POST /api/v1/group_chats/join_by_code`

**Description:** Join a group chat using an invite code. Code is case-insensitive.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "invite_code": "ABC12345"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Joined group chat successfully",
  "data": {
    "group_chat": {
      "id": "group_chat_uuid",
      "name": "Group Name",
      "member_count": 10
    }
  }
}
```

---

### 19. Edit Group Chat Message

**Endpoint:** `PATCH /api/v1/group_chats/:group_chat_id/messages/:id/edit`

**Description:** Edit a message. Users can only edit their own messages within 15 minutes of sending.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "content": "Updated message content"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Message edited successfully",
  "data": {
    "message": {
      "id": "message_uuid",
      "content": "Updated message content",
      "is_edited": true,
      "edited_at": "2025-11-26T08:30:00Z"
    }
  }
}
```

---

### 20. Forward Group Chat Message

**Endpoint:** `POST /api/v1/group_chats/:group_chat_id/messages/:id/forward`

**Description:** Forward a message to another group chat. You must be a member of the target group chat.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "target_group_chat_id": "target_group_chat_uuid"
}
```

**Response:**
```json
{
  "status": 201,
  "message": "Message forwarded successfully",
  "data": {
    "message": {
      "id": "forwarded_message_uuid",
      "content": "Original message content",
      "forwarded_from": {
        "id": "original_message_uuid",
        "type": "GroupChatMessage",
        "content": "Original message content"
      }
    }
  }
}
```

---

## Chats (One-on-One)

One-on-one chat messaging with real-time WebSocket support via ActionCable. Features include block, report, mute, pin, archive, edit messages, forward messages, and read receipts.

### 1. List Chats

**Endpoint:** `GET /api/v1/chats`

**Description:** Get list of user's one-on-one chats. Pinned chats appear first.

**Authentication:** Bearer token required

**Query Parameters:**
- `pinned` (boolean, optional): Filter by pinned chats
- `limit` (integer, optional): Number of results per page (default: 20, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "chats": [
      {
        "id": "chat_uuid",
        "other_user": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "is_blocked": false,
        "is_muted": false,
        "is_pinned": true,
        "is_archived": false,
        "unread_count": 3,
        "last_message": {
          "id": "message_uuid",
          "content": "Hello!",
          "message_type": "text",
          "sender_id": "user_uuid",
          "created_at": "2025-11-26T08:00:00Z"
        },
        "last_message_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 20,
      "offset": 0,
      "total_count": 15,
      "has_more": false
    }
  }
}
```

---

### 2. Get Chat Details

**Endpoint:** `GET /api/v1/chats/:id`

**Description:** Get detailed information about a specific chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "other_user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "is_blocked": false,
      "is_muted": false,
      "is_pinned": false,
      "is_archived": false,
      "unread_count": 0,
      "messages_count": 50,
      "last_message_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 3. Create or Get Chat

**Endpoint:** `POST /api/v1/chats`

**Description:** Create a new chat with another user or get existing chat if it already exists.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "user_id": "user_uuid"
}
```

**Response:**
```json
{
  "status": 201,
  "message": "Chat created successfully",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "other_user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      }
    }
  }
}
```

---

### 4. Block/Unblock User in Chat

**Endpoints:**
- `POST /api/v1/chats/:id/block`
- `POST /api/v1/chats/:id/unblock`

**Description:** Block or unblock the other user in the chat. Blocks all communication.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "User blocked successfully",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "is_blocked": true
    }
  }
}
```

---

### 5. Report User in Chat

**Endpoint:** `POST /api/v1/chats/:id/report`

**Description:** Report the other user. Reasons: spam, harassment, inappropriate, fake_account, other.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "reason": "harassment",
  "description": "User is sending inappropriate messages"
}
```

**Parameters:**
- `reason` (string, required): Report reason (spam, harassment, inappropriate, fake_account, other)
- `description` (string, optional): Additional details

**Response:**
```json
{
  "status": 201,
  "message": "User reported successfully. Our team will review it shortly.",
  "data": {
    "report": {
      "id": "report_uuid",
      "reported_user": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "reason": "harassment",
      "description": "User is sending inappropriate messages",
      "status": "pending",
      "created_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 6. Mute/Unmute Chat

**Endpoints:**
- `POST /api/v1/chats/:id/mute`
- `POST /api/v1/chats/:id/unmute`

**Description:** Mute or unmute notifications for a chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Chat muted",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "is_muted": true
    }
  }
}
```

---

### 7. Pin/Unpin Chat

**Endpoints:**
- `POST /api/v1/chats/:id/pin`
- `POST /api/v1/chats/:id/unpin`

**Description:** Pin or unpin a chat to the top of the list.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Chat pinned",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "is_pinned": true
    }
  }
}
```

---

### 8. Archive/Unarchive Chat

**Endpoints:**
- `POST /api/v1/chats/:id/archive`
- `POST /api/v1/chats/:id/unarchive`

**Description:** Archive or unarchive a chat.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Chat archived",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "is_archived": true
    }
  }
}
```

---

### 9. List Chat Messages

**Endpoint:** `GET /api/v1/chats/:chat_id/messages`

**Description:** Get messages from a chat. Messages are ordered oldest first. Automatically marks messages as read.

**Authentication:** Bearer token required

**Query Parameters:**
- `message_type` (string, optional): Filter by message type
- `limit` (integer, optional): Number of results per page (default: 50, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "chat": {
      "id": "chat_uuid",
      "other_user": {
        "id": "user_uuid",
        "name": "John Doe"
      }
    },
    "messages": [
      {
        "id": "message_uuid",
        "sender": {
          "id": "user_uuid",
          "name": "John Doe",
          "username": "johndoe"
        },
        "content": "Hello!",
        "message_type": "text",
        "is_read": true,
        "read_at": "2025-11-26T08:00:00Z",
        "created_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  }
}
```

---

### 10. Send Chat Message

**Endpoint:** `POST /api/v1/chats/:chat_id/messages`

**Description:** Send a message in a chat. Message types: text, image, video, audio, location.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "message": {
    "content": "Hello!",
    "message_type": "text",
    "reply_to_id": null
  }
}
```

**Response:**
```json
{
  "status": 201,
  "message": "Message sent successfully",
  "data": {
    "message": {
      "id": "message_uuid",
      "sender": {
        "id": "user_uuid",
        "name": "John Doe",
        "username": "johndoe"
      },
      "content": "Hello!",
      "message_type": "text",
      "is_read": true,
      "created_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 11. Edit Chat Message

**Endpoint:** `PATCH /api/v1/chats/:chat_id/messages/:id/edit`

**Description:** Edit a message. Users can only edit their own messages within 15 minutes.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "content": "Updated message content"
}
```

**Response:**
```json
{
  "status": 200,
  "message": "Message edited successfully",
  "data": {
    "message": {
      "id": "message_uuid",
      "content": "Updated message content",
      "is_edited": true,
      "edited_at": "2025-11-26T08:30:00Z"
    }
  }
}
```

---

### 12. Forward Chat Message

**Endpoint:** `POST /api/v1/chats/:chat_id/messages/:id/forward`

**Description:** Forward a message to another chat.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "target_chat_id": "target_chat_uuid"
}
```

**Response:**
```json
{
  "status": 201,
  "message": "Message forwarded successfully",
  "data": {
    "message": {
      "id": "forwarded_message_uuid",
      "content": "Original message content",
      "forwarded_from": {
        "id": "original_message_uuid",
        "type": "ChatMessage",
        "content": "Original message content"
      }
    }
  }
}
```

---

### 13. Delete Chat Message

**Endpoint:** `DELETE /api/v1/chats/:chat_id/messages/:id`

**Description:** Delete (soft delete) a message. Users can only delete their own messages.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Message deleted successfully"
}
```

---

## Floor Plans

Floor plans allow venue managers to create visual representations of their venue layout, including zones, tables, seats, and decorative elements. Floor plans are used for table booking, capacity management, and visual venue representation.

### Base Endpoint

All floor plan endpoints are nested under venues:
```
/api/v1/venues/:venue_id/floor_plans
```

**Authentication:** Required (Bearer token)  
**Authorization:** Only venue owners or admins can manage floor plans

---

### List Floor Plans

**GET** `/api/v1/venues/:venue_id/floor_plans`

List all floor plans for a venue.

**Query Parameters:**
- `status` (optional): Filter by status (`active`, `draft`, `archived`)
- `venue_type` (optional): Filter by venue type (`restaurant`, `bar`, `club`, etc.)

**Response:**
```json
{
  "success": true,
  "data": {
    "venue_id": "uuid",
    "venue_name": "Venue Name",
    "floor_plans": [
      {
        "id": "uuid",
        "name": "Main Floor",
        "description": "Main dining area",
        "venue_type": "restaurant",
        "dimensions": {
          "width": 1000,
          "height": 800
        },
        "scale_factor": 1.0,
        "status": "active",
        "is_default": true,
        "thumbnail_url": "https://...",
        "stats": {
          "total_zones": 3,
          "total_tables": 25,
          "total_seats": 100,
          "total_capacity": 100,
          "bookable_tables": 20
        },
        "created_at": "2025-01-01T00:00:00Z",
        "updated_at": "2025-01-01T00:00:00Z"
      }
    ]
  }
}
```

---

### Get Floor Plan

**GET** `/api/v1/venues/:venue_id/floor_plans/:id`

Get detailed floor plan including zones, tables, seats, and elements.

**Response:**
```json
{
  "success": true,
  "data": {
    "floor_plan": {
      "id": "uuid",
      "name": "Main Floor",
      "description": "Main dining area",
      "venue_type": "restaurant",
      "dimensions": {
        "width": 1000,
        "height": 800
      },
      "scale_factor": 1.0,
      "status": "active",
      "is_default": true,
      "thumbnail_url": "https://...",
      "settings": {
        "grid_enabled": true,
        "snap_to_grid": true
      },
      "stats": {
        "total_zones": 3,
        "total_tables": 25,
        "total_seats": 100,
        "total_capacity": 100,
        "bookable_tables": 20
      },
      "zones": [
        {
          "id": "uuid",
          "name": "VIP Section",
          "zone_type": "vip",
          "geometry": {
            "type": "polygon",
            "coordinates": [[0, 0], [100, 0], [100, 100], [0, 100]]
          },
          "color": "#FFD700",
          "capacity": 50,
          "is_bookable": true,
          "is_active": true,
          "min_spend": 100.0,
          "display_order": 1,
          "stats": {
            "total_tables": 10,
            "available_tables": 8
          },
          "tables": [
            {
              "id": "uuid",
              "table_number": "T-01",
              "table_name": "Table 1",
              "full_name": "VIP Section - Table 1",
              "table_type": "dining",
              "shape": "rectangle",
              "position": {
                "x": 100,
                "y": 200
              },
              "dimensions": {
                "width": 80,
                "height": 120
              },
              "rotation": 0,
              "capacity": {
                "min": 2,
                "max": 4
              },
              "is_accessible": true,
              "is_active": true,
              "is_bookable": true,
              "color": "#4CAF50",
              "custom_properties": {},
              "seats": [
                {
                  "id": "uuid",
                  "seat_number": 1,
                  "position": {
                    "x": 100,
                    "y": 200
                  },
                  "position_label": "Seat 1",
                  "seat_type": "standard",
                  "is_active": true,
                  "is_accessible": true
                }
              ]
            }
          ]
        }
      ],
      "elements": [
        {
          "id": "uuid",
          "element_type": "bar",
          "name": "Main Bar",
          "color": "#8B4513",
          "rotation": 0,
          "is_visible": true,
          "display_order": 1,
          "geometry": {
            "type": "rectangle",
            "x": 500,
            "y": 100,
            "width": 200,
            "height": 50
          },
          "properties": {
            "has_stools": true,
            "stool_count": 10
          }
        }
      ],
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-01T00:00:00Z"
    }
  }
}
```

---

### Get Floor Plan Canvas

**GET** `/api/v1/venues/:venue_id/floor_plans/:id/canvas`

Get floor plan data in canvas-ready JSON format for WebView rendering.

**Response:**
```json
{
  "success": true,
  "data": {
    "canvas": {
      "floor_plan": {
        "id": "uuid",
        "name": "Main Floor",
        "width": 1000,
        "height": 800
      },
      "zones": [...],
      "tables": [...],
      "elements": [...]
    },
    "venue": {
      "id": "uuid",
      "name": "Venue Name",
      "capacity": 100
    }
  }
}
```

---

### Floor Plan WebView (Selection)

**GET** `/webviews/venues/:venue_id/floor_plans/:id/select`

Returns an HTML WebView for selecting a table. Intended for mobile WebView usage.

**Query Parameters:**
- `booking_id` (uuid, optional): Booking to attach selection to (used by client)
- `auth_token` (string, optional): Bearer token for optional auto-assign
- `auto_assign` (boolean, optional): If `true`, calls `POST /api/v1/bookings/:id/assign_table` when user confirms

**Notes:**
- WebView posts `table_selected` via `window.ReactNativeWebView.postMessage`.
- Client can call `assign_table` directly if `auto_assign` is not used.

---

### Create Floor Plan

**POST** `/api/v1/venues/:venue_id/floor_plans`

Create a new floor plan for a venue.

**Request Body:**
```json
{
  "floor_plan": {
    "name": "Main Floor",
    "description": "Main dining area floor plan",
    "venue_type": "restaurant",
    "width": 1000,
    "height": 800,
    "scale_factor": 1.0,
    "status": "draft",
    "is_default": false,
    "settings": {
      "grid_enabled": true,
      "snap_to_grid": true
    }
  }
}
```

**Required Fields:**
- `name`: Floor plan name
- `venue_type`: Type of venue (`restaurant`, `bar`, `club`, etc.)
- `width`: Floor plan width in pixels
- `height`: Floor plan height in pixels

**Optional Fields:**
- `description`: Description of the floor plan
- `scale_factor`: Scale factor for the floor plan (default: 1.0)
- `thumbnail_url`: URL to thumbnail image
- `status`: Status (`draft`, `active`, `archived`) - default: `draft`
- `is_default`: Set as default floor plan (default: `false`)
- `settings`: Custom settings object

**Response:** 201 Created with floor plan details

---

### Update Floor Plan

**PATCH** `/api/v1/venues/:venue_id/floor_plans/:id`

Update floor plan details.

**Request Body:**
```json
{
  "floor_plan": {
    "name": "Updated Main Floor",
    "status": "active",
    "is_default": true
  }
}
```

**Response:** 200 OK with updated floor plan details

---

### Delete Floor Plan

**DELETE** `/api/v1/venues/:venue_id/floor_plans/:id`

Delete a floor plan. Cannot delete the default floor plan - set another as default first.

**Response:** 200 OK

**Error Response (422):**
```json
{
  "success": false,
  "error": "Cannot delete the default floor plan. Set another floor plan as default first."
}
```

---

### Activate Floor Plan

**POST** `/api/v1/venues/:venue_id/floor_plans/:id/activate`

Set a floor plan as the active/default floor plan. Sets status to `active` and `is_default` to `true`.

**Response:** 200 OK with floor plan summary

---

### Duplicate Floor Plan

**POST** `/api/v1/venues/:venue_id/floor_plans/:id/duplicate`

Duplicate an existing floor plan including all zones, tables, seats, and elements. The new floor plan will have "(Copy)" appended to the name and status set to `draft`.

**Response:** 201 Created with new floor plan details

---

### Create Zone

**POST** `/api/v1/venues/:venue_id/floor_plans/:id/zones`

Add a zone to a floor plan.

**Request Body:**
```json
{
  "zone": {
    "name": "VIP Section",
    "zone_type": "vip",
    "color": "#FFD700",
    "capacity": 50,
    "is_bookable": true,
    "is_active": true,
    "min_spend": 100.0,
    "display_order": 1,
    "geometry": {
      "type": "polygon",
      "coordinates": [[0, 0], [100, 0], [100, 100], [0, 100]]
    }
  }
}
```

**Required Fields:**
- `name`: Zone name
- `zone_type`: Type of zone (`vip`, `general`, `outdoor`, etc.)
- `geometry`: Geometry object defining the zone shape

**Optional Fields:**
- `color`: Zone color (hex code)
- `capacity`: Maximum capacity for the zone
- `is_bookable`: Whether zone is bookable (default: `false`)
- `is_active`: Whether zone is active (default: `true`)
- `min_spend`: Minimum spend requirement
- `display_order`: Display order for sorting

**Response:** 201 Created with zone details

---

### Update Zone

**PATCH** `/api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id`

Update zone details.

**Request Body:**
```json
{
  "zone": {
    "name": "Updated VIP Section",
    "capacity": 60,
    "min_spend": 150.0
  }
}
```

**Response:** 200 OK with updated zone details

---

### Delete Zone

**DELETE** `/api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id`

Delete a zone from a floor plan. This will also delete all tables and seats in the zone.

**Response:** 200 OK

---

### Create Table

**POST** `/api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id/tables`

Add a table to a zone. Optionally provide `seat_positions` array to auto-create seats.

**Request Body:**
```json
{
  "table": {
    "table_number": "T-01",
    "table_name": "Table 1",
    "table_type": "dining",
    "shape": "rectangle",
    "x_position": 100,
    "y_position": 200,
    "width": 80,
    "height": 120,
    "rotation": 0,
    "min_capacity": 2,
    "max_capacity": 4,
    "is_accessible": true,
    "is_active": true,
    "is_bookable": true,
    "color": "#4CAF50",
    "custom_properties": {}
  },
  "seat_positions": [
    {"x": 100, "y": 200, "label": "Seat 1", "type": "standard"},
    {"x": 180, "y": 200, "label": "Seat 2", "type": "standard"},
    {"x": 100, "y": 320, "label": "Seat 3", "type": "standard"},
    {"x": 180, "y": 320, "label": "Seat 4", "type": "standard"}
  ]
}
```

**Required Fields:**
- `table_number`: Unique table identifier
- `table_name`: Display name for the table
- `x_position`: X coordinate on floor plan
- `y_position`: Y coordinate on floor plan
- `width`: Table width
- `height`: Table height

**Optional Fields:**
- `table_type`: Type of table (`dining`, `bar`, `lounge`, etc.)
- `shape`: Table shape (`rectangle`, `circle`, `oval`, etc.)
- `rotation`: Rotation angle in degrees
- `min_capacity`: Minimum seating capacity
- `max_capacity`: Maximum seating capacity
- `is_accessible`: Whether table is wheelchair accessible
- `is_active`: Whether table is active
- `is_bookable`: Whether table is bookable
- `color`: Table color (hex code)
- `custom_properties`: Custom properties object
- `seat_positions`: Array of seat positions to auto-create

**Response:** 201 Created with table details

---

### Update Table

**PATCH** `/api/v1/venues/:venue_id/floor_plans/:id/tables/:table_id`

Update table details.

**Request Body:**
```json
{
  "table": {
    "table_name": "Updated Table 1",
    "max_capacity": 6,
    "is_bookable": false
  }
}
```

**Response:** 200 OK with updated table details

---

### Delete Table

**DELETE** `/api/v1/venues/:venue_id/floor_plans/:id/tables/:table_id`

Delete a table from a floor plan. This will also delete all seats for the table.

**Response:** 200 OK

---

### Create Element

**POST** `/api/v1/venues/:venue_id/floor_plans/:id/elements`

Add a decorative or functional element to a floor plan (e.g., bar, stage, entrance, restroom).

**Request Body:**
```json
{
  "element": {
    "element_type": "bar",
    "name": "Main Bar",
    "color": "#8B4513",
    "rotation": 0,
    "is_visible": true,
    "display_order": 1,
    "geometry": {
      "type": "rectangle",
      "x": 500,
      "y": 100,
      "width": 200,
      "height": 50
    },
    "properties": {
      "has_stools": true,
      "stool_count": 10
    }
  }
}
```

**Required Fields:**
- `element_type`: Type of element (`bar`, `stage`, `entrance`, `restroom`, etc.)
- `name`: Element name
- `geometry`: Geometry object defining element position and shape

**Optional Fields:**
- `color`: Element color (hex code)
- `rotation`: Rotation angle in degrees
- `is_visible`: Whether element is visible
- `display_order`: Display order for sorting
- `properties`: Custom properties object

**Response:** 201 Created with element details

---

### Update Element

**PATCH** `/api/v1/venues/:venue_id/floor_plans/:id/elements/:element_id`

Update element details.

**Request Body:**
```json
{
  "element": {
    "name": "Updated Main Bar",
    "is_visible": false
  }
}
```

**Response:** 200 OK with updated element details

---

### Delete Element

**DELETE** `/api/v1/venues/:venue_id/floor_plans/:id/elements/:element_id`

Delete an element from a floor plan.

**Response:** 200 OK

---

## Wallets & Payments

Comprehensive wallet and payment system with support for multiple payment providers (Stripe, PayPal, Crypto) and cryptocurrencies.

### 0. List Supported Currencies

**Endpoint:** `GET /api/v1/currencies`

**Description:** List supported currencies with icons.

**Response:**
```json
{
  "data": {
    "currencies": [
      { "code": "USD", "name": "US Dollar", "symbol": "$", "icon": "🇺🇸" },
      { "code": "EUR", "name": "Euro", "symbol": "€", "icon": "🇪🇺" }
    ]
  }
}
```

### 0b. List Supported Allergens

**Endpoint:** `GET /api/v1/allergens`

**Description:** List standardized allergens for menu items.

**Response:**
```json
{
  "data": {
    "allergens": [
      { "code": "milk", "label": "Milk" },
      { "code": "eggs", "label": "Eggs" },
      { "code": "fish", "label": "Fish" }
    ]
  }
}
```

### 0c. Create Allergen

**Endpoint:** `POST /api/v1/allergens`

**Authentication:** Bearer token required (admin)

**Request Body:**
```json
{
  "allergen": {
    "code": "peanuts",
    "label": "Peanuts",
    "description": "Peanuts and peanut-derived products"
  }
}
```

---

### 0d. Delete Allergen

**Endpoint:** `DELETE /api/v1/allergens/:id`

**Authentication:** Bearer token required (admin)

### 0e. Promo Codes

**List Promo Codes:** `GET /api/v1/promo_codes` (admin)

**Validate Promo Code:** `GET /api/v1/promo_codes/validate?code=SAVE10&event_id=...` or `&venue_id=...`

**Create Promo Code:** `POST /api/v1/promo_codes` (admin)
```json
{
  "promo_code": {
    "venue_id": "venue_uuid",
    "code": "SAVE10",
    "label": "10% Off",
    "discount_type": "percentage",
    "discount_value": 10,
    "starts_at": "2026-01-01T00:00:00Z",
    "ends_at": "2026-12-31T23:59:59Z",
    "max_uses": 100,
    "is_active": true
  }
}
```

**Notes:**
- Use `event_id` to scope a promo code to a single event.
- Use `venue_id` to scope a promo code to a venue (applies to all events in that venue).
- Do not send both `event_id` and `venue_id` in the same promo code.

**Update Promo Code:** `PATCH /api/v1/promo_codes/:id` (admin)

**Delete Promo Code:** `DELETE /api/v1/promo_codes/:id` (admin)

### 1. List Wallets

**Endpoint:** `GET /api/v1/wallets`

**Description:** Get list of user's wallets for all currencies.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "wallets": [
      {
        "id": "wallet_uuid",
        "currency": "USD",
        "balance": 150.50,
        "locked_balance": 25.00,
        "available_balance": 125.50,
        "status": "active",
        "created_at": "2025-11-20T12:00:00Z",
        "updated_at": "2025-11-26T08:00:00Z"
      }
    ]
  }
}
```

---

### 2. Get Wallet Details

**Endpoint:** `GET /api/v1/wallets/:id`

**Description:** Get detailed information about a specific wallet including recent transactions.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "wallet": {
      "id": "wallet_uuid",
      "currency": "USD",
      "balance": 150.50,
      "locked_balance": 25.00,
      "available_balance": 125.50,
      "status": "active",
      "recent_transactions": [...],
      "created_at": "2025-11-20T12:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 3. Get Wallet by Currency

**Endpoint:** `GET /api/v1/wallets/by_currency/:currency`

**Description:** Get wallet for a specific currency. Creates wallet if it doesn't exist.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "wallet": {
      "id": "wallet_uuid",
      "currency": "USD",
      "balance": 0.0,
      "locked_balance": 0.0,
      "available_balance": 0.0,
      "status": "active",
      "created_at": "2025-11-26T08:00:00Z",
      "updated_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 4. Deposit Funds

**Endpoint:** `POST /api/v1/payments/deposit`

**Description:** Initiate a deposit to user's wallet. Supports multiple payment providers.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "amount": 100.00,
  "currency": "USD",
  "payment_method": "credit_card",
  "provider": "stripe",
  "metadata": {
    "payment_method_id": "pm_1234"
  }
}
```

**Parameters:**
- `amount` (decimal, required): Deposit amount
- `currency` (string, optional): Currency code (default: USD)
- `payment_method` (string, required): Payment method type
- `provider` (string, optional): Payment provider name (default: configured default)
- `metadata` (object, optional): Additional metadata

**Response:**
```json
{
  "status": 201,
  "message": "Deposit initiated successfully",
  "data": {
    "transaction": {
      "id": "transaction_uuid",
      "transaction_type": "deposit",
      "status": "completed",
      "amount": 100.00,
      "currency": "USD",
      "payment_method": "credit_card",
      "payment_provider": "stripe",
      "fee": 3.20,
      "net_amount": 96.80,
      "created_at": "2025-11-26T08:00:00Z"
    },
    "provider_result": {
      "transaction_id": "ch_1234",
      "status": "succeeded"
    }
  }
}
```

---

### 5. Withdraw Funds

**Endpoint:** `POST /api/v1/payments/withdraw`

**Description:** Initiate a withdrawal from user's wallet. Balance is locked until transaction completes.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "amount": 50.00,
  "currency": "USD",
  "payment_method": "bank_transfer",
  "destination": "bank_account_id",
  "provider": "stripe"
}
```

**Parameters:**
- `amount` (decimal, required): Withdrawal amount
- `currency` (string, optional): Currency code (default: USD)
- `payment_method` (string, required): Payment method type
- `destination` (string, required): Destination account/wallet address
- `provider` (string, optional): Payment provider name

**Response:**
```json
{
  "status": 201,
  "message": "Withdrawal initiated successfully",
  "data": {
    "transaction": {
      "id": "transaction_uuid",
      "transaction_type": "withdrawal",
      "status": "processing",
      "amount": 50.00,
      "currency": "USD",
      "payment_method": "bank_transfer",
      "fee": 0.50,
      "net_amount": 49.50
    }
  }
}
```

---

### 6. Process Payment

**Endpoint:** `POST /api/v1/payments/pay`

**Description:** Process a payment. Can be linked to bookings, events, or other references.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "amount": 25.00,
  "currency": "USD",
  "payment_method": "credit_card",
  "reference_type": "Booking",
  "reference_id": "booking_uuid",
  "provider": "stripe"
}
```

**Parameters:**
- `amount` (decimal, required): Payment amount
- `currency` (string, optional): Currency code (default: USD)
- `payment_method` (string, required): Payment method type
- `reference_type` (string, optional): Type of reference (Booking, Event, etc.)
- `reference_id` (string, optional): ID of the reference
- `provider` (string, optional): Payment provider name

**Response:**
```json
{
  "status": 201,
  "message": "Payment processed successfully",
  "data": {
    "transaction": {
      "id": "transaction_uuid",
      "transaction_type": "payment",
      "status": "completed",
      "amount": 25.00,
      "currency": "USD",
      "payment_method": "credit_card",
      "fee": 1.03,
      "net_amount": 23.97
    }
  }
}
```

---

### 6b. Create Payment Intent (Stripe - Flutter Integration)

**Endpoint:** `POST /api/v1/payments/create_intent`

**Description:** Create a Stripe Payment Intent for Flutter app integration. Supports **partial payments, pre-payments, full payments, and overpayments** when linked to a booking. Returns a `client_secret` that can be used with Stripe Flutter SDK to process payments securely on the client side.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "amount": 50.00,
  "currency": "USD",
  "provider": "stripe",
  "reference_type": "Booking",
  "reference_id": "booking_uuid",
  "payment_type": "full",
  "customer_id": "cus_1234",
  "payment_method_id": "pm_1234",
  "metadata": {
    "event_id": "event_uuid",
    "booking_id": "booking_uuid"
  }
}
```

**Parameters:**
- `amount` (decimal, required): Payment amount
- `currency` (string, optional): Currency code (default: USD). If `reference_type` is `Booking`, uses booking currency
- `provider` (string, optional): Payment provider name (default: stripe)
- `reference_type` (string, optional): Type of reference (Booking, Event, etc.)
- `reference_id` (string, optional): ID of the reference
- `payment_type` (string, optional): Payment type - `pre_payment`, `partial`, `full`, or `overpayment`. If not provided, automatically determined based on amount:
  - If `amount >= remaining`: `full` or `overpayment` (if amount > remaining)
  - If `amount < remaining`: `partial`
- `customer_id` (string, optional): Stripe customer ID (if available)
- `payment_method_id` (string, optional): Stripe payment method ID (if available)
- `metadata` (object, optional): Additional metadata

**Payment Types (when reference_type is Booking):**

1. **Pre-payment (`pre_payment`)**: Deposit before full booking confirmation
   - Amount can be less than booking price
   - Useful for securing a booking with a deposit

2. **Partial Payment (`partial`)**: Paying part of the remaining amount
   - Amount must be less than remaining amount
   - Booking status remains `created` or `confirmed` with `payment_status: partial`
   - Can make multiple partial payments until fully paid

3. **Full Payment (`full`)**: Paying exactly the remaining amount
   - Amount must match remaining amount (within 1 cent tolerance)
   - Booking status updated to `confirmed` and `payment_status: paid`
   - Default if amount not provided

4. **Overpayment (`overpayment`)**: Paying more than booking price
   - Amount must be greater than remaining amount
   - Useful when including pre-orders or additional items
   - Booking marked as fully paid, excess tracked separately

**Response (Generic Payment):**
```json
{
  "status": 201,
  "message": "Payment intent created successfully",
  "data": {
    "payment_intent_id": "pi_1234567890",
    "client_secret": "pi_1234567890_secret_abc123",
    "transaction_id": "transaction_uuid",
    "status": "requires_payment_method",
    "amount": 50.00,
    "currency": "USD"
  }
}
```

**Response (Booking Payment):**
```json
{
  "status": 201,
  "message": "Payment intent created successfully",
  "data": {
    "payment_intent_id": "pi_1234567890",
    "client_secret": "pi_1234567890_secret_abc123",
    "transaction_id": "transaction_uuid",
    "booking_id": "booking_uuid",
    "payment_type": "full",
    "amount": 50.00,
    "currency": "USD",
    "booking_price": 100.00,
    "remaining_amount": 0.00,
    "current_paid_amount": 50.00,
    "original_price": 100.00,
    "discount_amount": 0.00,
    "promo_code": null,
    "status": "requires_payment_method"
  }
}
```

**Usage Flow (Flutter):**
1. Call this endpoint to create a Payment Intent (specify `amount` and `payment_type` if needed)
2. Use `client_secret` with Stripe Flutter SDK
3. Confirm payment in Flutter app
4. Optionally call `/confirm_intent` endpoint to verify
5. Backend receives webhook from Stripe to update transaction status
6. If linked to booking, booking `paid_amount` and `payment_status` automatically updated

**Booking Payment Validation:**
- When `reference_type` is `Booking`, the system validates:
  - `amount` matches booking requirements based on `payment_type`
  - Booking is not already fully paid
  - Booking is not canceled
  - Booking is not free
- If validation fails, returns `400 Bad Request` with details

**Errors:**
- `400`: Provider not found or inactive
- `400`: Invalid payment_type
- `400`: Partial payment amount must be less than remaining amount
- `400`: Full payment amount must match remaining amount
- `400`: Overpayment amount must be greater than remaining amount
- `400`: Payment amount does not match booking price (if full payment expected)
- `404`: Reference not found (if reference_type/reference_id provided)
- `403`: Unauthorized (booking belongs to different user)

---

### 6c. Confirm Payment Intent (Stripe - Flutter Integration)

**Endpoint:** `POST /api/v1/payments/confirm_intent`

**Description:** Confirm a Payment Intent after Flutter app processes payment. This is optional as webhooks will also update the status, but can be used for immediate confirmation.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "payment_intent_id": "pi_1234567890",
  "payment_method_id": "pm_1234",
  "return_url": "https://yourapp.com/return"
}
```

**Parameters:**
- `payment_intent_id` (string, required): Stripe Payment Intent ID
- `payment_method_id` (string, optional): Payment method ID to attach
- `return_url` (string, optional): Return URL for 3D Secure redirects

**Response:**
```json
{
  "status": 200,
  "message": "Payment intent confirmed",
  "data": {
    "payment_intent_id": "pi_1234567890",
    "status": "succeeded",
    "transaction": {
      "id": "transaction_uuid",
      "status": "completed",
      "amount": 50.00,
      "currency": "USD"
    }
  }
}
```

**Status Values:**
- `succeeded`: Payment completed successfully
- `requires_action`: Additional action needed (3D Secure, etc.)
- `requires_payment_method`: Payment method required
- `processing`: Payment is being processed
- `canceled`: Payment was canceled

---

### 6d. Check Payment Intent Status

**Endpoint:** `GET /api/v1/payments/intent/:payment_intent_id`

**Description:** Check the status of a Payment Intent. Useful for polling payment status or verifying completion.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "data": {
    "payment_intent_id": "pi_1234567890",
    "status": "succeeded",
    "transaction": {
      "id": "transaction_uuid",
      "transaction_type": "payment",
      "status": "completed",
      "amount": 50.00,
      "currency": "USD",
      "payment_method": "credit_card",
      "payment_provider": "stripe",
      "created_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

**Errors:**
- `404`: Transaction not found
- `403`: Unauthorized (transaction belongs to different user)

---

### 6e. Create Payment Intent for Booking

**Endpoint:** `POST /api/v1/bookings/:id/create_payment_intent`

**Description:** Create a Payment Intent specifically for a booking. Supports **partial payments, pre-payments, full payments, and overpayments**. Automatically uses booking currency.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "provider": "stripe",
  "amount": 50.00,
  "payment_type": "full",
  "customer_id": "cus_1234",
  "payment_method_id": "pm_1234"
}
```

**Parameters:**
- `provider` (string, optional): Payment provider name (default: stripe)
- `amount` (decimal, optional): Payment amount. If not provided, defaults to remaining amount (full payment)
- `payment_type` (string, optional): Payment type - `pre_payment`, `partial`, `full`, or `overpayment`. If not provided, automatically determined based on amount
- `customer_id` (string, optional): Stripe customer ID
- `payment_method_id` (string, optional): Stripe payment method ID

**Payment Types:**

1. **Pre-payment (`pre_payment`)**: Deposit before full booking confirmation
2. **Partial Payment (`partial`)**: Paying part of the remaining amount
3. **Full Payment (`full`)**: Paying exactly the remaining amount (default)
4. **Overpayment (`overpayment`)**: Paying more than booking price

**Response:**
```json
{
  "status": 201,
  "message": "Payment intent created successfully",
  "data": {
    "payment_intent_id": "pi_1234567890",
    "client_secret": "pi_1234567890_secret_abc123",
    "transaction_id": "transaction_uuid",
    "booking_id": "booking_uuid",
    "amount": 50.00,
    "currency": "USD",
    "payment_type": "full",
    "booking_price": 100.00,
    "remaining_amount": 0.00,
    "current_paid_amount": 50.00,
    "original_price": 100.00,
    "discount_amount": 0.00,
    "promo_code": null,
    "status": "requires_payment_method"
  }
}
```

**Errors:**
- `400`: Booking is already fully paid
- `400`: Booking is canceled
- `400`: Booking is free (no payment required)
- `400`: Invalid payment_type
- `400`: Amount validation failed (e.g., partial payment exceeds remaining amount)
- `404`: Booking not found

**Notes:**
- This endpoint automatically uses the booking's currency
- Payment Intent is linked to the booking via reference
- When payment succeeds (via webhook), booking `paid_amount` and `payment_status` are automatically updated
- Multiple payments can be made until booking is fully paid
- See section 6b for detailed payment type explanations

---

### 6f. Stripe Payment Intents Flow (Flutter Integration)

**Complete Payment Flow:**

1. **Create Payment Intent** (`POST /api/v1/payments/create_intent` or `POST /api/v1/bookings/:id/create_payment_intent`)
   - Backend creates Stripe Payment Intent
   - Returns `client_secret` and `payment_intent_id`
   - Creates `PaymentTransaction` record with status `pending`
   - For bookings, supports partial/pre-payment/full/overpayment types

2. **Process Payment in Flutter**
   - Use `client_secret` with Stripe Flutter SDK
   - Stripe SDK handles card input, 3D Secure, etc.
   - Payment is processed securely on client side

3. **Confirm Payment (Optional)**
   - Call `POST /api/v1/payments/confirm_intent` for immediate confirmation

**Partial Payment Flow:**

1. **First Payment (Partial)**
   ```json
   POST /api/v1/bookings/:id/create_payment_intent
   {
     "amount": 25.00,
     "payment_type": "partial"
   }
   ```
   - Booking: `paid_amount: 0`, `payment_status: pending`, `remaining_amount: 100`
   - After payment: `paid_amount: 25`, `payment_status: partial`, `remaining_amount: 75`, `payment_progress_percentage: 25.0`, `fully_paid: false`, `partially_paid: true`

2. **Second Payment (Partial)**
   ```json
   POST /api/v1/bookings/:id/create_payment_intent
   {
     "amount": 30.00,
     "payment_type": "partial"
   }
   ```
   - After payment: `paid_amount: 55`, `payment_status: partial`, `remaining_amount: 45`, `payment_progress_percentage: 55.0`, `fully_paid: false`, `partially_paid: true`

3. **Final Payment (Full)**
   ```json
   POST /api/v1/bookings/:id/create_payment_intent
   {
     "amount": 45.00,
     "payment_type": "full"
   }
   ```
   - After payment: `paid_amount: 100`, `payment_status: paid`, `remaining_amount: 0`, `payment_progress_percentage: 100.0`, `fully_paid: true`, `partially_paid: false`, `status: confirmed`

**Booking Response Fields:**

All booking responses now include the following payment-related fields:

- `payment_type` (string): Type of payment - `pre_payment`, `partial`, `full`, or `overpayment`
- `paid_amount` (decimal): Cumulative amount paid (can exceed `price` for overpayments)
- `remaining_amount` (decimal): Amount still owed (`price - paid_amount`, minimum 0)
- `payment_progress_percentage` (decimal): Payment progress percentage (can exceed 100% for overpayments)
- `fully_paid` (boolean): Whether booking is fully paid (`payment_status: paid` and `remaining_amount: 0`)
- `partially_paid` (boolean): Whether booking is partially paid (`payment_status: partial`)
- `payment_status` (string): Payment status - `pending`, `partial`, `paid`, `failed`, or `refunded`
   - Or wait for webhook (recommended)

4. **Webhook Updates (Automatic)**
   - Stripe sends webhook to `POST /api/v1/webhooks/stripe`
   - Backend receives `payment_intent.succeeded` event
   - Automatically updates:
     - `PaymentTransaction` status to `completed`
     - If linked to booking: booking status to `confirmed` and `payment_status` to `paid`
     - Wallet balance (if applicable)

5. **Check Status (Optional)**
   - Poll `GET /api/v1/payments/intent/:payment_intent_id` to check status
   - Or rely on webhook updates

**Webhook Events Handled:**
- `payment_intent.succeeded`: Payment completed successfully
- `payment_intent.payment_failed`: Payment failed
- `payment_intent.requires_action`: Additional action needed (3D Secure)
- `charge.succeeded`: Charge completed
- `charge.refunded`: Refund processed

**Webhook Setup:**
- Configure webhook endpoint in Stripe Dashboard: `https://your-domain.com/api/v1/webhooks/stripe`
- Required events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`
- Webhook secret stored in `STRIPE_WEBHOOK_SECRET` environment variable

---

### 7. List Payment Transactions

**Endpoint:** `GET /api/v1/payment_transactions`

**Description:** Get list of payment transactions with optional filters.

**Authentication:** Bearer token required

**Query Parameters:**
- `transaction_type` (string, optional): Filter by type (deposit, withdrawal, payment, refund, transfer)
- `status` (string, optional): Filter by status (pending, processing, completed, failed, cancelled, refunded)
- `payment_method` (string, optional): Filter by payment method
- `currency` (string, optional): Filter by currency
- `limit` (integer, optional): Number of results per page (default: 50, max: 100)
- `offset` (integer, optional): Number of results to skip (default: 0)

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "transactions": [
      {
        "id": "transaction_uuid",
        "transaction_type": "deposit",
        "status": "completed",
        "amount": 100.00,
        "currency": "USD",
        "payment_method": "credit_card",
        "payment_provider": "stripe",
        "fee": 3.20,
        "net_amount": 96.80,
        "created_at": "2025-11-26T08:00:00Z"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 25,
      "has_more": false
    }
  }
}
```

---

### 8. Get Transaction Details

**Endpoint:** `GET /api/v1/payment_transactions/:id`

**Description:** Get detailed information about a specific transaction.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "transaction": {
      "id": "transaction_uuid",
      "transaction_type": "payment",
      "status": "completed",
      "amount": 25.00,
      "currency": "USD",
      "payment_method": "credit_card",
      "payment_provider": "stripe",
      "fee": 1.03,
      "net_amount": 23.97,
      "description": "Payment for event booking",
      "wallet": {
        "id": "wallet_uuid",
        "currency": "USD"
      },
      "provider_transaction_id": "ch_1234",
      "reference": {
        "type": "Booking",
        "id": "booking_uuid"
      },
      "metadata": {},
      "processed_at": "2025-11-26T08:00:00Z",
      "created_at": "2025-11-26T08:00:00Z"
    }
  }
}
```

---

### 9. Refund Transaction

**Endpoint:** `POST /api/v1/payment_transactions/:id/refund`

**Description:** Process a refund for a completed transaction. Amount is optional (defaults to full amount).

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "amount": null,
  "reason": "Customer requested refund"
}
```

**Parameters:**
- `amount` (decimal, optional): Refund amount (defaults to full transaction amount)
- `reason` (string, optional): Refund reason

**Response:**
```json
{
  "status": 201,
  "message": "Refund processed successfully",
  "data": {
    "refund_transaction": {
      "id": "refund_transaction_uuid",
      "transaction_type": "refund",
      "status": "completed",
      "amount": 25.00,
      "currency": "USD",
      "fee": 0,
      "net_amount": 25.00
    }
  }
}
```

---

### 10. List Payment Methods

**Endpoint:** `GET /api/v1/payment_methods`

**Description:** Get list of saved payment methods.

**Authentication:** Bearer token required

**Query Parameters:**
- `provider` (string, optional): Filter by provider
- `type` (string, optional): Filter by payment method type

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "payment_methods": [
      {
        "id": "payment_method_uuid",
        "payment_method_type": "credit_card",
        "provider": "stripe",
        "display_name": "Visa •••• 4242",
        "is_default": true,
        "status": "active",
        "created_at": "2025-11-20T12:00:00Z"
      }
    ]
  }
}
```

---

### 11. Add Payment Method

**Endpoint:** `POST /api/v1/payment_methods`

**Description:** Add a saved payment method (card, bank account, crypto wallet, etc.).

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "payment_method": {
    "payment_method_type": "credit_card",
    "provider": "stripe",
    "provider_payment_method_id": "pm_1234",
    "card_brand": "Visa",
    "card_last4": "4242",
    "card_exp_month": "12",
    "card_exp_year": "2025",
    "billing_name": "John Doe",
    "billing_email": "john@example.com",
    "billing_address": {
      "line1": "123 Main St",
      "city": "San Juan",
      "state": "PR",
      "postal_code": "00901",
      "country": "US"
    }
  }
}
```

**Response:**
```json
{
  "status": 201,
  "message": "Payment method added successfully",
  "data": {
    "payment_method": {
      "id": "payment_method_uuid",
      "payment_method_type": "credit_card",
      "provider": "stripe",
      "display_name": "Visa •••• 4242",
      "is_default": false,
      "status": "active"
    }
  }
}
```

---

### 12. Set Default Payment Method

**Endpoint:** `POST /api/v1/payment_methods/:id/set_default`

**Description:** Set a payment method as default for the user.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Payment method set as default",
  "data": {
    "payment_method": {
      "id": "payment_method_uuid",
      "is_default": true
    }
  }
}
```

---

### 13. List Crypto Wallets

**Endpoint:** `GET /api/v1/crypto_wallets`

**Description:** Get list of user's cryptocurrency wallets.

**Authentication:** Bearer token required

**Response:**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "crypto_wallets": [
      {
        "id": "crypto_wallet_uuid",
        "crypto_currency": "BTC",
        "wallet_address": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        "short_address": "bc1qx...#wlh",
        "wallet_type": "external",
        "network": "bitcoin",
        "status": "active",
        "display_name": "BTC Wallet",
        "created_at": "2025-11-20T12:00:00Z"
      }
    ]
  }
}
```

---

### 14. Add Crypto Wallet

**Endpoint:** `POST /api/v1/crypto_wallets`

**Description:** Add a cryptocurrency wallet address. Supported: BTC, ETH, USDT, USDC, SOL, MATIC, BNB.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "crypto_wallet": {
    "crypto_currency": "BTC",
    "wallet_address": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
    "wallet_type": "external",
    "network": "bitcoin"
  }
}
```

**Parameters:**
- `crypto_wallet.crypto_currency` (string, required): Cryptocurrency code (BTC, ETH, USDT, USDC, SOL, MATIC, BNB)
- `crypto_wallet.wallet_address` (string, required): Wallet address
- `crypto_wallet.wallet_type` (string, optional): Type (external, internal) - default: external
- `crypto_wallet.network` (string, optional): Network name

**Response:**
```json
{
  "status": 201,
  "message": "Crypto wallet added successfully",
  "data": {
    "crypto_wallet": {
      "id": "crypto_wallet_uuid",
      "crypto_currency": "BTC",
      "wallet_address": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
      "wallet_type": "external",
      "network": "bitcoin",
      "status": "active",
      "display_name": "BTC Wallet"
    }
  }
}
```

---

### Payment Providers

The system supports multiple payment providers:

- **Stripe**: Credit/debit cards, Apple Pay, Google Pay
- **PayPal**: PayPal payments and payouts
- **Crypto**: Cryptocurrency payments (BTC, ETH, USDT, USDC, SOL, MATIC, BNB)

Payment providers are configured via the admin interface and can be activated/deactivated as needed.

---

### Supported Payment Methods

- `credit_card` - Credit card payments
- `debit_card` - Debit card payments
- `bank_transfer` - Bank transfer/ACH
- `crypto` - Cryptocurrency payments
- `paypal` - PayPal payments
- `apple_pay` - Apple Pay
- `google_pay` - Google Pay

---

### Transaction Types

- `deposit` - Funds added to wallet
- `withdrawal` - Funds withdrawn from wallet
- `payment` - Payment for goods/services
- `refund` - Refund of a previous payment
- `transfer` - Transfer between wallets

---

### Transaction Statuses

- `pending` - Transaction initiated, awaiting processing
- `processing` - Transaction being processed
- `completed` - Transaction completed successfully
- `failed` - Transaction failed
- `cancelled` - Transaction cancelled
- `refunded` - Transaction refunded

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Validation failed",
  "errors": {
    "email": ["is invalid"],
    "password": ["is too short"]
  }
}
```

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

### 404 Not Found
```json
{
  "error": "Not Found",
  "message": "Resource not found"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Unprocessable Entity",
  "message": "OTP verification failed"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```

---

## Rate Limiting

API endpoints may be rate-limited. Rate limit headers are included in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1633024800
```

---

## Environment Variables

The Postman collection uses the following environment variables:

- `base_url`: API base URL (default: `http://localhost:3000`)
- `jwt_token`: JWT authentication token
- `user_id`: Current user ID
- `phone_number`: User phone number
- `email`: User email
- `verification_token`: OTP verification token
- `device_token`: Device authentication token
- `device_id`: Device ID
- `is_new_user`: Whether user is new
- `category_id_1`, `category_id_2`, etc.: Category IDs for testing
- `venue_id`: Venue ID
- `event_id`: Event ID
- `rating_id`: Rating ID
- `booking_id`: Booking ID
- `group_chat_id`: Group chat ID
- `message_id`: Message ID
- `chat_id`: One-on-one chat ID
- `chat_message_id`: Chat message ID
- `wallet_id`: Wallet ID
- `transaction_id`: Payment transaction ID
- `payment_method_id`: Payment method ID
- `crypto_wallet_id`: Crypto wallet ID
- `email_verification_token`: Token for email change verification
- `phone_verification_token`: Token for phone change verification

---

## Support

### 1. Support Tickets

Support tickets allow users to contact the support team for common issues (payments, bookings, events, venues, accounts, bugs, feedback).

#### 1.1 Create Support Ticket

**Endpoint:** `POST /api/v1/support/tickets`

**Description:** Create a support ticket as the current authenticated user.

**Authentication:** Bearer token required

**Request Body:**
```json
{
  "ticket": {
    "reason": "booking_issue",
    "custom_reason": null,
    "description": "My QR code is not scanning at the door.",
    "related_type": "Booking",
    "related_id": "booking_uuid"
  }
}
```

**Reason values:**
- `payment_issue`
- `booking_issue`
- `event_issue`
- `venue_issue`
- `account_issue`
- `bug_report`
- `feedback`
- `other`

When `reason` is `other`, clients should prompt for `custom_reason`.

#### 1.2 List My Tickets

**Endpoint:** `GET /api/v1/support/tickets/my`

**Description:** List support tickets created by the current user.

**Query Parameters:**
- `status` (optional): `open`, `in_progress`, `resolved`, `closed`

#### 1.3 Support Team Endpoints

For users with `support` or `admin` role:

- `GET /api/v1/support/tickets` – list tickets (filters: `status`, `reason`, `assigned_to_id`).
- `GET /api/v1/support/tickets/:id` – get single ticket.
- `PATCH /api/v1/support/tickets/:id` – update `status`, `priority` (`low`, `medium`, `high`), `assigned_to_id`, `description`, `custom_reason`.
- `GET /api/v1/support/reasons` – list reasons with keys and labels for client dropdowns.

---

**Document Version:** 2.0  
**Last Updated:** November 2025  
**Maintained By:** Vibes Engineering Team


