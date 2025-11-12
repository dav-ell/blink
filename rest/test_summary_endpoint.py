#!/usr/bin/env python3
"""
Comprehensive tests for GET /chats/{chat_id}/summary endpoint

Tests all aspects of the summary endpoint including:
- Valid requests
- Required fields
- Recent message counts
- Error conditions
- Edge cases
"""

import pytest
import requests
import time
from typing import Optional

BASE_URL = "http://localhost:8000"
TIMEOUT = 30


class TestSummaryEndpoint:
    """Test suite for summary endpoint"""
    
    @pytest.fixture(scope="class")
    def valid_chat_id(self) -> Optional[str]:
        """Get a valid chat ID for testing"""
        response = requests.get(f"{BASE_URL}/chats?limit=1", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            if data.get('chats'):
                return data['chats'][0]['chat_id']
        pytest.skip("No chats available for testing")
    
    def test_get_summary_valid_chat(self, valid_chat_id):
        """Test getting summary for a valid chat"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        data = response.json()
        print(f"Got summary for chat: {data.get('name', 'Unknown')}")
    
    def test_summary_required_fields(self, valid_chat_id):
        """Test that summary includes all required fields"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        required_fields = [
            'chat_id', 'name', 'message_count', 'recent_messages',
            'can_continue', 'created_at', 'last_updated'
        ]
        
        for field in required_fields:
            assert field in data, f"Field '{field}' should be present"
        
        print(f"All {len(required_fields)} required fields present")
    
    @pytest.mark.parametrize("count", [1, 3, 5])
    def test_recent_messages_count(self, valid_chat_id, count):
        """Test that recent_count parameter works"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary?recent_count={count}",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        actual_count = len(data['recent_messages'])
        
        assert actual_count <= count, \
            f"Should have at most {count} messages, got {actual_count}"
        
        print(f"recent_count={count} returned {actual_count} messages")
    
    def test_messages_chronological_order(self, valid_chat_id):
        """Test that messages are in chronological order"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary?recent_count=5",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        messages = data['recent_messages']
        
        if len(messages) > 1:
            timestamps = [m.get('created_at') for m in messages if m.get('created_at')]
            if timestamps:
                # Messages should be ordered (oldest to newest)
                is_ordered = all(
                    timestamps[i] <= timestamps[i+1] 
                    for i in range(len(timestamps)-1)
                )
                assert is_ordered, "Messages should be chronologically ordered"
                print(f"{len(messages)} messages correctly ordered")
        else:
            pytest.skip("Not enough messages to verify order")
    
    def test_invalid_chat_id_404(self):
        """Test that invalid chat ID returns 404"""
        invalid_id = "00000000-0000-0000-0000-000000000000"
        response = requests.get(
            f"{BASE_URL}/chats/{invalid_id}/summary",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 404, \
            f"Should return 404 for invalid chat, got {response.status_code}"
    
    def test_recent_count_zero(self, valid_chat_id):
        """Test recent_count=0 returns no messages"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary?recent_count=0",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data['recent_messages']) == 0, "Should return 0 messages"
    
    def test_recent_count_large(self, valid_chat_id):
        """Test large recent_count value"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary?recent_count=100",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data['recent_messages']) <= 100, \
            "Should return at most 100 messages"
        
        print(f"Large recent_count returned {len(data['recent_messages'])} messages")
    
    def test_content_flags(self, valid_chat_id):
        """Test has_code, has_todos flags"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert 'has_code' in data, "Should have has_code field"
        assert 'has_todos' in data, "Should have has_todos field"
        assert isinstance(data['has_code'], bool), "has_code should be boolean"
        assert isinstance(data['has_todos'], bool), "has_todos should be boolean"
        
        print(f"Flags present: has_code={data['has_code']}, has_todos={data['has_todos']}")
    
    def test_can_continue_field(self, valid_chat_id):
        """Test can_continue field is present and true"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert 'can_continue' in data, "Should have can_continue field"
        assert data['can_continue'] is True, "All chats should be continuable"
    
    def test_response_time(self, valid_chat_id):
        """Test response time is acceptable"""
        start = time.time()
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            timeout=TIMEOUT
        )
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 2.0, \
            f"Response should be under 2s, got {duration:.2f}s"
        
        print(f"Response time: {duration:.2f}s (target: <2s)")


if __name__ == "__main__":
    # Run with pytest
    pytest.main([__file__, "-v", "--tb=short"])
