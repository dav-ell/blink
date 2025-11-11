# Blink - Cursor Chat Manager

A Flutter mobile app for managing and interacting with your Cursor IDE chat sessions.

## Features

### Current (Stage 1 - Mock Data)
- View all chat sessions with Cursor IDE
- See chat history and message details
- Send new messages to inactive chats
- Status indicators (active, inactive, completed)
- Responsive and modern UI

### Planned (Future Stages)
- Real-time backend integration with Cursor IDE
- Live updates when Cursor responds
- Push notifications
- File attachments
- Chat export and sharing
- Offline support

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── chat.dart               # Chat data model
│   └── message.dart            # Message data model
├── services/
│   └── chat_service.dart       # Service layer (currently mocked)
├── screens/
│   ├── chat_list_screen.dart   # Main screen showing all chats
│   └── chat_detail_screen.dart # Chat detail with message history
└── widgets/
    ├── chat_list_item.dart     # Chat list item widget
    └── message_bubble.dart     # Message bubble widget
```

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK
- iOS/Android development environment

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd blink
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## Mock Data

The app currently uses mock data defined in `lib/services/chat_service.dart`. This includes:
- 3 sample chats with different statuses
- Sample messages between user and Cursor IDE
- Simulated network delays

## Backend Integration

All backend integration points are documented in `BACKEND_INTEGRATION.md`. Each location that needs backend integration is marked with `// TODO:` comments in the code.

Key integration points:
- Fetching chats from API
- Fetching individual chat details
- Sending messages to Cursor IDE
- Creating new chat sessions
- Real-time message updates via WebSocket

## Development Stages

### Stage 1 (Current)
- ✅ Basic UI implementation
- ✅ Mock data
- ✅ Navigation
- ✅ Message display
- ✅ Message input

### Stage 2 (Planned)
- Backend API integration
- Authentication
- Real API calls replacing mock data

### Stage 3 (Planned)
- WebSocket for real-time updates
- Push notifications
- Offline support

### Stage 4 (Planned)
- File attachments
- Chat export/sharing
- Advanced features

## Contributing

This is a personal project for managing Cursor IDE chats. Contributions and suggestions are welcome!

## License

[Add your license here]
