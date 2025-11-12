#!/usr/bin/env python3
"""
Master test runner for cursor-agent REST API
Runs all test suites and generates a comprehensive report
"""

import sys
import subprocess
import requests
from pathlib import Path

# ANSI color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'  # No Color

BASE_URL = "http://localhost:8000"


def print_header(text: str):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"{BLUE}{text}{NC}")
    print("=" * 70)


def print_success(text: str):
    """Print success message"""
    print(f"{GREEN}✓ {text}{NC}")


def print_error(text: str):
    """Print error message"""
    print(f"{RED}✗ {text}{NC}")


def print_warning(text: str):
    """Print warning message"""
    print(f"{YELLOW}⚠ {text}{NC}")


def check_api_server():
    """Check if API server is running"""
    try:
        response = requests.get(BASE_URL, timeout=5)
        return response.status_code == 200
    except:
        return False


def run_pytest_suite(test_file: str, name: str, markers: str = None) -> bool:
    """Run a pytest test suite"""
    print_header(f"Test Suite: {name}")
    
    cmd = ["pytest", test_file, "-v", "--tb=short"]
    if markers:
        cmd.extend(["-m", markers])
    
    result = subprocess.run(cmd, capture_output=False)
    
    if result.returncode == 0:
        print_success(f"{name} PASSED")
        return True
    else:
        print_error(f"{name} FAILED")
        return False


def main():
    """Run all test suites"""
    print_header("CURSOR-AGENT REST API - COMPREHENSIVE TEST SUITE (Python)")
    
    print("\nEnvironment:")
    print(f"  Python: {sys.executable}")
    print(f"  Base URL: {BASE_URL}")
    
    # Check if API is running
    print("\nChecking API server status...")
    if check_api_server():
        print_success("API server is running")
    else:
        print_error("API server is not running")
        print("\nPlease start the API server first:")
        print("  cd /Users/davell/Documents/github/blink/rest")
        print("  ./start_api.sh")
        return 1
    
    # Define test suites
    test_suites = [
        ("test_summary_endpoint.py", "Summary Endpoint", "not slow"),
        ("test_batch_info.py", "Batch Info Endpoint", "not slow"),
        ("test_edge_cases.py", "Edge Cases & Error Conditions", "not slow"),
        ("test_performance.py", "Performance Benchmarks", "not slow"),
        ("test_enhanced_agent_prompt.py", "Enhanced Agent Prompt", None),
        ("test_e2e_workflows.py", "End-to-End Workflows", "workflow"),
    ]
    
    # Track results
    total = len(test_suites)
    passed = 0
    failed = 0
    
    # Run each suite
    for test_file, name, markers in test_suites:
        if Path(test_file).exists():
            if run_pytest_suite(test_file, name, markers):
                passed += 1
            else:
                failed += 1
        else:
            print_warning(f"Test file not found: {test_file}")
            failed += 1
    
    # Final report
    print_header("FINAL TEST REPORT")
    
    print(f"\nTest Suites Run: {total}")
    print(f"{GREEN}  Passed: {passed}{NC}")
    if failed > 0:
        print(f"{RED}  Failed: {failed}{NC}")
    
    print("\nTest Coverage:")
    print("  ✓ Summary endpoint (GET /chats/{id}/summary)")
    print("  ✓ Batch info endpoint (POST /chats/batch-info)")
    print("  ✓ Enhanced agent prompt (show_context parameter)")
    print("  ✓ Edge cases and error conditions")
    print("  ✓ Performance benchmarks")
    print("  ✓ End-to-end user workflows")
    
    if failed == 0:
        print("\n" + "=" * 70)
        print(f"{GREEN}              ✓ ALL TESTS PASSED!{NC}")
        print("=" * 70)
        return 0
    else:
        print("\n" + "=" * 70)
        print(f"{RED}           ✗ SOME TESTS FAILED{NC}")
        print("=" * 70)
        print("\nPlease review the test output above for details.")
        return 1


if __name__ == "__main__":
    sys.exit(main())

