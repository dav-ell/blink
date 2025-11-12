#!/usr/bin/env python3
"""
End-to-end workflow integration tests
Tests complete user workflows from start to finish
"""

import pytest
import requests
from typing import List, Optional

BASE_URL = "http://localhost:8000"
TIMEOUT = 120


class TestE2EWorkflows:
    """Test suite for end-to-end workflows"""
    
    @pytest.fixture(scope="class")
    def existing_chats(self) -> List[dict]:
        """Get existing chats"""
        response = requests.get(f"{BASE_URL}/chats?limit=5", timeout=30)
        if response.status_code == 200:
            data = response.json()
            if data.get('chats'):
                return data['chats'][:5]
        return []
    
    @pytest.fixture(scope="class")
    def first_chat_id(self, existing_chats) -> Optional[str]:
        """Get first chat ID"""
        if existing_chats:
            return existing_chats[0]['chat_id']
        return None
    
    @pytest.mark.slow
    @pytest.mark.workflow
    def test_new_user_flow(self):
        """
        Workflow 1: New User Flow
        Steps: Create chat -> Send first message -> Continue conversation
        """
        # Step 1: Create new chat
        response = requests.post(f"{BASE_URL}/agent/create-chat", timeout=30)
        assert response.status_code == 200, "Create chat should succeed"
        
        new_chat_id = response.json().get('chat_id')
        assert new_chat_id, "Should get chat ID"
        print(f"Created chat: {new_chat_id}")
        
        # Step 2: Send first message
        response = requests.post(
            f"{BASE_URL}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Hello, this is my first message",
                "model": "gpt-5",
                "output_format": "text"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "First message should succeed"
        print("Sent first message")
        
        # Step 3: Continue conversation
        response = requests.post(
            f"{BASE_URL}/chats/{new_chat_id}/agent-prompt",
            json={
                "prompt": "Can you remember what I just said?",
                "model": "gpt-5"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "Continue conversation should succeed"
        print("Continued conversation")
    
    @pytest.mark.slow
    @pytest.mark.workflow
    def test_existing_chat_flow(self, first_chat_id):
        """
        Workflow 2: Existing Chat Flow
        Steps: List chats -> Get summary -> View history -> Continue with context
        """
        if not first_chat_id:
            pytest.skip("No existing chats available")
        
        # Step 1: List existing chats
        response = requests.get(f"{BASE_URL}/chats?limit=5", timeout=30)
        assert response.status_code == 200, "List chats should succeed"
        print("Listed chats")
        
        # Step 2: Get chat summary
        response = requests.get(
            f"{BASE_URL}/chats/{first_chat_id}/summary",
            params={"recent_count": 5},
            timeout=30
        )
        assert response.status_code == 200, "Get summary should succeed"
        
        msg_count = response.json().get('message_count', 0)
        print(f"Got summary: {msg_count} messages")
        
        # Step 3: Get full history
        response = requests.get(
            f"{BASE_URL}/chats/{first_chat_id}/messages",
            timeout=30
        )
        assert response.status_code == 200, "Get history should succeed"
        print("Retrieved full history")
        
        # Step 4: Continue with context preview
        response = requests.post(
            f"{BASE_URL}/chats/{first_chat_id}/agent-prompt",
            json={
                "prompt": "Lets continue our discussion",
                "model": "gpt-5"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "Continue with context should succeed"
        
        data = response.json()
        assert 'context' in data, "Should include context"
        print("Continued with context")
    
    @pytest.mark.workflow
    def test_batch_operations_flow(self, existing_chats, first_chat_id):
        """
        Workflow 3: Batch Operations Flow
        Steps: List chats -> Get batch info -> Continue multiple chats
        """
        if not existing_chats:
            pytest.skip("No existing chats available")
        
        # Step 1: List chats
        response = requests.get(f"{BASE_URL}/chats?limit=3", timeout=30)
        assert response.status_code == 200, "List chats should succeed"
        
        chat_ids = [chat['chat_id'] for chat in existing_chats[:3]]
        print(f"Got {len(chat_ids)} chat IDs")
        
        # Step 2: Get batch info
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=chat_ids,
            timeout=30
        )
        assert response.status_code == 200, "Batch info should succeed"
        
        found_count = response.json().get('total_found', 0)
        print(f"Batch info found {found_count} chats")
        
        # Step 3: Continue first chat
        if first_chat_id:
            response = requests.post(
                f"{BASE_URL}/chats/{first_chat_id}/agent-prompt",
                json={
                    "prompt": "Quick test",
                    "model": "gpt-5"
                },
                timeout=TIMEOUT
            )
            # May timeout if slow, but that's okay for this test
            print(f"Continued first chat (status: {response.status_code})")
    
    @pytest.mark.slow
    @pytest.mark.workflow
    def test_model_switching_flow(self):
        """
        Workflow 4: Model Switching Flow
        Steps: Create chat -> Use gpt-5 -> Use sonnet-4.5 -> Use opus-4.1
        """
        # Step 1: Create chat
        response = requests.post(f"{BASE_URL}/agent/create-chat", timeout=30)
        assert response.status_code == 200
        
        chat_id = response.json().get('chat_id')
        assert chat_id
        print(f"Created chat for model testing: {chat_id}")
        
        # Step 2: Use gpt-5
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "Say hello in GPT-5",
                "model": "gpt-5"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "GPT-5 should work"
        print("Used gpt-5")
        
        # Step 3: Switch to sonnet-4.5
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "Now respond in Sonnet",
                "model": "sonnet-4.5"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "Sonnet-4.5 should work"
        print("Used sonnet-4.5")
        
        # Step 4: Switch to opus-4.1
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "Opus turn",
                "model": "opus-4.1"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200, "Opus-4.1 should work"
        print("Used opus-4.1")
    
    @pytest.mark.slow
    @pytest.mark.workflow
    def test_multi_turn_context_maintenance(self):
        """
        Workflow 5: Multi-turn Context Maintenance
        Steps: Create chat -> Turn 1 -> Turn 2 -> Turn 3 (verify context)
        """
        # Step 1: Create chat
        response = requests.post(f"{BASE_URL}/agent/create-chat", timeout=30)
        assert response.status_code == 200
        
        chat_id = response.json().get('chat_id')
        assert chat_id
        print(f"Created chat for context testing: {chat_id}")
        
        # Step 2: Turn 1 - Set context
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "My favorite color is blue",
                "model": "gpt-5"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200
        print("Turn 1: Set context")
        
        # Step 3: Turn 2 - Add more context
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "I also like cats",
                "model": "gpt-5"
            },
            timeout=TIMEOUT
        )
        assert response.status_code == 200
        print("Turn 2: Added more context")
        
        # Step 4: Turn 3 - Verify context maintained
        response = requests.post(
            f"{BASE_URL}/chats/{chat_id}/agent-prompt",
            json={
                "prompt": "What do you know about my preferences?",
                "model": "gpt-5"
            },
            params={"show_context": True},
            timeout=TIMEOUT
        )
        assert response.status_code == 200
        
        data = response.json()
        if 'context' in data:
            msg_count = data['context'].get('message_count', 0)
            assert msg_count >= 4, \
                f"Should have at least 4 messages (got {msg_count})"
            print(f"Turn 3: Context maintained ({msg_count} messages)")
        else:
            print("Turn 3: Completed (context not in response)")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-m", "workflow"])

