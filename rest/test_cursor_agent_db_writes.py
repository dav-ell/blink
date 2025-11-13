#!/usr/bin/env python3
"""
Test: Does cursor-agent write to database when using --print flag?

This test will:
1. Create a new chat
2. Count bubbles before calling cursor-agent
3. Call cursor-agent with --print --force --resume
4. Count bubbles after
5. Determine if cursor-agent wrote to the database
"""

import sqlite3
import subprocess
import sys
import os
from pathlib import Path

# Database path (macOS)
DB_PATH = os.path.expanduser("~/Library/Application Support/Cursor/User/globalStorage/state.vscdb")
CURSOR_AGENT_PATH = os.path.expanduser("~/.local/bin/cursor-agent")

def count_bubbles_for_chat(chat_id: str) -> int:
    """Count number of bubbles for a given chat"""
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found at: {DB_PATH}")
        return 0
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT COUNT(*) FROM cursorDiskKV 
        WHERE key LIKE ?
    """, (f'bubbleId:{chat_id}:%',))
    
    count = cursor.fetchone()[0]
    conn.close()
    return count

def get_bubble_ids_for_chat(chat_id: str) -> list:
    """Get all bubble IDs for a given chat"""
    if not os.path.exists(DB_PATH):
        return []
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT key FROM cursorDiskKV 
        WHERE key LIKE ?
        ORDER BY key
    """, (f'bubbleId:{chat_id}:%',))
    
    keys = [row[0] for row in cursor.fetchall()]
    conn.close()
    return keys

def create_chat() -> str:
    """Create a new chat and return its ID"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "create-chat"],
        capture_output=True,
        text=True,
        timeout=10
    )
    
    if result.returncode != 0:
        print(f"❌ Failed to create chat: {result.stderr}")
        sys.exit(1)
    
    return result.stdout.strip()

def call_cursor_agent_with_print(chat_id: str, prompt: str) -> dict:
    """Call cursor-agent with --print flag"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--resume", chat_id, prompt],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
        "success": result.returncode == 0
    }

def main():
    print("=" * 80)
    print("Testing: Does cursor-agent write to database with --print flag?")
    print("=" * 80)
    
    # Check if cursor-agent exists
    if not os.path.exists(CURSOR_AGENT_PATH):
        print(f"❌ cursor-agent not found at: {CURSOR_AGENT_PATH}")
        sys.exit(1)
    
    # Check if database exists
    if not os.path.exists(DB_PATH):
        print(f"❌ Cursor database not found at: {DB_PATH}")
        print("Please run Cursor IDE at least once to create the database.")
        sys.exit(1)
    
    print(f"✓ cursor-agent found: {CURSOR_AGENT_PATH}")
    print(f"✓ Database found: {DB_PATH}")
    print()
    
    # Step 1: Create a new chat
    print("Step 1: Creating new chat...")
    chat_id = create_chat()
    print(f"✓ Created chat: {chat_id}")
    print()
    
    # Step 2: Count bubbles before
    print("Step 2: Counting bubbles before cursor-agent call...")
    bubbles_before = count_bubbles_for_chat(chat_id)
    bubble_ids_before = get_bubble_ids_for_chat(chat_id)
    print(f"  Bubbles before: {bubbles_before}")
    if bubble_ids_before:
        for bid in bubble_ids_before:
            print(f"    - {bid}")
    print()
    
    # Step 3: Call cursor-agent with --print
    print("Step 3: Calling cursor-agent with --print flag...")
    prompt = "Say 'Hello World' and nothing else."
    result = call_cursor_agent_with_print(chat_id, prompt)
    
    if result["success"]:
        print(f"✓ cursor-agent succeeded")
        print(f"  Output: {result['stdout'][:200]}")
    else:
        print(f"❌ cursor-agent failed: {result['stderr']}")
        sys.exit(1)
    print()
    
    # Step 4: Count bubbles after
    print("Step 4: Counting bubbles after cursor-agent call...")
    bubbles_after = count_bubbles_for_chat(chat_id)
    bubble_ids_after = get_bubble_ids_for_chat(chat_id)
    print(f"  Bubbles after: {bubbles_after}")
    if bubble_ids_after:
        for bid in bubble_ids_after:
            print(f"    - {bid}")
    print()
    
    # Step 5: Analysis
    print("=" * 80)
    print("RESULTS:")
    print("=" * 80)
    new_bubbles = bubbles_after - bubbles_before
    print(f"Bubbles before: {bubbles_before}")
    print(f"Bubbles after:  {bubbles_after}")
    print(f"New bubbles:    {new_bubbles}")
    print()
    
    if new_bubbles == 0:
        print("❌ CONCLUSION: cursor-agent does NOT write to database with --print flag")
        print()
        print("This means:")
        print("  - cursor-agent only outputs to stdout")
        print("  - The REST API MUST manually write bubbles to the database")
        print("  - Option A (let cursor-agent handle everything) will NOT work")
        print("  - We need Option B or a hybrid approach")
    elif new_bubbles == 1:
        print("⚠️  CONCLUSION: cursor-agent wrote 1 bubble (possibly just user or assistant)")
        print()
        print("This is unexpected - normally we'd expect 2 bubbles (user + assistant)")
    elif new_bubbles == 2:
        print("✓ CONCLUSION: cursor-agent DOES write to database with --print flag")
        print()
        print("This means:")
        print("  - cursor-agent wrote both user and assistant bubbles")
        print("  - Option A (let cursor-agent handle everything) WILL work")
        print("  - We can read cursor-agent's bubbles for tool calls and thinking")
    else:
        print(f"⚠️  CONCLUSION: Unexpected number of new bubbles: {new_bubbles}")
    
    print("=" * 80)
    
    # Show what changed
    if new_bubbles > 0:
        print()
        print("New bubble IDs:")
        new_ids = set(bubble_ids_after) - set(bubble_ids_before)
        for bid in sorted(new_ids):
            print(f"  - {bid}")

if __name__ == "__main__":
    main()

