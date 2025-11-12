"""Timestamp parsing utilities"""

from datetime import datetime
from typing import Optional


def parse_timestamp(ts_value) -> Optional[str]:
    """Parse timestamp to ISO format
    
    Args:
        ts_value: Timestamp as int/float (milliseconds) or string
        
    Returns:
        ISO format string or None if parsing fails
    """
    if not ts_value:
        return None
    try:
        if isinstance(ts_value, str):
            return ts_value
        if isinstance(ts_value, (int, float)):
            return datetime.fromtimestamp(ts_value / 1000.0).isoformat()
    except Exception:
        return None

