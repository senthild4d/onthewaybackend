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
- `UserNotificationsChannel` — per-user updates such as viewing status changes.

See `docs/REAL_ESTATE_WEBSOCKET.md` for subscribe payloads and event shapes.

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

