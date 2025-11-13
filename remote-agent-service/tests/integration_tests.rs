mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
    routing::{get, post},
    Json,
};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use std::{net::TcpListener, sync::Arc};
use tempfile::TempDir;
use tower::ServiceExt as TowerServiceExt;

/// Helper to create test app
async fn create_test_app() -> (axum::Router, String) {
    use std::sync::Arc;
    
    // Find available port
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let api_key = common::valid_api_key();
    
    // Set up test environment
    std::env::set_var("API_KEY", &api_key);
    std::env::set_var("HOST", "127.0.0.1");
    std::env::set_var("PORT", addr.port().to_string());
    std::env::set_var("CURSOR_AGENT_PATH", "/bin/echo"); // Use echo for testing
    std::env::set_var("EXECUTION_TIMEOUT", "10");
    
    let config = remote_agent_service::Config::from_env().unwrap();
    
    #[derive(Clone)]
    struct AppState {
        config: Arc<remote_agent_service::Config>,
    }
    
    let state = AppState {
        config: Arc::new(config),
    };
    
    // Health endpoint handler
    async fn health_handler(
        axum::extract::State(state): axum::extract::State<AppState>,
    ) -> Json<Value> {
        Json(json!({
            "status": "ok",
            "version": env!("CARGO_PKG_VERSION"),
            "cursor_agent_path": state.config.cursor_agent_path
        }))
    }
    
    // Execute endpoint handler
    async fn execute_handler(
        axum::extract::State(state): axum::extract::State<AppState>,
        Json(payload): Json<Value>,
    ) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
        // Validate API key
        let req_api_key = payload.get("api_key")
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                (StatusCode::BAD_REQUEST, Json(json!({"error": "Missing api_key"})))
            })?;
        
        if req_api_key != state.config.api_key {
            return Err((StatusCode::UNAUTHORIZED, Json(json!({"error": "Invalid API key"}))));
        }
        
        // Extract fields
        let working_dir = payload.get("working_directory")
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                (StatusCode::BAD_REQUEST, Json(json!({"error": "Missing working_directory"})))
            })?;
        
        let prompt = payload.get("prompt")
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                (StatusCode::BAD_REQUEST, Json(json!({"error": "Missing prompt"})))
            })?;
        
        let chat_id = payload.get("chat_id")
            .and_then(|v| v.as_str())
            .unwrap_or("test-chat");
        
        let model = payload.get("model")
            .and_then(|v| v.as_str())
            .unwrap_or("test-model");
        
        let output_format = payload.get("output_format")
            .and_then(|v| v.as_str())
            .unwrap_or("json");
        
        // Execute
        match remote_agent_service::execute_cursor_agent(
            &state.config.cursor_agent_path,
            chat_id,
            prompt,
            working_dir,
            model,
            output_format,
        ).await {
            Ok(result) => Ok(Json(json!({
                "success": result.success,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode,
                "execution_time_ms": 0
            }))),
            Err(e) => Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"error": e.to_string()})))),
        }
    }
    
    let app = axum::Router::new()
        .route("/health", get(health_handler))
        .route("/execute", post(execute_handler))
        .with_state(state);
    
    (app, api_key)
}

#[tokio::test]
async fn test_health_endpoint() {
    let (app, _api_key) = create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["status"], "ok");
    assert!(json.get("version").is_some());
    
    common::cleanup_test_env();
}

#[tokio::test]
async fn test_execute_with_valid_api_key() {
    let (app, api_key) = create_test_app().await;
    let temp_dir = TempDir::new().unwrap();
    
    let payload = json!({
        "chat_id": "test-123",
        "prompt": "test prompt",
        "working_directory": temp_dir.path().to_str().unwrap(),
        "model": "test",
        "output_format": "json",
        "api_key": api_key
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/execute")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    let status = response.status();
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    if status != StatusCode::OK {
        eprintln!("Error response: {:?}", json);
    }
    
    assert_eq!(status, StatusCode::OK);
    assert_eq!(json["success"], true);
    assert_eq!(json["returncode"], 0);
    
    common::cleanup_test_env();
}

#[tokio::test]
async fn test_execute_with_invalid_api_key() {
    let (app, _api_key) = create_test_app().await;
    let temp_dir = TempDir::new().unwrap();
    
    let payload = json!({
        "chat_id": "test-123",
        "prompt": "test prompt",
        "working_directory": temp_dir.path().to_str().unwrap(),
        "model": "test",
        "output_format": "json",
        "api_key": "wrong_api_key_12345678901234567890"
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/execute")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    
    common::cleanup_test_env();
}

#[tokio::test]
async fn test_execute_with_missing_working_directory() {
    let (app, api_key) = create_test_app().await;
    
    let payload = json!({
        "chat_id": "test-123",
        "prompt": "test prompt",
        "model": "test",
        "output_format": "json",
        "api_key": api_key
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/execute")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    
    common::cleanup_test_env();
}

#[tokio::test]
async fn test_execute_with_nonexistent_directory() {
    let (app, api_key) = create_test_app().await;
    
    let payload = json!({
        "chat_id": "test-123",
        "prompt": "test prompt",
        "working_directory": "/nonexistent/directory/path",
        "model": "test",
        "output_format": "json",
        "api_key": api_key
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/execute")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json["error"].as_str().unwrap().contains("does not exist"));
    
    common::cleanup_test_env();
}

