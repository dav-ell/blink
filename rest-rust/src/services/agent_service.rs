use crate::{utils::parse_cursor_agent_output, Result, Settings};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

pub const AVAILABLE_MODELS: &[&str] = &[
    "composer-1",
    "auto",
    "sonnet-4.5",
    "sonnet-4.5-thinking",
    "gpt-5",
    "gpt-5-codex",
    "gpt-5-codex-high",
    "grok",
];

#[derive(Debug, Clone)]
pub struct AgentResponse {
    pub stdout: String,
    pub stderr: String,
    pub returncode: i32,
    pub success: bool,
    pub command: String,
    pub parsed_content: Option<HashMap<String, Value>>,
    pub parse_error: Option<String>,
}

/// Execute cursor-agent CLI with chat history support
pub async fn run_cursor_agent(
    settings: &Settings,
    chat_id: &str,
    prompt: &str,
    model: Option<&str>,
    output_format: &str,
    timeout_secs: u64,
) -> Result<AgentResponse> {
    // Set default model if not specified
    let model = model.unwrap_or("sonnet-4.5-thinking");
    
    // Validate model
    if !AVAILABLE_MODELS.contains(&model) {
        return Err(crate::AppError::BadRequest(format!(
            "Invalid model '{}'. Available: {}",
            model,
            AVAILABLE_MODELS.join(", ")
        )));
    }
    
    // Build command
    let cursor_agent_path = &settings.cursor_agent_path;
    let mut cmd = Command::new(cursor_agent_path);
    
    cmd.arg("--print")
        .arg("--force")
        .arg("--model")
        .arg(model)
        .arg("--output-format")
        .arg(output_format)
        .arg("--resume")
        .arg(chat_id)
        .arg(prompt);
    
    let command_str = format!(
        "{} --print --force --model {} --output-format {} --resume {} {}",
        cursor_agent_path.display(),
        model,
        output_format,
        chat_id,
        prompt
    );
    
    // Execute with timeout
    let result = timeout(Duration::from_secs(timeout_secs), cmd.output()).await;
    
    match result {
        Ok(Ok(output)) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let returncode = output.status.code().unwrap_or(-1);
            let success = output.status.success();
            
            let mut response = AgentResponse {
                stdout: stdout.clone(),
                stderr,
                returncode,
                success,
                command: command_str,
                parsed_content: None,
                parse_error: None,
            };
            
            // Parse stream-json output if format is stream-json
            if output_format == "stream-json" && success {
                match parse_cursor_agent_output(&stdout) {
                    Ok(parsed) => {
                        let mut content = HashMap::new();
                        content.insert("text".to_string(), json!(parsed.text));
                        if let Some(thinking) = parsed.thinking {
                            content.insert("thinking".to_string(), json!(thinking));
                        }
                        if let Some(tool_calls) = parsed.tool_calls {
                            content.insert("tool_calls".to_string(), json!(tool_calls));
                        }
                        response.parsed_content = Some(content);
                    }
                    Err(e) => {
                        response.parse_error = Some(e.to_string());
                    }
                }
            }
            
            Ok(response)
        }
        Ok(Err(e)) => {
            // Command failed to execute
            Ok(AgentResponse {
                stdout: String::new(),
                stderr: e.to_string(),
                returncode: -1,
                success: false,
                command: command_str,
                parsed_content: None,
                parse_error: None,
            })
        }
        Err(_) => {
            // Timeout
            Ok(AgentResponse {
                stdout: String::new(),
                stderr: format!("Command timed out after {} seconds", timeout_secs),
                returncode: -1,
                success: false,
                command: command_str,
                parsed_content: None,
                parse_error: None,
            })
        }
    }
}

