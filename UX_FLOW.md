# Blink - User Experience Flow

## Application Flow

### 1. App Launch
```
User opens app
    ↓
App initializes
    ↓
ChatListScreen loads
    ↓
Fetches sessions from service (mock data)
    ↓
Displays list of chat sessions
```

### 2. Chat List Screen (Home)

**Elements Displayed:**
- App Bar with "Cursor Chat Sessions" title
- Refresh button
- List of session cards with:
  - Status indicator (colored avatar with icon)
  - Session title
  - Status text + message count
  - Last activity timestamp
  - Chevron for navigation
- Floating Action Button: "New Session"

**User Actions:**
- **Tap session card** → Navigate to Chat Detail Screen
- **Pull down** → Refresh sessions
- **Tap refresh button** → Reload sessions
- **Tap "New Session"** → Show dialog to create new session

**Status Colors:**
- 🟢 Green: Active (Cursor is running)
- 🟠 Orange: Idle (Not running, ready for commands)
- ⚪ Gray: Completed (Session ended)

### 3. Chat Detail Screen

**Elements Displayed:**
- App Bar with:
  - Session title
  - Status subtitle
  - Info button
- Warning banner (if idle): "Cursor is not running. Send a message..."
- Message list (scrollable)
- Message input area with:
  - Text field
  - Send button

**Message Display:**
- Left-aligned: Cursor messages (purple container)
- Right-aligned: User messages (blue container)
- Each bubble shows:
  - Sender name
  - Timestamp
  - Message content
  - Type badge (for commands)
  - Code formatting (for code messages)

**User Actions:**
- **Tap info button** → Show session details dialog
- **Type message + send** → Send message to Cursor
- **Type command (starts with /)** → Marked as command type
- **Scroll** → View message history
- **Back button** → Return to Chat List

### 4. Create Session Flow
```
User taps "New Session"
    ↓
Dialog appears
    ↓
User enters session title
    ↓
User taps "Create"
    ↓
Service creates session
    ↓
Success message shown
    ↓
Session list refreshes
```

### 5. Send Message Flow
```
User types message
    ↓
User taps send button
    ↓
Service sends message
    ↓
Message added to list
    ↓
Auto-scroll to bottom
    ↓
Success notification shown
```

## UI States

### Loading States
- **Initial Load:** Circular progress indicator in center
- **Sending Message:** Loading spinner on send button
- **Empty State:** 
  - Icon + "No sessions/messages yet" text
  - Helpful instruction text

### Error States
- Snackbar notifications for:
  - Failed to load sessions
  - Failed to load messages
  - Failed to send message
  - Failed to create session

### Interactive States
- Pull-to-refresh indicator
- Button press animations
- Card tap ripple effects
- Disabled send button when empty or sending

## Navigation Structure

```
BlinkApp (MaterialApp)
    ↓
ChatListScreen (Home)
    ↓
ChatDetailScreen (Push navigation)
    ↓
Back to ChatListScreen
```

## Message Types & Visual Indicators

1. **Text Message**
   - Standard text display
   - No special indicator

2. **Command Message**
   - Standard text display
   - Orange "COMMAND" badge below

3. **Code Message**
   - Monospace font
   - Dark background container
   - Preserves formatting

4. **Error Message** (placeholder for future)
   - Red accent color
   - Error icon

## Responsive Design

- Card margins: 12px horizontal, 6px vertical
- Message width: Max 75% of screen width
- Input padding: 8px all around
- Status indicators: Visible at all sizes
- Text scales with system font size

## Accessibility Considerations

- Semantic colors with icons (not color-only indicators)
- Text contrast meets WCAG guidelines
- Touch targets meet minimum size requirements
- Screen reader friendly labels
- Keyboard navigation support

## Time Formatting

- **Just now:** < 1 minute
- **Xm ago:** < 1 hour
- **Xh ago:** < 1 day
- **Xd ago:** < 1 week
- **MMM d:** > 1 week
- **HH:mm:** Message timestamps in detail view

## Future UX Enhancements (Noted for later stages)

- [ ] Swipe to delete session
- [ ] Long press for session options
- [ ] Search/filter sessions
- [ ] Attachment support
- [ ] Voice input
- [ ] Push notifications
- [ ] Real-time message updates
- [ ] Message reactions
- [ ] Thread/conversation view
- [ ] Export conversation
- [ ] Session tags/categories
