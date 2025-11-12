#!/usr/bin/env python3
"""
Test chat history and resume functionality
This is the CRITICAL test for our use case
"""
import subprocess
import sys
import time
from pathlib import Path
from experiment_logger import ExperimentTracker, logger

def run_cursor_agent(args: list, stdin_input: str = None, timeout: int = 30) -> dict:
    """Run cursor-agent with given arguments"""
    try:
        cmd = ["/Users/davell/.local/bin/cursor-agent"] + args
        logger.debug(f"Running: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            input=stdin_input,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0,
            "command": ' '.join(cmd)
        }
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": "Command timed out",
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd)
        }
    except Exception as e:
        return {
            "stdout": "",
            "stderr": str(e),
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd)
        }

def test_approach_a_resume_flag(tracker: ExperimentTracker):
    """
    Approach A: Use --resume flag with chat ID
    This is the most likely method based on --help output
    """
    logger.info("\n   Step 1: Create a new chat...")
    create_result = run_cursor_agent(["create-chat"])
    
    if not create_result["success"]:
        tracker.log_test(
            "approach_a_create_chat",
            success=False,
            details={"error": "Failed to create chat"},
            error=create_result["stderr"]
        )
        return None
    
    chat_id = create_result["stdout"].strip()
    logger.info(f"   Created chat: {chat_id}")
    
    # Step 2: Send first message
    logger.info("   Step 2: Send first message...")
    msg1_result = run_cursor_agent([
        "--print",
        "--resume", chat_id,
        "Hello, my name is Alice. Remember this."
    ])
    
    tracker.log_test(
        "approach_a_first_message",
        success=msg1_result["success"] and len(msg1_result["stdout"]) > 0,
        details={
            "chat_id": chat_id,
            "output_length": len(msg1_result["stdout"]),
            "output_preview": msg1_result["stdout"][:300]
        },
        error=msg1_result["stderr"] if not msg1_result["success"] else None
    )
    
    if not msg1_result["success"]:
        return None
    
    logger.info(f"   Response: {msg1_result['stdout'][:200]}...")
    
    # Step 3: Send follow-up message to test history
    logger.info("   Step 3: Send follow-up message to test history...")
    time.sleep(1)  # Brief pause
    
    msg2_result = run_cursor_agent([
        "--print",
        "--resume", chat_id,
        "What is my name? Answer with just the name."
    ])
    
    # Check if response mentions "Alice"
    response_lower = msg2_result["stdout"].lower()
    remembers_name = "alice" in response_lower
    
    tracker.log_test(
        "approach_a_resume_with_history",
        success=msg2_result["success"] and remembers_name,
        details={
            "chat_id": chat_id,
            "question": "What is my name?",
            "response": msg2_result["stdout"][:300],
            "remembers_context": remembers_name,
            "full_command": msg2_result["command"]
        },
        error=None if remembers_name else "Did not remember context from previous message"
    )
    
    logger.info(f"   Response: {msg2_result['stdout'][:200]}...")
    logger.info(f"   Context remembered: {remembers_name}")
    
    return chat_id if remembers_name else None

def test_approach_b_history_in_prompt(tracker: ExperimentTracker):
    """
    Approach B: Include history as part of the prompt text
    """
    history_prompt = """Previous conversation:
User: Hello, my name is Bob.
Assistant: Hello Bob! Nice to meet you.

Current question: What is my name?"""
    
    result = run_cursor_agent([
        "--print",
        history_prompt
    ])
    
    response_lower = result["stdout"].lower()
    remembers_name = "bob" in response_lower
    
    tracker.log_test(
        "approach_b_history_in_prompt",
        success=result["success"] and remembers_name,
        details={
            "approach": "Include history in prompt text",
            "response": result["stdout"][:300],
            "remembers_context": remembers_name
        },
        error=None if remembers_name else "Did not extract name from prompt history"
    )
    
    logger.info(f"   Context remembered: {remembers_name}")
    return remembers_name

def test_approach_c_markdown_format(tracker: ExperimentTracker):
    """
    Approach C: Use structured markdown format for history
    """
    markdown_history = """# Chat History

## Message 1
**User**: My favorite color is purple.
**Assistant**: I'll remember that your favorite color is purple.

## Current Question
**User**: What is my favorite color?"""
    
    result = run_cursor_agent([
        "--print",
        markdown_history
    ])
    
    response_lower = result["stdout"].lower()
    remembers_color = "purple" in response_lower
    
    tracker.log_test(
        "approach_c_markdown_format",
        success=result["success"] and remembers_color,
        details={
            "approach": "Markdown structured history",
            "response": result["stdout"][:300],
            "remembers_context": remembers_color
        },
        error=None if remembers_color else "Did not extract color from markdown history"
    )
    
    logger.info(f"   Context remembered: {remembers_color}")
    return remembers_color

def test_approach_d_resume_without_new_prompt(tracker: ExperimentTracker, existing_chat_id: str = None):
    """
    Approach D: Test --resume without additional prompt
    """
    if not existing_chat_id:
        logger.info("   No existing chat ID, skipping test")
        tracker.log_test(
            "approach_d_resume_no_prompt",
            success=False,
            details={"reason": "No chat ID available"},
            error="Requires existing chat"
        )
        return False
    
    result = run_cursor_agent([
        "--print",
        "--resume", existing_chat_id
    ], timeout=10)
    
    tracker.log_test(
        "approach_d_resume_no_prompt",
        success=result["success"],
        details={
            "chat_id": existing_chat_id,
            "behavior": "Resume without new prompt",
            "output": result["stdout"][:300] if result["stdout"] else None,
            "stderr": result["stderr"][:300] if result["stderr"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    
    return result["success"]

def test_approach_e_multiple_messages_in_resume(tracker: ExperimentTracker):
    """
    Approach E: Test multiple back-and-forth messages using resume
    """
    logger.info("\n   Creating chat and testing multi-turn conversation...")
    
    # Create chat
    create_result = run_cursor_agent(["create-chat"])
    if not create_result["success"]:
        tracker.log_test(
            "approach_e_multi_turn",
            success=False,
            details={"error": "Failed to create chat"},
            error=create_result["stderr"]
        )
        return None
    
    chat_id = create_result["stdout"].strip()
    logger.info(f"   Chat ID: {chat_id}")
    
    # Conversation sequence
    conversations = [
        ("I have 5 apples.", "apples"),
        ("I give away 2 apples.", "apples"),
        ("How many apples do I have now? Just give me the number.", "3")
    ]
    
    all_success = True
    conversation_log = []
    
    for i, (prompt, expected_keyword) in enumerate(conversations, 1):
        logger.info(f"   Turn {i}: {prompt}")
        time.sleep(0.5)
        
        result = run_cursor_agent([
            "--print",
            "--resume", chat_id,
            prompt
        ])
        
        response_lower = result["stdout"].lower()
        has_keyword = expected_keyword.lower() in response_lower
        
        conversation_log.append({
            "turn": i,
            "prompt": prompt,
            "response": result["stdout"][:200],
            "expected": expected_keyword,
            "found": has_keyword
        })
        
        logger.info(f"   Response: {result['stdout'][:100]}...")
        logger.info(f"   Expected '{expected_keyword}': {has_keyword}")
        
        if not result["success"] or not has_keyword:
            all_success = False
            break
    
    tracker.log_test(
        "approach_e_multi_turn_conversation",
        success=all_success,
        details={
            "chat_id": chat_id,
            "turns": len(conversation_log),
            "conversation": conversation_log
        },
        error=None if all_success else "Failed to maintain context across multiple turns"
    )
    
    return chat_id if all_success else None

def test_resume_with_existing_cursor_chat(tracker: ExperimentTracker):
    """
    Test resuming a real chat from Cursor's database
    """
    # Try to get a chat ID from the database
    import os
    import sqlite3
    import json
    
    db_path = os.path.expanduser('~/Library/Application Support/Cursor/User/globalStorage/state.vscdb')
    
    if not os.path.exists(db_path):
        tracker.log_test(
            "resume_existing_cursor_chat",
            success=False,
            details={"reason": "Cursor database not found"},
            error=f"Database not found at {db_path}"
        )
        return None
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get a recent chat
        cursor.execute("""
            SELECT key, value 
            FROM cursorDiskKV 
            WHERE key LIKE 'composerData:%'
            ORDER BY key DESC
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            tracker.log_test(
                "resume_existing_cursor_chat",
                success=False,
                details={"reason": "No chats found in database"},
                error="No chats in Cursor database"
            )
            return None
        
        key, value_blob = row
        data = json.loads(value_blob)
        chat_id = data.get('composerId')
        chat_name = data.get('name', 'Untitled')
        
        logger.info(f"   Found existing chat: {chat_name} ({chat_id})")
        
        # Try to resume and add a message
        result = run_cursor_agent([
            "--print",
            "--resume", chat_id,
            "What did we discuss previously? Give a brief summary."
        ])
        
        tracker.log_test(
            "resume_existing_cursor_chat",
            success=result["success"] and len(result["stdout"]) > 0,
            details={
                "chat_id": chat_id,
                "chat_name": chat_name,
                "response_length": len(result["stdout"]),
                "response_preview": result["stdout"][:300]
            },
            error=result["stderr"] if not result["success"] else None
        )
        
        logger.info(f"   Response length: {len(result['stdout'])} chars")
        
        return chat_id if result["success"] else None
        
    except Exception as e:
        tracker.log_test(
            "resume_existing_cursor_chat",
            success=False,
            details={"error": str(e)},
            error=str(e)
        )
        return None

def main():
    logger.info("=" * 70)
    logger.info("CHAT HISTORY & RESUME FUNCTIONALITY TESTS")
    logger.info("=" * 70)
    
    tracker = ExperimentTracker("history_resume")
    
    # Test Approach A: --resume flag (MOST IMPORTANT)
    logger.info("\n▶ APPROACH A: --resume flag with chat ID")
    logger.info("-" * 70)
    chat_id_a = test_approach_a_resume_flag(tracker)
    
    # Test Approach B: History in prompt
    logger.info("\n▶ APPROACH B: Include history in prompt text")
    logger.info("-" * 70)
    test_approach_b_history_in_prompt(tracker)
    
    # Test Approach C: Markdown format
    logger.info("\n▶ APPROACH C: Markdown structured history")
    logger.info("-" * 70)
    test_approach_c_markdown_format(tracker)
    
    # Test Approach D: Resume without prompt
    logger.info("\n▶ APPROACH D: Resume without new prompt")
    logger.info("-" * 70)
    test_approach_d_resume_without_new_prompt(tracker, chat_id_a)
    
    # Test Approach E: Multi-turn conversation
    logger.info("\n▶ APPROACH E: Multi-turn conversation with resume")
    logger.info("-" * 70)
    test_approach_e_multiple_messages_in_resume(tracker)
    
    # Test with existing Cursor chat
    logger.info("\n▶ BONUS: Resume existing Cursor chat from database")
    logger.info("-" * 70)
    test_resume_with_existing_cursor_chat(tracker)
    
    # Save results
    logger.info("\n" + "=" * 70)
    summary = tracker.save_results()
    logger.info("=" * 70)
    
    # Print key findings
    logger.info("\n" + "=" * 70)
    logger.info("KEY FINDINGS:")
    logger.info("=" * 70)
    
    resume_works = any(r["success"] and "resume" in r["test_name"] 
                       for r in summary["results"])
    
    if resume_works:
        logger.info("✓ --resume flag successfully maintains chat history!")
        logger.info("✓ This is the recommended approach for our REST API")
    else:
        logger.info("✗ --resume flag did not work as expected")
        logger.info("  Fallback: Include history in prompt text")
    
    return summary

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("\nTests interrupted by user")
        sys.exit(1)

