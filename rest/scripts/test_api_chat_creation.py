#!/usr/bin/env python3
"""
Test chat creation via API with new complete bubble structure.
This verifies that chats created by the API can now be loaded in Cursor IDE.
"""

import requests
import time
import sys

BASE_URL = "http://localhost:8000"

def test_api_availability():
    """Test if API is running"""
    print("=" * 80)
    print("TESTING API AVAILABILITY")
    print("=" * 80)
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ API is running")
            print(f"  Total chats: {data.get('total_chats', 'N/A')}")
            print(f"  Total messages: {data.get('total_messages', 'N/A')}")
            return True
        else:
            print(f"❌ API returned status code: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Could not connect to API: {e}")
        print("\nPlease start the API server first:")
        print("  cd rest && ./start_api.sh")
        return False

def test_create_chat():
    """Test creating a new chat"""
    print("\n" + "=" * 80)
    print("TESTING CHAT CREATION")
    print("=" * 80)
    
    try:
        response = requests.post(f"{BASE_URL}/agent/create-chat", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            chat_id = data.get('chat_id')
            print(f"✓ Created new chat: {chat_id}")
            return chat_id
        else:
            print(f"❌ Failed to create chat: {response.status_code}")
            print(f"   Response: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error creating chat: {e}")
        return None

def test_send_message(chat_id, prompt, test_number):
    """Test sending a message to a chat"""
    print(f"\n  Test {test_number}: Sending message...")
    
    try:
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": prompt,
                "output_format": "text"
            },
            timeout=60
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"  ✓ Message sent successfully")
            print(f"    User bubble: {data.get('user_bubble_id', 'N/A')[:8]}...")
            print(f"    Assistant bubble: {data.get('assistant_bubble_id', 'N/A')[:8]}...")
            print(f"    Response length: {len(data.get('response', ''))} chars")
            return True
        else:
            print(f"  ❌ Failed to send message: {response.status_code}")
            print(f"     Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"  ❌ Error sending message: {e}")
        return False

def test_complete_workflow():
    """Test complete workflow: create chat + multiple messages"""
    print("\n" + "=" * 80)
    print("TESTING COMPLETE WORKFLOW")
    print("=" * 80)
    
    # Create chat
    chat_id = test_create_chat()
    if not chat_id:
        return False
    
    # Wait for cursor-agent to finish writing to database
    print("\n  Waiting for chat to be available in database...")
    time.sleep(3)
    
    # Send multiple messages to build conversation
    tests = [
        "Hello! This is a test message to verify the API works correctly.",
        "Can you remember what I just said?",
        "What did I say in my first message?"
    ]
    
    print("\n  Sending test messages...")
    for i, prompt in enumerate(tests, 1):
        success = test_send_message(chat_id, prompt, i)
        if not success:
            print(f"\n❌ Test {i} failed")
            return False
        time.sleep(2)
    
    return chat_id

def verify_in_database(chat_id):
    """Verify chat exists in database with proper structure"""
    print("\n" + "=" * 80)
    print("VERIFYING CHAT IN DATABASE")
    print("=" * 80)
    
    try:
        # Get chat metadata
        response = requests.get(f"{BASE_URL}/chats/{chat_id}/metadata", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Chat metadata found")
            print(f"  Name: {data.get('name', 'N/A')}")
            print(f"  Messages: {data.get('message_count', 0)}")
            print(f"  Created: {data.get('created_at_iso', 'N/A')}")
        
        # Get messages
        response = requests.get(f"{BASE_URL}/chats/{chat_id}?limit=10", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Retrieved {data.get('message_count', 0)} messages")
            return True
        else:
            print(f"❌ Failed to retrieve messages: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error verifying in database: {e}")
        return False

def main():
    """Run all tests"""
    print("\n" + "█" * 80)
    print("  API CHAT CREATION TEST")
    print("  Testing new complete bubble structure")
    print("█" * 80 + "\n")
    
    # Test 1: API availability
    if not test_api_availability():
        return 1
    
    time.sleep(1)
    
    # Test 2: Complete workflow
    chat_id = test_complete_workflow()
    if not chat_id:
        print("\n❌ Workflow test FAILED")
        return 1
    
    time.sleep(1)
    
    # Test 3: Database verification
    if not verify_in_database(chat_id):
        print("\n❌ Database verification FAILED")
        return 1
    
    # Success!
    print("\n" + "=" * 80)
    print("✅ ALL TESTS PASSED")
    print("=" * 80)
    
    print(f"\n📝 Test Chat Created: {chat_id}")
    print("\n🔍 MANUAL VERIFICATION REQUIRED:")
    print("   1. Open Cursor IDE")
    print("   2. Open the Composer/Chat panel")
    print("   3. Look for a chat with recent timestamp")
    print("   4. Try to open it - it should load without errors")
    print("   5. Verify you can see the test messages")
    print("\n   If the chat loads successfully, the fix is working! ✨")
    
    print("\n" + "=" * 80)
    print("TEST COMPLETE")
    print("=" * 80 + "\n")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

