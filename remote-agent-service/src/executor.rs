use crate::error::AppError;
use std::process::Stdio;
use tokio::process::Command;
use tokio::time::{timeout, Duration};

/// Result of cursor-agent execution
#[derive(Debug, Clone)]
pub struct ExecutionResult {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
    pub returncode: i32,
}

/// Execute cursor-agent command asynchronously
pub async fn execute_cursor_agent(
    cursor_agent_path: &str,
    chat_id: &str,
    prompt: &str,
    working_directory: &str,
    model: &str,
    output_format: &str,
    correlation_id: Option<&str>,
) -> Result<ExecutionResult, AppError> {
    let corr_id = correlation_id.unwrap_or("unknown");
    
    tracing::info!(
        "Executing cursor-agent\n\
         Correlation ID: {}\n\
         Path: {}\n\
         Chat ID: {}\n\
         Working Dir: {}\n\
         Model: {}\n\
         Output Format: {}",
        corr_id,
        cursor_agent_path,
        chat_id,
        working_directory,
        model,
        output_format
    );

    // Validate working directory exists
    if !tokio::fs::metadata(working_directory).await.is_ok() {
        return Err(AppError::ValidationError(format!(
            "Working directory does not exist: {}",
            working_directory
        )));
    }

    // Build command
    let mut cmd = Command::new(cursor_agent_path);
    cmd.current_dir(working_directory)
        .arg("--print")
        .arg("--force")
        .arg("--model")
        .arg(model)
        .arg("--output-format")
        .arg(output_format)
        .arg("--resume")
        .arg(chat_id)
        .arg(prompt)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    tracing::debug!("Command: {:?}", cmd);

    let start = std::time::Instant::now();
    
    // Execute with timeout (5 minutes default)
    let execution = timeout(Duration::from_secs(300), cmd.output()).await;
    
    let duration = start.elapsed();

    match execution {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let returncode = output.status.code().unwrap_or(-1);
            let success = output.status.success();

            if success {
                tracing::info!(
                    "Cursor-agent execution successful\n\
                     Correlation ID: {}\n\
                     Return Code: {}\n\
                     Execution Time: {:.2}s\n\
                     Stdout Length: {} bytes",
                    corr_id,
                    returncode,
                    duration.as_secs_f64(),
                    stdout.len()
                );
            } else {
                tracing::error!(
                    "Cursor-agent execution failed\n\
                     Correlation ID: {}\n\
                     Return Code: {}\n\
                     Execution Time: {:.2}s\n\
                     Stderr: {}",
                    corr_id,
                    returncode,
                    duration.as_secs_f64(),
                    &stderr[..stderr.len().min(500)]
                );
            }

            Ok(ExecutionResult {
                success,
                stdout,
                stderr,
                returncode,
            })
        }
        Ok(Err(e)) => {
            tracing::error!(
                "Failed to execute cursor-agent\n\
                 Correlation ID: {}\n\
                 Error: {}",
                corr_id,
                e
            );
            Err(AppError::ExecutionError(format!(
                "Failed to execute cursor-agent: {}",
                e
            )))
        }
        Err(_) => {
            tracing::error!(
                "Cursor-agent execution timed out\n\
                 Correlation ID: {}\n\
                 Timeout: 5 minutes",
                corr_id
            );
            Err(AppError::ExecutionError(
                "Command execution timed out after 5 minutes".to_string(),
            ))
        }
    }
}

