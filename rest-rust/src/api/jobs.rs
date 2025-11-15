use axum::{
    extract::{Path, State},
    Json,
};
use serde::Serialize;
use serde_json::{json, Value};
use std::sync::Arc;

use crate::{
    models::{AgentPromptRequest, Job},
    services::{
        create_job, execute_remote_cursor_agent, get_chat_jobs, get_device, get_job,
        get_remote_chat, run_cursor_agent, update_job_status, update_job_result,
    },
    AppState, Result,
};

#[derive(Debug, Serialize)]
pub struct JobCreateResponse {
    pub status: String,
    pub job_id: String,
    pub message: String,
}

/// Create an async job for agent prompt (returns immediately)
pub async fn create_agent_prompt_job(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
    Json(request): Json<AgentPromptRequest>,
) -> Result<Json<JobCreateResponse>> {
    let job = create_job(
        &state.job_pool,
        &chat_id,
        &request.prompt,
        Some(&request.model),
    )
    .await?;

    let job_id = job.job_id.clone();
    let model = job.model.clone().unwrap_or_else(|| "sonnet-4.5-thinking".to_string());
    
    // Spawn background task to execute the job
    tokio::spawn(execute_job(
        state.clone(),
        job_id.clone(),
        chat_id.clone(),
        request.prompt.clone(),
        model,
        request.output_format.clone(),
    ));

    Ok(Json(JobCreateResponse {
        status: "accepted".to_string(),
        job_id,
        message: "Job created and queued for processing".to_string(),
    }))
}

/// Execute a job in the background
async fn execute_job(
    state: Arc<AppState>,
    job_id: String,
    chat_id: String,
    prompt: String,
    model: String,
    output_format: String,
) {
    tracing::info!("Starting job execution: {}", job_id);
    
    // Mark job as processing
    if let Err(e) = update_job_status(&state.job_pool, &job_id, "processing").await {
        tracing::error!("Failed to update job status to processing: {}", e);
        return;
    }

    // Check if this is a remote chat
    let is_remote = match get_remote_chat(&state.job_pool, &chat_id).await {
        Ok(Some(remote_chat)) => {
            tracing::info!("Job {} is for remote chat on device {}", job_id, remote_chat.device_id);
            true
        }
        Ok(None) => {
            tracing::info!("Job {} is for local chat", job_id);
            false
        }
        Err(e) => {
            tracing::error!("Failed to check if chat is remote: {}", e);
            false // Fallback to local
        }
    };

    // Execute cursor-agent (locally or remotely)
    let result = if is_remote {
        // Get remote chat and device info
        let remote_chat = match get_remote_chat(&state.job_pool, &chat_id).await {
            Ok(Some(chat)) => chat,
            Ok(None) => {
                let error_msg = "Remote chat not found";
                tracing::error!("Job {} failed: {}", job_id, error_msg);
                if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                    tracing::error!("Failed to update job status: {}", e);
                }
                if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                    .bind(error_msg)
                    .bind(&job_id)
                    .execute(&state.job_pool)
                    .await
                {
                    tracing::error!("Failed to update job error: {}", e);
                }
                return;
            }
            Err(e) => {
                let error_msg = format!("Failed to get remote chat: {}", e);
                tracing::error!("Job {} failed: {}", job_id, error_msg);
                if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                    tracing::error!("Failed to update job status: {}", e);
                }
                if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                    .bind(&error_msg)
                    .bind(&job_id)
                    .execute(&state.job_pool)
                    .await
                {
                    tracing::error!("Failed to update job error: {}", e);
                }
                return;
            }
        };

        let device = match get_device(&state.job_pool, &remote_chat.device_id).await {
            Ok(Some(dev)) => dev,
            Ok(None) => {
                let error_msg = format!("Device {} not found", remote_chat.device_id);
                tracing::error!("Job {} failed: {}", job_id, error_msg);
                if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                    tracing::error!("Failed to update job status: {}", e);
                }
                if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                    .bind(&error_msg)
                    .bind(&job_id)
                    .execute(&state.job_pool)
                    .await
                {
                    tracing::error!("Failed to update job error: {}", e);
                }
                return;
            }
            Err(e) => {
                let error_msg = format!("Failed to get device: {}", e);
                tracing::error!("Job {} failed: {}", job_id, error_msg);
                if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                    tracing::error!("Failed to update job status: {}", e);
                }
                if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                    .bind(&error_msg)
                    .bind(&job_id)
                    .execute(&state.job_pool)
                    .await
                {
                    tracing::error!("Failed to update job error: {}", e);
                }
                return;
            }
        };

        tracing::info!("Executing job {} on remote device: {}", job_id, device.name);
        execute_remote_cursor_agent(
            &state.settings,
            &device,
            &chat_id,
            &prompt,
            &remote_chat.working_directory,
            Some(&model),
            &output_format,
        )
        .await
        .map(|http_response| {
            // Parse the remote output if it's JSON
            let (parsed_content, parse_error) = match crate::utils::parse_cursor_agent_output(&http_response.stdout) {
                Ok(parsed) => {
                    let mut map = std::collections::HashMap::new();
                    map.insert("text".to_string(), serde_json::json!(parsed.text));
                    if let Some(thinking) = parsed.thinking {
                        map.insert("thinking".to_string(), serde_json::json!(thinking));
                    }
                    if let Some(tool_calls) = parsed.tool_calls {
                        map.insert("tool_calls".to_string(), serde_json::json!(tool_calls));
                    }
                    (Some(map), None)
                },
                Err(e) => (None, Some(format!("Failed to parse output: {}", e))),
            };
            
            crate::services::agent_service::AgentResponse {
                success: http_response.success,
                stdout: http_response.stdout.clone(),
                stderr: http_response.stderr,
                returncode: http_response.returncode,
                command: format!("Remote execution on {}", http_response.device_name),
                parsed_content,
                parse_error,
            }
        })
    } else {
        tracing::info!("Executing job {} locally", job_id);
        run_cursor_agent(
            &state.settings,
            &chat_id,
            &prompt,
            Some(&model),
            &output_format,
            state.settings.cursor_agent_timeout,
        )
        .await
    };

    match result {
        Ok(response) if response.success => {
            // Extract parsed content or use raw stdout
            let (text, thinking, tool_calls) = if let Some(parsed) = response.parsed_content {
                let text = parsed
                    .get("text")
                    .and_then(|v| v.as_str())
                    .unwrap_or(&response.stdout)
                    .to_string();
                let thinking = parsed
                    .get("thinking")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());
                let tool_calls = parsed.get("tool_calls").and_then(|v| v.as_array()).cloned();
                (text, thinking, tool_calls)
            } else {
                (response.stdout.clone(), None, None)
            };

            let result_json = json!({
                "success": true,
                "content": {
                    "assistant": text,
                    "thinking": thinking,
                    "tool_calls": tool_calls,
                },
                "metadata": {
                    "command": response.command,
                    "returncode": response.returncode,
                }
            });

            if let Err(e) = update_job_result(&state.job_pool, &job_id, &result_json, thinking.as_deref(), tool_calls.as_ref()).await {
                tracing::error!("Failed to update job result: {}", e);
            } else {
                tracing::info!("Job completed successfully: {}", job_id);
            }
        }
        Ok(response) => {
            // cursor-agent returned non-zero exit code
            let error_msg = format!("cursor-agent failed: {}", response.stderr);
            tracing::error!("Job failed: {} - {}", job_id, error_msg);
            
            if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                tracing::error!("Failed to update job status to failed: {}", e);
            }
            
            if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                .bind(&error_msg)
                .bind(&job_id)
                .execute(&state.job_pool)
                .await
            {
                tracing::error!("Failed to update job error: {}", e);
            }
        }
        Err(e) => {
            // Execution error
            let error_msg = format!("Execution error: {}", e);
            tracing::error!("Job failed: {} - {}", job_id, error_msg);
            
            if let Err(e) = update_job_status(&state.job_pool, &job_id, "failed").await {
                tracing::error!("Failed to update job status to failed: {}", e);
            }
            
            if let Err(e) = sqlx::query("UPDATE jobs SET error = ? WHERE job_id = ?")
                .bind(&error_msg)
                .bind(&job_id)
                .execute(&state.job_pool)
                .await
            {
                tracing::error!("Failed to update job error: {}", e);
            }
        }
    }
}

/// Get job details
pub async fn get_job_details(
    State(state): State<Arc<AppState>>,
    Path(job_id): Path<String>,
) -> Result<Json<Job>> {
    let job = get_job(&state.job_pool, &job_id)
        .await?
        .ok_or_else(|| crate::AppError::NotFound(format!("Job {} not found", job_id)))?;

    Ok(Json(job))
}

/// Get job status (lightweight)
pub async fn get_job_status(
    State(state): State<Arc<AppState>>,
    Path(job_id): Path<String>,
) -> Result<Json<Value>> {
    let job = get_job(&state.job_pool, &job_id)
        .await?
        .ok_or_else(|| crate::AppError::NotFound(format!("Job {} not found", job_id)))?;

    Ok(Json(json!({
        "job_id": job.job_id,
        "status": job.status,
        "created_at": job.created_at,
        "elapsed_seconds": job.elapsed_seconds(),
    })))
}

/// Get all jobs for a chat
pub async fn get_chat_jobs_list(
    State(state): State<Arc<AppState>>,
    Path(chat_id): Path<String>,
) -> Result<Json<Value>> {
    let jobs = get_chat_jobs(&state.job_pool, &chat_id, 20).await?;

    Ok(Json(json!({
        "chat_id": chat_id,
        "total": jobs.len(),
        "jobs": jobs,
    })))
}
