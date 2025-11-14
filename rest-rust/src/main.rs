use axum::{
    middleware,
    routing::{delete, get, post, put},
    Router,
};
use blink_api::{api, db, services, AppState, Settings};
use std::sync::Arc;
use std::time::Duration;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "blink_api=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    let settings = Settings::new()?;
    
    tracing::info!("{}", "=".repeat(80));
    tracing::info!("Cursor Chat REST API Server Starting (Rust Edition)");
    tracing::info!("{}", "=".repeat(80));
    tracing::info!("Database: {}", settings.db_path.display());
    tracing::info!("Cursor Agent: {}", settings.cursor_agent_path.display());
    tracing::info!("API Endpoint: http://{}:{}", settings.api_host, settings.api_port);
    tracing::info!("{}", "=".repeat(80));
    
    // Initialize internal databases (jobs + devices)
    let internal_db_url = format!("sqlite://{}", settings.device_db_path.display());
    let internal_pool = db::internal_pool::create_internal_pool(&internal_db_url).await?;
    
    // Initialize database schemas
    services::init_jobs_db(&internal_pool).await?;
    db::device_db::ensure_device_db_initialized(&internal_pool).await?;
    tracing::info!("Internal databases initialized");
    
    // Create circuit breaker with configuration
    let circuit_breaker_config = blink_api::middleware::circuit_breaker::CircuitBreakerConfig {
        failure_threshold: 5,
        success_threshold: 2,
        timeout: Duration::from_secs(60),
    };
    
    // Create shared state
    let state = Arc::new(AppState {
        settings: settings.clone(),
        job_pool: internal_pool,
        metrics: blink_api::MetricsCollector::new(),
        circuit_breaker: blink_api::middleware::DeviceCircuitBreaker::new(circuit_breaker_config),
    });
    
    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    
    // Build router with middleware
    let app = Router::new()
        // Health endpoints
        .route("/", get(api::health::root))
        .route("/health", get(api::health::health_check))
        // Metrics endpoints
        .route("/metrics", get(api::metrics::get_metrics))
        .route("/metrics/prometheus", get(api::metrics::get_metrics_prometheus))
        .route("/metrics/reset", post(api::metrics::reset_metrics))
        // Chat endpoints
        .route("/chats", get(api::chats::list_chats))
        .route("/chats/:chat_id", get(api::chats::get_chat_messages))
        .route("/chats/:chat_id/metadata", get(api::chats::get_chat_metadata))
        .route("/chats/:chat_id/sync-cache", post(api::chats::sync_chat_cache))
        // Cache management endpoints
        .route("/cache/status", get(api::chats::get_cache_status))
        .route("/cache/verify", post(api::chats::verify_and_fix_cache))
        // Agent endpoints
        .route("/agent/models", get(api::agent::get_models))
        .route("/agent/create-chat", post(api::agent::create_chat))
        .route("/chats/:chat_id/agent-prompt", post(api::agent::send_agent_prompt))
        .route("/chats/:chat_id/agent-prompt-async", post(api::jobs::create_agent_prompt_job))
        // Job endpoints
        .route("/jobs/:job_id", get(api::jobs::get_job_details))
        .route("/jobs/:job_id/status", get(api::jobs::get_job_status))
        .route("/chats/:chat_id/jobs", get(api::jobs::get_chat_jobs_list))
        // Device endpoints
        .route("/devices", post(api::devices::create_device))
        .route("/devices", get(api::devices::list_devices))
        .route("/devices/:device_id", get(api::devices::get_device))
        .route("/devices/:device_id", put(api::devices::update_device))
        .route("/devices/:device_id", delete(api::devices::delete_device))
        .route("/devices/:device_id/test", post(api::devices::test_device_connection))
        .route("/devices/:device_id/verify-agent", post(api::devices::verify_agent_installed))
        .route("/devices/:device_id/create-chat", post(api::devices::create_device_chat))
        .route("/devices/chats/remote", get(api::devices::list_remote_chats))
        .route("/devices/chats/:chat_id/send-prompt", post(api::devices::send_remote_prompt))
        // Add middleware (order matters: last added runs first)
        .layer(middleware::from_fn(
            blink_api::middleware::request_tracing_middleware,
        ))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);
    
    // Start server
    let addr = format!("{}:{}", settings.api_host, settings.api_port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    
    tracing::info!("Server listening on {}", addr);
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

