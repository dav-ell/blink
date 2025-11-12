"""Health check and API information endpoints"""

import os
from fastapi import APIRouter, HTTPException

from ..config import settings
from ..database import get_db_connection

router = APIRouter()


@router.get("/")
def root():
    """API information and available endpoints"""
    return {
        "name": "Cursor Chat API",
        "version": "2.0.0",
        "description": "REST API for Cursor chat database with async job support",
        "database": settings.db_path,
        "cursor_agent": {
            "installed": os.path.exists(settings.cursor_agent_path),
            "path": settings.cursor_agent_path
        },
        "endpoints": {
            "GET /": "API information",
            "GET /health": "Health check",
            "GET /chats": "List all chats with metadata",
            "GET /chats/{chat_id}": "Get all messages for a specific chat",
            "GET /chats/{chat_id}/metadata": "Get metadata for a specific chat",
            "GET /chats/{chat_id}/summary": "Get chat summary optimized for UI",
            "POST /chats/{chat_id}/messages": "Send a message to a chat (DANGEROUS - disabled by default)",
            "POST /chats/{chat_id}/agent-prompt": "Send prompt to cursor-agent (synchronous, blocks until complete)",
            "POST /chats/{chat_id}/agent-prompt-async": "Submit prompt asynchronously (NEW v2.0 - returns immediately)",
            "GET /jobs/{job_id}": "Get full job details including status and result (NEW v2.0)",
            "GET /jobs/{job_id}/status": "Quick status check for a job (NEW v2.0)",
            "GET /chats/{chat_id}/jobs": "List all jobs for a chat (NEW v2.0)",
            "DELETE /jobs/{job_id}": "Cancel a pending or processing job (NEW v2.0)",
            "POST /chats/batch-info": "Get info for multiple chats at once",
            "POST /agent/create-chat": "Create new cursor-agent chat",
            "GET /agent/models": "List available AI models"
        },
        "features": {
            "async_jobs": "Submit prompts asynchronously and poll for results (NEW v2.0)",
            "concurrent_processing": "Run multiple cursor-agent calls simultaneously (NEW v2.0)",
            "job_tracking": "Track job status with elapsed time and detailed results (NEW v2.0)",
            "chat_continuation": "Continue existing Cursor conversations seamlessly",
            "context_preview": "Get recent messages before continuing",
            "batch_operations": "Fetch multiple chat summaries at once",
            "history_management": "Automatic history via cursor-agent --resume"
        },
        "documentation": "http://localhost:8000/docs"
    }


@router.get("/health")
def health_check():
    """Check if database is accessible and return basic stats"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Count chats
        cursor.execute("SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%'")
        chat_count = cursor.fetchone()[0]
        
        # Count messages
        cursor.execute("SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'")
        message_count = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            "status": "healthy",
            "database": "accessible",
            "database_path": settings.db_path,
            "total_chats": chat_count,
            "total_messages": message_count
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Database unhealthy: {str(e)}"
        )

