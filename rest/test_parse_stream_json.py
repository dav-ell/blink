#!/usr/bin/env python3
"""
Parse stream-json output to understand all available event types
"""

import subprocess
import json
import sys
import os
from collections import defaultdict

CURSOR_AGENT_PATH = os.path.expanduser("~/.local/bin/cursor-agent")

def get_stream_json_events(prompt: str) -> list:
    """Get all events from stream-json output"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--output-format", "stream-json", prompt],
        capture_output=True,
        text=True,
        timeout=60
    )
    
    if result.returncode != 0:
        print(f"❌ Failed: {result['stderr']}")
        return []
    
    events = []
    for line in result.stdout.strip().split('\n'):
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"Warning: Failed to parse line: {e}")
                print(f"  Line: {line[:200]}")
    
    return events

def analyze_events(events: list):
    """Analyze event types and structure"""
    # Count event types
    type_counts = defaultdict(int)
    type_subtypes = defaultdict(set)
    
    for event in events:
        event_type = event.get('type', 'unknown')
        subtype = event.get('subtype', 'none')
        
        type_counts[event_type] += 1
        type_subtypes[event_type].add(subtype)
    
    print("=" * 80)
    print("EVENT TYPE SUMMARY")
    print("=" * 80)
    for event_type, count in sorted(type_counts.items()):
        subtypes = sorted(type_subtypes[event_type])
        print(f"{event_type:20} Count: {count:4}   Subtypes: {', '.join(subtypes)}")
    print()
    
    # Show sample of each event type
    print("=" * 80)
    print("SAMPLE EVENTS BY TYPE")
    print("=" * 80)
    
    shown_types = set()
    for event in events:
        event_type = event.get('type', 'unknown')
        if event_type not in shown_types:
            shown_types.add(event_type)
            print(f"\nType: {event_type}")
            print("-" * 80)
            print(json.dumps(event, indent=2)[:500])
    
    # Extract thinking content
    print("\n" + "=" * 80)
    print("THINKING CONTENT")
    print("=" * 80)
    thinking_parts = []
    for event in events:
        if event.get('type') == 'thinking' and event.get('subtype') == 'delta':
            thinking_parts.append(event.get('text', ''))
    
    if thinking_parts:
        full_thinking = ''.join(thinking_parts)
        print(f"Total thinking characters: {len(full_thinking)}")
        print("\nFull thinking text:")
        print(full_thinking)
    else:
        print("No thinking content found")
    
    # Extract tool calls
    print("\n" + "=" * 80)
    print("TOOL CALLS")
    print("=" * 80)
    tool_calls = [e for e in events if e.get('type') == 'tool_call' or 'tool' in e.get('type', '').lower()]
    if tool_calls:
        print(f"Found {len(tool_calls)} tool call events:")
        for tc in tool_calls:
            print(json.dumps(tc, indent=2))
    else:
        print("No explicit tool_call events found")
        # Check for tool-related events
        tool_related = [e for e in events if 'tool' in str(e).lower()]
        if tool_related:
            print(f"\nFound {len(tool_related)} tool-related events:")
            for tr in tool_related[:3]:  # Show first 3
                print(json.dumps(tr, indent=2)[:500])

def main():
    print("=" * 80)
    print("Analyzing stream-json output structure")
    print("=" * 80)
    print()
    
    # Use a prompt that should trigger tool use
    prompt = "What Python files are in the current directory? Use ls command."
    
    print(f"Prompt: {prompt}")
    print()
    
    events = get_stream_json_events(prompt)
    print(f"Total events: {len(events)}")
    print()
    
    if events:
        analyze_events(events)
    else:
        print("❌ No events captured")

if __name__ == "__main__":
    main()

