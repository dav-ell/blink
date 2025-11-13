#!/usr/bin/env python3
"""
Test: Does cursor-agent's JSON output include tool calls and thinking?

This will test if --output-format json gives us structured data
with tool calls, thinking, and other rich content.
"""

import subprocess
import json
import sys
import os

CURSOR_AGENT_PATH = os.path.expanduser("~/.local/bin/cursor-agent")

def test_json_format(prompt: str) -> dict:
    """Test cursor-agent with JSON output format"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--output-format", "json", prompt],
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

def test_stream_json_format(prompt: str) -> dict:
    """Test cursor-agent with stream-json output format"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--output-format", "stream-json", prompt],
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

def test_text_format(prompt: str) -> dict:
    """Test cursor-agent with text output format (default)"""
    result = subprocess.run(
        [CURSOR_AGENT_PATH, "--print", "--force", "--output-format", "text", prompt],
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
    print("Testing: cursor-agent JSON output formats")
    print("=" * 80)
    print()
    
    # Use a prompt that should trigger tool calls or reasoning
    prompt = "List all Python files in the current directory using a shell command"
    
    # Test 1: Text format (baseline)
    print("TEST 1: --output-format text")
    print("-" * 80)
    result = test_text_format(prompt)
    if result["success"]:
        print("✓ Success")
        print(f"Output length: {len(result['stdout'])} chars")
        print("Output preview:")
        print(result['stdout'][:500])
    else:
        print(f"❌ Failed: {result['stderr']}")
    print()
    
    # Test 2: JSON format
    print("TEST 2: --output-format json")
    print("-" * 80)
    result = test_json_format(prompt)
    if result["success"]:
        print("✓ Success")
        print(f"Output length: {len(result['stdout'])} chars")
        print("Attempting to parse JSON...")
        try:
            data = json.loads(result['stdout'])
            print("✓ Valid JSON!")
            print("\nJSON structure:")
            print(f"  Type: {type(data)}")
            if isinstance(data, dict):
                print(f"  Keys: {list(data.keys())}")
                # Check for tool calls, thinking, etc.
                if 'toolCalls' in data or 'tool_calls' in data:
                    print("  ✓ Contains tool_calls!")
                if 'thinking' in data or 'reasoning' in data:
                    print("  ✓ Contains thinking/reasoning!")
                if 'text' in data or 'content' in data or 'response' in data:
                    print("  ✓ Contains text content!")
                
                # Show full structure
                print("\nFull JSON:")
                print(json.dumps(data, indent=2)[:2000])
            elif isinstance(data, list):
                print(f"  Length: {len(data)}")
                if len(data) > 0:
                    print(f"  First item keys: {list(data[0].keys()) if isinstance(data[0], dict) else 'not a dict'}")
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON: {e}")
            print("Raw output:")
            print(result['stdout'][:1000])
    else:
        print(f"❌ Failed: {result['stderr']}")
    print()
    
    # Test 3: Stream JSON format
    print("TEST 3: --output-format stream-json")
    print("-" * 80)
    result = test_stream_json_format(prompt)
    if result["success"]:
        print("✓ Success")
        print(f"Output length: {len(result['stdout'])} chars")
        print("Output (stream-json may be multiple JSON objects):")
        print(result['stdout'][:1000])
        
        # Try to parse as newline-delimited JSON
        lines = result['stdout'].strip().split('\n')
        print(f"\nNumber of lines: {len(lines)}")
        if lines:
            print("First line:")
            try:
                first = json.loads(lines[0])
                print(json.dumps(first, indent=2)[:500])
            except:
                print(lines[0][:500])
    else:
        print(f"❌ Failed: {result['stderr']}")
    print()
    
    print("=" * 80)
    print("CONCLUSION:")
    print("=" * 80)
    print("Check the output above to see if JSON format includes:")
    print("  - Tool calls/commands executed")
    print("  - Thinking/reasoning traces")
    print("  - Structured content vs plain text")
    print()

if __name__ == "__main__":
    main()

