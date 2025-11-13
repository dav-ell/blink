use crate::{models::device::Device, utils::retry::RetryPolicy, Result, Settings};
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

#[derive(Debug, Serialize, Clone)]
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
    let correlation_id = crate::utils::request_context::get_correlation_id()
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());
    
    tracing::info!(
        "[HTTP Connection Test] Testing connection to {} at {}\n\
         Correlation ID: {}",
        device.name,
        device.api_endpoint,
        correlation_id
    );
    
    let client = Client::builder()
        .timeout(Duration::from_secs(connect_timeout))
        .build()
        .map_err(|e| crate::AppError::Http(format!("Failed to create HTTP client: {}", e)))?;
    
    let health_url = format!("{}/health", device.api_endpoint);
    
    let result = client
        .get(&health_url)
        .header("X-Correlation-ID", &correlation_id)
        .send()
        .await;
    
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

/// Execute cursor-agent on remote device via HTTP with retry logic
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
    
    let correlation_id = crate::utils::request_context::get_correlation_id()
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());
    
    tracing::info!(
        "[HTTP Remote Exec] Starting remote cursor-agent execution\n\
         Device: {} ({})\n\
         Endpoint: {}\n\
         Chat ID: {}\n\
         Working Dir: {}\n\
         Model: {}\n\
         Prompt Length: {} chars\n\
         Correlation ID: {}",
        device.name,
        device.id,
        device.api_endpoint,
        chat_id,
        working_directory,
        model,
        prompt.len(),
        correlation_id
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
    
    // Create HTTP client with timeout and connection pooling
    let client = Client::builder()
        .timeout(Duration::from_secs(settings.remote_agent_timeout))
        .connect_timeout(Duration::from_secs(settings.remote_agent_connect_timeout))
        .pool_max_idle_per_host(settings.connection_pool_size)
        .pool_idle_timeout(Duration::from_secs(settings.connection_pool_timeout))
        .build()
        .map_err(|e| crate::AppError::Http(format!("Failed to create HTTP client: {}", e)))?;
    
    let execute_url = format!("{}/execute", device.api_endpoint);
    
    tracing::info!(
        "[HTTP Remote Exec] Sending request\n\
         URL: {}\n\
         Timeout: {}s\n\
         Retry Policy: {} attempts",
        execute_url,
        settings.remote_agent_timeout,
        settings.http_retry_attempts
    );
    
    // Execute with retry logic
    let retry_policy = RetryPolicy::from_settings(
        settings.http_retry_attempts,
        settings.http_retry_delay_ms,
        settings.http_max_backoff_ms,
    );
    
    let start = std::time::Instant::now();
    let device_id = device.id.clone();
    let device_name = device.name.clone();
    let execute_url_clone = execute_url.clone();
    let correlation_id_clone = correlation_id.clone();
    
    let retry_result = retry_policy
        .execute_with_metadata(|| {
            let client = client.clone();
            let url = execute_url_clone.clone();
            let req = request.clone();
            let corr_id = correlation_id_clone.clone();
            
            async move {
                client
                    .post(&url)
                    .header("X-Correlation-ID", &corr_id)
                    .json(&req)
                    .send()
                    .await
                    .map_err(|e| {
                        if e.is_timeout() {
                            crate::AppError::Timeout(format!("HTTP request timeout: {}", e))
                        } else if e.is_connect() {
                            crate::AppError::Http(format!("Connection failed: {}", e))
                        } else {
                            crate::AppError::Http(format!("Request failed: {}", e))
                        }
                    })
            }
        })
        .await;
    
    let duration = start.elapsed();
    
    tracing::info!(
        "[HTTP Remote Exec] Request completed\n\
         Attempts: {}\n\
         Total Duration: {:.2}s\n\
         Succeeded: {}",
        retry_result.attempts,
        duration.as_secs_f64(),
        retry_result.succeeded
    );
    
    let result = retry_result.result?;
    
    let status_code = result.status();
    
    if status_code.is_success() {
        // Parse the response
        match result.json::<ExecuteResponse>().await {
            Ok(exec_response) => {
                if exec_response.success {
                    tracing::info!(
                        "[HTTP Remote Exec] ✅ Command executed successfully\n\
                         Device: {}\n\
                         Return Code: {}\n\
                         Execution Time: {:.2}s\n\
                         Remote Execution Time: {}ms\n\
                         Stdout Length: {} chars\n\
                         Retry Attempts: {}",
                        device_name,
                        exec_response.returncode,
                        duration.as_secs_f64(),
                        exec_response.execution_time_ms,
                        exec_response.stdout.len(),
                        retry_result.attempts
                    );
                } else {
                    tracing::error!(
                        "[HTTP Remote Exec] ❌ Command failed\n\
                         Device: {}\n\
                         Return Code: {}\n\
                         Execution Time: {:.2}s\n\
                         Retry Attempts: {}\n\
                         Stderr: {}",
                        device_name,
                        exec_response.returncode,
                        duration.as_secs_f64(),
                        retry_result.attempts,
                        &exec_response.stderr[..exec_response.stderr.len().min(500)]
                    );
                }
                
                Ok(HttpAgentResponse {
                    stdout: exec_response.stdout,
                    stderr: exec_response.stderr,
                    returncode: exec_response.returncode,
                    success: exec_response.success,
                    execution_time_ms: exec_response.execution_time_ms,
                    device_id,
                    device_name,
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
        let error_text = result.text().await.unwrap_or_else(|_| "Unknown error".to_string());
        tracing::error!(
            "[HTTP Remote Exec] ❌ HTTP error {}\n\
             Device: {}\n\
             Error: {}",
            status_code,
            device_name,
            error_text
        );
        
        Err(crate::AppError::Http(format!(
            "HTTP {} - {}",
            status_code,
            error_text
        )))
    }
}

