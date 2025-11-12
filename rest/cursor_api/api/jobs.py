"""Job management endpoints for async operations"""

from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, Query

from ..models.job import JobStatus
from ..services import get_job, get_chat_jobs, update_job

router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.get("/{job_id}")
def get_job_details(job_id: str):
    """
    Get full job details including status and result
    
    **Response for completed job:**
    ```json
    {
        "job_id": "...",
        "chat_id": "...",
        "status": "completed",
        "prompt": "...",
        "result": "AI response text...",
        "created_at": "2025-11-12T10:00:00Z",
        "started_at": "2025-11-12T10:00:01Z",
        "completed_at": "2025-11-12T10:00:15Z",
        "elapsed_seconds": 14.5,
        "user_bubble_id": "...",
        "assistant_bubble_id": "..."
    }
    ```
    
    **Response for failed job:**
    ```json
    {
        "job_id": "...",
        "status": "failed",
        "error": "cursor-agent failed: ...",
        ...
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    response = job.to_dict()
    response['elapsed_seconds'] = job.elapsed_seconds()
    
    return response


@router.get("/{job_id}/status")
def get_job_status_quick(job_id: str):
    """
    Quick status check (lighter response than full job details)
    
    **Response:**
    ```json
    {
        "job_id": "...",
        "status": "processing",
        "elapsed_seconds": 5.2
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    return {
        "job_id": job.job_id,
        "status": job.status.value,
        "elapsed_seconds": job.elapsed_seconds()
    }


@router.delete("/{job_id}")
def cancel_job(job_id: str):
    """
    Cancel a pending or processing job
    
    Note: Jobs that are already being executed by cursor-agent cannot be
    interrupted, but will be marked as cancelled once they complete.
    
    **Response:**
    ```json
    {
        "job_id": "...",
        "status": "cancelled",
        "message": "Job cancelled successfully"
    }
    ```
    """
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    
    if job.status in [JobStatus.COMPLETED, JobStatus.FAILED]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel job with status: {job.status.value}"
        )
    
    update_job(
        job_id,
        status=JobStatus.CANCELLED,
        completed_at=datetime.now(timezone.utc),
        error="Cancelled by user"
    )
    
    return {
        "job_id": job_id,
        "status": "cancelled",
        "message": "Job cancelled successfully"
    }

