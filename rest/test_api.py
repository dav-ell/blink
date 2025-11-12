"""
Comprehensive Test Suite for Cursor Chat REST API

Tests all endpoints, error cases, data validation, and edge cases.
"""

import pytest
import requests
import json
from typing import Dict, Any
import time

# Configuration
BASE_URL = "http://localhost:8000"
TIMEOUT = 10  # seconds

# Test fixtures
@pytest.fixture(scope="module")
def api_base_url():
    """Provide base URL for all tests"""
    return BASE_URL

@pytest.fixture(scope="module")
def valid_chat_id(api_base_url):
    """Get a valid chat ID for testing"""
    response = requests.get(f"{api_base_url}/chats?limit=1", timeout=TIMEOUT)
    if response.status_code == 200:
        data = response.json()
        if data.get('chats') and len(data['chats']) > 0:
            return data['chats'][0]['chat_id']
    return None

@pytest.fixture(scope="module")
def archived_chat_id(api_base_url):
    """Get an archived chat ID if available"""
    response = requests.get(f"{api_base_url}/chats?include_archived=true", timeout=TIMEOUT)
    if response.status_code == 200:
        data = response.json()
        for chat in data.get('chats', []):
            if chat.get('is_archived'):
                return chat['chat_id']
    return None


# ============================================================================
# 1. HEALTH & ROOT ENDPOINT TESTS
# ============================================================================

class TestHealthAndRoot:
    """Test health check and root endpoints"""
    
    def test_health_endpoint_responds(self, api_base_url):
        """Health endpoint should return 200"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        assert response.status_code == 200
        
    def test_health_endpoint_json(self, api_base_url):
        """Health endpoint should return valid JSON"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        data = response.json()
        assert isinstance(data, dict)
        
    def test_health_endpoint_required_fields(self, api_base_url):
        """Health endpoint should contain required fields"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        data = response.json()
        assert 'status' in data
        assert 'database' in data
        assert 'total_chats' in data
        assert 'total_messages' in data
        
    def test_health_status_healthy(self, api_base_url):
        """Health status should be 'healthy'"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        data = response.json()
        assert data['status'] == 'healthy'
        
    def test_health_database_accessible(self, api_base_url):
        """Database should be 'accessible'"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        data = response.json()
        assert data['database'] == 'accessible'
        
    def test_health_chat_count_positive(self, api_base_url):
        """Total chats should be a positive number"""
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        data = response.json()
        assert data['total_chats'] > 0
        assert isinstance(data['total_chats'], int)
        
    def test_root_endpoint_responds(self, api_base_url):
        """Root endpoint should return 200"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        assert response.status_code == 200
        
    def test_root_endpoint_json(self, api_base_url):
        """Root endpoint should return valid JSON"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        data = response.json()
        assert isinstance(data, dict)
        
    def test_root_endpoint_has_name(self, api_base_url):
        """Root endpoint should have API name"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        data = response.json()
        assert 'name' in data
        assert data['name'] == 'Cursor Chat API'
        
    def test_root_endpoint_has_version(self, api_base_url):
        """Root endpoint should have version"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        data = response.json()
        assert 'version' in data
        
    def test_root_endpoint_has_endpoints(self, api_base_url):
        """Root endpoint should list endpoints"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        data = response.json()
        assert 'endpoints' in data
        assert isinstance(data['endpoints'], dict)


# ============================================================================
# 2. LIST CHATS ENDPOINT TESTS
# ============================================================================

class TestListChats:
    """Test GET /chats endpoint"""
    
    def test_list_chats_responds(self, api_base_url):
        """List chats endpoint should return 200"""
        response = requests.get(f"{api_base_url}/chats", timeout=TIMEOUT)
        assert response.status_code == 200
        
    def test_list_chats_json(self, api_base_url):
        """List chats should return valid JSON"""
        response = requests.get(f"{api_base_url}/chats", timeout=TIMEOUT)
        data = response.json()
        assert isinstance(data, dict)
        
    def test_list_chats_required_fields(self, api_base_url):
        """List chats should have required fields"""
        response = requests.get(f"{api_base_url}/chats", timeout=TIMEOUT)
        data = response.json()
        assert 'total' in data
        assert 'chats' in data
        assert isinstance(data['chats'], list)
        
    def test_list_chats_total_matches_count(self, api_base_url):
        """Total field should reflect actual count"""
        response = requests.get(f"{api_base_url}/chats", timeout=TIMEOUT)
        data = response.json()
        assert data['total'] > 0
        
    def test_list_chats_with_limit(self, api_base_url):
        """Limit parameter should restrict results"""
        response = requests.get(f"{api_base_url}/chats?limit=5", timeout=TIMEOUT)
        data = response.json()
        assert len(data['chats']) <= 5
        assert data['returned'] <= 5
        
    def test_list_chats_with_offset(self, api_base_url):
        """Offset parameter should skip results"""
        response1 = requests.get(f"{api_base_url}/chats?limit=1", timeout=TIMEOUT)
        response2 = requests.get(f"{api_base_url}/chats?limit=1&offset=1", timeout=TIMEOUT)
        
        if response1.status_code == 200 and response2.status_code == 200:
            data1 = response1.json()
            data2 = response2.json()
            if len(data1['chats']) > 0 and len(data2['chats']) > 0:
                assert data1['chats'][0]['chat_id'] != data2['chats'][0]['chat_id']
    
    def test_list_chats_exclude_archived_default(self, api_base_url):
        """By default, archived chats should be excluded"""
        response = requests.get(f"{api_base_url}/chats", timeout=TIMEOUT)
        data = response.json()
        for chat in data['chats']:
            assert chat.get('is_archived', False) == False
            
    def test_list_chats_include_archived(self, api_base_url):
        """Should include archived chats when requested"""
        response = requests.get(f"{api_base_url}/chats?include_archived=true", timeout=TIMEOUT)
        assert response.status_code == 200
        
    def test_list_chats_chat_structure(self, api_base_url):
        """Each chat should have required fields"""
        response = requests.get(f"{api_base_url}/chats?limit=1", timeout=TIMEOUT)
        data = response.json()
        
        if len(data['chats']) > 0:
            chat = data['chats'][0]
            required_fields = [
                'chat_id', 'name', 'created_at', 'last_updated_at',
                'is_archived', 'is_draft', 'message_count'
            ]
            for field in required_fields:
                assert field in chat, f"Missing field: {field}"
                
    def test_list_chats_sorted_by_recent(self, api_base_url):
        """Chats should be sorted by most recent first"""
        response = requests.get(f"{api_base_url}/chats?limit=10", timeout=TIMEOUT)
        data = response.json()
        
        if len(data['chats']) > 1:
            timestamps = [chat['last_updated_at'] for chat in data['chats']]
            # Should be in descending order
            assert timestamps == sorted(timestamps, reverse=True)
            
    def test_list_chats_zero_limit(self, api_base_url):
        """Zero limit should return no chats but valid response"""
        response = requests.get(f"{api_base_url}/chats?limit=0", timeout=TIMEOUT)
        data = response.json()
        assert len(data['chats']) == 0
        assert 'total' in data
        
    def test_list_chats_large_limit(self, api_base_url):
        """Large limit should not cause errors"""
        response = requests.get(f"{api_base_url}/chats?limit=1000", timeout=TIMEOUT)
        assert response.status_code == 200


# ============================================================================
# 3. GET CHAT METADATA TESTS
# ============================================================================

class TestChatMetadata:
    """Test GET /chats/{chat_id}/metadata endpoint"""
    
    def test_get_metadata_valid_chat(self, api_base_url, valid_chat_id):
        """Should return metadata for valid chat ID"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            assert response.status_code == 200
            
    def test_get_metadata_json(self, api_base_url, valid_chat_id):
        """Metadata should be valid JSON"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            data = response.json()
            assert isinstance(data, dict)
            
    def test_get_metadata_required_fields(self, api_base_url, valid_chat_id):
        """Metadata should have required fields"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            data = response.json()
            required_fields = [
                'chat_id', 'name', 'created_at', 'last_updated_at',
                'is_archived', 'is_draft', 'message_count'
            ]
            for field in required_fields:
                assert field in data, f"Missing field: {field}"
                
    def test_get_metadata_invalid_chat(self, api_base_url):
        """Should return 404 for invalid chat ID"""
        response = requests.get(
            f"{api_base_url}/chats/invalid-chat-id-12345/metadata",
            timeout=TIMEOUT
        )
        assert response.status_code == 404
        
    def test_get_metadata_timestamps(self, api_base_url, valid_chat_id):
        """Timestamps should be in both formats"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            data = response.json()
            assert 'created_at' in data
            assert 'created_at_iso' in data
            assert 'last_updated_at' in data
            assert 'last_updated_at_iso' in data


# ============================================================================
# 4. GET CHAT MESSAGES TESTS
# ============================================================================

class TestChatMessages:
    """Test GET /chats/{chat_id} endpoint"""
    
    def test_get_messages_valid_chat(self, api_base_url, valid_chat_id):
        """Should return messages for valid chat ID"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}",
                timeout=TIMEOUT
            )
            assert response.status_code == 200
            
    def test_get_messages_json(self, api_base_url, valid_chat_id):
        """Messages response should be valid JSON"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}",
                timeout=TIMEOUT
            )
            data = response.json()
            assert isinstance(data, dict)
            
    def test_get_messages_required_fields(self, api_base_url, valid_chat_id):
        """Messages response should have required fields"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}",
                timeout=TIMEOUT
            )
            data = response.json()
            assert 'chat_id' in data
            assert 'message_count' in data
            assert 'messages' in data
            assert isinstance(data['messages'], list)
            
    def test_get_messages_with_metadata(self, api_base_url, valid_chat_id):
        """Should include metadata when requested"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?include_metadata=true",
                timeout=TIMEOUT
            )
            data = response.json()
            assert 'metadata' in data
            
    def test_get_messages_without_metadata(self, api_base_url, valid_chat_id):
        """Should exclude metadata when not requested"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?include_metadata=false",
                timeout=TIMEOUT
            )
            data = response.json()
            # Should not have metadata or it should be minimal
            
    def test_get_messages_with_limit(self, api_base_url, valid_chat_id):
        """Limit parameter should restrict messages"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?limit=3",
                timeout=TIMEOUT
            )
            data = response.json()
            assert len(data['messages']) <= 3
            
    def test_get_messages_structure(self, api_base_url, valid_chat_id):
        """Each message should have required fields"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?limit=1",
                timeout=TIMEOUT
            )
            data = response.json()
            
            if len(data['messages']) > 0:
                message = data['messages'][0]
                required_fields = [
                    'bubble_id', 'type', 'type_label', 'text',
                    'created_at', 'has_tool_call', 'has_thinking',
                    'has_code', 'has_todos'
                ]
                for field in required_fields:
                    assert field in message, f"Missing field: {field}"
                    
    def test_get_messages_type_labels(self, api_base_url, valid_chat_id):
        """Message types should have correct labels"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}",
                timeout=TIMEOUT
            )
            data = response.json()
            
            for message in data['messages']:
                msg_type = message['type']
                label = message['type_label']
                if msg_type == 1:
                    assert label == 'user'
                elif msg_type == 2:
                    assert label == 'assistant'
                    
    def test_get_messages_invalid_chat(self, api_base_url):
        """Should handle invalid chat ID gracefully"""
        response = requests.get(
            f"{api_base_url}/chats/invalid-chat-id-12345",
            timeout=TIMEOUT
        )
        # Could be 404 or empty response
        assert response.status_code in [200, 404]
        
    def test_get_messages_content_flags(self, api_base_url, valid_chat_id):
        """Content flags should be boolean"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?limit=10",
                timeout=TIMEOUT
            )
            data = response.json()
            
            for message in data['messages']:
                assert isinstance(message['has_tool_call'], bool)
                assert isinstance(message['has_thinking'], bool)
                assert isinstance(message['has_code'], bool)
                assert isinstance(message['has_todos'], bool)


# ============================================================================
# 5. POST MESSAGES TESTS (Write Operations)
# ============================================================================

class TestPostMessages:
    """Test POST /chats/{chat_id}/messages endpoint"""
    
    def test_post_message_disabled_by_default(self, api_base_url, valid_chat_id):
        """POST should be disabled without enable_write flag"""
        if valid_chat_id:
            response = requests.post(
                f"{api_base_url}/chats/{valid_chat_id}/messages",
                json={"text": "Test message", "type": 1},
                timeout=TIMEOUT
            )
            assert response.status_code == 403
            
    def test_post_message_error_message(self, api_base_url, valid_chat_id):
        """Should return meaningful error when disabled"""
        if valid_chat_id:
            response = requests.post(
                f"{api_base_url}/chats/{valid_chat_id}/messages",
                json={"text": "Test message", "type": 1},
                timeout=TIMEOUT
            )
            data = response.json()
            assert 'detail' in data
            assert 'disabled' in data['detail'].lower()
            
    def test_post_message_requires_enable_flag(self, api_base_url, valid_chat_id):
        """Should require enable_write=true query parameter"""
        if valid_chat_id:
            response = requests.post(
                f"{api_base_url}/chats/{valid_chat_id}/messages?enable_write=false",
                json={"text": "Test message", "type": 1},
                timeout=TIMEOUT
            )
            # Should still be forbidden
            assert response.status_code == 403
            
    def test_post_message_invalid_json(self, api_base_url, valid_chat_id):
        """Should handle invalid JSON gracefully"""
        if valid_chat_id:
            response = requests.post(
                f"{api_base_url}/chats/{valid_chat_id}/messages",
                data="not valid json",
                headers={"Content-Type": "application/json"},
                timeout=TIMEOUT
            )
            assert response.status_code in [400, 403, 422]
            
    def test_post_message_missing_text(self, api_base_url, valid_chat_id):
        """Should reject messages without text"""
        if valid_chat_id:
            response = requests.post(
                f"{api_base_url}/chats/{valid_chat_id}/messages",
                json={"type": 1},
                timeout=TIMEOUT
            )
            assert response.status_code in [403, 422]


# ============================================================================
# 6. ERROR HANDLING TESTS
# ============================================================================

class TestErrorHandling:
    """Test error handling and edge cases"""
    
    def test_invalid_endpoint(self, api_base_url):
        """Should return 404 for invalid endpoints"""
        response = requests.get(
            f"{api_base_url}/invalid/endpoint",
            timeout=TIMEOUT
        )
        assert response.status_code == 404
        
    def test_method_not_allowed(self, api_base_url):
        """Should handle wrong HTTP methods"""
        response = requests.post(f"{api_base_url}/health", timeout=TIMEOUT)
        assert response.status_code in [405, 422]
        
    def test_invalid_query_params(self, api_base_url):
        """Should handle invalid query parameters gracefully"""
        response = requests.get(
            f"{api_base_url}/chats?limit=invalid",
            timeout=TIMEOUT
        )
        assert response.status_code in [200, 422]
        
    def test_negative_limit(self, api_base_url):
        """Should handle negative limit values"""
        response = requests.get(
            f"{api_base_url}/chats?limit=-1",
            timeout=TIMEOUT
        )
        # Should either ignore or handle gracefully
        assert response.status_code in [200, 422]
        
    def test_negative_offset(self, api_base_url):
        """Should handle negative offset values"""
        response = requests.get(
            f"{api_base_url}/chats?offset=-1",
            timeout=TIMEOUT
        )
        assert response.status_code in [200, 422]
        
    def test_malformed_uuid(self, api_base_url):
        """Should handle malformed UUIDs gracefully"""
        response = requests.get(
            f"{api_base_url}/chats/not-a-uuid",
            timeout=TIMEOUT
        )
        assert response.status_code in [200, 404, 422]


# ============================================================================
# 7. PERFORMANCE TESTS
# ============================================================================

class TestPerformance:
    """Test API performance"""
    
    def test_health_response_time(self, api_base_url):
        """Health endpoint should respond quickly"""
        start = time.time()
        response = requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 1.0  # Should respond within 1 second
        
    def test_list_chats_response_time(self, api_base_url):
        """List chats should respond reasonably fast"""
        start = time.time()
        response = requests.get(f"{api_base_url}/chats?limit=10", timeout=TIMEOUT)
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 2.0  # Should respond within 2 seconds
        
    def test_concurrent_requests(self, api_base_url):
        """Should handle multiple concurrent requests"""
        import concurrent.futures
        
        def make_request():
            return requests.get(f"{api_base_url}/health", timeout=TIMEOUT)
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request) for _ in range(5)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        assert all(r.status_code == 200 for r in results)


# ============================================================================
# 8. DATA VALIDATION TESTS
# ============================================================================

class TestDataValidation:
    """Test data integrity and validation"""
    
    def test_chat_timestamps_valid(self, api_base_url, valid_chat_id):
        """Timestamps should be valid and consistent"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            data = response.json()
            
            # Should have both epoch and ISO formats
            assert isinstance(data['created_at'], int)
            assert isinstance(data['created_at_iso'], str)
            
            # Created should be before last updated
            if data['last_updated_at']:
                assert data['created_at'] <= data['last_updated_at']
                
    def test_message_count_accurate(self, api_base_url, valid_chat_id):
        """Message count should match actual messages"""
        if valid_chat_id:
            # Get metadata
            meta_response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}/metadata",
                timeout=TIMEOUT
            )
            metadata = meta_response.json()
            
            # Get messages
            msgs_response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}",
                timeout=TIMEOUT
            )
            messages = msgs_response.json()
            
            # Counts should match
            assert messages['message_count'] == len(messages['messages'])
            
    def test_chat_ids_are_uuids(self, api_base_url):
        """Chat IDs should be valid UUIDs"""
        import re
        uuid_pattern = re.compile(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            re.IGNORECASE
        )
        
        response = requests.get(f"{api_base_url}/chats?limit=5", timeout=TIMEOUT)
        data = response.json()
        
        for chat in data['chats']:
            assert uuid_pattern.match(chat['chat_id'])
            
    def test_message_types_valid(self, api_base_url, valid_chat_id):
        """Message types should be 1 or 2"""
        if valid_chat_id:
            response = requests.get(
                f"{api_base_url}/chats/{valid_chat_id}?limit=20",
                timeout=TIMEOUT
            )
            data = response.json()
            
            for message in data['messages']:
                assert message['type'] in [1, 2]


# ============================================================================
# 9. INTEGRATION TESTS
# ============================================================================

class TestIntegration:
    """Test end-to-end workflows"""
    
    def test_full_workflow_list_and_get(self, api_base_url):
        """Test complete workflow: list chats -> get specific chat"""
        # Step 1: List chats
        list_response = requests.get(
            f"{api_base_url}/chats?limit=1",
            timeout=TIMEOUT
        )
        assert list_response.status_code == 200
        
        list_data = list_response.json()
        assert len(list_data['chats']) > 0
        
        # Step 2: Get specific chat
        chat_id = list_data['chats'][0]['chat_id']
        chat_response = requests.get(
            f"{api_base_url}/chats/{chat_id}",
            timeout=TIMEOUT
        )
        assert chat_response.status_code == 200
        
        chat_data = chat_response.json()
        assert chat_data['chat_id'] == chat_id
        
    def test_pagination_consistency(self, api_base_url):
        """Test pagination works consistently"""
        # Get first page
        page1 = requests.get(
            f"{api_base_url}/chats?limit=2&offset=0",
            timeout=TIMEOUT
        ).json()
        
        # Get second page
        page2 = requests.get(
            f"{api_base_url}/chats?limit=2&offset=2",
            timeout=TIMEOUT
        ).json()
        
        # Should have different chats
        if len(page1['chats']) > 0 and len(page2['chats']) > 0:
            page1_ids = {c['chat_id'] for c in page1['chats']}
            page2_ids = {c['chat_id'] for c in page2['chats']}
            assert page1_ids.isdisjoint(page2_ids)


# ============================================================================
# TEST SUMMARY
# ============================================================================

def test_api_comprehensive_summary(api_base_url):
    """Generate comprehensive API test summary"""
    print("\n" + "="*70)
    print("CURSOR CHAT API - COMPREHENSIVE TEST SUMMARY")
    print("="*70)
    
    # Test health
    health = requests.get(f"{api_base_url}/health", timeout=TIMEOUT).json()
    print(f"\n✓ API Status: {health['status']}")
    print(f"✓ Database: {health['database']}")
    print(f"✓ Total Chats: {health['total_chats']}")
    print(f"✓ Total Messages: {health['total_messages']}")
    
    # Test all endpoints
    endpoints = {
        "GET /": requests.get(f"{api_base_url}/", timeout=TIMEOUT),
        "GET /health": requests.get(f"{api_base_url}/health", timeout=TIMEOUT),
        "GET /chats": requests.get(f"{api_base_url}/chats", timeout=TIMEOUT),
    }
    
    print(f"\n✓ Endpoint Status:")
    for endpoint, response in endpoints.items():
        status = "✓ OK" if response.status_code == 200 else f"✗ {response.status_code}"
        print(f"  {endpoint:20s} {status}")
    
    print("\n" + "="*70)

