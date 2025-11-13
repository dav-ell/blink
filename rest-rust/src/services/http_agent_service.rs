use crate::{models::device::Device, Result, Settings};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct HttpAgentResponse {
    pub stdout: String,
    pub stderr: String,
    pub returncode: i32,
    pub success: bool,
    pub execution_time_ms: u64,
    pub device_id: String,
    pub device_name: String,
}

#[derive(Debug, Serialize)]
struct ExecuteRequest {
    chat_id: String,
    prompt: String,
    working_directory: String,
    model: String,
    output_format: String,
    api_key: String,
}

#[derive(Debug, Deserialize)]
struct ExecuteResponse {
    success: bool,
    stdout: String,
    stderr: String,
    returncode: i32,
    execution_time_ms: u64,
}

#[derive(Debug, Deserialize)]
struct HealthResponse {
    status: String,
    version: String,
    cursor_agent_path: String,
}

/// Test connection to remote agent service
pub async fn test_http_connection(
    device: &Device,
    connect_timeout: u64,
) -> Result<HttpAgentResponse> {
    tracing::info!(
        "[HTTP Connection Test] Testing connection to {} at {}",
        device.name,
        device.api_endpoint
    );
    
    let client = Client::builder()
        .timeout(Duration::from_secs(connect_timeout))
        .build()
        .map_err(|e| crate::AppError::Http(format!("Failed to create HTTP client: {}", e)))?;
    
    let health_url = format!("{}/health", device.api_endpoint);
    
    let result = client.get(&health_url).send().await;
    
    match result {
        Ok(response) => {
            let status_code = response.status();
            
            if status_code.is_success() {
                // Try to parse the health response
                match response.json::<HealthResponse>().await {
                    Ok(health) => {
                        tracing::info!(
                            "[HTTP Connection Test] ✅ Connection successful to {}\n\
                             Version: {}\n\
                             Cursor Agent Path: {}",
                            device.name,
                            health.version,
                            health.cursor_agent_path
                        );
                        
                        Ok(HttpAgentResponse {
                            stdout: format!("Connection successful. Version: {}", health.version),
                            stderr: String::new(),
                            returncode: 0,
                            success: true,
                            execution_time_ms: 0,
                            device_id: device.id.clone(),
                            device_name: device.name.clone(),
                        })
                    }
                    Err(e) => {
                        tracing::warn!(
                            "[HTTP Connection Test] ⚠️ Connected but failed to parse response: {}",
                            e
                        );
                        Ok(HttpAgentResponse {
                            stdout: "Connection successful (unknown format)".to_string(),
                            stderr: String::new(),
                            returncode: 0,
                            success: true,
                            execution_time_ms: 0,
                            device_id: device.id.clone(),
                            device_name: device.name.clone(),
                        })
                    }
                }
            } else {
                let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                tracing::error!(
                    "[HTTP Connection Test] ❌ Connection failed to {}: HTTP {}\n\
                     Error: {}",
                    device.name,
                    status_code,
                    error_text
                );
                
                Err(crate::AppError::Http(format!(
                    "HTTP {} - {}",
                    status_code,
                    error_text
                )))
            }
        }
        Err(e) => {
            tracing::error!(
                "[HTTP Connection Test] ❌ Failed to connect to {}: {}",
                device.name,
                e
            );
            
            if e.is_timeout() {
                Err(crate::AppError::Timeout(format!(
                    "Connection timeout to {}",
                    device.api_endpoint
                )))
            } else {
                Err(crate::AppError::Http(format!("Connection failed: {}", e)))
            }
        }
    }
}

/// Execute cursor-agent on remote device via HTTP
pub async fn execute_remote_cursor_agent(
    settings: &Settings,
    device: &Device,
    chat_id: &str,
    prompt: &str,
    working_directory: &str,
    model: Option<&str>,
    output_format: &str,
) -> Result<HttpAgentResponse> {
    let model = model.unwrap_or("sonnet-4.5-thinking");
    
    // Verify API key is set
    let api_key = device.api_key.as_ref().ok_or_else(|| {
        crate::AppError::Validation("Device API key is not configured".to_string())
    })?;
    
    tracing::info!(
        "[HTTP Remote Exec] Starting remote cursor-agent execution\n\
         Device: {} ({})\n\
         Endpoint: {}\n\
         Chat ID: {}\n\
         Working Dir: {}\n\
         Model: {}\n\
         Prompt Length: {} chars",
        device.name,
        device.id,
        device.api_endpoint,
        chat_id,
        working_directory,
        model,
        prompt.len()
    );
    
    // Build request payload
    let request = ExecuteRequest {
        chat_id: chat_id.to_string(),
        prompt: prompt.to_string(),
        working_directory: working_directory.to_string(),
        model: model.to_string(),
        output_format: output_format.to_string(),
        api_key: api_key.clone(),
    };
    
    // Create HTTP client with timeout
    let client = Client::builder()
        .timeout(Duration::from_secs(settings.remote_agent_timeout))
        .build()
        .map_err(|e| crate::AppError::Http(format!("Failed to create HTTP client: {}", e)))?;
    
    let execute_url = format!("{}/execute", device.api_endpoint);
    
    tracing::info!(
        "[HTTP Remote Exec] Sending request\n\
         URL: {}\n\
         Timeout: {}s",
        execute_url,
        settings.remote_agent_timeout
    );
    
    let start = std::time::Instant::now();
    let result = client.post(&execute_url).json(&request).send().await;
    let duration = start.elapsed();
    
    match result {
        Ok(response) => {
            let status_code = response.status();
            
            if status_code.is_success() {
                // Parse the response
                match response.json::<ExecuteResponse>().await {
                    Ok(exec_response) => {
                        if exec_response.success {
                            tracing::info!(
                                "[HTTP Remote Exec] ✅ Command executed successfully\n\
                                 Device: {}\n\
                                 Return Code: {}\n\
                                 Execution Time: {:.2}s\n\
                                 Remote Execution Time: {}ms\n\
                                 Stdout Length: {} chars",
                                device.name,
                                exec_response.returncode,
                                duration.as_secs_f64(),
                                exec_response.execution_time_ms,
                                exec_response.stdout.len()
                            );
                        } else {
                            tracing::error!(
                                "[HTTP Remote Exec] ❌ Command failed\n\
                                 Device: {}\n\
                                 Return Code: {}\n\
                                 Execution Time: {:.2}s\n\
                                 Stderr: {}",
                                device.name,
                                exec_response.returncode,
                                duration.as_secs_f64(),
                                &exec_response.stderr[..exec_response.stderr.len().min(500)]
                            );
                        }
                        
                        Ok(HttpAgentResponse {
                            stdout: exec_response.stdout,
                            stderr: exec_response.stderr,
                            returncode: exec_response.returncode,
                            success: exec_response.success,
                            execution_time_ms: exec_response.execution_time_ms,
                            device_id: device.id.clone(),
                            device_name: device.name.clone(),
                        })
                    }
                    Err(e) => {
                        tracing::error!(
                            "[HTTP Remote Exec] ❌ Failed to parse response: {}",
                            e
                        );
                        Err(crate::AppError::Http(format!("Failed to parse response: {}", e)))
                    }
                }
            } else {
                let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                tracing::error!(
                    "[HTTP Remote Exec] ❌ HTTP error {}\n\
                     Device: {}\n\
                     Error: {}",
                    status_code,
                    device.name,
                    error_text
                );
                
                Err(crate::AppError::Http(format!(
                    "HTTP {} - {}",
                    status_code,
                    error_text
                )))
            }
        }
        Err(e) => {
            tracing::error!(
                "[HTTP Remote Exec] ❌ Request failed\n\
                 Device: {}\n\
                 Error: {}",
                device.name,
                e
            );
            
            if e.is_timeout() {
                Err(crate::AppError::Timeout(format!(
                    "Request timeout after {}s",
                    settings.remote_agent_timeout
                )))
            } else {
                Err(crate::AppError::Http(format!("Request failed: {}", e)))
            }
        }
    }
}

