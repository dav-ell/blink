use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{env, sync::Arc, time::Instant};
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use remote_agent_service::{AppError, Config, execute_cursor_agent, get_chat_messages_from_agent, get_chat_metadata_from_agent};

/// Application state shared across handlers
#[derive(Clone)]
struct AppState {
    config: Arc<Config>,
}

/// Health check response
#[derive(Serialize)]
struct HealthResponse {
    status: String,
    version: String,
    cursor_agent_path: String,
}

/// Execute request payload
#[derive(Debug, Deserialize)]
struct ExecuteRequest {
    chat_id: String,
    prompt: String,
    working_directory: String,
    #[serde(default = "default_model")]
    model: String,
    #[serde(default = "default_output_format")]
    output_format: String,
    api_key: String,
}

fn default_model() -> String {
    "sonnet-4.5-thinking".to_string()
}

fn default_output_format() -> String {
    "stream-json".to_string()
}

/// Execute response payload
#[derive(Debug, Serialize)]
struct ExecuteResponse {
    success: bool,
    stdout: String,
    stderr: String,
    returncode: i32,
    execution_time_ms: u64,
}

/// Query parameters for messages endpoint
#[derive(Debug, Deserialize)]
struct GetMessagesQuery {
    #[serde(default = "default_true")]
    include_metadata: bool,
    #[serde(default = "default_true")]
    include_content: bool,
    limit: Option<usize>,
}

fn default_true() -> bool {
    true
}

/// Health check endpoint
async fn health_handler(State(state): State<AppState>) -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        cursor_agent_path: state.config.cursor_agent_path.clone(),
    })
}

/// Execute cursor-agent command
async fn execute_handler(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(payload): Json<ExecuteRequest>,
) -> Result<Json<ExecuteResponse>, AppError> {
    let start = Instant::now();
    
    // Extract correlation ID from headers
    let correlation_id = headers
        .get("X-Correlation-ID")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    // Validate API key
    if payload.api_key != state.config.api_key {
        tracing::warn!(
            "Unauthorized access attempt\n\
             Correlation ID: {}",
            correlation_id
        );
        return Err(AppError::Unauthorized);
    }

    tracing::info!(
        "Executing cursor-agent command\n\
         Correlation ID: {}\n\
         Chat ID: {}\n\
         Working Dir: {}\n\
         Model: {}\n\
         Prompt Length: {} chars",
        correlation_id,
        payload.chat_id,
        payload.working_directory,
        payload.model,
        payload.prompt.len()
    );

    // Execute cursor-agent
    let result = execute_cursor_agent(
        &state.config.cursor_agent_path,
        &payload.chat_id,
        &payload.prompt,
        &payload.working_directory,
        &payload.model,
        &payload.output_format,
        Some(&correlation_id),
    )
    .await?;

    let execution_time = start.elapsed().as_millis() as u64;

    if result.success {
        tracing::info!(
            "Command executed successfully\n\
             Correlation ID: {}\n\
             Chat ID: {}\n\
             Return Code: {}\n\
             Execution Time: {}ms\n\
             Stdout Length: {} chars",
            correlation_id,
            payload.chat_id,
            result.returncode,
            execution_time,
            result.stdout.len()
        );
    } else {
        tracing::error!(
            "Command failed\n\
             Correlation ID: {}\n\
             Chat ID: {}\n\
             Return Code: {}\n\
             Execution Time: {}ms\n\
             Stderr: {}",
            correlation_id,
            payload.chat_id,
            result.returncode,
            execution_time,
            result.stderr
        );
    }

    Ok(Json(ExecuteResponse {
        success: result.success,
        stdout: result.stdout,
        stderr: result.stderr,
        returncode: result.returncode,
        execution_time_ms: execution_time,
    }))
}

/// Get messages for a chat
async fn messages_handler(
    Path(chat_id): Path<String>,
    Query(params): Query<GetMessagesQuery>,
) -> Result<Json<Value>, AppError> {
    tracing::info!("Getting messages for chat: {}", chat_id);
    
    // Fetch messages from cursor-agent format
    let chat_id_for_messages = chat_id.clone();
    let messages = tokio::task::spawn_blocking(move || {
        get_chat_messages_from_agent(&chat_id_for_messages, params.include_content)
    })
    .await
    .map_err(|e| anyhow::anyhow!("Task join error: {}", e))??;
    
    let mut result = json!({
        "chat_id": chat_id,
        "message_count": messages.len(),
        "messages": messages
    });
    
    // Add metadata if requested
    if params.include_metadata {
        let chat_id_for_metadata = chat_id.clone();
        let metadata = tokio::task::spawn_blocking(move || {
            get_chat_metadata_from_agent(&chat_id_for_metadata)
        })
        .await
        .map_err(|e| anyhow::anyhow!("Task join error: {}", e))?;
        
        match metadata {
            Ok(meta) => {
                result["metadata"] = json!({
                    "name": meta.get("name"),
                    "created_at": meta.get("createdAt"),
                    "agent_id": meta.get("agentId"),
                    "mode": meta.get("mode"),
                });
            }
            Err(e) => {
                tracing::warn!("Failed to get metadata: {}", e);
            }
        }
    }
    
    // Apply limit if specified
    if let Some(limit) = params.limit {
        if let Some(messages_array) = result["messages"].as_array_mut() {
            messages_array.truncate(limit);
            result["message_count"] = json!(messages_array.len());
        }
    }
    
    tracing::info!(
        "Returning {} messages for chat: {}",
        result["message_count"],
        result["chat_id"]
    );
    
    Ok(Json(result))
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "remote_agent_service=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    let config = Config::from_env()?;

    let separator = "=".repeat(80);
    tracing::info!("{}", separator);
    tracing::info!("Remote Agent Service Starting");
    tracing::info!("{}", separator);
    tracing::info!("Version: {}", env!("CARGO_PKG_VERSION"));
    tracing::info!("Cursor Agent: {}", config.cursor_agent_path);
    tracing::info!("Listen Address: {}:{}", config.host, config.port);
    tracing::info!("API Key: {}***", &config.api_key[..8.min(config.api_key.len())]);
    tracing::info!("{}", separator);

    // Create shared state
    let state = AppState {
        config: Arc::new(config.clone()),
    };

    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build router
    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/execute", post(execute_handler))
        .route("/messages/:chat_id", get(messages_handler))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    // Start server
    let addr = format!("{}:{}", config.host, config.port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    tracing::info!("Server listening on http://{}", addr);
    tracing::info!("Ready to accept requests");

    axum::serve(listener, app).await?;

    Ok(())
}

