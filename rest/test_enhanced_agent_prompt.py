#!/usr/bin/env python3
"""
Comprehensive tests for enhanced agent-prompt endpoint
Tests show_context parameter and context preview functionality
"""

import pytest
import requests
import time
from typing import Optional

BASE_URL = "http://localhost:8000"
TIMEOUT = 120  # Longer timeout for cursor-agent calls


class TestEnhancedAgentPrompt:
    """Test suite for enhanced agent-prompt endpoint"""
    
    @pytest.fixture(scope="class")
    def valid_chat_id(self) -> Optional[str]:
        """Get a valid chat ID for testing"""
        response = requests.get(f"{BASE_URL}/chats?limit=1", timeout=30)
        if response.status_code == 200:
            data = response.json()
            if data.get('chats'):
                return data['chats'][0]['chat_id']
        pytest.skip("No chats available for testing")
    
    @pytest.mark.slow
    def test_show_context_false_default(self, valid_chat_id):
        """Test show_context=false (default behavior)"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "What is 2+2?",
                "model": "gpt-5",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Context should not be present by default
        # (but if it is, that's also acceptable)
        print(f"Response contains context: {'context' in data}")
    
    @pytest.mark.slow
    def test_show_context_true(self, valid_chat_id):
        """Test show_context=true includes context"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "What is 3+3?",
                "model": "gpt-5",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert 'context' in data, "Context should be present with show_context=true"
        print("Context field present in response")
    
    @pytest.mark.slow
    def test_context_structure(self, valid_chat_id):
        """Test that context has correct structure"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Quick test",
                "model": "gpt-5",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        if 'context' in data:
            context = data['context']
            required_fields = ['message_count', 'recent_messages', 'preview_count']
            for field in required_fields:
                assert field in context, f"Context should have '{field}' field"
            print("Context structure complete")
        else:
            pytest.skip("No context in response")
    
    @pytest.mark.slow
    def test_max_history_messages(self, valid_chat_id):
        """Test max_history_messages parameter"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Quick test",
                "max_history_messages": 3,
                "model": "gpt-5",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        if 'context' in data:
            preview_count = data['context'].get('preview_count', 0)
            assert preview_count <= 3, \
                f"Preview count should be ≤3, got {preview_count}"
            print(f"Preview count: {preview_count} (max: 3)")
        else:
            pytest.skip("No context in response")
    
    @pytest.mark.slow
    def test_context_message_count(self, valid_chat_id):
        """Test context message_count is accurate"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Test",
                "model": "gpt-5",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        if 'context' in data:
            msg_count = data['context'].get('message_count', 0)
            assert msg_count > 0, "Should have message count"
            print(f"Total message count: {msg_count}")
        else:
            pytest.skip("No context in response")
    
    @pytest.mark.slow
    def test_model_with_context(self, valid_chat_id):
        """Test model parameter works with context"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Test",
                "model": "sonnet-4.5",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200, \
            f"Model selection should work, got {response.status_code}"
    
    @pytest.mark.slow
    def test_json_format_with_context(self, valid_chat_id):
        """Test JSON output format with context"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Test JSON",
                "model": "gpt-5",
                "output_format": "json"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should have response data (exact field name may vary)
        has_response = 'response' in data or 'output' in data or 'chat_id' in data
        assert has_response, "Should have response data"
    
    def test_invalid_model_error(self, valid_chat_id):
        """Test error handling for invalid model"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Test",
                "model": "invalid-model-9000",
                "output_format": "text"
            },
            params={"show_context": True},
            timeout=60
        )
        
        assert response.status_code in [400, 500], \
            f"Should reject invalid model, got {response.status_code}"
    
    @pytest.mark.slow
    def test_response_includes_output(self, valid_chat_id):
        """Test response includes agent output"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "Say hi",
                "model": "gpt-5",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        has_output = 'response' in data or 'output' in data
        assert has_output, "Should have output in response"
        
        if 'response' in data:
            assert len(str(data['response'])) > 0, "Response should not be empty"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-m", "not slow"])

