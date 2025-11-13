"""Agent prompt endpoints (sync/async) and agent-related operations"""

import json
import os
import subprocess
import uuid as uuid_lib
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, HTTPException, BackgroundTasks, Query

from ..config import settings
from ..models.request import AgentPromptRequest
from ..database import get_db_connection, save_message_to_db, update_chat_metadata, ensure_chat_exists
from ..services import run_cursor_agent, execute_job_in_background, create_job, get_chat_jobs
from ..services.agent_service import AVAILABLE_MODELS
from ..services.chat_service import create_new_chat
from ..utils import create_bubble_data, validate_bubble_structure, parse_timestamp, extract_message_content
from ..models.job import JobStatus

router = APIRouter(tags=["agent"])


@router.post("/chats/{chat_id}/agent-prompt")
def send_agent_prompt(
    chat_id: str,
    request: AgentPromptRequest,
    show_context: bool = Query(False, description="Include recent messages in response")
):
    """
    Send a prompt with manual database persistence.
    
    This endpoint:
    1. Writes user message to database
    2. Calls cursor-agent for AI response
    3. Writes AI response to database
    4. Rolls back if any step fails
    
    **Usage:**
    ```
    POST /chats/{chat_id}/agent-prompt
    {
        "prompt": "What did we discuss about authentication?",
        "include_history": true,
        "model": "sonnet-4.5-thinking",
        "output_format": "text"
    }
    ```
    """
    if not os.path.exists(settings.cursor_agent_path):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {settings.cursor_agent_path}"
        )
    
    conn = get_db_connection()
    
    try:
        # Ensure chat exists (auto-create if needed)
        was_created, metadata = ensure_chat_exists(conn, chat_id)
        
        # Start transaction
        conn.execute("BEGIN TRANSACTION")
        
        # Generate bubble IDs
        user_bubble_id = str(uuid_lib.uuid4())
        assistant_bubble_id = str(uuid_lib.uuid4())
        
        # Create and validate user message bubble
        user_bubble = create_bubble_data(user_bubble_id, 1, request.prompt)
        if not validate_bubble_structure(user_bubble):
            raise ValueError("Invalid user bubble structure")
        
        # Save user message
        save_message_to_db(conn, chat_id, user_bubble_id, user_bubble)
        
        # Call cursor-agent for AI response with stream-json to get rich content
        result = run_cursor_agent(
            chat_id=chat_id,
            prompt=request.prompt,
            model=request.model,
            output_format="stream-json",  # Always use stream-json to get tool calls and thinking
            timeout=90
        )
        
        if not result["success"]:
            # Rollback on cursor-agent failure
            conn.rollback()
            conn.close()
            raise HTTPException(
                status_code=500,
                detail=f"cursor-agent failed: {result['stderr']}"
            )
        
        # Extract parsed content (text, thinking, tool_calls)
        parsed = result.get("parsed_content", {})
        ai_response_text = parsed.get("text", result["stdout"].strip())
        thinking = parsed.get("thinking")
        tool_calls = parsed.get("tool_calls")
        
        # Create and validate AI response bubble with rich content
        assistant_bubble = create_bubble_data(
            assistant_bubble_id,
            2,  # assistant message type
            ai_response_text,
            thinking=thinking,
            tool_calls=tool_calls
        )
        if not validate_bubble_structure(assistant_bubble):
            conn.rollback()
            conn.close()
            raise ValueError("Invalid assistant bubble structure")
        
        # Save AI response
        save_message_to_db(conn, chat_id, assistant_bubble_id, assistant_bubble)
        
        # Update chat metadata with both messages
        update_chat_metadata(conn, chat_id, [
            (user_bubble_id, 1),
            (assistant_bubble_id, 2)
        ])
        
        # Commit transaction
        conn.commit()
        
        # Build response with rich content
        response_obj = {
            "status": "success",
            "chat_id": chat_id,
            "prompt": request.prompt,
            "model": request.model or "default",
            "output_format": "stream-json",
            "response": ai_response_text,
            "thinking_content": thinking,
            "tool_calls": tool_calls,
            "user_bubble_id": user_bubble_id,
            "assistant_bubble_id": assistant_bubble_id,
            "metadata": {
                "command": result["command"],
                "returncode": result["returncode"],
                "stderr": result["stderr"] if result["stderr"] else None
            }
        }
        
        return response_obj
        
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error sending message: {str(e)}"
        )
    finally:
        conn.close()


@router.post("/chats/{chat_id}/agent-prompt-async")
def submit_prompt_async(
    chat_id: str,
    request: AgentPromptRequest,
    background_tasks: BackgroundTasks
):
    """
    Submit a prompt asynchronously and return immediately with job ID
    
    The job will be processed in the background. Use GET /jobs/{job_id}
    to check status and retrieve the result when complete.
    
    **Usage:**
    ```
    POST /chats/{chat_id}/agent-prompt-async
    {
        "prompt": "What did we discuss about authentication?",
        "model": "sonnet-4.5-thinking"
    }
    
    Response:
    {
        "job_id": "abc-123-def",
        "status": "pending",
        "chat_id": "...",
        "message": "Job submitted successfully"
    }
    ```
    """
    if not os.path.exists(settings.cursor_agent_path):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {settings.cursor_agent_path}"
        )
    
    # Ensure chat exists (auto-create if needed)
    try:
        conn = get_db_connection()
        was_created, metadata = ensure_chat_exists(conn, chat_id)
        conn.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error ensuring chat exists: {str(e)}")
    
    # Create job
    job = create_job(chat_id, request.prompt, request.model)
    
    # Schedule background execution
    background_tasks.add_task(execute_job_in_background, job.job_id)
    
    return {
        "job_id": job.job_id,
        "status": job.status.value,
        "chat_id": job.chat_id,
        "message": "Job submitted successfully",
        "created_at": job.created_at.isoformat()
    }


@router.post("/agent/create-chat")
def create_agent_chat():
    """
    Create a new cursor-agent chat
    
    Returns a new chat ID that can be used with /chats/{chat_id}/agent-prompt
    to build a conversation with full history tracking.
    
    **Example:**
    ```
    POST /agent/create-chat
    
    Response:
    {
        "status": "success",
        "chat_id": "7c1283c9-bc7d-480a-8dc9-1ed382251471"
    }
    ```
    """
    if not os.path.exists(settings.cursor_agent_path):
        raise HTTPException(
            status_code=503,
            detail=f"cursor-agent not found at {settings.cursor_agent_path}"
        )
    
    try:
        result = subprocess.run(
            [settings.cursor_agent_path, "create-chat"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to create chat: {result.stderr}"
            )
        
        chat_id = result.stdout.strip()
        
        return {
            "status": "success",
            "chat_id": chat_id,
            "message": "Chat created successfully"
        }
        
    except subprocess.TimeoutExpired:
        raise HTTPException(
            status_code=500,
            detail="create-chat command timed out"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error creating chat: {str(e)}"
        )


@router.get("/agent/models")
def list_available_models():
    """
    List all available AI models for cursor-agent
    
    Returns the list of models that can be used with the --model parameter.
    """
    return {
        "models": AVAILABLE_MODELS,
        "default": "sonnet-4.5-thinking",
        "recommended": ["sonnet-4.5-thinking", "sonnet-4.5", "gpt-5"]
    }


@router.get("/chats/{chat_id}/summary")
def get_chat_summary(
    chat_id: str,
    recent_count: int = Query(5, description="Number of recent messages to include")
):
    """
    Get chat summary optimized for continuation UI
    
    Returns chat metadata and recent messages in a format optimized for
    displaying in iOS/Flutter apps before continuing a conversation.
    
    **Usage:**
    ```
    GET /chats/{chat_id}/summary?recent_count=5
    ```
    
    **Response:**
    ```json
    {
      "chat_id": "...",
      "name": "Authentication Implementation",
      "created_at": "...",
      "message_count": 23,
      "last_updated": "...",
      "recent_messages": [...],
      "can_continue": true
    }
    ```
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Get chat metadata
        cursor.execute("""
            SELECT value 
            FROM cursorDiskKV 
            WHERE key = ?
        """, (f'composerData:{chat_id}',))
        
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail=f"Chat {chat_id} not found")
        
        metadata = json.loads(row[0])
        
        # Get recent messages
        cursor.execute("""
            SELECT key, value FROM cursorDiskKV 
            WHERE key LIKE ? 
            ORDER BY key
        """, (f'bubbleId:{chat_id}:%',))
        
        # Fetch all and sort by createdAt, then take last N
        all_messages = []
        for key, value in cursor.fetchall():
            try:
                bubble = json.loads(value)
                content = extract_message_content(bubble)
                created_at = bubble.get('createdAt')
                all_messages.append({
                    "role": "user" if bubble.get('type') == 1 else "assistant",
                    "text": content[:200] + "..." if len(content) > 200 else content,
                    "created_at": created_at,
                    "has_code": bool(bubble.get('codeBlocks')),
                    "has_thinking": bool(bubble.get('thinking')),
                    "has_tool_call": bool(bubble.get('toolFormerData')),
                    "has_todos": bool(bubble.get('todos')),
                    "_sort_key": created_at or ""
                })
            except (json.JSONDecodeError, KeyError):
                continue
        
        # Sort by timestamp and take most recent N
        all_messages.sort(key=lambda m: m['_sort_key'])
        if recent_count == 0:
            messages = []
        elif len(all_messages) > recent_count:
            messages = all_messages[-recent_count:]
        else:
            messages = all_messages
        
        # Remove sort key from output
        for m in messages:
            m.pop('_sort_key', None)
        
        # Determine if chat can be continued
        can_continue = True  # All cursor chats can be continued with --resume
        
        return {
            "chat_id": chat_id,
            "name": metadata.get('name', 'Untitled'),
            "created_at": parse_timestamp(metadata.get('createdAt')),
            "last_updated": parse_timestamp(metadata.get('lastUpdatedAt')),
            "message_count": len(metadata.get('fullConversationHeadersOnly', [])),
            "recent_messages": messages,
            "can_continue": can_continue,
            "has_code": any(m.get('has_code') for m in messages),
            "has_todos": any(m.get('has_todos') for m in messages),
            "participants": ["user", "assistant"]
        }
        
    finally:
        conn.close()


@router.post("/chats/batch-info")
def get_batch_chat_info(chat_ids: List[str]):
    """
    Get information for multiple chats at once
    
    Optimized for iOS list views where you need summary info for multiple chats.
    
    **Request:**
    ```json
    ["chat_id_1", "chat_id_2", "chat_id_3"]
    ```
    
    **Response:**
    ```json
    {
      "chats": [
        {"chat_id": "...", "name": "...", "message_count": 10},
        {"chat_id": "...", "name": "...", "message_count": 5}
      ],
      "not_found": ["chat_id_that_doesnt_exist"]
    }
    ```
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    chats = []
    not_found = []
    
    try:
        for chat_id in chat_ids:
            cursor.execute("""
                SELECT value 
                FROM cursorDiskKV 
                WHERE key = ?
            """, (f'composerData:{chat_id}',))
            
            row = cursor.fetchone()
            if not row:
                not_found.append(chat_id)
                continue
            
            try:
                metadata = json.loads(row[0])
                chats.append({
                    "chat_id": chat_id,
                    "name": metadata.get('name', 'Untitled'),
                    "created_at": parse_timestamp(metadata.get('createdAt')),
                    "last_updated": parse_timestamp(metadata.get('lastUpdatedAt')),
                    "message_count": len(metadata.get('fullConversationHeadersOnly', [])),
                    "is_archived": metadata.get('isArchived', False),
                    "is_draft": metadata.get('isDraft', False)
                })
            except (json.JSONDecodeError, KeyError):
                not_found.append(chat_id)
        
        return {
            "chats": chats,
            "not_found": not_found,
            "total_requested": len(chat_ids),
            "total_found": len(chats)
        }
        
    finally:
        conn.close()


@router.get("/chats/{chat_id}/jobs")
def list_chat_jobs_endpoint(
    chat_id: str,
    limit: int = Query(20, description="Maximum number of jobs to return"),
    status_filter: Optional[str] = Query(None, description="Filter by status (pending, processing, completed, failed)")
):
    """
    List all jobs for a chat
    
    **Usage:**
    ```
    GET /chats/{chat_id}/jobs?limit=10&status_filter=processing
    ```
    
    **Response:**
    ```json
    {
        "chat_id": "...",
        "total": 15,
        "jobs": [
            {
                "job_id": "...",
                "status": "processing",
                "prompt": "...",
                "created_at": "...",
                "elapsed_seconds": 5.2
            },
            ...
        ]
    }
    ```
    """
    jobs = get_chat_jobs(chat_id, limit)
    
    # Filter by status if requested
    if status_filter:
        try:
            filter_status = JobStatus(status_filter)
            jobs = [j for j in jobs if j.status == filter_status]
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid status filter. Valid values: {[s.value for s in JobStatus]}"
            )
    
    jobs_data = []
    for job in jobs:
        job_dict = job.to_dict()
        job_dict['elapsed_seconds'] = job.elapsed_seconds()
        jobs_data.append(job_dict)
    
    return {
        "chat_id": chat_id,
        "total": len(jobs_data),
        "jobs": jobs_data
    }

