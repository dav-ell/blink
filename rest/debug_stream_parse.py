#!/usr/bin/env python3
"""Debug: Check what cursor-agent returns and how parser handles it"""

import subprocess
import json
import sys
import os

sys.path.insert(0, '/Users/davell/Documents/github/blink/rest')

from cursor_api.utils.stream_json_parser import parse_cursor_agent_output

CURSOR_AGENT_PATH = os.path.expanduser("~/.local/bin/cursor-agent")

def test_with_real_chat():
    """Test with a real chat ID"""
    # Create chat
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "create-chat"],
        capture_output=True,
        text=True,
        timeout=10
    )
    chat_id = result.stdout.strip()
    print(f"Created chat: {chat_id}")
    print()
    
    # Run cursor-agent with stream-json
    prompt = "List Python files in current directory using ls command"
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--output-format", "stream-json",
         "--resume", chat_id, prompt],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    print("=" * 80)
    print("RAW OUTPUT (first 2000 chars):")
    print("=" * 80)
    print(result.stdout[:2000])
    print()
    
    print("=" * 80)
    print("PARSED OUTPUT:")
    print("=" * 80)
    parsed = parse_cursor_agent_output(result.stdout)
    print(json.dumps(parsed, indent=2)[:1000])
    print()
    
    print("=" * 80)
    print("SUMMARY:")
    print("=" * 80)
    print(f"Text: {len(parsed.get('text', ''))} chars")
    print(f"Thinking: {len(parsed.get('thinking', '') or '')} chars")
    print(f"Tool calls: {len(parsed.get('tool_calls') or [])}")
    
    if parsed.get('thinking'):
        print("\nThinking content:")
        print(parsed['thinking'][:200])
    
    if parsed.get('tool_calls'):
        print("\nTool calls:")
        for tc in parsed['tool_calls']:
            print(f"  - {tc.get('name')}: {tc.get('command')}")

if __name__ == "__main__":
    test_with_real_chat()

