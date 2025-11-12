"""Message-related Pydantic models"""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel


class MessageCreate(BaseModel):
    """Request model for creating a message"""
    text: str
    type: int = 1  # 1 = user, 2 = assistant
    
    class Config:
        json_schema_extra = {
            "example": {
                "text": "Hello, this is a test message",
                "type": 1
            }
        }


class ChatMetadata(BaseModel):
    """Chat metadata model"""
    chat_id: str
    name: Optional[str] = None
    created_at: Optional[int] = None
    created_at_iso: Optional[str] = None
    last_updated_at: Optional[int] = None
    last_updated_at_iso: Optional[str] = None
    is_archived: bool = False
    is_draft: bool = False
    total_lines_added: int = 0
    total_lines_removed: int = 0
    subtitle: Optional[str] = None
    message_count: int = 0


class Message(BaseModel):
    """Message model with content parsing"""
    bubble_id: str
    type: int
    type_label: str
    text: str
    created_at: Optional[str] = None
    has_tool_call: bool = False
    has_thinking: bool = False
    has_code: bool = False
    has_todos: bool = False
    # Separated content fields
    tool_calls: Optional[List[Dict[str, Any]]] = None
    thinking_content: Optional[str] = None
    code_blocks: Optional[List[Dict[str, Any]]] = None
    todos: Optional[List[Dict[str, Any]]] = None

