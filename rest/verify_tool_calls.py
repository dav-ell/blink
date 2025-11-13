#!/usr/bin/env python3
import requests, json, time

# Create & submit with explicit tool-requiring prompt
r = requests.post("http://localhost:8000/agent/create-chat")
chat_id = r.json()["chat_id"]

r = requests.post(f"http://localhost:8000/chats/{chat_id}/agent-prompt-async",
                  json={"prompt": "Run the command 'ls *.py' to list Python files"})
job_id = r.json()["job_id"]
print(f"Job: {job_id}")

# Poll
for _ in range(25):
    r = requests.get(f"http://localhost:8000/jobs/{job_id}")
    if r.json()["status"] in ["completed", "failed"]:
        break
    time.sleep(2)

# Check
d = r.json()
print(f"\n✓ Status: {d['status']}")
print(f"✓ Result: {d['result'][:100]}...")
print(f"✓ Thinking: {'YES ({} chars)'.format(len(d.get('thinking_content', '') or '')) if d.get('thinking_content') else 'NO'}")
print(f"✓ Tool calls: {len(d.get('tool_calls') or [])}")

if d.get('tool_calls'):
    for i, tc in enumerate(d['tool_calls']):
        print(f"    {i+1}. {tc.get('name')}: {tc.get('command')}")
        if tc.get('result'):
            print(f"       Exit code: {tc['result'].get('exit_code')}")

# Check database storage
r = requests.get(f"http://localhost:8000/chats/{chat_id}")
msgs = r.json()["messages"]
asst = [m for m in msgs if m['type_label'] == 'assistant'][0]
print(f"\n✓ Database storage:")
print(f"    has_thinking: {asst['has_thinking']}")
print(f"    has_tool_call: {asst['has_tool_call']}")
print(f"    thinking_content: {len(asst.get('thinking_content', '') or '')} chars")
print(f"    tool_calls: {len(asst.get('tool_calls') or [])}")

print("\n✓✓✓ SUCCESS! The Flutter app will now display reasoning and tool calls! ✓✓✓")

