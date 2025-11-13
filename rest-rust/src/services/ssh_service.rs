use crate::{models::device::Device, Result, Settings};
use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

#[derive(Debug, Clone)]
pub struct SshResponse {
    pub stdout: String,
    pub stderr: String,
    pub returncode: i32,
    pub success: bool,
    pub command: String,
    pub device_id: String,
    pub device_name: String,
}

/// Test SSH connection to a device
pub async fn test_ssh_connection(
    device: &Device,
    connect_timeout: u64,
) -> Result<SshResponse> {
    tracing::info!(
        "[SSH Connection Test] Testing connection to {}@{}:{}",
        device.username,
        device.hostname,
        device.port
    );
    
    let mut cmd = Command::new("ssh");
    cmd.arg("-o")
        .arg(format!("ConnectTimeout={}", connect_timeout))
        .arg("-o")
        .arg("BatchMode=yes")
        .arg("-o")
        .arg("StrictHostKeyChecking=no")
        .arg("-p")
        .arg(device.port.to_string())
        .arg(format!("{}@{}", device.username, device.hostname))
        .arg("echo 'Connection successful'");
    
    let result = timeout(Duration::from_secs(connect_timeout + 5), cmd.output()).await;
    
    match result {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let success = output.status.success();
            
            if success {
                tracing::info!("[SSH Connection Test] ✅ Connection successful to {}", device.name);
            } else {
                tracing::error!("[SSH Connection Test] ❌ Connection failed to {}: {}", device.name, stderr);
            }
            
            Ok(SshResponse {
                stdout,
                stderr,
                returncode: output.status.code().unwrap_or(-1),
                success,
                command: format!("ssh test to {}@{}", device.username, device.hostname),
                device_id: device.id.clone(),
                device_name: device.name.clone(),
            })
        }
        Ok(Err(e)) => {
            tracing::error!("[SSH Connection Test] ❌ SSH command failed: {}", e);
            Err(crate::AppError::Ssh(format!("SSH command failed: {}", e)))
        }
        Err(_) => {
            tracing::error!("[SSH Connection Test] ⏱️ Connection TIMED OUT to {}", device.name);
            Err(crate::AppError::Timeout(format!(
                "SSH connection timeout to {}@{}",
                device.username, device.hostname
            )))
        }
    }
}

/// Verify cursor-agent is installed on remote device
pub async fn verify_cursor_agent(
    device: &Device,
    cursor_agent_path: &str,
    connect_timeout: u64,
) -> Result<SshResponse> {
    tracing::info!(
        "[SSH Verify Agent] Checking cursor-agent on {}",
        device.name
    );
    
    let mut cmd = Command::new("ssh");
    cmd.arg("-o")
        .arg(format!("ConnectTimeout={}", connect_timeout))
        .arg("-o")
        .arg("BatchMode=yes")
        .arg("-o")
        .arg("StrictHostKeyChecking=no")
        .arg("-p")
        .arg(device.port.to_string())
        .arg(format!("{}@{}", device.username, device.hostname))
        .arg(format!("{} --version", cursor_agent_path));
    
    let result = timeout(Duration::from_secs(connect_timeout + 5), cmd.output()).await;
    
    match result {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let success = output.status.success();
            
            if success {
                tracing::info!("[SSH Verify Agent] ✅ cursor-agent found on {}", device.name);
            } else {
                tracing::warn!("[SSH Verify Agent] ⚠️ cursor-agent not found on {}", device.name);
            }
            
            Ok(SshResponse {
                stdout,
                stderr,
                returncode: output.status.code().unwrap_or(-1),
                success,
                command: format!("{} --version", cursor_agent_path),
                device_id: device.id.clone(),
                device_name: device.name.clone(),
            })
        }
        Ok(Err(e)) => {
            Err(crate::AppError::Ssh(format!("Failed to verify agent: {}", e)))
        }
        Err(_) => {
            Err(crate::AppError::Timeout("Agent verification timeout".to_string()))
        }
    }
}

/// Execute cursor-agent on remote device via SSH
pub async fn execute_remote_cursor_agent(
    settings: &Settings,
    device: &Device,
    chat_id: &str,
    prompt: &str,
    working_directory: &str,
    model: Option<&str>,
    output_format: &str,
) -> Result<SshResponse> {
    let model = model.unwrap_or("sonnet-4.5-thinking");
    let cursor_agent_path = device
        .cursor_agent_path
        .as_deref()
        .unwrap_or(&settings.default_cursor_agent_path);
    
    tracing::info!(
        "[SSH Remote Exec] Starting remote cursor-agent execution\n\
         Device: {} ({})\n\
         Target: {}@{}:{}\n\
         Chat ID: {}\n\
         Working Dir: {}\n\
         Model: {}\n\
         Prompt Length: {} chars",
        device.name,
        device.id,
        device.username,
        device.hostname,
        device.port,
        chat_id,
        working_directory,
        model,
        prompt.len()
    );
    
    // Build cursor-agent command
    let agent_cmd = format!(
        "{} --print --force --model {} --output-format {} --resume {} {}",
        shell_quote(cursor_agent_path),
        shell_quote(model),
        shell_quote(output_format),
        shell_quote(chat_id),
        shell_quote(prompt)
    );
    
    // Build full command with cd
    let full_cmd = format!(
        "cd {} && {}",
        shell_quote(working_directory),
        agent_cmd
    );
    
    // Build SSH command
    let mut cmd = Command::new("ssh");
    cmd.arg("-o")
        .arg(format!("ConnectTimeout={}", settings.ssh_connect_timeout))
        .arg("-o")
        .arg("BatchMode=yes")
        .arg("-o")
        .arg("StrictHostKeyChecking=no")
        .arg("-p")
        .arg(device.port.to_string())
        .arg(format!("{}@{}", device.username, device.hostname))
        .arg(&full_cmd);
    
    tracing::info!(
        "[SSH Remote Exec] Executing SSH command\n\
         SSH Timeout: {}s\n\
         Connect Timeout: {}s",
        settings.ssh_timeout,
        settings.ssh_connect_timeout
    );
    
    let start = std::time::Instant::now();
    let result = timeout(Duration::from_secs(settings.ssh_timeout), cmd.output()).await;
    let duration = start.elapsed();
    
    match result {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let returncode = output.status.code().unwrap_or(-1);
            let success = output.status.success();
            
            if success {
                tracing::info!(
                    "[SSH Remote Exec] ✅ Command executed successfully\n\
                     Device: {}\n\
                     Return Code: {}\n\
                     Execution Time: {:.2}s\n\
                     Stdout Length: {} chars",
                    device.name,
                    returncode,
                    duration.as_secs_f64(),
                    stdout.len()
                );
            } else {
                tracing::error!(
                    "[SSH Remote Exec] ❌ Command failed\n\
                     Device: {}\n\
                     Return Code: {}\n\
                     Execution Time: {:.2}s\n\
                     Stderr: {}",
                    device.name,
                    returncode,
                    duration.as_secs_f64(),
                    &stderr[..stderr.len().min(500)]
                );
            }
            
            Ok(SshResponse {
                stdout,
                stderr,
                returncode,
                success,
                command: format!("ssh to {} (command truncated)", device.hostname),
                device_id: device.id.clone(),
                device_name: device.name.clone(),
            })
        }
        Ok(Err(e)) => {
            tracing::error!("[SSH Remote Exec] ❌ SSH command failed: {}", e);
            Err(crate::AppError::Ssh(format!("SSH execution failed: {}", e)))
        }
        Err(_) => {
            tracing::error!(
                "[SSH Remote Exec] ⏱️ SSH command TIMED OUT\n\
                 Device: {} ({}@{}:{})\n\
                 Timeout Threshold: {}s",
                device.name,
                device.username,
                device.hostname,
                device.port,
                settings.ssh_timeout
            );
            Err(crate::AppError::Timeout(format!(
                "SSH command timeout after {}s",
                settings.ssh_timeout
            )))
        }
    }
}

/// Simple shell quoting for command arguments
fn shell_quote(s: &str) -> String {
    if s.contains(' ')
        || s.contains('$')
        || s.contains('`')
        || s.contains('"')
        || s.contains('\'')
        || s.contains('\\')
    {
        format!("'{}'", s.replace('\'', "'\\''"))
    } else {
        s.to_string()
    }
}

