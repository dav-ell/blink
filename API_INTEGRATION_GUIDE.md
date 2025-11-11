# Backend API Integration Guide

This guide provides detailed instructions for integrating the Blink app with a real Cursor CLI backend.

## Current State

All data operations are currently mocked in `lib/services/chat_service.dart`. Each method includes:
- Simulated network delays
- Mock data responses
- TODO comments with API specifications

## Required Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0  # For REST API calls
  # OR
  dio: ^5.3.0   # For more advanced HTTP features
```

## API Endpoints Required

### Base URL
```
https://api.cursor.cli/v1  # Replace with actual base URL
```

### Authentication
Most APIs will require authentication. Add a header to all requests:
```
Authorization: Bearer {token}
```

---

## 1. Get All Sessions

**Current Mock:** `getSessions()`

**API Specification:**
- **Endpoint:** `GET /api/sessions`
- **Headers:** Authorization required
- **Query Parameters:** 
  - `status` (optional): Filter by status (active, idle, completed)
  - `limit` (optional): Number of results (default: 50)
  - `offset` (optional): Pagination offset

**Request Example:**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/sessions'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
);
```

**Expected Response (200 OK):**
```json
{
  "sessions": [
    {
      "id": "session_123",
      "title": "Implement user authentication",
      "start_time": "2024-11-11T14:00:00Z",
      "last_activity_time": "2024-11-11T16:25:00Z",
      "status": "active",
      "message_count": 12
    }
  ],
  "total": 5,
  "has_more": false
}
```

**Implementation:**
```dart
Future<List<ChatSession>> getSessions() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['sessions'] as List)
          .map((json) => ChatSession.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load sessions: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error fetching sessions: $e');
  }
}
```

---

## 2. Get Session Messages

**Current Mock:** `getMessages(String sessionId)`

**API Specification:**
- **Endpoint:** `GET /api/sessions/{sessionId}/messages`
- **Headers:** Authorization required
- **Query Parameters:**
  - `limit` (optional): Number of messages (default: 100)
  - `before` (optional): Get messages before this timestamp
  - `after` (optional): Get messages after this timestamp

**Request Example:**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/sessions/$sessionId/messages'),
  headers: _getHeaders(),
);
```

**Expected Response (200 OK):**
```json
{
  "messages": [
    {
      "id": "msg_456",
      "session_id": "session_123",
      "content": "I need help implementing user authentication",
      "timestamp": "2024-11-11T14:30:00Z",
      "sender": "user",
      "type": "text"
    },
    {
      "id": "msg_457",
      "session_id": "session_123",
      "content": "I can help you with that...",
      "timestamp": "2024-11-11T14:31:00Z",
      "sender": "cursor",
      "type": "text"
    }
  ],
  "has_more": false
}
```

---

## 3. Send Message

**Current Mock:** `sendMessage({required String sessionId, required String content, MessageType type})`

**API Specification:**
- **Endpoint:** `POST /api/sessions/{sessionId}/messages`
- **Headers:** Authorization required
- **Body:** JSON with message content and type

**Request Example:**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/sessions/$sessionId/messages'),
  headers: _getHeaders(),
  body: json.encode({
    'content': content,
    'type': type.toString().split('.').last,
  }),
);
```

**Request Body:**
```json
{
  "content": "Can you add password reset functionality?",
  "type": "command"
}
```

**Expected Response (201 Created):**
```json
{
  "message": {
    "id": "msg_458",
    "session_id": "session_123",
    "content": "Can you add password reset functionality?",
    "timestamp": "2024-11-11T14:45:00Z",
    "sender": "user",
    "type": "command"
  }
}
```

---

## 4. Create Session

**Current Mock:** `createSession(String title)`

**API Specification:**
- **Endpoint:** `POST /api/sessions`
- **Headers:** Authorization required
- **Body:** JSON with session title

**Request Example:**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/sessions'),
  headers: _getHeaders(),
  body: json.encode({
    'title': title,
  }),
);
```

**Request Body:**
```json
{
  "title": "Implement user authentication"
}
```

**Expected Response (201 Created):**
```json
{
  "session": {
    "id": "session_789",
    "title": "Implement user authentication",
    "start_time": "2024-11-11T16:00:00Z",
    "last_activity_time": "2024-11-11T16:00:00Z",
    "status": "idle",
    "message_count": 0
  }
}
```

---

## 5. Delete Session

**Current Mock:** `deleteSession(String sessionId)`

**API Specification:**
- **Endpoint:** `DELETE /api/sessions/{sessionId}`
- **Headers:** Authorization required

**Request Example:**
```dart
final response = await http.delete(
  Uri.parse('$baseUrl/api/sessions/$sessionId'),
  headers: _getHeaders(),
);
```

**Expected Response (204 No Content):**
```
(Empty body)
```

---

## 6. Update Session Status

**Current Mock:** `updateSessionStatus(String sessionId, ChatStatus status)`

**API Specification:**
- **Endpoint:** `PATCH /api/sessions/{sessionId}`
- **Headers:** Authorization required
- **Body:** JSON with status update

**Request Example:**
```dart
final response = await http.patch(
  Uri.parse('$baseUrl/api/sessions/$sessionId'),
  headers: _getHeaders(),
  body: json.encode({
    'status': status.toString().split('.').last,
  }),
);
```

**Request Body:**
```json
{
  "status": "completed"
}
```

**Expected Response (200 OK):**
```json
{
  "session": {
    "id": "session_123",
    "title": "Implement user authentication",
    "start_time": "2024-11-11T14:00:00Z",
    "last_activity_time": "2024-11-11T16:25:00Z",
    "status": "completed",
    "message_count": 12
  }
}
```

---

## Implementation Steps

### Step 1: Add Data Model Serialization

Update models to support JSON serialization:

```dart
// lib/models/chat_session.dart
class ChatSession {
  // ... existing properties ...

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      startTime: DateTime.parse(json['start_time']),
      lastActivityTime: DateTime.parse(json['last_activity_time']),
      status: _statusFromString(json['status']),
      messageCount: json['message_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'last_activity_time': lastActivityTime.toIso8601String(),
      'status': status.toString().split('.').last,
      'message_count': messageCount,
    };
  }

  static ChatStatus _statusFromString(String status) {
    switch (status) {
      case 'active': return ChatStatus.active;
      case 'idle': return ChatStatus.idle;
      case 'completed': return ChatStatus.completed;
      default: return ChatStatus.idle;
    }
  }
}
```

### Step 2: Create API Client

Create a new file `lib/services/api_client.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://api.cursor.cli/v1';
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  Future<void> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete: ${response.statusCode}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }
}
```

### Step 3: Update ChatService

Replace mock implementations with real API calls:

```dart
// lib/services/chat_service.dart
import 'api_client.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

  Future<List<ChatSession>> getSessions() async {
    final data = await _apiClient.get('/api/sessions');
    return (data['sessions'] as List)
        .map((json) => ChatSession.fromJson(json))
        .toList();
  }

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final data = await _apiClient.get('/api/sessions/$sessionId/messages');
    return (data['messages'] as List)
        .map((json) => ChatMessage.fromJson(json))
        .toList();
  }

  // ... implement other methods similarly
}
```

### Step 4: Add Error Handling

Create `lib/utils/exceptions.dart`:

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
```

### Step 5: Add Authentication

Create `lib/services/auth_service.dart`:

```dart
class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<void> login(String email, String password) async {
    final data = await _apiClient.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    _apiClient.setToken(data['token']);
  }

  Future<void> logout() async {
    await _apiClient.post('/api/auth/logout', {});
    _apiClient.setToken(null);
  }
}
```

## Testing API Integration

1. **Use Postman or curl** to test endpoints independently
2. **Mock API Server**: Use tools like json-server for local testing
3. **Environment Variables**: Store API URLs in configuration
4. **Error Scenarios**: Test network failures, timeouts, invalid responses

## WebSocket Support (Future Enhancement)

For real-time updates, consider adding WebSocket support:

```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

```dart
class WebSocketService {
  WebSocketChannel? _channel;

  void connect(String sessionId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://api.cursor.cli/ws/sessions/$sessionId'),
    );
    
    _channel!.stream.listen((message) {
      // Handle incoming messages
    });
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
```

## Deployment Checklist

- [ ] Replace mock data with API calls
- [ ] Add authentication flow
- [ ] Implement proper error handling
- [ ] Add retry logic for failed requests
- [ ] Add request/response logging (debug only)
- [ ] Test all CRUD operations
- [ ] Handle offline scenarios
- [ ] Add data caching
- [ ] Implement WebSocket for real-time updates
- [ ] Add rate limiting handling
- [ ] Security: Never log sensitive data
- [ ] Performance: Implement pagination
- [ ] UX: Add loading indicators
- [ ] UX: Show meaningful error messages
