#!/usr/bin/env python3
"""
Integration Tests for Existing Chat Continuation

Tests the complete workflow of continuing existing Cursor chats via REST API.
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"
TIMEOUT = 30

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def test_list_existing_chats():
    """Test 1: List existing chats"""
    print_section("TEST 1: List Existing Chats")
    
    response = requests.get(f"{BASE_URL}/chats?limit=5", timeout=TIMEOUT)
    assert response.status_code == 200, f"Failed to list chats: {response.status_code}"
    
    data = response.json()
    assert "chats" in data, "Response missing 'chats' field"
    assert len(data["chats"]) > 0, "No chats found in database"
    
    print(f"✓ Found {data['total']} total chats")
    print(f"✓ Returned first {len(data['chats'])} chats")
    
    # Return first chat for further testing
    return data["chats"][0]["chat_id"]

def test_get_chat_summary(chat_id):
    """Test 2: Get chat summary"""
    print_section("TEST 2: Get Chat Summary")
    
    response = requests.get(
        f"{BASE_URL}/chats/{chat_id}/summary?recent_count=3",
        timeout=TIMEOUT
    )
    assert response.status_code == 200, f"Failed to get summary: {response.status_code}"
    
    data = response.json()
    required_fields = ["chat_id", "name", "message_count", "recent_messages", "can_continue"]
    for field in required_fields:
        assert field in data, f"Summary missing field: {field}"
    
    print(f"✓ Chat Name: {data['name']}")
    print(f"✓ Message Count: {data['message_count']}")
    print(f"✓ Recent Messages: {len(data['recent_messages'])}")
    print(f"✓ Can Continue: {data['can_continue']}")
    
    return data

def test_view_full_history(chat_id):
    """Test 3: View full chat history"""
    print_section("TEST 3: View Full Chat History")
    
    response = requests.get(
        f"{BASE_URL}/chats/{chat_id}?limit=10",
        timeout=TIMEOUT
    )
    assert response.status_code == 200, f"Failed to get history: {response.status_code}"
    
    data = response.json()
    assert "messages" in data, "Response missing 'messages' field"
    
    print(f"✓ Retrieved {data['message_count']} messages")
    if data["messages"]:
        print(f"✓ Last message preview: {data['messages'][-1]['text'][:100]}...")
    
    return data["messages"]

def test_continue_conversation(chat_id):
    """Test 4: Continue existing conversation"""
    print_section("TEST 4: Continue Existing Conversation")
    
    prompt = "Based on our previous discussion, can you provide a brief summary?"
    
    response = requests.post(
        f"{BASE_URL}/chats/{chat_id}/agent-prompt",
        json={
            "prompt": prompt,
            "output_format": "text"
        },
        timeout=TIMEOUT
    )
    
    assert response.status_code == 200, f"Failed to continue: {response.status_code}"
    
    data = response.json()
    assert data["status"] == "success", "Request failed"
    assert "response" in data, "Missing response field"
    assert len(data["response"]) > 0, "Empty response"
    
    print(f"✓ Prompt sent successfully")
    print(f"✓ Response length: {len(data['response'])} characters")
    print(f"✓ Response preview: {data['response'][:200]}...")
    
    return data

def test_continue_with_context_preview(chat_id):
    """Test 5: Continue with context preview"""
    print_section("TEST 5: Continue with Context Preview")
    
    response = requests.post(
        f"{BASE_URL}/chats/{chat_id}/agent-prompt?show_context=true",
        json={
            "prompt": "What was the main topic we discussed?",
            "output_format": "text",
            "max_history_messages": 5
        },
        timeout=TIMEOUT
    )
    
    assert response.status_code == 200, f"Failed: {response.status_code}"
    
    data = response.json()
    assert "context" in data, "Missing context field"
    assert "recent_messages" in data["context"], "Missing recent_messages in context"
    
    print(f"✓ Context included in response")
    print(f"✓ Context message count: {data['context']['message_count']}")
    print(f"✓ Recent messages: {len(data['context']['recent_messages'])}")
    print(f"✓ Chat name: {data['context']['chat_name']}")
    
    return data

def test_batch_chat_info():
    """Test 6: Get batch chat info"""
    print_section("TEST 6: Batch Chat Info")
    
    # First get some chat IDs
    chats_response = requests.get(f"{BASE_URL}/chats?limit=3", timeout=TIMEOUT)
    chats = chats_response.json()["chats"]
    chat_ids = [chat["chat_id"] for chat in chats]
    
    # Add an invalid ID
    chat_ids.append("invalid-uuid-12345")
    
    response = requests.post(
        f"{BASE_URL}/chats/batch-info",
        json=chat_ids,
        timeout=TIMEOUT
    )
    
    assert response.status_code == 200, f"Failed: {response.status_code}"
    
    data = response.json()
    assert "chats" in data, "Missing chats field"
    assert "not_found" in data, "Missing not_found field"
    assert len(data["not_found"]) == 1, "Should have 1 not found chat"
    
    print(f"✓ Requested: {data['total_requested']} chats")
    print(f"✓ Found: {data['total_found']} chats")
    print(f"✓ Not found: {len(data['not_found'])} chats")
    
    return data

def test_multi_turn_continuation(chat_id):
    """Test 7: Multi-turn conversation continuation"""
    print_section("TEST 7: Multi-Turn Continuation")
    
    # Turn 1
    print("\nTurn 1: Establishing context...")
    response1 = requests.post(
        f"{BASE_URL}/chats/{chat_id}/agent-prompt",
        json={"prompt": "Let's discuss Python programming.", "output_format": "text"},
        timeout=TIMEOUT
    )
    assert response1.status_code == 200
    print(f"✓ Turn 1 completed: {response1.json()['response'][:100]}...")
    
    time.sleep(1)
    
    # Turn 2
    print("\nTurn 2: Building on context...")
    response2 = requests.post(
        f"{BASE_URL}/chats/{chat_id}/agent-prompt",
        json={"prompt": "What did we just start discussing?", "output_format": "text"},
        timeout=TIMEOUT
    )
    assert response2.status_code == 200
    response_text = response2.json()['response'].lower()
    
    # Verify context was maintained
    assert "python" in response_text, "Context not maintained across turns"
    print(f"✓ Turn 2 completed with context: {response2.json()['response'][:100]}...")
    print("✓ Context successfully maintained!")
    
    return True

def test_error_handling():
    """Test 8: Error handling"""
    print_section("TEST 8: Error Handling")
    
    # Test invalid chat ID
    response = requests.get(
        f"{BASE_URL}/chats/invalid-uuid-99999/summary",
        timeout=TIMEOUT
    )
    assert response.status_code == 404, "Should return 404 for invalid chat"
    print("✓ Correctly handles invalid chat ID")
    
    # Test missing prompt
    response = requests.post(
        f"{BASE_URL}/chats/some-id/agent-prompt",
        json={},
        timeout=TIMEOUT
    )
    assert response.status_code == 422, "Should return 422 for missing prompt"
    print("✓ Correctly validates required fields")
    
    return True

def main():
    """Run all integration tests"""
    print("\n" + "█" * 70)
    print("  EXISTING CHAT INTEGRATION TESTS")
    print("█" * 70)
    
    try:
        # Phase 1: Discovery
        chat_id = test_list_existing_chats()
        
        # Phase 2: Inspection
        summary = test_get_chat_summary(chat_id)
        messages = test_view_full_history(chat_id)
        
        # Phase 3: Continuation
        response1 = test_continue_conversation(chat_id)
        response2 = test_continue_with_context_preview(chat_id)
        
        # Phase 4: Batch Operations
        batch_info = test_batch_chat_info()
        
        # Phase 5: Advanced Scenarios
        multi_turn = test_multi_turn_continuation(chat_id)
        errors = test_error_handling()
        
        # Summary
        print_section("TEST SUMMARY")
        print("✅ All integration tests PASSED!")
        print(f"\nTested Chat: {chat_id}")
        print(f"Chat Name: {summary['name']}")
        print(f"Total Messages: {summary['message_count']}")
        print("\n✓ List existing chats")
        print("✓ Get chat summary")
        print("✓ View full history")
        print("✓ Continue conversation")
        print("✓ Continue with context preview")
        print("✓ Batch chat info")
        print("✓ Multi-turn continuation")
        print("✓ Error handling")
        
        print("\n" + "=" * 70)
        print("  INTEGRATION COMPLETE ✓")
        print("=" * 70 + "\n")
        
        return 0
        
    except AssertionError as e:
        print(f"\n❌ TEST FAILED: {e}")
        return 1
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())

