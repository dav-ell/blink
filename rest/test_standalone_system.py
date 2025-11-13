#!/usr/bin/env python3
"""
Test standalone Blink chat system end-to-end
"""

import requests
import json
import time

BASE_URL = "http://localhost:9090"

def print_section(title):
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80)

def test_health():
    """Test health endpoint"""
    print_section("Test 1: Health Check")
    response = requests.get(f"{BASE_URL}/health")
    data = response.json()
    
    print(f"✓ Status: {data['status']}")
    print(f"✓ Mode: {data['mode']}")
    print(f"✓ Database: {data['database']['type']}")
    print(f"✓ Total chats: {data['stats']['total_chats']}")
    print(f"✓ Total messages: {data['stats']['total_messages']}")
    
    assert data['status'] == 'healthy'
    assert data['mode'] == 'standalone'
    return True

def test_create_chat(initial_count):
    """Test creating a new chat"""
    print_section("Test 2: Create New Chat")
    response = requests.post(f"{BASE_URL}/agent/create-chat")
    data = response.json()
    
    chat_id = data['chat_id']
    print(f"✓ Created chat: {chat_id}")
    
    # Verify chat exists in database
    health = requests.get(f"{BASE_URL}/health").json()
    new_count = health['stats']['total_chats']
    print(f"✓ Total chats now: {new_count} (was {initial_count})")
    
    assert new_count == initial_count + 1, f"Expected {initial_count + 1} chats, got {new_count}"
    return chat_id

def test_send_message(chat_id):
    """Test sending a message via cursor-agent"""
    print_section("Test 3: Send Message (Async)")
    
    # Submit async job
    response = requests.post(
        f"{BASE_URL}/chats/{chat_id}/agent-prompt-async",
        json={
            "prompt": "Say 'Hello from Blink!' and nothing else",
            "model": "gpt-5"
        }
    )
    data = response.json()
    job_id = data['job_id']
    
    print(f"✓ Job submitted: {job_id}")
    print(f"  Status: {data['status']}")
    
    # Poll for completion
    print("\n  Polling for completion...")
    max_attempts = 60  # 60 seconds max
    for attempt in range(max_attempts):
        time.sleep(1)
        status_response = requests.get(f"{BASE_URL}/jobs/{job_id}/status")
        status = status_response.json()
        
        print(f"    Attempt {attempt + 1}: {status['status']}", end='\r')
        
        if status['status'] in ['completed', 'failed']:
            print()  # New line
            break
    
    # Get full job details
    job_response = requests.get(f"{BASE_URL}/jobs/{job_id}")
    job = job_response.json()
    
    print(f"\n✓ Job completed: {job['status']}")
    if job['status'] == 'completed':
        print(f"✓ AI Response: {job['result'][:100]}...")
    else:
        print(f"✗ Error: {job.get('error', 'Unknown error')}")
        return False
    
    # Check database stats
    health = requests.get(f"{BASE_URL}/health").json()
    print(f"✓ Total messages now: {health['stats']['total_messages']}")
    
    assert health['stats']['total_messages'] > 0
    return True

def test_list_chats():
    """Test listing chats"""
    print_section("Test 4: List Chats")
    response = requests.get(f"{BASE_URL}/chats")
    data = response.json()
    
    print(f"✓ Found {len(data['chats'])} chat(s)")
    
    for chat in data['chats']:
        print(f"  - {chat['chat_id']}")
        print(f"    Name: {chat['name']}")
        print(f"    Messages: {chat['message_count']}")
    
    assert len(data['chats']) > 0
    return True

def test_get_chat_details(chat_id):
    """Test getting chat details"""
    print_section("Test 5: Get Chat Details")
    response = requests.get(f"{BASE_URL}/chats/{chat_id}")
    data = response.json()
    
    print(f"✓ Chat ID: {data['chat_id']}")
    print(f"✓ Name: {data.get('metadata', {}).get('name', 'N/A')}")
    print(f"✓ Messages: {data['message_count']}")
    
    for i, msg in enumerate(data['messages'], 1):
        role = msg['type_label']
        preview = msg['text'][:60] + "..." if len(msg['text']) > 60 else msg['text']
        print(f"  {i}. [{role}] {preview}")
    
    assert len(data['messages']) >= 2  # User + Assistant
    return True

def main():
    """Run all tests"""
    print("\n")
    print("╔" + "═" * 78 + "╗")
    print("║" + " " * 20 + "BLINK STANDALONE SYSTEM TEST" + " " * 30 + "║")
    print("╚" + "═" * 78 + "╝")
    
    try:
        # Test 1: Health check
        test_health()
        
        # Get initial count
        initial_health = requests.get(f"{BASE_URL}/health").json()
        initial_count = initial_health['stats']['total_chats']
        
        # Test 2: Create chat
        chat_id = test_create_chat(initial_count)
        
        # Test 3: Send message
        success = test_send_message(chat_id)
        if not success:
            print("\n✗ Message sending failed!")
            return False
        
        # Test 4: List chats
        test_list_chats()
        
        # Test 5: Get chat details
        test_get_chat_details(chat_id)
        
        print_section("ALL TESTS PASSED! ✓")
        print("\n✓ Standalone system is working correctly!")
        print("✓ Backend database is operational")
        print("✓ cursor-agent integration is functional")
        print("✓ No dependency on Cursor IDE")
        print("\n")
        return True
        
    except Exception as e:
        print(f"\n\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    exit(0 if main() else 1)

