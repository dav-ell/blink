use axum::{extract::State, Json};
use serde_json::{json, Value};
use std::sync::Arc;
use std::path::Path;

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

/// Health check endpoint
pub async fn health_check(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let settings = &state.settings;
    
    // Use spawn_blocking for synchronous DB operations
    let db_path = settings.db_path.clone();
    let (chat_count, message_count) = tokio::task::spawn_blocking(move || {
        let conn = rusqlite::Connection::open(&db_path)?;
        
        let chat_count: i32 = conn.query_row(
            "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%'",
            [],
            |row| row.get(0),
        )?;
        
        let message_count: i32 = conn.query_row(
            "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'bubbleId:%'",
            [],
            |row| row.get(0),
        )?;
        
        Ok::<_, crate::AppError>((chat_count, message_count))
    })
    .await
    .map_err(|e| crate::AppError::Internal(format!("Task join error: {}", e)))??;
    
    Ok(Json(json!({
        "status": "healthy",
        "database": "accessible",
        "database_path": settings.db_path,
        "total_chats": chat_count,
        "total_messages": message_count
    })))
}

