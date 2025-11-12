"""Cursor-agent integration service"""

import subprocess
import uuid as uuid_lib
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from ..config import settings
from ..models.job import JobStatus
from ..database import get_db_connection, save_message_to_db, update_chat_metadata
from ..utils import create_bubble_data, validate_bubble_structure
from .job_service import get_job, update_job


# Available AI models for cursor-agent
AVAILABLE_MODELS = [
    "composer-1", "auto", "sonnet-4.5", "sonnet-4.5-thinking",
    "gpt-5", "gpt-5-codex", "gpt-5-codex-high", "opus-4.1", "grok"
]


def run_cursor_agent(
    chat_id: str,
    prompt: str,
    model: Optional[str] = None,
    output_format: str = "text",
    timeout: int = 60
) -> Dict[str, Any]:
    """Execute cursor-agent CLI with chat history support
    
    Args:
        chat_id: Cursor chat ID to resume (provides history context)
        prompt: User prompt/question
        model: AI model to use (optional)
        output_format: Output format (text, json, stream-json)
        timeout: Command timeout in seconds
        
    Returns:
        Dict with stdout, stderr, returncode, success, command
    """
    try:
        # Build command
        cmd = [settings.cursor_agent_path, "--print", "--force"]
        
        # Add model if specified
        if model:
            if model not in AVAILABLE_MODELS:
                raise ValueError(f"Invalid model '{model}'. Available: {', '.join(AVAILABLE_MODELS)}")
            cmd.extend(["--model", model])
        
        # Add output format
        cmd.extend(["--output-format", output_format])
        
        # Add resume with chat ID (this provides history)
        cmd.extend(["--resume", chat_id])
        
        # Add prompt
        cmd.append(prompt)
        
        # Execute command
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0,
            "command": ' '.join(cmd)
        }
        
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": f"Command timed out after {timeout} seconds",
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd) if 'cmd' in locals() else "unknown"
        }
    except Exception as e:
        return {
            "stdout": "",
            "stderr": str(e),
            "returncode": -1,
            "success": False,
            "command": ' '.join(cmd) if 'cmd' in locals() else "unknown"
        }


def execute_job_in_background(job_id: str):
    """Execute a cursor-agent job in the background
    
    This function:
    1. Marks job as processing
    2. Writes user message to database
    3. Calls cursor-agent
    4. Writes AI response to database
    5. Updates job status (completed or failed)
    
    Args:
        job_id: Job UUID to execute
    """
    job = get_job(job_id)
    if not job:
        return
    
    try:
        # Mark as processing
        update_job(
            job_id,
            status=JobStatus.PROCESSING,
            started_at=datetime.now(timezone.utc)
        )
        
        # Get database connection
        conn = get_db_connection()
        
        try:
            # Verify chat exists
            cursor = conn.cursor()
            cursor.execute(
                "SELECT value FROM cursorDiskKV WHERE key = ?",
                (f'composerData:{job.chat_id}',)
            )
            if not cursor.fetchone():
                raise ValueError(f"Chat {job.chat_id} not found")
            
            # Start transaction
            conn.execute("BEGIN TRANSACTION")
            
            # Generate bubble IDs
            user_bubble_id = str(uuid_lib.uuid4())
            assistant_bubble_id = str(uuid_lib.uuid4())
            
            # Create and save user message bubble
            user_bubble = create_bubble_data(user_bubble_id, 1, job.prompt)
            if not validate_bubble_structure(user_bubble):
                raise ValueError("Invalid user bubble structure")
            
            save_message_to_db(conn, job.chat_id, user_bubble_id, user_bubble)
            
            # Call cursor-agent for AI response
            result = run_cursor_agent(
                chat_id=job.chat_id,
                prompt=job.prompt,
                model=job.model,
                output_format="text",
                timeout=120  # 2 minutes for async jobs
            )
            
            if not result["success"]:
                # Rollback on cursor-agent failure
                conn.rollback()
                conn.close()
                
                update_job(
                    job_id,
                    status=JobStatus.FAILED,
                    completed_at=datetime.now(timezone.utc),
                    error=f"cursor-agent failed: {result['stderr']}"
                )
                return
            
            # Parse AI response
            ai_response_text = result["stdout"].strip()
            
            # Create and save AI response bubble
            assistant_bubble = create_bubble_data(assistant_bubble_id, 2, ai_response_text)
            if not validate_bubble_structure(assistant_bubble):
                conn.rollback()
                conn.close()
                
                update_job(
                    job_id,
                    status=JobStatus.FAILED,
                    completed_at=datetime.now(timezone.utc),
                    error="Invalid assistant bubble structure"
                )
                return
            
            save_message_to_db(conn, job.chat_id, assistant_bubble_id, assistant_bubble)
            
            # Update chat metadata with both messages
            update_chat_metadata(conn, job.chat_id, [
                (user_bubble_id, 1),
                (assistant_bubble_id, 2)
            ])
            
            # Commit transaction
            conn.commit()
            conn.close()
            
            # Mark job as completed
            update_job(
                job_id,
                status=JobStatus.COMPLETED,
                completed_at=datetime.now(timezone.utc),
                result=ai_response_text,
                user_bubble_id=user_bubble_id,
                assistant_bubble_id=assistant_bubble_id
            )
            
        except Exception as e:
            conn.rollback()
            conn.close()
            raise e
            
    except Exception as e:
        # Mark job as failed
        update_job(
            job_id,
            status=JobStatus.FAILED,
            completed_at=datetime.now(timezone.utc),
            error=str(e)
        )

