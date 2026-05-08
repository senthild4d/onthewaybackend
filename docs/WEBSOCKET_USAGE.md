# WebSocket Usage

## Overview

The Vibes platform uses **ActionCable (WebSocket)** for:

- **Group Chat** – real-time messaging
- **Direct Chat** – one-on-one messaging
- **Booking** – real-time payment status and seat/table assignment updates
- **Order** – real-time split payment updates (food/bar order)

---

## Booking Channel (Payment & Seat/Table)

Use the **BookingChannel** to receive real-time updates for a specific booking: payment completed/failed, table assigned, check-in.

### Subscribe to Booking Channel

Only the booking owner, event venue owner, or admin can subscribe.

```javascript
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"BookingChannel\",\"booking_id\":\"BOOKING_UUID\"}"
}
```

### Events Received

**Payment completed** (after Stripe webhook or REST pay):

```json
{
  "action": "payment_completed",
  "booking_id": "booking-uuid",
  "amount": 25.50,
  "booking": {
    "id": "booking-uuid",
    "status": "confirmed",
    "payment_status": "paid",
    "paid_amount": 25.50,
    "remaining_amount": 0,
    "payment_progress_percentage": 100,
    "fully_paid": true,
    "table_number": null,
    "table_assigned_at": null,
    "checked_in_at": null,
    "updated_at": "2026-02-13T10:00:00Z"
  }
}
```

**Payment failed**:

```json
{
  "action": "payment_failed",
  "booking_id": "booking-uuid",
  "booking": { ... }
}
```

**Table/seat assigned** (venue staff assigns a table):

```json
{
  "action": "table_assigned",
  "booking_id": "booking-uuid",
  "table_number": "T5",
  "booking": {
    "id": "booking-uuid",
    "status": "confirmed",
    "payment_status": "paid",
    "table_number": "T5",
    "table_assigned_at": "2026-02-13T10:05:00Z",
    ...
  }
}
```

**Check-in** (venue staff checks in the guest):

```json
{
  "action": "check_in",
  "booking_id": "booking-uuid",
  "booking": {
    ...
    "checked_in_at": "2026-02-13T11:00:00Z"
  }
}
```

### Flow

1. **Payment**: User initiates payment (Stripe or REST). When payment succeeds (webhook or REST), the backend broadcasts `payment_completed` to `booking_<id>`. The Flutter app subscribed to that booking updates UI (e.g. “Paid”, show ticket).
2. **Seat/table**: Venue staff call `POST /api/v1/bookings/:id/assign_table` with `table_number`. Backend broadcasts `table_assigned`. The guest’s app can show “Your table: T5” without polling.
3. **Check-in**: Staff call check-in; backend broadcasts `check_in`; app can show “Checked in” or unlock content.

---

## Group Chat

### Connection Setup

### 1. Connect to WebSocket

Connect to the ActionCable server at `/cable` endpoint with JWT authentication.

**Connection URL:**
```
ws://localhost:3000/cable (Development)
wss://your-domain.com/cable (Production)
```

### 2. Authentication

Pass JWT token in one of two ways:

**Option 1: Query Parameter**
```
ws://localhost:3000/cable?token=YOUR_JWT_TOKEN
```

**Option 2: Authorization Header**
```
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Subscribe to Group Chat Channel

Once connected, subscribe to a specific group chat:

```javascript
{
  command: 'subscribe',
  identifier: JSON.stringify({
    channel: 'GroupChatChannel',
    group_chat_id: 'GROUP_CHAT_UUID'
  })
}
```

## Sending Messages

### Via WebSocket (Real-time)

Send a message directly through WebSocket:

```javascript
{
  command: 'message',
  identifier: JSON.stringify({
    channel: 'GroupChatChannel',
    group_chat_id: 'GROUP_CHAT_UUID'
  }),
  data: JSON.stringify({
    action: 'speak',
    content: 'Hello, everyone!',
    message_type: 'text',
    reply_to_id: null // Optional: UUID of message to reply to
  })
}
```

### Via REST API (Recommended)

For better validation and error handling, use the REST API:

```
POST /api/v1/group_chats/:group_chat_id/messages
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "message": {
    "content": "Hello, everyone!",
    "message_type": "text",
    "reply_to_id": null
  }
}
```

The REST API will automatically broadcast the message via WebSocket to all subscribers.

## Receiving Messages

When a message is sent (via WebSocket or REST API), all subscribed clients receive:

```json
{
  "id": "message-uuid",
  "user": {
    "id": "user-uuid",
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
```

## Message Types

Supported message types:
- `text` - Plain text message
- `image` - Image message
- `video` - Video message
- `audio` - Audio message
- `location` - Location sharing

## Message Deletion

When a message is deleted, subscribers receive:

```json
{
  "action": "message_deleted",
  "message_id": "message-uuid"
}
```

## Example JavaScript Client

```javascript
// Connect to ActionCable
const cable = ActionCable.createConsumer('ws://localhost:3000/cable?token=YOUR_JWT_TOKEN');

// Subscribe to group chat
const subscription = cable.subscriptions.create(
  {
    channel: 'GroupChatChannel',
    group_chat_id: 'GROUP_CHAT_UUID'
  },
  {
    connected() {
      console.log('Connected to group chat');
    },
    
    disconnected() {
      console.log('Disconnected from group chat');
    },
    
    received(data) {
      if (data.action === 'message_deleted') {
        // Handle message deletion
        console.log('Message deleted:', data.message_id);
      } else {
        // Handle new message
        console.log('New message:', data);
        // Update UI with new message
      }
    },
    
    speak(content, messageType = 'text', replyToId = null) {
      this.perform('speak', {
        content: content,
        message_type: messageType,
        reply_to_id: replyToId
      });
    }
  }
);

// Send a message
subscription.speak('Hello, everyone!', 'text', null);
```

## Security

- Only members of a group chat can subscribe to its channel
- JWT token is validated on connection
- Users must be active to connect
- Unauthorized connection attempts are rejected

## Error Handling

If connection fails or is rejected:
- Check JWT token validity
- Verify user is a member of the group chat
- Ensure user account is active
- Check network connectivity

## Best Practices

1. **Use REST API for sending messages** - Better validation and error handling
2. **Use WebSocket for receiving messages** - Real-time updates
3. **Handle reconnection** - Implement automatic reconnection logic
4. **Validate messages client-side** - Before sending via WebSocket
5. **Handle offline state** - Queue messages when offline, send when reconnected

---

## Booking: Payment and Seat Handling Summary

| Event             | Trigger                         | Action on client                          |
|-------------------|----------------------------------|-------------------------------------------|
| payment_completed | Stripe webhook or REST pay       | Update payment UI, show confirmation      |
| payment_failed    | Stripe failed or REST pay failed | Show error, allow retry                   |
| table_assigned   | REST assign_table                | Show “Your table: T5” (or seat)           |
| check_in         | REST check_in                    | Show “Checked in”, unlock entry/ticket    |

---

## Pushing WebSocket Messages (Backend)

The server broadcasts to channels; clients subscribed to that channel receive the message.

### Booking channel

Use **BookingBroadcaster** so payloads stay consistent:

```ruby
# Rails console: rails c
booking = Booking.find('YOUR_BOOKING_UUID')

# Payment completed (e.g. after Stripe webhook or REST pay)
BookingBroadcaster.payment_completed(booking, amount: 25.50)

# Payment failed
BookingBroadcaster.payment_failed(booking)

# Table/seat assigned (venue staff flow)
BookingBroadcaster.table_assigned(booking, table_number: 'T5')

# Check-in
BookingBroadcaster.check_in(booking)

# Check-out
BookingBroadcaster.check_out(booking)

# Generic status change
BookingBroadcaster.status_updated(booking)
```

Stream name used: `booking_<booking.id>`. Only subscribers to that booking (owner, venue owner, admin) receive the message.

### Order channel (food/bar)

Use **OrderBroadcaster** for split/order payment updates:

```ruby
order = FoodBarOrder.find('ORDER_UUID')
OrderBroadcaster.split_paid(order, split_id: split.id, amount: 10.0)
OrderBroadcaster.order_fully_paid(order)
OrderBroadcaster.split_payment_failed(order, split_id: split.id)
```

Stream name: `order_<order.id>`.

### Group chat / direct chat

Messages are broadcast when you send via **REST API** (recommended) or via the channel's `speak` action. Stream names: `group_chat_<id>` and `chat_<id>`.

### Raw broadcast (any stream)

For one-off or custom streams:

```ruby
ActionCable.server.broadcast("booking_#{booking.id}", {
  action: 'payment_completed',
  booking_id: booking.id,
  booking: { id: booking.id, status: 'confirmed', ... }
})
```

---

## Testing WebSockets

### 1. Start the app

```bash
# From project root
bin/rails server
# Or: bundle exec rails s
```

ActionCable is mounted at `/cable` (same host/port as the app).

### 2. Get a JWT

- Log in via Postman (e.g. **2. EXISTING USER FLOW → Login with Password**) or any login endpoint.
- Copy the `jwt_token` (or `access_token`) from the response or from your Postman environment.

### 3. Connect and subscribe (Booking channel)

**Option A: wscat (CLI)**

```bash
# Install: npm install -g wscat
# Replace YOUR_JWT and BOOKING_UUID
wscat -c "ws://localhost:3000/cable?token=YOUR_JWT"
```

After connecting, send the subscribe command (one line, no line breaks inside the JSON):

```json
{"command":"subscribe","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"BOOKING_UUID\"}"}
```

Example (replace the UUID):

```json
{"command":"subscribe","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"a1b2c3d4-e5f6-7890-abcd-ef1234567890\"}"}
```

You should get a `confirm_subscription` message. Leave this terminal open.

**Option B: Postman**

1. New request → WebSocket request.
2. URL: `wss://vibesapp.digital4design.com/cable?token=YOUR_JWT` (production) or `ws://localhost:3000/cable?token=YOUR_JWT` (local).
3. Click **Connect**.
4. In the **Message** tab, you must send the subscribe as **raw text**. The `identifier` must be a **string** (escaped JSON), not an object. If you use an object like `"identifier": {"channel": "BookingChannel", "booking_id": "..."}`, the server will not accept it.

   **Copy this exactly** (one line; it must be a JSON **object** `{ }`, not an array `[ ]`). Replace the booking ID if needed:

   ```json
   {"command":"subscribe","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"fec17c72-6127-4dec-afae-678a252b673c\"}"}
   ```

   Common mistakes:
   - Using an **array** `["command":...]` → must be an **object** `{"command":...}`.
   - Truncated or edited `booking_id` (e.g. `\*fec17c72-6127-4dec-` or missing `-678a252b673c\"}"`) → use the full UUID and keep the closing `\"}"}`.

   Then click **Send** right after connecting. You should see a `confirm_subscription` message in the response list. After that, any broadcast to that booking (e.g. from `BookingBroadcaster.payment_completed`) will appear there too. If the connection drops (~20–30 s), reconnect and send the subscribe again before testing the broadcast.

**Option C: Browser console (same origin)**

```javascript
const token = 'YOUR_JWT';
const ws = new WebSocket(`ws://localhost:3000/cable?token=${token}`);

ws.onopen = () => {
  const sub = { channel: 'BookingChannel', booking_id: 'BOOKING_UUID' };
  ws.send(JSON.stringify({ command: 'subscribe', identifier: JSON.stringify(sub) }));
};
ws.onmessage = (e) => console.log('Received:', JSON.parse(e.data));
```

### 4. Trigger a broadcast (Rails console)

In a **second terminal**:

```bash
cd /path/to/vibes
bin/rails c
```

Then:

```ruby
booking = Booking.find('BOOKING_UUID')   # same UUID you subscribed to
BookingBroadcaster.payment_completed(booking, amount: 25.0)
# Or: BookingBroadcaster.table_assigned(booking, table_number: 'T5')
```

In the WebSocket client you should see a message like:

```json
{
  "action": "payment_completed",
  "booking_id": "...",
  "amount": 25.0,
  "booking": { "id": "...", "status": "confirmed", ... }
}
```

### 5. Who can subscribe to BookingChannel

- The **booking owner** (`booking.user_id`).
- The **event's venue owner** (`booking.event.venue.owner_id`).
- **Admins** (`user.role == 'admin'`).

Use a JWT for one of these users and a booking they're allowed to see; otherwise the subscription is rejected.

### Quick checklist

| Step | Action |
|------|--------|
| 1 | `bin/rails server` |
| 2 | Get JWT (Postman login), set `YOUR_JWT` |
| 3 | Get a booking id (e.g. from API or DB), set `BOOKING_UUID` |
| 4 | Connect: `wscat -c "ws://localhost:3000/cable?token=YOUR_JWT"` |
| 5 | Send subscribe: `{"command":"subscribe","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"BOOKING_UUID\"}"}` |
| 6 | In another terminal: `rails c` → `BookingBroadcaster.payment_completed(Booking.find('BOOKING_UUID'), amount: 1.0)` |
| 7 | See the message in the wscat (or Postman/browser) client |

### Production: broadcast and URL

If your **client** (Postman, Flutter app) connects to **production** (e.g. `vibesapp.digital4design.com`), the broadcast must run in the **same** environment so it goes to production’s ActionCable (Redis).

- **Wrong:** `rails c` on the server (loads **development**) → broadcast stays in development; production WebSocket clients never see it.
- **Right:** run console in production and broadcast there:

```bash
RAILS_ENV=production rails c
# then in console:
BookingBroadcaster.payment_completed(Booking.find("fec17c72-6127-4dec-afae-678a252b673c"), amount: 1.0)
```

Production WebSocket URL must use **wss://** and the full host:

- **Correct:** `wss://vibesapp.digital4design.com/cable?token=YOUR_JWT`
- **Wrong:** `vibesapp.digital4design.com/cable?token=...` (missing `wss://`)

Keep the client **connected and subscribed** when you run the broadcast; if the connection is already "Disconnected", the message cannot be delivered.

### Troubleshooting: "Not getting data in Postman" / broadcast returns 0

**Interpret Pry / `BookingBroadcaster` return values carefully (depends on ActionCable adapter).**

- **`ActionCable::SubscriptionAdapter::Redis`**: `ActionCable.server.broadcast(...)` usually returns an **integer** subscriber count (`0`, `1`, …). **`=> 0` means nobody was subscribed at that instant** on that Redis.
- **`ActionCable::SubscriptionAdapter::Async`**: broadcasts are **process-local**. A `rails console` using `Async` will **NOT** reliably deliver to WebSocket subscribers handled by separate Puma processes; Pry may print **`=> nil`**, even though Rails logs **`[ActionCable] Broadcasting …`**.

If Pry shows `adapter=ActionCable::SubscriptionAdapter::Async` and `redis_url=nil`, your console isn’t picking up **`ENV['REDIS_URL']`** the same way Puma/Cable does. Fix by starting console with the **same systemd/supervisor environment** (`RAILS_ENV=production`, `REDIS_URL=...`). Sanity checks:

```ruby
Rails.application.config_for(:cable)
ActionCable.server.pubsub.class.name # should NOT be Async on production websocket servers
ENV['REDIS_URL']
```

Booking-specific debug logs (sanitized Redis URL + adapter + receiver info) print when **`BOOKING_CABLE_DEBUG=true`**:

```ruby
ENV['BOOKING_CABLE_DEBUG']='true'
BookingBroadcaster.status_updated(Booking.find("BOOKING_UUID"))
```

1. **Stay connected**  
   Postman must show **"Connected"** (not "Disconnected") when you run the broadcast. If the connection drops (idle timeout, tab closed, or you clicked Disconnect), there are 0 subscribers → you get 0. Reconnect and keep the tab open.

2. **Subscribe after connecting**  
   Connecting to `/cable` is not enough. You must **send** the subscribe message **after** you see "Connected":
   - In Postman: click **Send** (with the subscribe JSON in the message box).
   - You should see a server message like: `{"type":"confirm_subscription","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"...\"}"}`.  
   If you see `reject_subscription` instead, the JWT user is not allowed (BookingChannel allows only: **booking owner**, **event venue owner**, or **admin**). Use a token for one of those users.

3. **Run the broadcast while connected and subscribed**  
   With Postman still **Connected** and after you've seen **confirm_subscription**, run in production console:
   ```bash
   rails c -e production
   BookingBroadcaster.payment_completed(Booking.find("fec17c72-6127-4dec-afae-678a252b673c"), amount: 1.0)
   ```
   You should get `=> 1` (or more) and the same message should appear in Postman's response list. If you get `=> 0`, no client was subscribed at that moment (disconnected or never confirmed subscription).

**Quick order:** Connect → Send subscribe → See "confirm_subscription" → (keep connected) → Run broadcast in console → See message in Postman.

**Only seeing "ping" messages?** Then the subscription likely failed (rejected or not processed). Do this:

1. **Check the message right after you click Send**  
   Clear messages, then Connect → click **Send** once with the subscribe JSON. In the response list, look for a message that is **not** a ping — it should be either `{"type":"confirm_subscription",...}` or `{"type":"reject_subscription",...}`. If you only ever see pings, the server may be rejecting the subscription (wrong user).

2. **Use a compact subscribe message (no spaces inside the identifier string)**  
   Some clients are picky. Send exactly:
   ```json
   {"command":"subscribe","identifier":"{\"channel\":\"BookingChannel\",\"booking_id\":\"fec17c72-6127-4dec-afae-678a252b673c\"}"}
   ```
   (No spaces after `\"channel\":` or `\"booking_id\":`.)

3. **Confirm your JWT user is allowed**  
   BookingChannel allows only: **booking owner**, **event venue owner**, or **admin**. On the server run:
   ```bash
   rails c -e production
   b = Booking.find("fec17c72-6127-4dec-afae-678a252b673c")
   puts "booking user_id: #{b.user_id}, venue owner: #{b.event&.venue&.owner_id}"
   ```
   The user id from your JWT (decode at jwt.io or check logs: "Registered connection (Z2lkOi8v...)" decodes to that user) must match `b.user_id`, or `b.event.venue.owner_id`, or be an admin.

4. **Check production.log when you Send**  
   After adding the subscribe message and clicking Send, run `tail -f log/production.log` on the server. You should see either:
   - `[BookingChannel] Subscribed: user=... → booking=...` (success), or  
   - `[BookingChannel] Rejected: ...` (with the reason).  
   That tells you whether the subscription is accepted or why it was rejected.
