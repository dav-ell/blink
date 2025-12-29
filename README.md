# Blink - Remote Desktop for Cursor IDE

Control your Mac's Cursor IDE from your iPhone with low-latency window streaming.

```
┌──────────────────┐         WebRTC          ┌──────────────────┐
│   macOS Server   │ ◀───────────────────────│   iOS Client     │
│                  │         Stream          │                  │
│  ┌────────────┐  │                         │  ┌────────────┐  │
│  │   Cursor   │──┼─────────────────────────┼──│   Live     │  │
│  │   Window   │  │                         │  │   View     │  │
│  └────────────┘  │                         │  └────────────┘  │
│                  │◀────────────────────────│                  │
│  CGEvent Input   │      Touch Events       │  Tap/Drag/Scroll │
└──────────────────┘                         └──────────────────┘
```

## Overview

Blink lets you stream and control multiple macOS windows from your iPhone:

- **Multi-window streaming** - View Cursor, Terminal, and other apps simultaneously
- **Touch-to-input** - Tap to click, drag to move, pinch to zoom
- **Zero-config discovery** - Automatically finds servers on your network via mDNS
- **Low latency** - Hardware-accelerated H.264 via WebRTC

## Architecture

```
blink/
├── apps/
│   └── ios/                    # Flutter iOS client
├── stream-server/              # macOS streaming server (Rust + Swift)
│   └── [See JacobPlan.md]
├── mcp-server/                 # MCP server for LLM agent control
├── rest-rust/                  # REST API backend
└── remote-agent-service/       # Remote cursor-agent execution
```

### Stream Server (macOS)

**Technology:** Rust + Swift bridge for ScreenCaptureKit

**Responsibilities:**
- Enumerate and capture macOS windows via ScreenCaptureKit
- Stream video to clients via WebRTC (multi-track)
- Receive input events and inject via CGEvent
- Advertise service via mDNS (`_blink._tcp`)

**Key Components:**
- WebSocket server for signaling and input
- Swift bridge for native macOS APIs
- Per-window video tracks

### iOS Client (Flutter)

**Location:** `apps/ios/`

**Responsibilities:**
- Discover servers via mDNS/Bonjour
- Connect and negotiate WebRTC streams
- Display multiple window streams with tab switching
- Translate touch gestures to mouse/keyboard events

**Key Features:**
- Frosted glass UI with 120fps animations
- Gesture-first interaction (tap, drag, pinch, scroll)
- Auto-hide controls when viewing
- Haptic feedback throughout

## Quick Start

### iOS Client

```bash
cd apps/ios
flutter pub get
flutter run
```

### Stream Server

See `stream-server/README.md` (or `JacobPlan.md` for spec)

```bash
cd stream-server
cargo run
```

## API Contract

### mDNS Discovery

- **Service Type:** `_blink._tcp`
- **Port:** `8080`
- **TXT Records:** `version=1`, `name=<hostname>`

### WebSocket Endpoints

#### `WS /signaling` - WebRTC Signaling

```json
// Client → Server: Offer
{"type": "offer", "sdp": "..."}

// Server → Client: Answer  
{"type": "answer", "sdp": "..."}

// Both: ICE candidates
{"type": "ice", "candidate": "..."}
```

#### `WS /windows` - Window Management

```json
// Server → Client: Window list
{
  "type": "window_list",
  "windows": [
    {"id": 12345, "title": "Cursor - project", "app": "Cursor", "bounds": {...}}
  ]
}

// Client → Server: Subscribe
{"type": "subscribe", "window_ids": [12345, 12346]}
```

#### `WS /input` - Input Events

```json
// Mouse
{"type": "mouse", "window_id": 12345, "action": "click", "x": 0.5, "y": 0.3}

// Keyboard
{"type": "key", "window_id": 12345, "action": "down", "key_code": 36}
```

## iOS Client Structure

```
apps/ios/lib/
├── main.dart
├── theme/
│   ├── remote_theme.dart        # Colors, typography
│   ├── animations.dart          # Motion design
│   └── glassmorphism.dart       # Frosted glass effects
├── models/
│   ├── server.dart              # Discovered server info
│   ├── remote_window.dart       # Window metadata
│   └── connection_state.dart    # Connection status
├── services/
│   ├── discovery_service.dart   # mDNS discovery
│   ├── stream_service.dart      # WebRTC management
│   └── input_service.dart       # Touch → input events
├── providers/
│   ├── connection_provider.dart
│   ├── windows_provider.dart
│   └── stream_provider.dart
├── screens/
│   ├── connection_screen.dart   # Server discovery
│   ├── window_picker_screen.dart
│   ├── remote_desktop_screen.dart
│   └── grid_view_screen.dart
└── widgets/
    ├── connection/              # Server cards, scanning
    ├── window/                  # Tab bar, video view
    └── input/                   # Touch overlay, keyboard
```

## Gestures

| Gesture | Action |
|---------|--------|
| **Tap** | Left click |
| **Double tap** | Double click |
| **Two-finger tap** | Right click |
| **Long press** | Right click (hold) |
| **Drag** | Mouse move |
| **Pinch** | Zoom window |
| **Two-finger scroll** | Scroll wheel |
| **Swipe tabs** | Switch windows |
| **Three-finger down** | Grid view |

## Requirements

### iOS Client
- Flutter 3.0+
- iOS 12+
- Same WiFi network as Mac

### Stream Server
- macOS 12.3+ (ScreenCaptureKit)
- Rust 1.70+
- Screen Recording permission

## Project Status

| Component | Status |
|-----------|--------|
| iOS Client | 🟡 In Development |
| Stream Server | 🔴 Not Started |
| mDNS Discovery | ✅ Implemented |
| WebRTC Streaming | 🟡 Scaffolded |
| Input Injection | 🔴 Not Started |

## Related Components

- **`mcp-server/`** - MCP server for LLM agents to control Blink
- **`rest-rust/`** - REST API for chat management (legacy)
- **`remote-agent-service/`** - Remote cursor-agent execution

## License

MIT
