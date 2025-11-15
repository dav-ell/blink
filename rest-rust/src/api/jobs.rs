use axum::{
    extract::{Path, State},
    Json,
};
use serde::Serialize;
use serde_json::{json, Value};
use std::sync::Arc;

use crate::{
    models::{AgentPromptRequest, Job},
    services::{create_job, get_chat_jobs, get_job, run_cursor_agent, update_job_status, update_job_result},
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

    // Execute cursor-agent
    let result = run_cursor_agent(
        &state.settings,
        &chat_id,
        &prompt,
        Some(&model),
        &output_format,
        state.settings.cursor_agent_timeout,
    )
    .await;

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
