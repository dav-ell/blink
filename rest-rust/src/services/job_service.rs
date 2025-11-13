use crate::models::{Job, JobStatus};
use crate::Result;
use chrono::Utc;
use sqlx::{Row, SqlitePool};
use uuid::Uuid;

/// Initialize the jobs database
pub async fn init_jobs_db(pool: &SqlitePool) -> Result<()> {
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS jobs (
            job_id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            prompt TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            started_at TEXT,
            completed_at TEXT,
            result TEXT,
            error TEXT,
            user_bubble_id TEXT,
            assistant_bubble_id TEXT,
            model TEXT,
            thinking_content TEXT,
            tool_calls TEXT,
            retry_count INTEGER DEFAULT 0,
            correlation_id TEXT,
            device_id TEXT,
            execution_time_ms INTEGER
        )
        "#,
    )
    .execute(pool)
    .await?;
    
    // Create indexes for faster lookups
    sqlx::query("CREATE INDEX IF NOT EXISTS idx_chat_id ON jobs(chat_id)")
        .execute(pool)
        .await?;
    
    sqlx::query("CREATE INDEX IF NOT EXISTS idx_correlation_id ON jobs(correlation_id)")
        .execute(pool)
        .await?;
    
    sqlx::query("CREATE INDEX IF NOT EXISTS idx_status ON jobs(status)")
        .execute(pool)
        .await?;
    
    Ok(())
}

/// Create a new job
pub async fn create_job(
    pool: &SqlitePool,
    chat_id: &str,
    prompt: &str,
    model: Option<&str>,
) -> Result<Job> {
    let job_id = Uuid::new_v4().to_string();
    let model = model.unwrap_or("sonnet-4.5-thinking");
    let now = Utc::now();
    let correlation_id = crate::utils::request_context::get_correlation_id();
    
    sqlx::query(
        r#"
        INSERT INTO jobs (job_id, chat_id, prompt, status, created_at, model, correlation_id, retry_count)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(&job_id)
    .bind(chat_id)
    .bind(prompt)
    .bind("pending")
    .bind(now.to_rfc3339())
    .bind(model)
    .bind(correlation_id.as_deref())
    .bind(0)
    .execute(pool)
    .await?;
    
    Ok(Job {
        job_id,
        chat_id: chat_id.to_string(),
        prompt: prompt.to_string(),
        status: JobStatus::Pending,
        created_at: now,
        started_at: None,
        completed_at: None,
        result: None,
        error: None,
        user_bubble_id: None,
        assistant_bubble_id: None,
        model: Some(model.to_string()),
        thinking_content: None,
        tool_calls: None,
        retry_count: 0,
        correlation_id,
        device_id: None,
        execution_time_ms: None,
    })
}

/// Get a job by ID
pub async fn get_job(pool: &SqlitePool, job_id: &str) -> Result<Option<Job>> {
    let row = sqlx::query(
        r#"
        SELECT job_id, chat_id, prompt, status, created_at, started_at, 
               completed_at, result, error, user_bubble_id, assistant_bubble_id,
               model, thinking_content, tool_calls, retry_count, correlation_id,
               device_id, execution_time_ms
        FROM jobs WHERE job_id = ?
        "#,
    )
    .bind(job_id)
    .fetch_optional(pool)
    .await?;
    
    match row {
        Some(row) => {
            let status_str: String = row.get("status");
            let status = match status_str.as_str() {
                "pending" => JobStatus::Pending,
                "processing" => JobStatus::Processing,
                "completed" => JobStatus::Completed,
                "failed" => JobStatus::Failed,
                "cancelled" => JobStatus::Cancelled,
                _ => JobStatus::Pending,
            };
            
            let created_at: String = row.get("created_at");
            let started_at: Option<String> = row.get("started_at");
            let completed_at: Option<String> = row.get("completed_at");
            
            let tool_calls_json: Option<String> = row.get("tool_calls");
            let tool_calls = tool_calls_json.and_then(|s| serde_json::from_str(&s).ok());
            
            let retry_count: Option<i64> = row.try_get("retry_count").ok();
            let execution_time_ms: Option<i64> = row.try_get("execution_time_ms").ok();
            
            Ok(Some(Job {
                job_id: row.get("job_id"),
                chat_id: row.get("chat_id"),
                prompt: row.get("prompt"),
                status,
                created_at: chrono::DateTime::parse_from_rfc3339(&created_at)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc))
                    .unwrap_or_else(Utc::now),
                started_at: started_at.and_then(|s| {
                    chrono::DateTime::parse_from_rfc3339(&s)
                        .ok()
                        .map(|dt| dt.with_timezone(&Utc))
                }),
                completed_at: completed_at.and_then(|s| {
                    chrono::DateTime::parse_from_rfc3339(&s)
                        .ok()
                        .map(|dt| dt.with_timezone(&Utc))
                }),
                result: row.get("result"),
                error: row.get("error"),
                user_bubble_id: row.get("user_bubble_id"),
                assistant_bubble_id: row.get("assistant_bubble_id"),
                model: row.get("model"),
                thinking_content: row.get("thinking_content"),
                tool_calls,
                retry_count: retry_count.unwrap_or(0) as u32,
                correlation_id: row.get("correlation_id"),
                device_id: row.get("device_id"),
                execution_time_ms: execution_time_ms.map(|v| v as u64),
            }))
        }
        None => Ok(None),
    }
}

/// Update job status and fields
pub async fn update_job(
    pool: &SqlitePool,
    job_id: &str,
    status: Option<JobStatus>,
    result: Option<&str>,
    error: Option<&str>,
    started_at: Option<chrono::DateTime<Utc>>,
    completed_at: Option<chrono::DateTime<Utc>>,
) -> Result<()> {
    let mut query = String::from("UPDATE jobs SET ");
    let mut updates = Vec::new();
    let mut bind_values: Vec<String> = Vec::new();
    
    if let Some(s) = status {
        updates.push("status = ?");
        bind_values.push(s.as_str().to_string());
    }
    
    if let Some(r) = result {
        updates.push("result = ?");
        bind_values.push(r.to_string());
    }
    
    if let Some(e) = error {
        updates.push("error = ?");
        bind_values.push(e.to_string());
    }
    
    if let Some(t) = started_at {
        updates.push("started_at = ?");
        bind_values.push(t.to_rfc3339());
    }
    
    if let Some(t) = completed_at {
        updates.push("completed_at = ?");
        bind_values.push(t.to_rfc3339());
    }
    
    if updates.is_empty() {
        return Ok(());
    }
    
    query.push_str(&updates.join(", "));
    query.push_str(" WHERE job_id = ?");
    
    let mut q = sqlx::query(&query);
    for val in bind_values {
        q = q.bind(val);
    }
    q = q.bind(job_id);
    
    q.execute(pool).await?;
    Ok(())
}

/// Get all jobs for a chat
pub async fn get_chat_jobs(
    pool: &SqlitePool,
    chat_id: &str,
    limit: i32,
) -> Result<Vec<Job>> {
    let rows = sqlx::query(
        r#"
        SELECT job_id, chat_id, prompt, status, created_at, started_at,
               completed_at, result, error, user_bubble_id, assistant_bubble_id,
               model, thinking_content, tool_calls, retry_count, correlation_id,
               device_id, execution_time_ms
        FROM jobs
        WHERE chat_id = ?
        ORDER BY created_at DESC
        LIMIT ?
        "#,
    )
    .bind(chat_id)
    .bind(limit)
    .fetch_all(pool)
    .await?;
    
    let mut jobs = Vec::new();
    for row in rows {
        let status_str: String = row.get("status");
        let status = match status_str.as_str() {
            "pending" => JobStatus::Pending,
            "processing" => JobStatus::Processing,
            "completed" => JobStatus::Completed,
            "failed" => JobStatus::Failed,
            "cancelled" => JobStatus::Cancelled,
            _ => JobStatus::Pending,
        };
        
        let created_at: String = row.get("created_at");
        let started_at: Option<String> = row.get("started_at");
        let completed_at: Option<String> = row.get("completed_at");
        
        let tool_calls_json: Option<String> = row.get("tool_calls");
        let tool_calls = tool_calls_json.and_then(|s| serde_json::from_str(&s).ok());
        
        let retry_count: Option<i64> = row.try_get("retry_count").ok();
        let execution_time_ms: Option<i64> = row.try_get("execution_time_ms").ok();
        
        jobs.push(Job {
            job_id: row.get("job_id"),
            chat_id: row.get("chat_id"),
            prompt: row.get("prompt"),
            status,
            created_at: chrono::DateTime::parse_from_rfc3339(&created_at)
                .ok()
                .map(|dt| dt.with_timezone(&Utc))
                .unwrap_or_else(Utc::now),
            started_at: started_at.and_then(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc))
            }),
            completed_at: completed_at.and_then(|s| {
                chrono::DateTime::parse_from_rfc3339(&s)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc))
            }),
            result: row.get("result"),
            error: row.get("error"),
            user_bubble_id: row.get("user_bubble_id"),
            assistant_bubble_id: row.get("assistant_bubble_id"),
            model: row.get("model"),
            thinking_content: row.get("thinking_content"),
            tool_calls,
            retry_count: retry_count.unwrap_or(0) as u32,
            correlation_id: row.get("correlation_id"),
            device_id: row.get("device_id"),
            execution_time_ms: execution_time_ms.map(|v| v as u64),
        });
    }
    
    Ok(jobs)
}

/// Clean up old completed/failed jobs
pub async fn cleanup_old_jobs(pool: &SqlitePool, max_age_hours: u64) -> Result<usize> {
    let cutoff = Utc::now() - chrono::Duration::hours(max_age_hours as i64);
    
    let result = sqlx::query(
        r#"
        DELETE FROM jobs
        WHERE status IN ('completed', 'failed', 'cancelled')
        AND completed_at < ?
        "#,
    )
    .bind(cutoff.to_rfc3339())
    .execute(pool)
    .await?;
    
    Ok(result.rows_affected() as usize)
}

