#!/usr/bin/env python3
"""
Comprehensive tests for POST /chats/batch-info endpoint
Tests batch operations for retrieving multiple chat summaries
"""

import pytest
import requests
import time
from typing import List

BASE_URL = "http://localhost:8000"
TIMEOUT = 30


class TestBatchInfoEndpoint:
    """Test suite for batch info endpoint"""
    
    @pytest.fixture(scope="class")
    def chat_ids(self) -> List[str]:
        """Get multiple chat IDs for testing"""
        response = requests.get(f"{BASE_URL}/chats?limit=5", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            ids = [chat['chat_id'] for chat in data['chats'][:5]]
            if ids:
                return ids
        pytest.skip("No chats available for testing")
    
    def test_batch_request_valid_ids(self, chat_ids):
        """Test batch request with valid chat IDs"""
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=chat_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert 'total_found' in data
        assert data['total_found'] > 0
        print(f"Found {data['total_found']} chats")
    
    def test_batch_mixed_valid_invalid(self, chat_ids):
        """Test batch request with mix of valid/invalid IDs"""
        mixed_ids = [
            chat_ids[0],
            "00000000-0000-0000-0000-000000000000",
            "invalid-id-12345"
        ]
        
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=mixed_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data['total_found'] == 1, "Should find 1 valid chat"
        assert len(data['not_found']) == 2, "Should have 2 invalid IDs"
    
    def test_batch_all_invalid(self):
        """Test batch request with all invalid IDs"""
        invalid_ids = [
            "00000000-0000-0000-0000-000000000000",
            "11111111-1111-1111-1111-111111111111"
        ]
        
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=invalid_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data['total_found'] == 0, "Should find 0 chats"
        assert len(data['not_found']) == 2, "Should have 2 invalid IDs"
    
    def test_batch_empty_array(self):
        """Test empty array request"""
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=[],
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['total_found'] == 0, "Should find 0 chats"
    
    def test_response_structure(self, chat_ids):
        """Test response includes all required fields"""
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=chat_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        required_fields = ['chats', 'not_found', 'total_requested', 'total_found']
        for field in required_fields:
            assert field in data, f"Field '{field}' should be present"
    
    def test_duplicate_chat_ids(self, chat_ids):
        """Test duplicate chat IDs in request"""
        dup_ids = [chat_ids[0], chat_ids[0], chat_ids[0]]
        
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=dup_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['total_requested'] == 3, "Should count all 3 requests"
    
    def test_response_time(self, chat_ids):
        """Test response time for batch operations"""
        start = time.time()
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=chat_ids,
            timeout=TIMEOUT
        )
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 5.0, \
            f"Response should be under 5s, got {duration:.2f}s"
        
        print(f"Response time: {duration:.2f}s (target: <5s)")
    
    def test_chat_metadata_complete(self, chat_ids):
        """Test each chat includes required metadata"""
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=chat_ids,
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        if data['chats']:
            chat = data['chats'][0]
            required_fields = [
                'chat_id', 'name', 'message_count', 
                'created_at', 'last_updated'
            ]
            for field in required_fields:
                assert field in chat, f"Chat should have '{field}' field"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])

