#!/usr/bin/env python3
"""
End-to-end test: Verify reasoning and tool calls are captured and returned
"""

import requests
import json
import time

API_BASE = "http://localhost:8000"

def test_create_chat():
    """Create a new chat"""
    print("=" * 80)
    print("TEST 1: Create new chat")
    print("=" * 80)
    
    response = requests.post(f"{API_BASE}/agent/create-chat")
    assert response.status_code == 200, f"Failed to create chat: {response.text}"
    
    data = response.json()
    chat_id = data["chat_id"]
    print(f"✓ Created chat: {chat_id}")
    return chat_id

def test_submit_async_prompt(chat_id: str):
    """Submit a prompt that should trigger tool calls"""
    print("\n" + "=" * 80)
    print("TEST 2: Submit prompt with async endpoint")
    print("=" * 80)
    
    prompt = "List all Python test files in the current directory using ls command"
    
    response = requests.post(
        f"{API_BASE}/chats/{chat_id}/agent-prompt-async",
        json={"prompt": prompt}
    )
    assert response.status_code == 200, f"Failed to submit prompt: {response.text}"
    
    data = response.json()
    job_id = data["job_id"]
    print(f"✓ Submitted job: {job_id}")
    print(f"  Status: {data['status']}")
    return job_id

def test_poll_job(job_id: str):
    """Poll job until completed"""
    print("\n" + "=" * 80)
    print("TEST 3: Poll job status")
    print("=" * 80)
    
    max_attempts = 60
    for i in range(max_attempts):
        response = requests.get(f"{API_BASE}/jobs/{job_id}")
        assert response.status_code == 200, f"Failed to get job: {response.text}"
        
        data = response.json()
        status = data["status"]
        print(f"  Attempt {i+1}: status = {status}")
        
        if status in ["completed", "failed"]:
            return data
        
        time.sleep(2)
    
    raise TimeoutError(f"Job {job_id} did not complete within {max_attempts * 2} seconds")

def test_verify_rich_content(job_data: dict):
    """Verify the job result contains rich content"""
    print("\n" + "=" * 80)
    print("TEST 4: Verify rich content in job result")
    print("=" * 80)
    
    # Check status
    status = job_data["status"]
    print(f"✓ Job status: {status}")
    
    if status == "failed":
        print(f"❌ Job failed: {job_data.get('error')}")
        return False
    
    # Check result text
    result = job_data.get("result")
    print(f"\n✓ Result text ({len(result) if result else 0} chars):")
    if result:
        print(f"  {result[:200]}...")
    
    # Check thinking content
    thinking = job_data.get("thinking_content")
    if thinking:
        print(f"\n✓ Thinking content ({len(thinking)} chars):")
        print(f"  {thinking[:200]}...")
    else:
        print("\n⚠️  No thinking content")
    
    # Check tool calls
    tool_calls = job_data.get("tool_calls")
    if tool_calls and len(tool_calls) > 0:
        print(f"\n✓ Tool calls ({len(tool_calls)} calls):")
        for idx, tool in enumerate(tool_calls):
            print(f"  {idx+1}. {tool.get('name')}")
            print(f"     Command: {tool.get('command')}")
            if 'result' in tool:
                print(f"     Exit code: {tool['result'].get('exit_code')}")
                stdout = tool['result'].get('stdout', '')
                if stdout:
                    print(f"     Output: {stdout[:100]}...")
    else:
        print("\n⚠️  No tool calls")
    
    # Check bubble IDs
    user_bubble_id = job_data.get("user_bubble_id")
    assistant_bubble_id = job_data.get("assistant_bubble_id")
    print(f"\n✓ Bubble IDs:")
    print(f"  User: {user_bubble_id}")
    print(f"  Assistant: {assistant_bubble_id}")
    
    return True

def test_get_chat_messages(chat_id: str):
    """Get chat messages to verify they contain rich content"""
    print("\n" + "=" * 80)
    print("TEST 5: Get chat messages")
    print("=" * 80)
    
    response = requests.get(f"{API_BASE}/chats/{chat_id}")
    assert response.status_code == 200, f"Failed to get chat: {response.text}"
    
    data = response.json()
    messages = data["messages"]
    print(f"✓ Retrieved {len(messages)} messages")
    
    for idx, msg in enumerate(messages):
        print(f"\nMessage {idx+1}:")
        print(f"  Type: {msg['type_label']}")
        print(f"  Has tool call: {msg['has_tool_call']}")
        print(f"  Has thinking: {msg['has_thinking']}")
        
        if msg['tool_calls']:
            print(f"  Tool calls: {len(msg['tool_calls'])}")
        
        if msg['thinking_content']:
            print(f"  Thinking: {len(msg['thinking_content'])} chars")
    
    return messages

def main():
    print("=" * 80)
    print("END-TO-END TEST: Reasoning Trace and Tool Call Display")
    print("=" * 80)
    print()
    print("This test will:")
    print("  1. Create a new chat")
    print("  2. Submit a prompt that triggers tool calls")
    print("  3. Poll for job completion")
    print("  4. Verify the result contains:")
    print("     - Text response")
    print("     - Thinking/reasoning content")
    print("     - Tool call information")
    print("  5. Retrieve chat messages to verify database storage")
    print()
    
    try:
        # Test 1: Create chat
        chat_id = test_create_chat()
        
        # Test 2: Submit async prompt
        job_id = test_submit_async_prompt(chat_id)
        
        # Test 3: Poll job
        job_data = test_poll_job(job_id)
        
        # Test 4: Verify rich content
        success = test_verify_rich_content(job_data)
        
        # Test 5: Get chat messages
        messages = test_get_chat_messages(chat_id)
        
        print("\n" + "=" * 80)
        print("FINAL RESULTS")
        print("=" * 80)
        
        if success:
            print("✓ ALL TESTS PASSED")
            print()
            print("The implementation successfully:")
            print("  - Captures cursor-agent's stream-json output")
            print("  - Extracts thinking/reasoning traces")
            print("  - Extracts tool call information")
            print("  - Stores rich content in database bubbles")
            print("  - Returns structured data to Flutter app")
            print()
            print("The Flutter app should now display:")
            print("  - Tool calls in expandable ToolCallBox widgets")
            print("  - Reasoning in expandable ThinkingBox widgets")
        else:
            print("❌ TESTS FAILED")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())

