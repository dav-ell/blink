"""Job-related models for async cursor-agent operations"""

from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Dict, Any


class JobStatus(str, Enum):
    """Status of an async job"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class Job:
    """Represents an async cursor-agent job"""
    job_id: str
    chat_id: str
    prompt: str
    status: JobStatus
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result: Optional[str] = None
    error: Optional[str] = None
    user_bubble_id: Optional[str] = None
    assistant_bubble_id: Optional[str] = None
    model: Optional[str] = None
    thinking_content: Optional[str] = None
    tool_calls: Optional[list] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = asdict(self)
        # Convert datetime objects to ISO strings
        for key in ['created_at', 'started_at', 'completed_at']:
            if data[key]:
                data[key] = data[key].isoformat()
        data['status'] = self.status.value
        return data
    
    def elapsed_seconds(self) -> Optional[float]:
        """Get elapsed time in seconds"""
        if self.started_at:
            end_time = self.completed_at or datetime.now(timezone.utc)
            return (end_time - self.started_at).total_seconds()
        return None

