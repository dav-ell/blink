use axum::{extract::{Path, State}, Json};
use serde::Serialize;
use serde_json::{json, Value};
use std::sync::Arc;

use crate::{
    models::{AgentPromptRequest, Job},
    services::{create_job, get_chat_jobs, get_job},
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
    
    // TODO: Spawn background task to execute the job
    // For now, just return the job ID
    
    Ok(Json(JobCreateResponse {
        status: "accepted".to_string(),
        job_id: job.job_id,
        message: "Job created and queued for processing".to_string(),
    }))
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

