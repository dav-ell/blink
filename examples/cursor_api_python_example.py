#!/usr/bin/env python3
"""
Cursor API Python Example
Demonstrates how to make direct API calls to Cursor's backend using extracted credentials
"""

import requests
import json
import os
from typing import Optional, Dict, List

class CursorAPI:
    """
    Client for Cursor's backend API
    
    Usage:
        # Set environment variables:
        export CURSOR_AUTH_TOKEN="your_token_here"
        export CURSOR_USER_ID="auth0|user_..."
        
        # Or pass directly:
        api = CursorAPI(
            auth_token="your_token",
            user_id="auth0|user_..."
        )
        
        response = api.chat("Explain Python decorators")
        print(response)
    """
    
    def __init__(
        self,
        auth_token: Optional[str] = None,
        user_id: Optional[str] = None,
        base_url: str = "https://api2.cursor.sh"
    ):
        self.auth_token = auth_token or os.getenv('CURSOR_AUTH_TOKEN')
        self.user_id = user_id or os.getenv('CURSOR_USER_ID')
        self.base_url = base_url
        
        if not self.auth_token:
            raise ValueError(
                "Auth token required. Set CURSOR_AUTH_TOKEN environment variable "
                "or pass auth_token parameter"
            )
        
        if not self.user_id:
            raise ValueError(
                "User ID required. Set CURSOR_USER_ID environment variable "
                "or pass user_id parameter"
            )
        
        self.session = requests.Session()
        self.session.headers.update(self._get_default_headers())
    
    def _get_default_headers(self) -> Dict[str, str]:
        """Get default headers for API requests"""
        return {
            "Authorization": f"Bearer {self.auth_token}",
            "Content-Type": "application/json",
            "X-Cursor-User-Id": self.user_id,
            "X-Cursor-Client-Version": "2.0.69",
            "User-Agent": "Cursor/2.0.69"
        }
    
    def chat(
        self,
        message: str,
        model: str = "claude-sonnet-4",
        max_tokens: int = 2000,
        temperature: float = 0.7,
        system_prompt: Optional[str] = None
    ) -> str:
        """
        Send a chat message to Cursor's backend
        
        Args:
            message: User's message
            model: Model to use (e.g., "claude-sonnet-4", "gpt-4")
            max_tokens: Maximum tokens in response
            temperature: Sampling temperature
            system_prompt: Optional system prompt
        
        Returns:
            Assistant's response text
        """
        messages = []
        
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.append({"role": "user", "content": message})
        
        payload = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False
        }
        
        response = self.session.post(
            f"{self.base_url}/v1/chat/completions",
            json=payload,
            timeout=60
        )
        
        response.raise_for_status()
        data = response.json()
        
        return data['choices'][0]['message']['content']
    
    def chat_with_code_context(
        self,
        message: str,
        code_context: str,
        file_path: Optional[str] = None,
        model: str = "claude-sonnet-4"
    ) -> str:
        """
        Send a message with code context (like Cursor does)
        
        Args:
            message: User's question
            code_context: Code to provide as context
            file_path: Optional file path for context
            model: Model to use
        
        Returns:
            Assistant's response
        """
        # Build context like Cursor does
        context_parts = []
        
        if file_path:
            context_parts.append(f"# File: {file_path}")
        
        context_parts.append("```")
        context_parts.append(code_context)
        context_parts.append("```")
        context_parts.append("")
        context_parts.append(f"Question: {message}")
        
        full_message = "\n".join(context_parts)
        
        return self.chat(full_message, model=model)
    
    def list_models(self) -> List[Dict]:
        """
        List available models
        
        Returns:
            List of available models
        """
        response = self.session.get(
            f"{self.base_url}/v1/models",
            timeout=30
        )
        
        response.raise_for_status()
        data = response.json()
        
        return data.get('data', [])
    
    def validate_token(self) -> bool:
        """
        Validate authentication token
        
        Returns:
            True if token is valid, False otherwise
        """
        try:
            # Try to list models as a validation check
            self.list_models()
            return True
        except requests.exceptions.HTTPError as e:
            if e.response.status_code in [401, 403]:
                return False
            raise

# Example usage functions

def example_simple_chat():
    """Example: Simple chat"""
    print("Example 1: Simple Chat")
    print("=" * 60)
    
    api = CursorAPI()
    
    response = api.chat("Explain Python list comprehensions in one sentence.")
    print(f"Response: {response}\n")


def example_with_code_context():
    """Example: Chat with code context"""
    print("Example 2: Chat with Code Context")
    print("=" * 60)
    
    api = CursorAPI()
    
    code = """
def calculate_fibonacci(n):
    if n <= 1:
        return n
    return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)
    """
    
    response = api.chat_with_code_context(
        message="How can I optimize this function?",
        code_context=code,
        file_path="fibonacci.py"
    )
    
    print(f"Response: {response}\n")


def example_validate_token():
    """Example: Validate token"""
    print("Example 3: Validate Token")
    print("=" * 60)
    
    api = CursorAPI()
    
    is_valid = api.validate_token()
    print(f"Token valid: {is_valid}\n")


def example_list_models():
    """Example: List available models"""
    print("Example 4: List Models")
    print("=" * 60)
    
    api = CursorAPI()
    
    try:
        models = api.list_models()
        print(f"Available models: {len(models)}")
        for model in models[:5]:
            print(f"  - {model.get('id', 'Unknown')}")
    except Exception as e:
        print(f"Could not list models: {e}")
    print()


def main():
    """Run all examples"""
    print("\n╔══════════════════════════════════════════════════════════╗")
    print("║        Cursor API Python Examples                       ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    
    # Check environment variables
    if not os.getenv('CURSOR_AUTH_TOKEN'):
        print("❌ CURSOR_AUTH_TOKEN not set!")
        print("\nTo run these examples:")
        print("  1. Capture your auth token using: ./tools/capture_cursor_auth.sh")
        print("  2. Set environment variables:")
        print("     export CURSOR_AUTH_TOKEN='your_token'")
        print("     export CURSOR_USER_ID='auth0|user_...'")
        print("  3. Run this script again\n")
        return
    
    if not os.getenv('CURSOR_USER_ID'):
        print("❌ CURSOR_USER_ID not set!")
        print("\nFound in: tools/cursor_auth_extraction_report.md")
        print("Or run: ./tools/extract_cursor_auth.py\n")
        return
    
    print("✅ Environment variables set\n")
    
    try:
        # Run examples
        example_validate_token()
        example_simple_chat()
        example_with_code_context()
        example_list_models()
        
        print("✅ All examples completed successfully!")
        
    except requests.exceptions.HTTPError as e:
        print(f"\n❌ API Error: {e}")
        print(f"Response: {e.response.text if e.response else 'No response'}")
        
        if e.response and e.response.status_code in [401, 403]:
            print("\n💡 Tip: Your token may have expired. Capture a new one:")
            print("   ./tools/capture_cursor_auth.sh")
    
    except Exception as e:
        print(f"\n❌ Error: {e}")


if __name__ == "__main__":
    main()

