#!/usr/bin/env python3
"""Final verification test"""
import requests
import json
import time

API_BASE = "http://localhost:8000"

# Create chat
print("Creating chat...")
response = requests.post(f"{API_BASE}/agent/create-chat")
chat_id = response.json()["chat_id"]
print(f"Chat ID: {chat_id}")

# Submit prompt
print("\nSubmitting prompt...")
response = requests.post(
    f"{API_BASE}/chats/{chat_id}/agent-prompt-async",
    json={"prompt": "List Python files using ls command"}
)
job_id = response.json()["job_id"]
print(f"Job ID: {job_id}")

# Poll for completion
print("\nWaiting for completion...")
for i in range(30):
    response = requests.get(f"{API_BASE}/jobs/{job_id}")
    data = response.json()
    status = data["status"]
    print(f"  {status}...", end="\r")
    if status in ["completed", "failed"]:
        break
    time.sleep(2)

print("\n\nJob Result:")
print(f"Status: {data['status']}")
print(f"Result length: {len(data.get('result', ''))}")
print(f"Thinking: {'YES ({} chars)'.format(len(data.get('thinking_content', '') or '')) if data.get('thinking_content') else 'NO'}")
print(f"Tool calls: {len(data.get('tool_calls') or [])}")

if data.get('thinking_content'):
    print(f"\nThinking preview: {data['thinking_content'][:150]}...")

if data.get('tool_calls'):
    print("\nTool calls:")
    for tc in data['tool_calls']:
        print(f"  - {tc.get('name')}: {tc.get('command')}")

# Check database
print("\n\nChecking database...")
response = requests.get(f"{API_BASE}/chats/{chat_id}")
messages = response.json()["messages"]
for msg in messages:
    if msg['type_label'] == 'assistant':
        print(f"Assistant message:")
        print(f"  Has thinking: {msg['has_thinking']}")
        print(f"  Has tool call: {msg['has_tool_call']}")
        if msg.get('thinking_content'):
            print(f"  Thinking length: {len(msg['thinking_content'])}")
        if msg.get('tool_calls'):
            print(f"  Tool calls: {len(msg['tool_calls'])}")

