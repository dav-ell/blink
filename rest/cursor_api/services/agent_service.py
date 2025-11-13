"""Cursor-agent integration service"""

import subprocess
import uuid as uuid_lib
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from ..config import settings
from ..models.job import JobStatus
from ..database import get_db_connection, save_message_to_db, update_chat_metadata, ensure_chat_exists
from ..utils import create_bubble_data, validate_bubble_structure, parse_cursor_agent_output
from .job_service import get_job, update_job
from .device_service import get_remote_chat, get_device, update_remote_chat_metadata, update_device_last_seen
from .ssh_agent_service import execute_remote_cursor_agent


# Available AI models for cursor-agent
AVAILABLE_MODELS = [
    "composer-1", "auto", "sonnet-4.5", "sonnet-4.5-thinking",
    "gpt-5", "gpt-5-codex", "gpt-5-codex-high", "grok"
]


def run_cursor_agent(
    chat_id: str,
    prompt: str,
    model: Optional[str] = None,
    output_format: str = "stream-json",
    timeout: int = 60
) -> Dict[str, Any]:
    """Execute cursor-agent CLI with chat history support
    
    Args:
        chat_id: Cursor chat ID to resume (provides history context)
        prompt: User prompt/question
        model: AI model to use (defaults to sonnet-4.5-thinking)
        output_format: Output format (text, json, stream-json)
        timeout: Command timeout in seconds
        
    Returns:
        Dict with stdout, stderr, returncode, success, command, and parsed_content (if stream-json)
    """
    try:
        # Build command
        cmd = [settings.cursor_agent_path, "--print", "--force"]
        
        # Set default model if not specified
        if model is None:
            model = "sonnet-4.5-thinking"
        
        # Add model (always specified now with default)
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
        
        response = {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0,
            "command": ' '.join(cmd)
        }
        
        # Parse stream-json output if format is stream-json
        if output_format == "stream-json" and result.returncode == 0:
            try:
                parsed = parse_cursor_agent_output(result.stdout)
                response["parsed_content"] = parsed
            except Exception as e:
                # If parsing fails, just return raw stdout
                response["parse_error"] = str(e)
        
        return response
        
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
    2. Checks if chat is local or remote
    3. Writes user message to database
    4. Calls cursor-agent (local or via SSH)
    5. Writes AI response to database
    6. Updates job status (completed or failed)
    
    Args:
        job_id: Job UUID to execute
    """
    job = get_job(job_id)
    if not job:
        return
    
    # Check if this is a remote chat
    remote_chat = get_remote_chat(job.chat_id)
    
    if remote_chat:
        # Execute on remote device
        _execute_remote_job(job_id, job, remote_chat)
    else:
        # Execute locally
        _execute_local_job(job_id, job)


def _execute_local_job(job_id: str, job):
    """Execute a local cursor-agent job
    
    Args:
        job_id: Job UUID
        job: Job object
    """
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
            # Ensure chat exists (auto-create if needed)
            was_created, metadata = ensure_chat_exists(conn, job.chat_id)
            
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
            
            # Call cursor-agent for AI response with stream-json to get rich content
            result = run_cursor_agent(
                chat_id=job.chat_id,
                prompt=job.prompt,
                model=job.model,
                output_format="stream-json",
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
            
            # Extract parsed content (text, thinking, tool_calls)
            parsed = result.get("parsed_content", {})
            ai_response_text = parsed.get("text", result["stdout"].strip())
            thinking = parsed.get("thinking")
            tool_calls = parsed.get("tool_calls")
            
            # Create and save AI response bubble with rich content
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
            
            # Mark job as completed with rich content
            update_job(
                job_id,
                status=JobStatus.COMPLETED,
                completed_at=datetime.now(timezone.utc),
                result=ai_response_text,
                thinking_content=thinking,
                tool_calls=tool_calls,
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


def _execute_remote_job(job_id: str, job, remote_chat):
    """Execute a remote cursor-agent job via SSH
    
    Args:
        job_id: Job UUID
        job: Job object
        remote_chat: RemoteChat object
    """
    try:
        # Mark as processing
        update_job(
            job_id,
            status=JobStatus.PROCESSING,
            started_at=datetime.now(timezone.utc)
        )
        
        # Get device
        device = get_device(remote_chat.device_id)
        if not device:
            update_job(
                job_id,
                status=JobStatus.FAILED,
                completed_at=datetime.now(timezone.utc),
                error=f"Device not found: {remote_chat.device_id}"
            )
            return
        
        # Execute cursor-agent remotely
        result = execute_remote_cursor_agent(
            device=device,
            chat_id=job.chat_id,
            prompt=job.prompt,
            working_directory=remote_chat.working_directory,
            model=job.model,
            output_format="stream-json"
        )
        
        if not result["success"]:
            update_job(
                job_id,
                status=JobStatus.FAILED,
                completed_at=datetime.now(timezone.utc),
                error=f"Remote cursor-agent failed: {result['stderr']}"
            )
            return
        
        # Extract parsed content
        parsed = result.get("parsed_content", {})
        if not parsed:
            # Try to parse if not already parsed
            try:
                parsed = parse_cursor_agent_output(result["stdout"])
            except Exception:
                parsed = {}
        
        ai_response_text = parsed.get("text", result["stdout"].strip())
        thinking = parsed.get("thinking")
        tool_calls = parsed.get("tool_calls")
        
        # Update remote chat metadata (message count, last message preview)
        last_message_preview = ai_response_text[:100] if ai_response_text else None
        update_remote_chat_metadata(
            chat_id=job.chat_id,
            message_count_delta=2,  # user + assistant
            last_message_preview=last_message_preview
        )
        
        # Update device last_seen
        update_device_last_seen(remote_chat.device_id)
        
        # Mark job as completed
        update_job(
            job_id,
            status=JobStatus.COMPLETED,
            completed_at=datetime.now(timezone.utc),
            result=ai_response_text,
            thinking_content=thinking,
            tool_calls=tool_calls
        )
        
    except Exception as e:
        # Mark job as failed
        update_job(
            job_id,
            status=JobStatus.FAILED,
            completed_at=datetime.now(timezone.utc),
            error=f"Remote execution error: {str(e)}"
        )

