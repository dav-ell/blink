#!/usr/bin/env python3
"""
Performance benchmarks and load tests for cursor-agent REST API
Measures response times and tests under concurrent load
"""

import pytest
import requests
import time
import concurrent.futures
from typing import List, Optional

BASE_URL = "http://localhost:8000"
TIMEOUT = 30


class TestPerformance:
    """Test suite for performance benchmarks"""
    
    @pytest.fixture(scope="class")
    def chat_ids(self) -> List[str]:
        """Get multiple chat IDs for testing"""
        response = requests.get(f"{BASE_URL}/chats?limit=10", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            ids = [chat['chat_id'] for chat in data['chats'][:10]]
            if ids:
                return ids
        pytest.skip("No chats available for testing")
    
    @pytest.fixture(scope="class")
    def first_chat_id(self, chat_ids) -> str:
        """Get first chat ID"""
        return chat_ids[0] if chat_ids else pytest.skip("No chats available")
    
    @pytest.mark.parametrize("limit", [10, 50, 100])
    def test_list_chats_performance(self, limit):
        """Test list chats performance with different limits"""
        start = time.time()
        response = requests.get(f"{BASE_URL}/chats?limit={limit}", timeout=TIMEOUT)
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 2.0, \
            f"List {limit} chats should be <2s, got {duration:.2f}s"
        
        print(f"List {limit} chats: {duration:.2f}s")
    
    @pytest.mark.parametrize("count", [0, 5, 20])
    def test_get_summary_performance(self, first_chat_id, count):
        """Test get summary performance with different message counts"""
        start = time.time()
        response = requests.get(
            f"{BASE_URL}/chats/{first_chat_id}/summary",
            params={"recent_count": count},
            timeout=TIMEOUT
        )
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 1.0, \
            f"Get summary (recent_count={count}) should be <1s, got {duration:.2f}s"
        
        print(f"Get summary (recent_count={count}): {duration:.2f}s")
    
    @pytest.mark.parametrize("batch_size", [1, 5, 10])
    def test_batch_info_performance(self, chat_ids, batch_size):
        """Test batch info performance with different batch sizes"""
        batch = chat_ids[:batch_size]
        
        start = time.time()
        response = requests.post(
            f"{BASE_URL}/chats/batch-info",
            json=batch,
            timeout=TIMEOUT
        )
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 3.0, \
            f"Batch info ({batch_size} chats) should be <3s, got {duration:.2f}s"
        
        print(f"Batch info ({batch_size} chats): {duration:.2f}s")
    
    @pytest.mark.slow
    def test_agent_prompt_performance(self, first_chat_id):
        """Test agent prompt performance"""
        start = time.time()
        response = requests.post(
            f"{BASE_URL}/chats/{first_chat_id}/agent-prompt",
            json={
                "prompt": "What is 1+1?",
                "model": "gpt-5",
                "output_format": "text"
            },
            timeout=120
        )
        duration = time.time() - start
        
        assert response.status_code == 200
        assert duration < 15.0, \
            f"Agent prompt should be <15s, got {duration:.2f}s"
        
        print(f"Agent prompt: {duration:.2f}s")
    
    def test_concurrent_list_requests(self):
        """Test concurrent list requests"""
        num_requests = 5
        
        def make_request():
            return requests.get(f"{BASE_URL}/chats?limit=10", timeout=TIMEOUT)
        
        start = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=num_requests) as executor:
            futures = [executor.submit(make_request) for _ in range(num_requests)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        duration = time.time() - start
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200
        
        avg_time = duration / num_requests
        print(f"{num_requests} concurrent requests in {duration:.2f}s (avg: {avg_time:.2f}s)")
    
    def test_repeated_requests_caching(self, first_chat_id):
        """Test repeated requests (caching behavior)"""
        times = []
        
        for i in range(3):
            start = time.time()
            response = requests.get(
                f"{BASE_URL}/chats/{first_chat_id}/summary",
                timeout=TIMEOUT
            )
            duration = time.time() - start
            
            assert response.status_code == 200
            times.append(duration)
            print(f"  Request {i+1}: {duration:.2f}s")
        
        avg_time = sum(times) / len(times)
        print(f"Average response time: {avg_time:.2f}s")
    
    def test_api_under_load(self, first_chat_id):
        """Test API responsiveness under load"""
        num_requests = 10
        
        def make_request():
            return requests.get(
                f"{BASE_URL}/chats/{first_chat_id}/summary",
                params={"recent_count": 5},
                timeout=TIMEOUT
            )
        
        start = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=num_requests) as executor:
            futures = [executor.submit(make_request) for _ in range(num_requests)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        duration = time.time() - start
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200
        
        avg_time = duration / num_requests
        assert avg_time < 3.0, \
            f"Average response time under load should be <3s, got {avg_time:.2f}s"
        
        print(f"{num_requests} requests in {duration:.2f}s (avg: {avg_time:.2f}s)")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-m", "not slow"])

