"""Parse cursor-agent stream-json output to extract rich content"""

import json
from typing import Dict, Any, List, Optional


class StreamJsonParser:
    """Parser for cursor-agent's --output-format stream-json"""
    
    def __init__(self):
        self.thinking_parts: List[str] = []
        self.tool_calls: List[Dict[str, Any]] = []
        self.final_result: Optional[str] = None
        self.assistant_messages: List[str] = []
    
    def parse_stream(self, stream_output: str) -> Dict[str, Any]:
        """Parse complete stream-json output
        
        Args:
            stream_output: Complete stdout from cursor-agent with stream-json format
            
        Returns:
            Dict with extracted content:
            {
                "text": str,  # Final result text
                "thinking": str or None,  # Combined thinking content
                "tool_calls": List[Dict] or None,  # Tool call events
                "assistant_messages": List[str]  # Intermediate assistant messages
            }
        """
        self._reset()
        
        # Parse each line as JSON
        for line in stream_output.strip().split('\n'):
            if not line:
                continue
            
            try:
                event = json.loads(line)
                self._process_event(event)
            except json.JSONDecodeError:
                # Skip malformed lines
                continue
        
        return self._build_result()
    
    def _reset(self):
        """Reset parser state"""
        self.thinking_parts = []
        self.tool_calls = []
        self.final_result = None
        self.assistant_messages = []
    
    def _process_event(self, event: Dict[str, Any]):
        """Process a single stream event"""
        event_type = event.get('type')
        subtype = event.get('subtype')
        
        if event_type == 'thinking':
            self._process_thinking(event, subtype)
        elif event_type == 'tool_call':
            self._process_tool_call(event, subtype)
        elif event_type == 'assistant':
            self._process_assistant_message(event)
        elif event_type == 'result':
            self._process_result(event)
    
    def _process_thinking(self, event: Dict[str, Any], subtype: Optional[str]):
        """Extract thinking/reasoning content"""
        if subtype == 'delta':
            # Streaming thinking text
            text = event.get('text', '')
            if text:
                self.thinking_parts.append(text)
        elif subtype == 'completed':
            # Full thinking block (some versions may send this)
            text = event.get('text', '')
            if text and not self.thinking_parts:
                self.thinking_parts = [text]
    
    def _process_tool_call(self, event: Dict[str, Any], subtype: Optional[str]):
        """Extract tool call information"""
        if subtype == 'completed':
            # Only store completed tool calls
            tool_call_data = event.get('tool_call', {})
            
            # Extract shell command info
            shell_tool = tool_call_data.get('shellToolCall', {})
            if shell_tool:
                args = shell_tool.get('args', {})
                result = shell_tool.get('result', {})
                success_data = result.get('success', {})
                
                tool_info = {
                    "name": "run_terminal_cmd",
                    "command": args.get('command', ''),
                    "explanation": f"Execute shell command: {args.get('command', '')}",
                    "arguments": {
                        "command": args.get('command', ''),
                        "working_directory": args.get('workingDirectory', ''),
                    }
                }
                
                # Add result if available
                if success_data:
                    tool_info["result"] = {
                        "exit_code": success_data.get('exitCode'),
                        "stdout": success_data.get('stdout', ''),
                        "stderr": success_data.get('stderr', ''),
                        "execution_time_ms": success_data.get('executionTime', 0)
                    }
                
                self.tool_calls.append(tool_info)
            
            # TODO: Add support for other tool types (read_file, write_file, etc.)
            # as we discover them in the stream output
    
    def _process_assistant_message(self, event: Dict[str, Any]):
        """Extract assistant message content"""
        message = event.get('message', {})
        content = message.get('content', [])
        
        for item in content:
            if item.get('type') == 'text':
                text = item.get('text', '')
                if text:
                    self.assistant_messages.append(text)
    
    def _process_result(self, event: Dict[str, Any]):
        """Extract final result"""
        if event.get('subtype') == 'success':
            self.final_result = event.get('result', '')
    
    def _build_result(self) -> Dict[str, Any]:
        """Build final parsed result"""
        # Combine thinking parts
        thinking = ''.join(self.thinking_parts) if self.thinking_parts else None
        
        # Use final result, or combine assistant messages if no result
        text = self.final_result
        if not text and self.assistant_messages:
            text = '\n\n'.join(self.assistant_messages)
        if not text:
            text = ''
        
        return {
            "text": text,
            "thinking": thinking,
            "tool_calls": self.tool_calls if self.tool_calls else None,
            "assistant_messages": self.assistant_messages
        }


def parse_cursor_agent_output(stdout: str) -> Dict[str, Any]:
    """Convenience function to parse cursor-agent stream-json output
    
    Args:
        stdout: Complete stdout from cursor-agent with --output-format stream-json
        
    Returns:
        Dict with text, thinking, and tool_calls
    """
    parser = StreamJsonParser()
    return parser.parse_stream(stdout)

