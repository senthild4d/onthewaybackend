# Real Estate WebSocket (ActionCable)

ActionCable is mounted at:

```
wss://<host>/cable?token=<jwt_token>
```

Local:

```
ws://localhost:3000/cable?token=<jwt_token>
```

The token is the same JWT used by the REST APIs.

## Subscribe Message Format

ActionCable subscriptions use an escaped JSON string in `identifier`:

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"OwnerDashboardChannel\"}"
}
```

## Channels

### OwnerDashboardChannel

Real-time updates for the current owner across all their properties.

Subscribe:

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"OwnerDashboardChannel\"}"
}
```

Events broadcast after property create/update/delete/status/media changes and viewing request/status changes.

Payload shape:

```json
{
  "type": "owner_dashboard",
  "action": "property_updated",
  "property": { "id": "...", "title": "...", "approval_status": "...", "listing_status": "..." },
  "viewing": null,
  "summary": { "total_properties": 10, "viewings": { "total": 4 } },
  "timestamp": "2026-05-21T..."
}
```

### PropertyChannel

Real-time updates for one property.

Subscribe:

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"PropertyChannel\",\"property_id\":\"PROPERTY_UUID\"}"
}
```

Allowed subscribers:

- admin
- property owner
- authenticated users for public approved active listings

Payload shape:

```json
{
  "type": "property",
  "action": "video_360_uploaded",
  "property": {
    "id": "...",
    "title": "...",
    "has_360_view": true,
    "video_projection": "equirectangular"
  },
  "timestamp": "2026-05-21T..."
}
```

Viewing changes on the property also broadcast to this channel:

```json
{
  "type": "property_viewing",
  "action": "requested",
  "viewing": { "id": "...", "status": "requested", "property_id": "..." },
  "property": { "id": "...", "title": "..." }
}
```

### UserNotificationsChannel

Per-user stream for viewing status updates and user-targeted real-time events.

Subscribe:

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"UserNotificationsChannel\"}"
}
```

## Actions Broadcast

Property actions:

- `created`
- `updated`
- `deleted`
- `submitted`
- `approved`
- `rejected`
- `sold`
- `archived`
- `unarchived`
- `images_uploaded`
- `image_removed`
- `video_uploaded`
- `video_360_uploaded`
- `video_removed`

Viewing actions:

- `requested`
- `updated`
- `cancelled`

## Postman Quick Test

1. Open a WebSocket request.
2. Connect to `wss://vibesapp.digital4design.com/ontheway/cable?token=<jwt_token>`.
3. Send one subscribe message from above.
4. Keep the socket open.
5. Trigger a REST action, for example `POST /api/v1/properties/:id/360_video`.
6. You should receive a message on the subscribed channel.
