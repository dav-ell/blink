#!/usr/bin/env python3
"""
Test basic cursor-agent invocation patterns
"""
import subprocess
import sys
from pathlib import Path
from experiment_logger import ExperimentTracker, logger

def run_cursor_agent(args: list, stdin_input: str = None, timeout: int = 30) -> dict:
    """
    Run cursor-agent with given arguments
    Returns dict with stdout, stderr, returncode, success
    """
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

def test_print_with_argument(tracker: ExperimentTracker):
    """Test: cursor-agent --print 'prompt'"""
    result = run_cursor_agent(["--print", "What is 2+2? Answer only with the number."])
    
    tracker.log_test(
        "print_with_argument",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "command": result["command"],
            "output_length": len(result["stdout"]),
            "output_preview": result["stdout"][:200] if result["stdout"] else None,
            "stderr": result["stderr"][:200] if result["stderr"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    return result

def test_print_with_stdin(tracker: ExperimentTracker):
    """Test: echo 'prompt' | cursor-agent --print"""
    result = run_cursor_agent(
        ["--print"],
        stdin_input="What is the capital of France? Answer with just the city name."
    )
    
    tracker.log_test(
        "print_with_stdin",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "command": result["command"],
            "output_length": len(result["stdout"]),
            "output_preview": result["stdout"][:200] if result["stdout"] else None,
            "stderr": result["stderr"][:200] if result["stderr"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    return result

def test_print_with_force(tracker: ExperimentTracker):
    """Test: cursor-agent --print --force 'prompt'"""
    result = run_cursor_agent(
        ["--print", "--force", "Say hello in one word"]
    )
    
    tracker.log_test(
        "print_with_force",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "command": result["command"],
            "output_length": len(result["stdout"]),
            "output_preview": result["stdout"][:200] if result["stdout"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    return result

def test_create_chat(tracker: ExperimentTracker):
    """Test: cursor-agent create-chat"""
    result = run_cursor_agent(["create-chat"])
    
    # Extract chat ID if successful
    chat_id = None
    if result["success"] and result["stdout"]:
        # Chat ID is typically in the output
        chat_id = result["stdout"].strip()
    
    tracker.log_test(
        "create_chat",
        success=result["success"] and chat_id is not None,
        details={
            "command": result["command"],
            "chat_id": chat_id,
            "output": result["stdout"][:200] if result["stdout"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    return chat_id

def test_prompt_without_print(tracker: ExperimentTracker):
    """Test: cursor-agent 'prompt' (without --print, should fail/timeout in non-interactive)"""
    result = run_cursor_agent(
        ["What is 1+1?"],
        timeout=5  # Short timeout since this will likely hang
    )
    
    # This is expected to fail or timeout in non-interactive mode
    tracker.log_test(
        "prompt_without_print_mode",
        success=True,  # Success means we detected it doesn't work
        details={
            "command": result["command"],
            "expected": "Should fail or timeout without --print flag",
            "actual": "Failed as expected" if not result["success"] else "Unexpectedly succeeded"
        },
        error="Non-interactive mode not suitable for automation" if not result["success"] else None
    )

def main():
    logger.info("=" * 70)
    logger.info("BASIC INVOCATION TESTS")
    logger.info("=" * 70)
    
    tracker = ExperimentTracker("basic_invocation")
    
    # Run tests
    logger.info("\n1. Testing --print with argument...")
    test_print_with_argument(tracker)
    
    logger.info("\n2. Testing --print with stdin...")
    test_print_with_stdin(tracker)
    
    logger.info("\n3. Testing --print --force...")
    test_print_with_force(tracker)
    
    logger.info("\n4. Testing create-chat...")
    chat_id = test_create_chat(tracker)
    if chat_id:
        logger.info(f"   Created chat ID: {chat_id}")
    
    logger.info("\n5. Testing without --print flag...")
    test_prompt_without_print(tracker)
    
    # Save results
    logger.info("\n" + "=" * 70)
    summary = tracker.save_results()
    logger.info("=" * 70)
    
    return summary

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("\nTests interrupted by user")
        sys.exit(1)

