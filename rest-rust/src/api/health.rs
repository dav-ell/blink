use axum::{extract::State, Json};
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;

use crate::{AppState, Result};

/// Root endpoint - API information
pub async fn root(State(state): State<Arc<AppState>>) -> Json<Value> {
    let cursor_agent_exists = Path::new(&state.settings.cursor_agent_path).exists();

    Json(json!({
        "name": "Cursor Chat API",
        "version": "3.0.0",
        "description": "REST API for Cursor chat database with async job support (Rust Edition)",
        "database": state.settings.db_path,
        "cursor_agent": {
            "installed": cursor_agent_exists,
            "path": state.settings.cursor_agent_path
        },
        "endpoints": {
            "GET /": "API information",
            "GET /health": "Health check",
            "GET /chats": "List all chats with metadata",
            "GET /chats/{chat_id}": "Get all messages for a specific chat",
            "GET /chats/{chat_id}/metadata": "Get metadata for a specific chat",
            "POST /chats/{chat_id}/agent-prompt": "Send prompt to cursor-agent",
            "POST /agent/create-chat": "Create new cursor-agent chat",
            "GET /agent/models": "List available AI models"
        },
        "features": {
            "rust_powered": "High performance Rust implementation",
            "async_runtime": "Tokio-based async runtime",
            "chat_continuation": "Continue existing Cursor conversations seamlessly",
            "history_management": "Automatic history via cursor-agent --resume"
        },
        "documentation": format!("http://{}:{}/docs", state.settings.api_host, state.settings.api_port)
    }))
}

/// Health check endpoint - Enhanced with dependency checks
pub async fn health_check(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let settings = &state.settings;
    let correlation_id = crate::utils::request_context::get_correlation_id()
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    // Check cursor agent
    let cursor_agent_available = Path::new(&settings.cursor_agent_path).exists();

    // Check cursor database
    let db_path = settings.db_path.clone();
    let db_check = tokio::task::spawn_blocking(move || {
        let conn = rusqlite::Connection::open(&db_path)?;

        let chat_count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%'",
                [],
                |row| row.get(0),
            )
            .unwrap_or(0);

        let message_count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'",
                [],
                |row| row.get(0),
            )
            .unwrap_or(0);

        Ok::<_, crate::AppError>((chat_count, message_count))
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))?;

    let (chat_count, message_count, cursor_db_status) = match db_check {
        Ok((chats, messages)) => (chats, messages, "healthy"),
        Err(_) => (0, 0, "unavailable"),
    };

    // Check internal database (jobs & devices)
    let job_count = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM jobs")
        .fetch_one(&state.job_pool)
        .await
        .unwrap_or(0);

    // Get metrics summary
    let metrics_snapshot = state.metrics.snapshot();

    // Overall health status
    let overall_status = if cursor_agent_available && cursor_db_status == "healthy" {
        "healthy"
    } else if cursor_agent_available || cursor_db_status == "healthy" {
        "degraded"
    } else {
        "unhealthy"
    };

    Ok(Json(json!({
        "status": overall_status,
        "correlation_id": correlation_id,
        "version": "3.0.0",
        "uptime_seconds": metrics_snapshot.uptime_seconds,
        "dependencies": {
            "cursor_database": {
                "status": cursor_db_status,
                "path": settings.db_path,
                "total_chats": chat_count,
                "total_messages": message_count
            },
            "cursor_agent": {
                "status": if cursor_agent_available { "available" } else { "unavailable" },
                "path": settings.cursor_agent_path
            },
            "internal_database": {
                "status": "healthy",
                "total_jobs": job_count
            }
        },
        "configuration": {
            "request_tracing": settings.enable_request_tracing,
            "metrics_enabled": settings.enable_metrics,
            "retry_attempts_http": settings.http_retry_attempts,
            "retry_attempts_ssh": settings.ssh_retry_attempts,
        }
    })))
}
