#!/usr/bin/env python3
"""
Comprehensive Test Suite for Cursor-Agent Integration

Tests the new REST API endpoints that integrate with cursor-agent CLI.
"""

import pytest
import requests
import json
import time
from typing import Dict, Any

# Configuration
BASE_URL = "http://localhost:8000"
TIMEOUT = 30  # seconds

# ============================================================================
# Test Fixtures
# ============================================================================

@pytest.fixture(scope="module")
def api_base_url():
    """Provide base URL for all tests"""
    return BASE_URL

@pytest.fixture(scope="module")
def health_check(api_base_url):
    """Ensure API is running"""
    try:
        response = requests.get(f"{api_base_url}/health", timeout=5)
        assert response.status_code == 200
        return response.json()
    except Exception as e:
        pytest.skip(f"API not available: {e}")

@pytest.fixture
def new_chat_id(api_base_url, health_check):
    """Create a new chat for testing"""
    response = requests.post(
        f"{api_base_url}/agent/create-chat",
        timeout=TIMEOUT
    )
    if response.status_code == 200:
        data = response.json()
        return data.get("chat_id")
    return None

# ============================================================================
# 1. AGENT ENDPOINT AVAILABILITY TESTS
# ============================================================================

class TestAgentEndpoints:
    """Test that new agent endpoints are available"""
    
    def test_root_shows_agent_endpoints(self, api_base_url):
        """Root endpoint should list new agent endpoints"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        assert response.status_code == 200
        
        data = response.json()
        assert "endpoints" in data
        assert "POST /chats/{chat_id}/agent-prompt" in data["endpoints"].values()
        assert "POST /agent/create-chat" in data["endpoints"].values()
        assert "GET /agent/models" in data["endpoints"].values()
    
    def test_root_shows_cursor_agent_status(self, api_base_url):
        """Root should show cursor-agent installation status"""
        response = requests.get(f"{api_base_url}/", timeout=TIMEOUT)
        data = response.json()
        
        assert "cursor_agent" in data
        assert "installed" in data["cursor_agent"]
        assert "path" in data["cursor_agent"]

# ============================================================================
# 2. CREATE CHAT TESTS
# ============================================================================

class TestCreateChat:
    """Test POST /agent/create-chat endpoint"""
    
    def test_create_chat_success(self, api_base_url, health_check):
        """Should successfully create a new chat"""
        response = requests.post(
            f"{api_base_url}/agent/create-chat",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["status"] == "success"
        assert "chat_id" in data
        assert len(data["chat_id"]) > 0
    
    def test_create_chat_returns_valid_uuid(self, api_base_url, health_check):
        """Chat ID should be a valid UUID"""
        import re
        uuid_pattern = re.compile(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            re.IGNORECASE
        )
        
        response = requests.post(
            f"{api_base_url}/agent/create-chat",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert uuid_pattern.match(data["chat_id"])

# ============================================================================
# 3. LIST MODELS TESTS
# ============================================================================

class TestListModels:
    """Test GET /agent/models endpoint"""
    
    def test_list_models_success(self, api_base_url):
        """Should return list of available models"""
        response = requests.get(
            f"{api_base_url}/agent/models",
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "models" in data
        assert isinstance(data["models"], list)
        assert len(data["models"]) > 0
    
    def test_list_models_includes_common_models(self, api_base_url):
        """Should include expected models"""
        response = requests.get(
            f"{api_base_url}/agent/models",
            timeout=TIMEOUT
        )
        
        data = response.json()
        models = data["models"]
        
        # Should include these based on experiments
        assert "gpt-5" in models
        assert "sonnet-4.5" in models
        assert "auto" in models
    
    def test_list_models_has_recommendations(self, api_base_url):
        """Should include recommended models"""
        response = requests.get(
            f"{api_base_url}/agent/models",
            timeout=TIMEOUT
        )
        
        data = response.json()
        
        assert "recommended" in data
        assert isinstance(data["recommended"], list)
        assert len(data["recommended"]) > 0

# ============================================================================
# 4. AGENT PROMPT TESTS (BASIC)
# ============================================================================

class TestAgentPromptBasic:
    """Test basic agent prompt functionality"""
    
    def test_agent_prompt_simple(self, api_base_url, new_chat_id, health_check):
        """Should handle a simple prompt"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "What is 5 + 3? Answer with just the number.",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["status"] == "success"
        assert "response" in data
        assert len(data["response"]) > 0
    
    def test_agent_prompt_with_model(self, api_base_url, new_chat_id, health_check):
        """Should accept model parameter"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Say hello",
                "model": "gpt-5",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["model"] == "gpt-5"
    
    def test_agent_prompt_invalid_model(self, api_base_url, new_chat_id, health_check):
        """Should reject invalid model"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Test",
                "model": "invalid-model-xyz",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 500

# ============================================================================
# 5. AGENT PROMPT WITH HISTORY TESTS
# ============================================================================

class TestAgentPromptHistory:
    """Test history/context functionality"""
    
    def test_remembers_context_across_messages(self, api_base_url, health_check):
        """Should maintain context across multiple prompts"""
        # Create new chat
        create_response = requests.post(
            f"{api_base_url}/agent/create-chat",
            timeout=TIMEOUT
        )
        assert create_response.status_code == 200
        chat_id = create_response.json()["chat_id"]
        
        # First message: Establish context
        msg1_response = requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "My name is TestUser. Remember this.",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        assert msg1_response.status_code == 200
        
        time.sleep(1)  # Brief pause
        
        # Second message: Test context
        msg2_response = requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "What is my name? Answer with just the name.",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        assert msg2_response.status_code == 200
        
        response_text = msg2_response.json()["response"].lower()
        assert "testuser" in response_text
    
    def test_multi_turn_conversation(self, api_base_url, health_check):
        """Should handle multi-turn conversation"""
        # Create chat
        create_response = requests.post(
            f"{api_base_url}/agent/create-chat",
            timeout=TIMEOUT
        )
        chat_id = create_response.json()["chat_id"]
        
        # Turn 1
        requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={"prompt": "I have 10 apples."},
            timeout=TIMEOUT
        )
        time.sleep(0.5)
        
        # Turn 2
        requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={"prompt": "I give away 3 apples."},
            timeout=TIMEOUT
        )
        time.sleep(0.5)
        
        # Turn 3: Test
        response = requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={"prompt": "How many apples do I have now? Just the number."},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        # The response should reference the calculation

# ============================================================================
# 6. OUTPUT FORMAT TESTS
# ============================================================================

class TestOutputFormats:
    """Test different output formats"""
    
    def test_output_format_text(self, api_base_url, new_chat_id, health_check):
        """Should return text format"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Say test",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert isinstance(data["response"], str)
    
    def test_output_format_json(self, api_base_url, new_chat_id, health_check):
        """Should return JSON format"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Say hello",
                "output_format": "json"
            },
            timeout=TIMEOUT
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Response should be parsed JSON or dict
        assert "response" in data

# ============================================================================
# 7. ERROR HANDLING TESTS
# ============================================================================

class TestErrorHandling:
    """Test error conditions"""
    
    def test_invalid_chat_id(self, api_base_url, health_check):
        """Should handle invalid chat ID gracefully"""
        response = requests.post(
            f"{api_base_url}/chats/invalid-uuid-12345/agent-prompt",
            json={"prompt": "Test"},
            timeout=TIMEOUT
        )
        
        # Should fail but not crash
        assert response.status_code in [404, 500]
    
    def test_missing_prompt(self, api_base_url, new_chat_id):
        """Should reject request without prompt"""
        if not new_chat_id:
            pytest.skip("Could not create chat")
        
        response = requests.post(
            f"{api_base_url}/chats/{new_chat_id}/agent-prompt",
            json={},
            timeout=TIMEOUT
        )
        
        assert response.status_code == 422  # Validation error

# ============================================================================
# 8. INTEGRATION TESTS
# ============================================================================

class TestIntegration:
    """Test complete workflows"""
    
    def test_full_workflow(self, api_base_url, health_check):
        """Test complete workflow: create → prompt → history → prompt"""
        # Step 1: Create chat
        create_resp = requests.post(
            f"{api_base_url}/agent/create-chat",
            timeout=TIMEOUT
        )
        assert create_resp.status_code == 200
        chat_id = create_resp.json()["chat_id"]
        
        # Step 2: First prompt
        msg1_resp = requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={"prompt": "Hello, I'm testing the API."},
            timeout=TIMEOUT
        )
        assert msg1_resp.status_code == 200
        
        time.sleep(1)
        
        # Step 3: Follow-up with context
        msg2_resp = requests.post(
            f"{api_base_url}/chats/{chat_id}/agent-prompt",
            json={"prompt": "What did I just say?"},
            timeout=TIMEOUT
        )
        assert msg2_resp.status_code == 200
        
        # Response should reference the previous message
        response = msg2_resp.json()["response"].lower()
        assert "testing" in response or "api" in response

# ============================================================================
# RUN TESTS
# ============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])

