"""Content extraction utilities for message bubbles"""

import json
from typing import Dict, Any, Optional, List


def extract_message_content(bubble: Dict) -> str:
    """Extract all content from a bubble (text, tool calls, thinking, etc.)
    
    Args:
        bubble: Message bubble dictionary
        
    Returns:
        Formatted content string
    """
    text_parts = []
    
    # Regular text
    if bubble.get('text'):
        text_parts.append(bubble['text'])
    
    # Tool calls
    if bubble.get('toolFormerData'):
        tool_data = bubble['toolFormerData']
        
        # Skip error tool calls that don't have a name
        # These are incomplete/failed tool calls with only {"additionalData": {"status": "error"}}
        if 'name' not in tool_data:
            # Check if this is just an error case
            if tool_data.get('additionalData', {}).get('status') == 'error':
                # Skip showing these error tool calls entirely
                pass
            else:
                # Unknown tool call structure - show minimal info
                text_parts.append(f"[Tool Call: incomplete data]")
        else:
            # Valid tool call with name
            tool_name = tool_data['name']
            
            # Try to parse args for better display
            raw_args = tool_data.get('rawArgs', '')
            try:
                args = json.loads(raw_args) if raw_args else {}
                if 'explanation' in args:
                    text_parts.append(f"[Tool Call: {tool_name}]\nPurpose: {args['explanation']}")
                elif 'command' in args:
                    text_parts.append(f"[Tool Call: {tool_name}]\nCommand: {args['command']}")
                else:
                    text_parts.append(f"[Tool Call: {tool_name}]")
            except:
                text_parts.append(f"[Tool Call: {tool_name}]")
    
    # Thinking/reasoning
    if bubble.get('thinking'):
        thinking = bubble['thinking']
        if isinstance(thinking, dict):
            thinking_text = thinking.get('text', str(thinking)[:200])
        else:
            thinking_text = str(thinking)[:200]
        text_parts.append(f"[Internal Reasoning]\n{thinking_text}")
    
    # Code blocks
    if bubble.get('codeBlocks'):
        code_blocks = bubble['codeBlocks']
        text_parts.append(f"[{len(code_blocks)} Code Block(s)]")
    
    # Todos
    if bubble.get('todos'):
        todos = bubble['todos']
        text_parts.append(f"[{len(todos)} Todo Item(s)]")
    
    return '\n\n'.join(text_parts) if text_parts else '[No content]'


def extract_tool_calls(bubble: Dict) -> Optional[List[Dict[str, Any]]]:
    """Extract tool calls from a bubble as structured data
    
    Args:
        bubble: Message bubble dictionary
        
    Returns:
        List of tool call dictionaries or None
    """
    if not bubble.get('toolFormerData'):
        return None
    
    tool_data = bubble['toolFormerData']
    
    # Skip error tool calls that don't have a name
    if 'name' not in tool_data:
        if tool_data.get('additionalData', {}).get('status') == 'error':
            return None
        return [{"name": "unknown", "description": "incomplete data"}]
    
    tool_name = tool_data['name']
    raw_args = tool_data.get('rawArgs', '')
    
    try:
        args = json.loads(raw_args) if raw_args else {}
        tool_call = {
            "name": tool_name,
            "explanation": args.get('explanation', ''),
            "command": args.get('command', ''),
            "arguments": args
        }
        return [tool_call]
    except:
        return [{"name": tool_name, "explanation": "", "arguments": {}}]


def extract_thinking(bubble: Dict) -> Optional[str]:
    """Extract thinking/reasoning content from a bubble
    
    Args:
        bubble: Message bubble dictionary
        
    Returns:
        Thinking text or None
    """
    if not bubble.get('thinking'):
        return None
    
    thinking = bubble['thinking']
    if isinstance(thinking, dict):
        return thinking.get('text', str(thinking))
    return str(thinking)


def extract_separated_content(bubble: Dict) -> Dict[str, Any]:
    """Extract content separated by type
    
    Args:
        bubble: Message bubble dictionary
        
    Returns:
        Dict with separated content fields
    """
    # Handle todos - may be strings or objects in database
    todos = bubble.get('todos')
    if todos and isinstance(todos, list):
        # Filter out non-dict items (strings from Cursor IDE)
        todos = [t for t in todos if isinstance(t, dict)]
        if not todos:
            todos = None
    
    # Handle code blocks - may be strings or objects
    code_blocks = bubble.get('codeBlocks')
    if code_blocks and isinstance(code_blocks, list):
        # Filter out non-dict items
        code_blocks = [cb for cb in code_blocks if isinstance(cb, dict)]
        if not code_blocks:
            code_blocks = None
    
    return {
        "text": bubble.get('text', ''),
        "tool_calls": extract_tool_calls(bubble),
        "thinking": extract_thinking(bubble),
        "code_blocks": code_blocks,
        "todos": todos
    }

