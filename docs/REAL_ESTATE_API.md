# Real Estate API Documentation

**Version:** 1.0  
**Base URL (dev):** `http://localhost:3000`  

## Roles

- **user**: Can browse approved properties.
- **owner**: Can create/update their properties and submit them for review.
- **admin**: Not a role. It is `users.is_admin=true`. Admin can approve/reject, manage viewings, and manage support tickets.

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
Allowed `role`: `user | owner`

### Current user
`GET /api/v1/auth/me`

Auth: `Authorization: Bearer <jwt>`

### Forgot password

Step 1: request reset OTP.

`POST /api/v1/auth/forgot_password`

By email:

```json
{ "email": "user@example.com" }
```

By phone:

```json
{ "phone": "9876543210" }
```

Step 2: verify reset OTP and get `reset_token`.

`POST /api/v1/auth/verify_reset_otp`

```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

Response:

```json
{
  "reset_token": "...",
  "expires_in": "15 minutes"
}
```

Step 3: reset password.

`POST /api/v1/auth/reset_password`

```json
{
  "reset_token": "...",
  "password": "NewPassword123",
  "password_confirmation": "NewPassword123"
}
```

On success, response includes a fresh login token.

### Delete account

Auth: `Authorization: Bearer <jwt>`

Preferred:

`DELETE /api/v1/users/me`

Also supported:

`POST /api/v1/users/me/delete`

Optional JSON body:

```json
{
  "reason": "Other reason",
  "additional_feedback": "No longer need the app"
}
```

This permanently deletes the account and attached profile picture. Use `POST /api/v1/users/me/deactivate` if the user only wants to disable the account.

### Register device
`POST /api/v1/auth/register_device`

Auth: `Authorization: Bearer <jwt>`

Use this after login to register the physical device. It also accepts `fcm_token`, so you can register the device and push token in one call.

```json
{
  "device_uuid": "device-uuid-123",
  "device_name": "Pixel 8",
  "device_type": "phone",
  "platform": "android",
  "platform_version": "14",
  "app_version": "1.0.0",
  "biometric_enabled": false,
  "fcm_token": "FCM_DEVICE_TOKEN_HERE"
}
```

Required:

- `device_uuid`
- `platform`: `ios | android`

Response for a new device includes `device_token`, which is used for biometric / PIN auth endpoints.

If the same `device_uuid` was previously registered to another account or to an old revoked record, the old record is removed and the new registration becomes the only valid one.

### Register FCM token
`POST /api/v1/auth/register_fcm_token`

Auth: `Authorization: Bearer <jwt>`

Use this after login, and whenever Firebase gives a new token.

```json
{
  "fcm_token": "FCM_DEVICE_TOKEN_HERE",
  "device_uuid": "device-uuid-123",
  "platform": "android",
  "device_name": "Pixel 8",
  "device_type": "phone",
  "platform_version": "14",
  "app_version": "1.0.0"
}
```

- `platform`: `ios | android`
- If the device already exists, this updates the token.
- If the device does not exist, this registers the device and stores the token.

Existing update-only endpoint:

`POST /api/v1/auth/update_fcm_token`

```json
{
  "fcm_token": "FCM_DEVICE_TOKEN_HERE",
  "device_uuid": "device-uuid-123"
}
```

### Device list / biometric / revoke

All endpoints require Bearer auth.

List active devices:

`GET /api/v1/auth/devices`

Enable biometric:

`POST /api/v1/auth/devices/:device_id/enable_biometric`

Also supports existing route:

`PATCH /api/v1/auth/devices/:device_id/enable_biometric`

Disable biometric:

`POST /api/v1/auth/devices/:device_id/disable_biometric`

Also supports existing route:

`PATCH /api/v1/auth/devices/:device_id/disable_biometric`

Revoke device:

`POST /api/v1/auth/devices/:device_id/revoke`

Also supports existing route:

`DELETE /api/v1/auth/devices/:device_id`

Use `device_id` from the `GET /api/v1/auth/devices` response.

## Legal Documents

### List legal documents
`GET /api/v1/legal_documents`

Returns all supported document slots:

- `community_guidelines`
- `terms_of_service`
- `privacy_policy`

### Show legal document
`GET /api/v1/legal_documents/:kind`

### Upload legal document (admin)
`POST /api/v1/legal_documents`

Auth: admin Bearer token.

Multipart form-data:

- `kind`: `community_guidelines | terms_of_service | privacy_policy`
- `file`: uploaded PDF/HTML/TXT/DOC/DOCX binary file

Also accepts `document` instead of `file`, and `document_type` or `type` instead of `kind`.

Existing admin path still works:

`POST /api/v1/admin/legal_documents/:kind/upload`

## WebSocket

ActionCable endpoint:

```text
wss://<host>/cable?token=<jwt_token>
```

Real-estate channels:

- `OwnerDashboardChannel` — owner dashboard summary updates.
- `PropertyChannel` — updates for one property (`property_id` required).
- `UserNotificationsChannel` — real-time DB notifications and per-user updates.

See `docs/REAL_ESTATE_WEBSOCKET.md` for subscribe payloads and event shapes.

## Notifications

All notification endpoints require Bearer auth.

### List notifications
`GET /api/v1/notifications?page=1&per_page=20`

Optional:

- `unread_only=true`
- `type=property_approved`

### Unread count
`GET /api/v1/notifications/unread_count`

### Show notification
`GET /api/v1/notifications/:id`

Marks the notification as read.

### Mark one read
`PATCH /api/v1/notifications/:id/mark_read`

### Mark all read
`POST /api/v1/notifications/mark_all_read`

### Delete notification
`DELETE /api/v1/notifications/:id`

### Test notification
`POST /api/v1/notifications/test`

```json
{
  "title": "Test Notification",
  "body": "This is a test"
}
```

Notification create/read/delete events also broadcast on `UserNotificationsChannel`.

## Properties

### List properties
`GET /api/v1/properties`

- Public: only `approved`
- Owner (authenticated): `approved` + their own (any status)
- Support/Admin: all
- Admin (`is_admin=true`): all

Optional query:
- `limit`
- `search`
- `country`
- `city`
- `region`
- `purpose` (`sale|rent`)
- `property_type` (repeatable)
- `min_price` / `max_price`
- `min_bedrooms` / `max_bedrooms`
- `min_bathrooms` / `max_bathrooms`
- `min_area_sqm` / `max_area_sqm`
- `features[]` (repeatable, matches `features.<key>=true`)
- `sort_by` (`newest|price_asc|price_desc`)
- `north/south/east/west` (bounding box)
- `status` (admin only: approval status filter)
- `listing_status` (admin only: `active|sold|archived`)

### Create property (owner)
`POST /api/v1/properties`

Auth: owner only

```json
{
  "property": {
    "title": "2BHK Apartment",
    "description": "Near metro",
    "property_type": "apartment",
    "purpose": "sale",
    "bedrooms": 2,
    "bathrooms": 2,
    "area_sqft": 950,
    "area_sqm": 88.0,
    "address1": "Street 1",
    "address2": "",
    "city": "Mumbai",
    "region": "MH",
    "postal_code": "400001",
    "country": "IN",
    "latitude": 19.076,
    "longitude": 72.8777,
    "price": 12000000,
    "currency": "INR",
    "features": { "elevator": true, "balcony": true }
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

### Mark sold (owner/admin)
`POST /api/v1/properties/:id/mark_sold`

### Archive (owner/admin)
`POST /api/v1/properties/:id/archive`

### Unarchive (owner/admin)
`POST /api/v1/properties/:id/unarchive`

## Favorites

### List my favorites
`GET /api/v1/favorites`

### Favorite a property
`POST /api/v1/properties/:property_id/favorite`

### Unfavorite a property
`DELETE /api/v1/properties/:property_id/favorite`

## Viewings (appointments)

### Request a viewing (user)
`POST /api/v1/properties/:property_id/viewings`

```json
{
  "viewing": {
    "requested_for": "2026-05-10T10:00:00Z",
    "message": "I want to visit on Saturday morning",
    "contact_phone": "1234567890"
  }
}
```

### My viewings (user)
`GET /api/v1/viewings/my`

### Viewings for a property (owner/admin)
`GET /api/v1/properties/:property_id/viewings`

### Admin list viewings
`GET /api/v1/viewings`

Optional query:
- `status`
- `property_id`
- `user_id`
- `limit`

### Admin update viewing status
`PATCH /api/v1/viewings/:id`

```json
{
  "viewing": {
    "status": "confirmed",
    "admin_notes": "Confirmed with owner by phone"
  }
}
```

### Cancel viewing (user/admin)
`POST /api/v1/viewings/:id/cancel`

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
- optional `video_projection=equirectangular` or `is_360=true`

Uploading a new video replaces the previous one.

### Upload 360 video (one-step)
`POST /api/v1/properties/:id/360_video`

Multipart form-data:
- `video` — equirectangular 2:1 MP4

This automatically sets `video_projection` to `equirectangular`, replaces the previous video, and returns `view_360_url` / `immersive_video_view_url`.

### Remove video
`DELETE /api/v1/properties/:id/video`

## Owner dashboard (replaces Vibes venue_manager)

Property owner only (`role: owner` or user with owned properties). **Not** scoped to a venue id.

### Summary (all listings)
`GET /api/v1/owner/dashboard_summary`

Legacy alias: `GET /api/v1/venue_manager/dashboard_summary`

Returns counts for your properties (approval/listing status), viewings, favorites, and 5 recent listings.

### Metrics by period
`GET /api/v1/owner/dashboard_metrics?period=monthly`

Legacy alias: `GET /api/v1/venue_manager/dashboard_metrics?period=monthly`

`period`: `weekly` | `monthly` | `6months` | `1year` (default `monthly`).

Includes `listings`, `viewings`, `engagement`, and legacy-shaped `rsvp` / `tickets` blocks for app compatibility (`rsvp` = viewings, `tickets` = sold listings / sale value).

## Map (properties only)

### Markers
`GET /api/v1/maps`

Vibes-style query (venues/events → **properties** on this app):

```
GET /api/v1/maps?show_properties=true
  &center_latitude=40.7128&center_longitude=-74.0060&radius_km=10
  &north=&south=&east=&west=
  &city=&country=&region=&search=
  &purpose=sale&property_type=apartment
  &min_price=&max_price=&min_bedrooms=&has_360_view=true&features[]=elevator
  &sort_by=distance&limit=100
```

**Layer toggle:** `show_properties=true|false` (default `true`). Legacy aliases: `show_venues`, `show_events` (either `true` includes properties).

**Geo:** use **radius** (`center_latitude`, `center_longitude`, `radius_km`) **or** **bounding box** (`north`, `south`, `east`, `west`) — not both required; empty strings are ignored.

**Filters:** `city`, `country`, `region`, `search`, `purpose`, `property_type` (legacy: `category`), `currency`, price/bedroom/bathroom/area ranges, `features[]`, `has_360_view=true`.

**Admin only:** `approval_status` / `status`, `listing_status`. Legacy `event_status`: `published` → approved.

**Sort:** `distance` (needs center), `newest`, `oldest`, `price_asc`, `price_desc`.

Returns:
- `properties` — full marker payloads (`type: "property"`, images with `id`, `is_favorited`, 360° fields, …)
  - `has_360_view` — `true` when equirectangular video is attached
  - `view_360_url` / `immersive_video_view_url` — WebView URL for `/venue_360_viewer.html`
  - `view_360` — `{ available, projection, video_url, viewer_url }`
- `bounds` — computed from results
- `metadata` — `properties_count`, `properties_with_360_count`, `total_markers`, `show_properties`, optional `center`

### Filter options
`GET /api/v1/maps/filter_options`

Returns property filter options from `PropertyOptions` plus map-specific `radius_options`, `sort_options`, and `query_params` documentation.

