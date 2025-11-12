#!/usr/bin/env python3
"""
Diagnose chat structure issues that might cause Flutter parsing errors.
"""

import sqlite3
import json
import os

DB_PATH = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')

def check_chat(chat_id):
    """Check a specific chat for structure issues"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    print(f"\n{'='*80}")
    print(f"Checking chat: {chat_id}")
    print(f"{'='*80}\n")
    
    # Check composerData
    cursor.execute("SELECT value FROM cursorDiskKV WHERE key = ?", (f'composerData:{chat_id}',))
    row = cursor.fetchone()
    
    if not row:
        print(f"❌ Chat not found!")
        return
    
    composer = json.loads(row[0])
    print(f"✓ ComposerData found:")
    print(f"  Name: {composer.get('name', 'Untitled')}")
    print(f"  Messages: {len(composer.get('fullConversationHeadersOnly', []))}")
    
    # Check for fields that might be JSON strings
    print(f"\n  Checking for JSON string fields:")
    for key, value in composer.items():
        if isinstance(value, str) and len(value) > 0 and (value[0] == '{' or value[0] == '['):
            print(f"    ⚠ {key} is a JSON string ({len(value)} chars)")
    
    # Check messages
    cursor.execute("SELECT key, value FROM cursorDiskKV WHERE key LIKE ?", (f'bubbleId:{chat_id}:%',))
    
    problem_messages = []
    total_messages = 0
    
    for key, value in cursor.fetchall():
        total_messages += 1
        try:
            bubble = json.loads(value)
            bubble_id = key.split(':')[-1]
            
            # Check for problematic structures
            issues = []
            
            # Check tool_calls
            if 'toolFormerData' in bubble and bubble['toolFormerData']:
                if isinstance(bubble['toolFormerData'], str):
                    issues.append("toolFormerData is a string")
            
            # Check code_blocks
            if 'codeBlocks' in bubble and bubble['codeBlocks']:
                if isinstance(bubble['codeBlocks'], str):
                    issues.append("codeBlocks is a string")
                elif isinstance(bubble['codeBlocks'], list):
                    for i, cb in enumerate(bubble['codeBlocks']):
                        if isinstance(cb, str):
                            issues.append(f"codeBlocks[{i}] is a string")
            
            # Check todos  
            if 'todos' in bubble and bubble['todos']:
                if isinstance(bubble['todos'], str):
                    issues.append("todos is a string")
                elif isinstance(bubble['todos'], list):
                    for i, td in enumerate(bubble['todos']):
                        if isinstance(td, str):
                            issues.append(f"todos[{i}] is a string")
            
            if issues:
                problem_messages.append((bubble_id[:8], issues))
                
        except Exception as e:
            print(f"  ❌ Error parsing bubble {key}: {e}")
    
    print(f"\n✓ Checked {total_messages} messages")
    
    if problem_messages:
        print(f"\n⚠ Found {len(problem_messages)} messages with potential issues:")
        for bid, issues in problem_messages[:5]:  # Show first 5
            print(f"  {bid}: {', '.join(issues)}")
    else:
        print(f"\n✓ No obvious structure issues found")
    
    conn.close()

def main():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get all chats
    cursor.execute("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'")
    chat_ids = [key.split(':')[1] for key, in cursor.fetchall()]
    
    print(f"Found {len(chat_ids)} chats to check:")
    for chat_id in chat_ids:
        cursor.execute("SELECT json_extract(value, '$.name') FROM cursorDiskKV WHERE key = ?", 
                      (f'composerData:{chat_id}',))
        name = cursor.fetchone()[0]
        print(f"  - {chat_id}: {name or 'Untitled'}")
    
    conn.close()
    
    # Check each chat
    for chat_id in chat_ids:
        check_chat(chat_id)

if __name__ == "__main__":
    main()

