"""SSH-based cursor-agent execution service"""

import subprocess
import shlex
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
import time

from ..config import settings
from ..models.device import Device

# Configure logger for SSH operations
logger = logging.getLogger(__name__)


def execute_remote_cursor_agent(
    device: Device,
    chat_id: str,
    prompt: str,
    working_directory: str,
    model: Optional[str] = None,
    output_format: str = "stream-json",
) -> Dict[str, Any]:
    """Execute cursor-agent CLI on a remote device via SSH
    
    Args:
        device: Device configuration
        chat_id: Cursor chat ID to resume
        prompt: User prompt/question
        working_directory: Remote working directory
        model: AI model to use
        output_format: Output format (text, json, stream-json)
        
    Returns:
        Dict with stdout, stderr, returncode, success, command
    """
    start_time = time.time()
    
    logger.info(
        f"[SSH Remote Exec] Starting remote cursor-agent execution\n"
        f"  Device: {device.name} ({device.id})\n"
        f"  Target: {device.username}@{device.hostname}:{device.port}\n"
        f"  Chat ID: {chat_id}\n"
        f"  Working Directory: {working_directory}\n"
        f"  Model: {model or 'default'}\n"
        f"  Output Format: {output_format}\n"
        f"  Prompt Length: {len(prompt)} chars"
    )
    
    try:
        # Get cursor-agent path (use device-specific or default)
        cursor_agent_path = device.cursor_agent_path or settings.default_cursor_agent_path
        logger.debug(f"[SSH Remote Exec] Using cursor-agent path: {cursor_agent_path}")
        
        # Set default model if not specified
        if model is None:
            model = "sonnet-4.5-thinking"
            logger.debug(f"[SSH Remote Exec] Using default model: {model}")
        
        # Build cursor-agent command
        agent_cmd_parts = [
            cursor_agent_path,
            "--print",
            "--force",
            "--model", model,
            "--output-format", output_format,
            "--resume", chat_id,
            prompt
        ]
        
        # Quote the prompt properly for shell execution
        agent_cmd = " ".join(shlex.quote(part) for part in agent_cmd_parts)
        
        # Build full SSH command with cd to working directory
        full_cmd = f"cd {shlex.quote(working_directory)} && {agent_cmd}"
        
        # Build SSH command
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",  # Don't prompt for passwords
            "-o", "StrictHostKeyChecking=no",  # Accept new host keys automatically
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            full_cmd
        ]
        
        logger.info(
            f"[SSH Remote Exec] Executing SSH command\n"
            f"  SSH Timeout: {settings.ssh_timeout}s\n"
            f"  Connect Timeout: {settings.ssh_connect_timeout}s\n"
            f"  Command: {' '.join(ssh_cmd[:6])}... [command truncated]"
        )
        
        # Execute SSH command
        exec_start = time.time()
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=settings.ssh_timeout
        )
        exec_duration = time.time() - exec_start
        
        total_duration = time.time() - start_time
        
        if result.returncode == 0:
            logger.info(
                f"[SSH Remote Exec] ✅ Command executed successfully\n"
                f"  Device: {device.name}\n"
                f"  Return Code: {result.returncode}\n"
                f"  Execution Time: {exec_duration:.2f}s\n"
                f"  Total Time: {total_duration:.2f}s\n"
                f"  Stdout Length: {len(result.stdout)} chars\n"
                f"  Stderr Length: {len(result.stderr)} chars"
            )
        else:
            logger.error(
                f"[SSH Remote Exec] ❌ Command failed\n"
                f"  Device: {device.name}\n"
                f"  Return Code: {result.returncode}\n"
                f"  Execution Time: {exec_duration:.2f}s\n"
                f"  Total Time: {total_duration:.2f}s\n"
                f"  Stderr: {result.stderr[:500]}"
            )
        
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0,
            "command": " ".join(ssh_cmd),
            "device_id": device.id,
            "device_name": device.name
        }
        
    except subprocess.TimeoutExpired as e:
        total_duration = time.time() - start_time
        logger.error(
            f"[SSH Remote Exec] ⏱️ SSH command TIMED OUT\n"
            f"  Device: {device.name} ({device.username}@{device.hostname}:{device.port})\n"
            f"  Timeout Threshold: {settings.ssh_timeout}s\n"
            f"  Total Time: {total_duration:.2f}s\n"
            f"  Possible Causes:\n"
            f"    - Network latency or packet loss\n"
            f"    - Remote command taking too long\n"
            f"    - Firewall blocking connection\n"
            f"    - SSH server not responding"
        )
        return {
            "stdout": "",
            "stderr": f"SSH command timed out after {settings.ssh_timeout} seconds",
            "returncode": -1,
            "success": False,
            "command": " ".join(ssh_cmd) if 'ssh_cmd' in locals() else "unknown",
            "device_id": device.id,
            "device_name": device.name
        }
    except Exception as e:
        total_duration = time.time() - start_time
        error_type = type(e).__name__
        logger.error(
            f"[SSH Remote Exec] 💥 SSH execution error\n"
            f"  Device: {device.name} ({device.username}@{device.hostname}:{device.port})\n"
            f"  Error Type: {error_type}\n"
            f"  Error Message: {str(e)}\n"
            f"  Total Time: {total_duration:.2f}s\n"
            f"  Troubleshooting:\n"
            f"    - Check network connectivity to {device.hostname}\n"
            f"    - Verify SSH key authentication is set up\n"
            f"    - Ensure port {device.port} is accessible\n"
            f"    - Check username '{device.username}' has proper permissions",
            exc_info=True
        )
        return {
            "stdout": "",
            "stderr": f"SSH execution error: {str(e)}",
            "returncode": -1,
            "success": False,
            "command": " ".join(ssh_cmd) if 'ssh_cmd' in locals() else "unknown",
            "device_id": device.id,
            "device_name": device.name
        }


def test_ssh_connection(device: Device) -> Dict[str, Any]:
    """Test SSH connection to a device
    
    Args:
        device: Device configuration to test
        
    Returns:
        Dict with success status and details
    """
    try:
        # Simple echo command to test connection
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            "echo 'connection_test_ok'"
        ]
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=settings.ssh_connect_timeout + 5
        )
        
        success = result.returncode == 0 and "connection_test_ok" in result.stdout
        
        return {
            "success": success,
            "message": "Connection successful" if success else "Connection failed",
            "stderr": result.stderr if not success else None,
            "tested_at": datetime.now().isoformat()
        }
        
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "message": f"Connection timed out after {settings.ssh_connect_timeout} seconds",
            "stderr": "Timeout",
            "tested_at": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"Connection error: {str(e)}",
            "stderr": str(e),
            "tested_at": datetime.now().isoformat()
        }


def verify_cursor_agent_installed(device: Device) -> Dict[str, Any]:
    """Verify that cursor-agent is installed on remote device
    
    Args:
        device: Device configuration
        
    Returns:
        Dict with installation status and version info
    """
    try:
        cursor_agent_path = device.cursor_agent_path or settings.default_cursor_agent_path
        
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            f"{cursor_agent_path} --version"
        ]
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            return {
                "installed": True,
                "version": result.stdout.strip(),
                "path": cursor_agent_path
            }
        else:
            return {
                "installed": False,
                "error": result.stderr or "cursor-agent not found or not executable",
                "path": cursor_agent_path
            }
            
    except Exception as e:
        return {
            "installed": False,
            "error": str(e),
            "path": cursor_agent_path if 'cursor_agent_path' in locals() else "unknown"
        }


def verify_remote_directory(device: Device, directory: str) -> Dict[str, Any]:
    """Verify that a directory exists on remote device
    
    Args:
        device: Device configuration
        directory: Path to verify
        
    Returns:
        Dict with exists status and details
    """
    try:
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            f"test -d {shlex.quote(directory)} && echo 'exists' || echo 'not_found'"
        ]
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        exists = result.returncode == 0 and "exists" in result.stdout
        
        return {
            "exists": exists,
            "directory": directory,
            "message": "Directory exists" if exists else "Directory not found"
        }
        
    except Exception as e:
        return {
            "exists": False,
            "directory": directory,
            "message": f"Verification error: {str(e)}"
        }


def list_remote_directory(device: Device, directory: str) -> Dict[str, Any]:
    """List contents of a remote directory
    
    Args:
        device: Device configuration
        directory: Path to list
        
    Returns:
        Dict with directory listing or error
    """
    try:
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            f"ls -la {shlex.quote(directory)}"
        ]
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            # Parse ls output into list of entries
            lines = result.stdout.strip().split('\n')
            entries = []
            
            for line in lines[1:]:  # Skip "total" line
                parts = line.split(maxsplit=8)
                if len(parts) >= 9:
                    entries.append({
                        "permissions": parts[0],
                        "name": parts[8],
                        "is_directory": parts[0].startswith('d')
                    })
            
            return {
                "success": True,
                "directory": directory,
                "entries": entries
            }
        else:
            return {
                "success": False,
                "directory": directory,
                "error": result.stderr or "Failed to list directory"
            }
            
    except Exception as e:
        return {
            "success": False,
            "directory": directory,
            "error": str(e)
        }


def create_remote_chat(device: Device, working_directory: str) -> Dict[str, Any]:
    """Create a new chat on remote device using cursor-agent create-chat
    
    Args:
        device: Device configuration
        working_directory: Remote working directory
        
    Returns:
        Dict with chat_id or error
    """
    try:
        cursor_agent_path = device.cursor_agent_path or settings.default_cursor_agent_path
        
        ssh_cmd = [
            "ssh",
            "-o", f"ConnectTimeout={settings.ssh_connect_timeout}",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            "-p", str(device.port),
            f"{device.username}@{device.hostname}",
            f"cd {shlex.quote(working_directory)} && {cursor_agent_path} create-chat"
        ]
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=15
        )
        
        if result.returncode == 0:
            chat_id = result.stdout.strip()
            return {
                "success": True,
                "chat_id": chat_id,
                "device_id": device.id,
                "working_directory": working_directory
            }
        else:
            return {
                "success": False,
                "error": result.stderr or "Failed to create chat"
            }
            
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

