"""Request models for API endpoints"""

from typing import Optional
from pydantic import BaseModel


class AgentPromptRequest(BaseModel):
    """Request model for sending prompts to cursor-agent"""
    prompt: str
    include_history: bool = True
    max_history_messages: Optional[int] = 20
    model: Optional[str] = None
    output_format: str = "text"
    
    class Config:
        json_schema_extra = {
            "example": {
                "prompt": "Please help me understand this code",
                "include_history": True,
                "max_history_messages": 10,
                "model": "gpt-5",
                "output_format": "text"
            }
        }

