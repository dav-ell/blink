"""Job management service for async cursor-agent operations"""

import threading
import uuid as uuid_lib
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict

from ..models.job import Job, JobStatus


# In-memory job storage
jobs_storage: Dict[str, Job] = {}
jobs_lock = threading.Lock()


def create_job(chat_id: str, prompt: str, model: Optional[str] = None) -> Job:
    """Create a new job and store it
    
    Args:
        chat_id: Chat UUID
        prompt: User prompt text
        model: AI model to use (defaults to sonnet-4.5-thinking)
        
    Returns:
        Created Job instance
    """
    job_id = str(uuid_lib.uuid4())
    
    # Set default model if not specified
    if model is None:
        model = "sonnet-4.5-thinking"
    
    job = Job(
        job_id=job_id,
        chat_id=chat_id,
        prompt=prompt,
        status=JobStatus.PENDING,
        created_at=datetime.now(timezone.utc),
        model=model
    )
    
    with jobs_lock:
        jobs_storage[job_id] = job
    
    return job


def get_job(job_id: str) -> Optional[Job]:
    """Get a job by ID
    
    Args:
        job_id: Job UUID
        
    Returns:
        Job instance or None if not found
    """
    with jobs_lock:
        return jobs_storage.get(job_id)


def update_job(job_id: str, **updates) -> Optional[Job]:
    """Update job fields
    
    Args:
        job_id: Job UUID
        **updates: Fields to update
        
    Returns:
        Updated Job instance or None if not found
    """
    with jobs_lock:
        job = jobs_storage.get(job_id)
        if job:
            for key, value in updates.items():
                if hasattr(job, key):
                    setattr(job, key, value)
        return job


def get_chat_jobs(chat_id: str, limit: int = 20) -> List[Job]:
    """Get all jobs for a chat, newest first
    
    Args:
        chat_id: Chat UUID
        limit: Maximum number of jobs to return
        
    Returns:
        List of Job instances, sorted by created_at descending
    """
    with jobs_lock:
        chat_jobs = [job for job in jobs_storage.values() if job.chat_id == chat_id]
    
    # Sort by created_at descending
    chat_jobs.sort(key=lambda j: j.created_at, reverse=True)
    return chat_jobs[:limit]


def cleanup_old_jobs(max_age_hours: int = 1) -> int:
    """Remove completed/failed jobs older than max_age_hours
    
    Args:
        max_age_hours: Age threshold in hours
        
    Returns:
        Number of jobs removed
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
    
    with jobs_lock:
        to_remove = []
        for job_id, job in jobs_storage.items():
            if job.status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED]:
                if job.completed_at and job.completed_at < cutoff:
                    to_remove.append(job_id)
        
        for job_id in to_remove:
            del jobs_storage[job_id]
    
    return len(to_remove)

