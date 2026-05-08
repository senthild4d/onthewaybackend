# Flutter WebSocket Integration Guide

## Overview

This guide explains how to integrate ActionCable WebSocket channels with a Flutter frontend application. The Vibes Rails backend uses ActionCable for real-time communication (group chats, direct chats, etc.).

## Prerequisites

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  web_socket_channel: ^2.4.0
  uuid: ^4.0.0
```

## ActionCable Protocol

ActionCable uses a specific WebSocket protocol. Messages are sent as JSON with specific structure:

### Connection
- **URL**: `ws://localhost:3000/cable` (Development) or `wss://your-domain.com/cable` (Production)
- **Authentication**: JWT token via query parameter `?token=YOUR_JWT_TOKEN` or Authorization header

### Message Format

**Subscribe to Channel:**
```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"GroupChatChannel\",\"group_chat_id\":\"GROUP_CHAT_UUID\"}"
}
```

**Send Message:**
```json
{
  "command": "message",
  "identifier": "{\"channel\":\"GroupChatChannel\",\"group_chat_id\":\"GROUP_CHAT_UUID\"}",
  "data": "{\"action\":\"speak\",\"content\":\"Hello!\",\"message_type\":\"text\"}"
}
```

**Unsubscribe:**
```json
{
  "command": "unsubscribe",
  "identifier": "{\"channel\":\"GroupChatChannel\",\"group_chat_id\":\"GROUP_CHAT_UUID\"}"
}
```

## Flutter Implementation

### 1. ActionCable Client Class

Create `lib/services/action_cable_client.dart`:

```dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

class ActionCableClient {
  WebSocketChannel? _channel;
  final String baseUrl;
  final String token;
  final Map<String, Function(Map<String, dynamic>)> _subscriptions = {};
  bool _isConnected = false;
  
  ActionCableClient({
    required this.baseUrl,
    required this.token,
  });

  // Connect to WebSocket
  Future<void> connect() async {
    try {
      final url = Uri.parse('$baseUrl/cable?token=$token');
      _channel = WebSocketChannel.connect(url);
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
      
      _isConnected = true;
      print('✅ Connected to ActionCable');
    } catch (e) {
      print('❌ Connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  // Subscribe to a channel
  void subscribe({
    required String channelName,
    required Map<String, dynamic> params,
    required Function(Map<String, dynamic>) onMessage,
  }) {
    final identifier = {
      'channel': channelName,
      ...params,
    };
    
    final identifierKey = jsonEncode(identifier);
    
    // Store callback
    _subscriptions[identifierKey] = onMessage;
    
    // Send subscribe command
    _sendCommand(
      command: 'subscribe',
      identifier: identifierKey,
    );
    
    print('📡 Subscribed to $channelName');
  }

  // Unsubscribe from a channel
  void unsubscribe({
    required String channelName,
    required Map<String, dynamic> params,
  }) {
    final identifier = {
      'channel': channelName,
      ...params,
    };
    
    final identifierKey = jsonEncode(identifier);
    
    // Remove callback
    _subscriptions.remove(identifierKey);
    
    // Send unsubscribe command
    _sendCommand(
      command: 'unsubscribe',
      identifier: identifierKey,
    );
    
    print('📴 Unsubscribed from $channelName');
  }

  // Send a message to a channel
  void sendMessage({
    required String channelName,
    required Map<String, dynamic> params,
    required String action,
    required Map<String, dynamic> data,
  }) {
    final identifier = {
      'channel': channelName,
      ...params,
    };
    
    final messageData = {
      'action': action,
      ...data,
    };
    
    _sendCommand(
      command: 'message',
      identifier: jsonEncode(identifier),
      data: jsonEncode(messageData),
    );
  }

  // Send command to WebSocket
  void _sendCommand({
    required String command,
    required String identifier,
    String? data,
  }) {
    if (!_isConnected || _channel == null) {
      print('⚠️ Not connected to WebSocket');
      return;
    }
    
    final message = {
      'command': command,
      'identifier': identifier,
      if (data != null) 'data': data,
    };
    
    _channel!.sink.add(jsonEncode(message));
  }

  // Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      
      // Handle welcome message
      if (data['type'] == 'welcome') {
        print('👋 Welcome message received');
        return;
      }
      
      // Handle confirm_subscription
      if (data['type'] == 'confirm_subscription') {
        print('✅ Subscription confirmed');
        return;
      }
      
      // Handle reject_subscription
      if (data['type'] == 'reject_subscription') {
        print('❌ Subscription rejected');
        return;
      }
      
      // Handle regular messages
      if (data['identifier'] != null && data['message'] != null) {
        final identifier = jsonDecode(data['identifier'] as String);
        final identifierKey = jsonEncode(identifier);
        
        final callback = _subscriptions[identifierKey];
        if (callback != null) {
          callback(data['message'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      print('❌ Error handling message: $e');
      print('Message: $message');
    }
  }

  // Handle errors
  void _handleError(dynamic error) {
    print('❌ WebSocket error: $error');
    _isConnected = false;
  }

  // Handle disconnect
  void _handleDisconnect() {
    print('🔌 Disconnected from WebSocket');
    _isConnected = false;
    _subscriptions.clear();
  }

  // Disconnect
  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _subscriptions.clear();
    print('👋 Disconnected');
  }

  bool get isConnected => _isConnected;
}
```

### 2. Group Chat Service

Create `lib/services/group_chat_service.dart`:

```dart
import 'action_cable_client.dart';

class GroupChatService {
  final ActionCableClient cableClient;
  final String groupChatId;
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String)? onMessageDeleted;
  
  GroupChatService({
    required this.cableClient,
    required this.groupChatId,
    this.onMessageReceived,
    this.onMessageDeleted,
  });

  // Subscribe to group chat channel
  void subscribe() {
    cableClient.subscribe(
      channelName: 'GroupChatChannel',
      params: {'group_chat_id': groupChatId},
      onMessage: (data) {
        // Handle message deletion
        if (data['action'] == 'message_deleted') {
          onMessageDeleted?.call(data['message_id'] as String);
          return;
        }
        
        // Handle new/updated message
        onMessageReceived?.call(data);
      },
    );
  }

  // Unsubscribe from group chat channel
  void unsubscribe() {
    cableClient.unsubscribe(
      channelName: 'GroupChatChannel',
      params: {'group_chat_id': groupChatId},
    );
  }

  // Send message via WebSocket (optional - REST API recommended)
  void sendMessage({
    required String content,
    String messageType = 'text',
    String? replyToId,
  }) {
    cableClient.sendMessage(
      channelName: 'GroupChatChannel',
      params: {'group_chat_id': groupChatId},
      action: 'speak',
      data: {
        'content': content,
        'message_type': messageType,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
  }
}
```

### 3. Chat Service (One-on-One)

Create `lib/services/chat_service.dart`:

```dart
import 'action_cable_client.dart';

class ChatService {
  final ActionCableClient cableClient;
  final String chatId;
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String)? onMessageDeleted;
  
  ChatService({
    required this.cableClient,
    required this.chatId,
    this.onMessageReceived,
    this.onMessageDeleted,
  });

  // Subscribe to chat channel
  void subscribe() {
    cableClient.subscribe(
      channelName: 'ChatChannel',
      params: {'chat_id': chatId},
      onMessage: (data) {
        // Handle message deletion
        if (data['action'] == 'message_deleted') {
          onMessageDeleted?.call(data['message_id'] as String);
          return;
        }
        
        // Handle new/updated message
        onMessageReceived?.call(data);
      },
    );
  }

  // Unsubscribe from chat channel
  void unsubscribe() {
    cableClient.unsubscribe(
      channelName: 'ChatChannel',
      params: {'chat_id': chatId},
    );
  }

  // Send message via WebSocket (optional - REST API recommended)
  void sendMessage({
    required String content,
    String messageType = 'text',
    String? replyToId,
  }) {
    cableClient.sendMessage(
      channelName: 'ChatChannel',
      params: {'chat_id': chatId},
      action: 'speak',
      data: {
        'content': content,
        'message_type': messageType,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
  }
}
```

### 4. Usage Example in Flutter Widget

```dart
import 'package:flutter/material.dart';
import 'services/action_cable_client.dart';
import 'services/group_chat_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupChatId;
  final String jwtToken;
  final String baseUrl;

  const GroupChatScreen({
    Key? key,
    required this.groupChatId,
    required this.jwtToken,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late ActionCableClient cableClient;
  late GroupChatService chatService;
  final List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // Initialize ActionCable client
    cableClient = ActionCableClient(
      baseUrl: widget.baseUrl,
      token: widget.jwtToken,
    );

    // Connect to WebSocket
    try {
      await cableClient.connect();
      
      // Initialize group chat service
      chatService = GroupChatService(
        cableClient: cableClient,
        groupChatId: widget.groupChatId,
        onMessageReceived: _handleMessageReceived,
        onMessageDeleted: _handleMessageDeleted,
      );
      
      // Subscribe to group chat channel
      chatService.subscribe();
    } catch (e) {
      print('Failed to connect: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _handleMessageReceived(Map<String, dynamic> message) {
    setState(() {
      messages.add(message);
    });
  }

  void _handleMessageDeleted(String messageId) {
    setState(() {
      messages.removeWhere((msg) => msg['id'] == messageId);
    });
  }

  @override
  void dispose() {
    chatService.unsubscribe();
    cableClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message['user']?['name'] ?? 'Unknown'),
                  subtitle: Text(message['content'] ?? ''),
                  trailing: Text(
                    _formatDate(message['created_at']),
                    style: TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
          // Message input field
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        // Send via REST API (recommended) or WebSocket
                        chatService.sendMessage(content: text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    // Parse ISO8601 date and format
    return dateString; // Implement your date formatting
  }
}
```

### 5. Booking Channel: Payment and Seat/Table Handling

Subscribe to **BookingChannel** to receive real-time updates for a booking: payment completed/failed, table assigned, check-in. No polling needed.

**BookingService** (add to your Flutter project):

```dart
import 'action_cable_client.dart';

class BookingService {
  final ActionCableClient cableClient;
  final String bookingId;
  void Function(Map<String, dynamic> booking)? onPaymentCompleted;
  void Function(Map<String, dynamic> booking)? onPaymentFailed;
  void Function(String? tableNumber, Map<String, dynamic> booking)? onTableAssigned;
  void Function(Map<String, dynamic> booking)? onCheckIn;

  BookingService({
    required this.cableClient,
    required this.bookingId,
    this.onPaymentCompleted,
    this.onPaymentFailed,
    this.onTableAssigned,
    this.onCheckIn,
  });

  void subscribe() {
    cableClient.subscribe(
      channelName: 'BookingChannel',
      params: {'booking_id': bookingId},
      onMessage: (data) {
        final action = data['action'] as String?;
        final booking = data['booking'] as Map<String, dynamic>? ?? {};
        switch (action) {
          case 'payment_completed':
            onPaymentCompleted?.call(booking);
            break;
          case 'payment_failed':
            onPaymentFailed?.call(booking);
            break;
          case 'table_assigned':
            onTableAssigned?.call(
              data['table_number'] as String?,
              booking,
            );
            break;
          case 'check_in':
            onCheckIn?.call(booking);
            break;
        }
      },
    );
  }

  void unsubscribe() {
    cableClient.unsubscribe(
      channelName: 'BookingChannel',
      params: {'booking_id': bookingId},
    );
  }
}
```

**Usage in a booking detail screen** (e.g. after user creates a booking and is on “My Booking”):

```dart
// In initState, after loading booking
final bookingService = BookingService(
  cableClient: cableClient,
  bookingId: bookingId,
  onPaymentCompleted: (booking) {
    setState(() {
      // Update local state from booking snapshot
      paymentStatus = booking['payment_status'];
      paidAmount = (booking['paid_amount'] ?? 0).toDouble();
      fullyPaid = booking['fully_paid'] == true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment successful!')),
    );
  },
  onPaymentFailed: (booking) {
    setState(() { /* update state */ });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed. Please try again.')),
    );
  },
  onTableAssigned: (tableNumber, booking) {
    setState(() {
      this.tableNumber = tableNumber ?? booking['table_number'];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Your table: $tableNumber')),
    );
  },
  onCheckIn: (booking) {
    setState(() {
      checkedInAt = booking['checked_in_at'];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You\'re checked in!')),
    );
  },
);
bookingService.subscribe();

// In dispose
bookingService.unsubscribe();
```

**Flow summary**

1. **Payment**: User taps Pay → you call REST (e.g. create payment intent, confirm with Stripe). When payment succeeds (Stripe webhook or your pay endpoint), backend broadcasts `payment_completed` → Flutter receives it and updates UI (e.g. “Paid”, show ticket).
2. **Seat/table**: Venue staff assign a table via API; backend broadcasts `table_assigned` → Flutter shows “Your table: T5” without polling.
3. **Check-in**: Staff check in the guest; backend broadcasts `check_in` → Flutter shows “Checked in” or unlocks content.

Payment and table assignment are **triggered only by the backend** (REST or webhooks). The Flutter app only **subscribes** to the booking and **reacts** to these events.

## Best Practices

### 1. Use REST API for Sending Messages

While WebSocket can send messages, it's recommended to use REST API for better validation and error handling:

```dart
// Send message via REST API
Future<void> sendMessage(String content) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/v1/group_chats/$groupChatId/messages'),
    headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'message': {
        'content': content,
        'message_type': 'text',
      },
    }),
  );
  
  if (response.statusCode == 201) {
    // Message sent successfully
    // WebSocket will automatically broadcast to all subscribers
  }
}
```

### 2. Handle Reconnection

Implement automatic reconnection logic:

```dart
class ActionCableClient {
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  
  void _handleDisconnect() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      _reconnectTimer = Timer(
        Duration(seconds: _reconnectAttempts * 2), // Exponential backoff
        () => connect(),
      );
    }
  }
}
```

### 3. Handle Offline State

Queue messages when offline and send when reconnected:

```dart
class MessageQueue {
  final List<Map<String, dynamic>> _queue = [];
  
  void queueMessage(Map<String, dynamic> message) {
    _queue.add(message);
  }
  
  Future<void> flushMessages(ActionCableClient client) async {
    for (final message in _queue) {
      // Send message
    }
    _queue.clear();
  }
}
```

### 4. Error Handling

Always handle connection errors gracefully:

```dart
try {
  await cableClient.connect();
} catch (e) {
  // Show error to user
  // Retry connection
  // Fallback to polling if WebSocket fails
}
```

## Testing

### Development Setup

1. **Backend**: Ensure Rails server is running on `http://localhost:3000`
2. **WebSocket URL**: Use `ws://localhost:3000/cable`
3. **JWT Token**: Get token from login/authentication endpoint

### Production Setup

1. **Backend**: Use your production URL
2. **WebSocket URL**: Use `wss://your-domain.com/cable` (secure WebSocket)
3. **JWT Token**: Get token from production authentication endpoint

## Troubleshooting

### Connection Issues

- **Check JWT token**: Ensure token is valid and not expired
- **Check URL**: Verify WebSocket URL is correct (ws:// for dev, wss:// for prod)
- **Check network**: Ensure device has internet connection
- **Check CORS**: Ensure backend allows WebSocket connections from your app

### Subscription Issues

- **Check channel name**: Must match exactly (e.g., `GroupChatChannel`, `ChatChannel`)
- **Check parameters**: Ensure all required parameters are included
- **Check permissions**: User must be a member of the group chat / chat

### Message Issues

- **Check message format**: Ensure JSON is properly formatted
- **Check action name**: Must match channel method (e.g., `speak`)
- **Check data structure**: Ensure data matches expected format

## Additional Resources

- [ActionCable Protocol](https://guides.rubyonrails.org/action_cable_overview.html)
- [WebSocket Channel Package](https://pub.dev/packages/web_socket_channel)
- [Flutter WebSocket Guide](https://flutter.dev/docs/cookbook/networking/web-sockets)
