#!/usr/bin/env python3
"""
Test output format options
"""
import subprocess
import sys
import json
from pathlib import Path
from experiment_logger import ExperimentTracker, logger

def run_cursor_agent(args: list, timeout: int = 30) -> dict:
    """Run cursor-agent with given arguments"""
    try:
        cmd = ["/Users/davell/.local/bin/cursor-agent"] + args
        logger.debug(f"Running: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
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
    except Exception as e:
        return {
            "stdout": "",
            "stderr": str(e),
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd)
        }

def test_format_text(tracker: ExperimentTracker):
    """Test --output-format text"""
    result = run_cursor_agent([
        "--print",
        "--output-format", "text",
        "What is 10 + 15? Answer with just the number."
    ])
    
    tracker.log_test(
        "format_text",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "format": "text",
            "output": result["stdout"][:500],
            "output_length": len(result["stdout"])
        },
        error=result["stderr"] if not result["success"] else None
    )

def test_format_json(tracker: ExperimentTracker):
    """Test --output-format json"""
    result = run_cursor_agent([
        "--print",
        "--output-format", "json",
        "What is 20 + 30? Answer with just the number."
    ])
    
    # Try to parse as JSON
    json_valid = False
    parsed_data = None
    if result["success"]:
        try:
            parsed_data = json.loads(result["stdout"])
            json_valid = True
        except json.JSONDecodeError as e:
            logger.warning(f"   JSON parse error: {e}")
    
    tracker.log_test(
        "format_json",
        success=result["success"] and json_valid,
        details={
            "format": "json",
            "output": result["stdout"][:500],
            "json_valid": json_valid,
            "parsed_keys": list(parsed_data.keys()) if parsed_data else None
        },
        error=result["stderr"] if not result["success"] else "Invalid JSON"
    )
    
    return parsed_data

def test_format_stream_json(tracker: ExperimentTracker):
    """Test --output-format stream-json"""
    result = run_cursor_agent([
        "--print",
        "--output-format", "stream-json",
        "Say the word 'test' three times."
    ])
    
    # Try to parse each line as JSON
    lines_valid = []
    if result["success"] and result["stdout"]:
        for line in result["stdout"].strip().split('\n'):
            if line.strip():
                try:
                    json.loads(line)
                    lines_valid.append(True)
                except json.JSONDecodeError:
                    lines_valid.append(False)
    
    all_valid = all(lines_valid) if lines_valid else False
    
    tracker.log_test(
        "format_stream_json",
        success=result["success"] and all_valid,
        details={
            "format": "stream-json",
            "output_preview": result["stdout"][:500],
            "total_lines": len(lines_valid),
            "valid_json_lines": sum(lines_valid),
            "all_lines_valid": all_valid
        },
        error=result["stderr"] if not result["success"] else None
    )

def test_stream_partial_output(tracker: ExperimentTracker):
    """Test --stream-partial-output with stream-json"""
    result = run_cursor_agent([
        "--print",
        "--output-format", "stream-json",
        "--stream-partial-output",
        "Count from 1 to 5."
    ])
    
    tracker.log_test(
        "stream_partial_output",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "format": "stream-json with partial output",
            "output_preview": result["stdout"][:500],
            "output_length": len(result["stdout"])
        },
        error=result["stderr"] if not result["success"] else None
    )

def test_format_with_resume(tracker: ExperimentTracker):
    """Test output formats with --resume"""
    # Create a chat
    create_result = run_cursor_agent(["create-chat"])
    if not create_result["success"]:
        tracker.log_test(
            "format_with_resume",
            success=False,
            details={"error": "Failed to create chat"},
            error=create_result["stderr"]
        )
        return
    
    chat_id = create_result["stdout"].strip()
    
    # Test with JSON format
    result = run_cursor_agent([
        "--print",
        "--output-format", "json",
        "--resume", chat_id,
        "Hello, this is a test. Just say hi back."
    ])
    
    json_valid = False
    if result["success"]:
        try:
            json.loads(result["stdout"])
            json_valid = True
        except json.JSONDecodeError:
            pass
    
    tracker.log_test(
        "format_json_with_resume",
        success=result["success"] and json_valid,
        details={
            "chat_id": chat_id,
            "format": "json",
            "output_preview": result["stdout"][:500],
            "json_valid": json_valid
        },
        error=result["stderr"] if not result["success"] else None
    )

def main():
    logger.info("=" * 70)
    logger.info("OUTPUT FORMAT TESTS")
    logger.info("=" * 70)
    
    tracker = ExperimentTracker("output_formats")
    
    logger.info("\n1. Testing --output-format text...")
    test_format_text(tracker)
    
    logger.info("\n2. Testing --output-format json...")
    test_format_json(tracker)
    
    logger.info("\n3. Testing --output-format stream-json...")
    test_format_stream_json(tracker)
    
    logger.info("\n4. Testing --stream-partial-output...")
    test_stream_partial_output(tracker)
    
    logger.info("\n5. Testing formats with --resume...")
    test_format_with_resume(tracker)
    
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

