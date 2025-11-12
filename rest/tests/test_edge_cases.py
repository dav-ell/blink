#!/usr/bin/env python3
"""
Edge case and error condition tests for cursor-agent REST API
Tests boundary conditions, malformed requests, and error handling
"""

import pytest
import requests
from typing import Optional

BASE_URL = "http://localhost:8000"
TIMEOUT = 30


class TestEdgeCases:
    """Test suite for edge cases and error conditions"""
    
    @pytest.fixture(scope="class")
    def valid_chat_id(self) -> Optional[str]:
        """Get a valid chat ID for testing"""
        response = requests.get(f"{BASE_URL}/chats?limit=1", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            if data.get('chats'):
                return data['chats'][0]['chat_id']
        pytest.skip("No chats available for testing")
    
    def test_empty_prompt(self, valid_chat_id):
        """Test empty string prompt"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={"prompt": ""},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 422], \
            f"Should reject empty prompt, got {response.status_code}"
    
    @pytest.mark.slow
    def test_whitespace_prompt(self, valid_chat_id):
        """Test whitespace-only prompt"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={"prompt": "   "},
            timeout=TIMEOUT
        )
        
        # May accept or reject whitespace - both are acceptable
        assert response.status_code in [200, 400, 422, 500]
    
    @pytest.mark.slow
    def test_very_long_prompt(self, valid_chat_id):
        """Test very long prompt (10KB)"""
        long_prompt = "A" * 10000
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={"prompt": long_prompt, "model": "gpt-5"},
            timeout=120
        )
        
        # Should either accept or reject with 413
        assert response.status_code in [200, 413, 500]
    
    @pytest.mark.slow
    def test_unicode_emoji_prompt(self, valid_chat_id):
        """Test Unicode and emoji in prompt"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={"prompt": "Hello 👋 世界 🌍", "model": "gpt-5"},
            timeout=120
        )
        
        assert response.status_code == 200, \
            "Should handle Unicode/emoji correctly"
    
    def test_malformed_json(self, valid_chat_id):
        """Test malformed JSON request"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            data="{invalid json}",
            headers={"Content-Type": "application/json"},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 422], \
            "Should reject malformed JSON"
    
    def test_missing_prompt_field(self, valid_chat_id):
        """Test missing required prompt field"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={"model": "gpt-5"},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 422], \
            "Should reject missing prompt field"
    
    def test_invalid_parameter_type(self, valid_chat_id):
        """Test invalid parameter type"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "test",
                "max_history_messages": "invalid"  # Should be int
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 422], \
            "Should reject invalid parameter type"
    
    def test_negative_max_history(self, valid_chat_id):
        """Test negative value for max_history_messages"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "test",
                "max_history_messages": -5
            },
            timeout=TIMEOUT
        )
        
        # May accept or handle gracefully
        assert response.status_code in [200, 400, 422]
    
    def test_invalid_model_name(self, valid_chat_id):
        """Test invalid model name"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "test",
                "model": "gpt-99-ultra-mega"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 500], \
            "Should reject invalid model"
    
    def test_invalid_output_format(self, valid_chat_id):
        """Test invalid output format"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": "test",
                "output_format": "xml"
            },
            timeout=TIMEOUT
        )
        
        # May pass to cursor-agent which will error
        assert response.status_code in [200, 400, 500]
    
    def test_invalid_chat_id_format(self):
        """Test invalid chat ID format"""
        response = requests.post(
            f"{BASE_URL}/chats/not-a-uuid/agent-prompt",
            json={"prompt": "test"},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [404, 422, 500], \
            "Should handle invalid chat ID format"
    
    def test_nonexistent_chat_id(self):
        """Test non-existent chat ID"""
        response = requests.post(
            f"{BASE_URL}/chats/00000000-0000-0000-0000-000000000000/agent-prompt",
            json={"prompt": "test"},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [404, 500], \
            "Should handle non-existent chat"
    
    @pytest.mark.slow
    def test_special_characters_in_prompt(self, valid_chat_id):
        """Test special characters in prompt"""
        response = requests.post(
            f"{BASE_URL}/chats/{valid_chat_id}/agent-prompt",
            json={
                "prompt": 'Test <html> & "quotes" \'single\' `backticks`',
                "model": "gpt-5"
            },
            timeout=120
        )
        
        assert response.status_code == 200, \
            "Should handle special characters"
    
    def test_summary_negative_recent_count(self, valid_chat_id):
        """Test summary with negative recent_count"""
        response = requests.get(
            f"{BASE_URL}/chats/{valid_chat_id}/summary",
            params={"recent_count": -1},
            timeout=TIMEOUT
        )
        
        # Should handle gracefully
        assert response.status_code in [200, 422]
    
    def test_batch_info_non_array(self):
        """Test batch info with non-array input"""
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json={"chat_ids": "not-an-array"},
            timeout=TIMEOUT
        )
        
        assert response.status_code in [400, 422], \
            "Should reject non-array input"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-m", "not slow"])

