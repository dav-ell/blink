#!/usr/bin/env python3
import requests, json, time

# Create & submit
r = requests.post("http://localhost:8000/agent/create-chat")
chat_id = r.json()["chat_id"]
print(f"Chat: {chat_id}")

r = requests.post(f"http://localhost:8000/chats/{chat_id}/agent-prompt-async",
                  json={"prompt": "List *.py files"})
job_id = r.json()["job_id"]
print(f"Job: {job_id}")

# Poll
for _ in range(20):
    r = requests.get(f"http://localhost:8000/jobs/{job_id}")
    if r.json()["status"] in ["completed", "failed"]:
        break
    time.sleep(2)

# Check
d = r.json()
print(f"\nStatus: {d['status']}")
print(f"Thinking: {'YES' if d.get('thinking_content') else 'NO'}")
print(f"Tool calls: {len(d.get('tool_calls') or [])}")

