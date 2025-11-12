#!/bin/bash
# Test manual database writes

CHAT_ID="a3dc74be-84ed-4c72-98e2-59b94356557f"
DB_PATH="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"

echo "=== Testing Manual Database Writes ==="
echo ""

# Get initial count
BEFORE=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:$CHAT_ID:%';")
echo "Messages before: $BEFORE"

# Send test message
echo "Sending test message..."
RESPONSE=$(curl -s -X POST "http://127.0.0.1:8000/chats/$CHAT_ID/agent-prompt" \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "Quick test - respond with just TEST OK", "include_history": true}')

echo "$RESPONSE" | python3 -m json.tool

# Get after count
AFTER=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:$CHAT_ID:%';")
echo ""
echo "Messages after: $AFTER"
echo "Added: $((AFTER - BEFORE)) messages"

# Verify messages exist
echo ""
echo "Checking for user message..."
USER_CHECK=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:$CHAT_ID:%' AND json_extract(value, '$.text') LIKE '%Quick test%';")
if [ "$USER_CHECK" -gt 0 ]; then
    echo "✓ User message found in database"
else
    echo "✗ User message NOT found"
fi

echo ""
echo "PAUSE: Please open this chat in Cursor IDE and verify messages appear correctly."
echo "Press Enter when done..."
read

