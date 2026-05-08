# Real Estate API Documentation

**Version:** 1.0  
**Base URL (dev):** `http://localhost:3000`  

## Roles

- **user**: Can browse approved properties.
- **owner**: Can create/update their properties and submit them for review.
- **support**: Can review and approve/reject properties.
- **admin**: Full access (same review powers as support).

Allowed roles are enforced by the DB constraint on `users.role`.

## Authentication (OTP)

### Send OTP
`POST /api/v1/auth/send_otp`

Body (phone):

```json
{ "phone": "1234567890" }
```

Body (email):

```json
{ "email": "test@example.com" }
```

### Verify OTP
`POST /api/v1/auth/verify_otp`

```json
{ "phone": "1234567890", "code": "123456" }
```

- If the user does not exist, response contains `verification_token` (use it to complete registration).
- If the user exists, response contains `token` (JWT).

### Complete registration
`POST /api/v1/auth/complete_registration`

```json
{
  "verification_token": "<token-from-verify_otp>",
  "role": "user",
  "name": "Your name"
}
```

Allowed `role`: `user | owner | support | admin`

### Current user
`GET /api/v1/auth/me`

Auth: `Authorization: Bearer <jwt>`

## Properties

### List properties
`GET /api/v1/properties`

- Public: only `approved`
- Owner (authenticated): `approved` + their own (any status)
- Support/Admin: all

Optional query:
- `limit`
- `search`
- `country`
- `city`
- `north/south/east/west` (bounding box)
- `status` (support/admin only)

### Create property (owner)
`POST /api/v1/properties`

Auth: owner only

```json
{
  "property": {
    "title": "2BHK Apartment",
    "description": "Near metro",
    "property_type": "apartment",
    "bedrooms": 2,
    "bathrooms": 2,
    "area_sqft": 950,
    "address1": "Street 1",
    "address2": "",
    "city": "Mumbai",
    "region": "MH",
    "postal_code": "400001",
    "country": "IN",
    "latitude": 19.076,
    "longitude": 72.8777,
    "price": 12000000,
    "currency": "INR"
  }
}
```

### Submit for approval (owner)
`POST /api/v1/properties/:id/submit`

Moves `draft/rejected → pending_review`.

### Approve (support/admin)
`POST /api/v1/properties/:id/approve`

### Reject (support/admin)
`POST /api/v1/properties/:id/reject`

```json
{ "reason": "Missing documents" }
```

## Property media

### Upload images (multiple)
`POST /api/v1/properties/:id/images`

Multipart form-data:
- `images[]` (repeatable)

### Remove one image
`DELETE /api/v1/properties/:id/images/:image_id`

### Upload video (exactly one)
`POST /api/v1/properties/:id/video`

Multipart form-data:
- `video`

Uploading a new video replaces the previous one.

### Remove video
`DELETE /api/v1/properties/:id/video`

## Map (properties only)

### Markers
`GET /api/v1/maps`

Returns:
- `properties` (markers)
- `bounds`
- `metadata`

### Filter options
`GET /api/v1/maps/filter_options`

