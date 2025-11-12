#!/usr/bin/env python3
"""
Test model selection
"""
import subprocess
import sys
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

def test_model(tracker: ExperimentTracker, model_name: str):
    """Test a specific model"""
    result = run_cursor_agent([
        "--print",
        "--model", model_name,
        "Say 'test' and nothing else."
    ])
    
    tracker.log_test(
        f"model_{model_name.replace('-', '_')}",
        success=result["success"] and len(result["stdout"]) > 0,
        details={
            "model": model_name,
            "output": result["stdout"][:200],
            "stderr": result["stderr"][:200] if result["stderr"] else None
        },
        error=result["stderr"] if not result["success"] else None
    )
    
    return result["success"]

def main():
    logger.info("=" * 70)
    logger.info("MODEL SELECTION TESTS")
    logger.info("=" * 70)
    
    tracker = ExperimentTracker("model_selection")
    
    # Test models mentioned in help text
    models_to_test = [
        "gpt-5",
        "sonnet-4",
        "sonnet-4-thinking",
    ]
    
    # Also test some common aliases
    models_to_test.extend([
        "claude-sonnet-4",
        "gpt-4",
    ])
    
    for model in models_to_test:
        logger.info(f"\nTesting model: {model}...")
        test_model(tracker, model)
    
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

