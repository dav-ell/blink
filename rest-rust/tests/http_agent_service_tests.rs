mod common;

use blink_api::{
    models::device::{Device, DeviceStatus},
    services::{execute_remote_cursor_agent, test_http_connection},
    Settings,
};
use chrono::Utc;
use mockito::Server;
use std::path::PathBuf;

/// Create a test device pointing to mock server
fn create_test_device(server_url: &str, api_key: Option<String>) -> Device {
    Device {
        id: "test-device-123".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: server_url.to_string(),
        api_key,
        cursor_agent_path: Some("cursor-agent".to_string()),
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    }
}

/// Create test settings
fn create_test_settings() -> Settings {
    Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8000,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    }
}

#[tokio::test]
async fn test_health_check_success() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("GET", "/health")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{"status":"ok","version":"0.1.0","cursor_agent_path":"/usr/local/bin/cursor-agent"}"#)
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    
    let result = test_http_connection(&device, 10).await;
    
    mock.assert_async().await;
    assert!(result.is_ok());
    
    let response = result.unwrap();
    assert!(response.success);
    assert_eq!(response.returncode, 0);
    assert!(response.stdout.contains("0.1.0"));
}

#[tokio::test]
async fn test_health_check_timeout() {
    let mut server = Server::new_async().await;
    
    // For timeout test, we can't easily simulate delay with mockito 1.x
    // Instead, we'll just drop the connection by not responding
    let mock = server
        .mock("GET", "/health")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{"status":"ok","version":"0.1.0","cursor_agent_path":"/usr/local/bin/cursor-agent"}"#)
        .create_async()
        .await;
    
    // Use an invalid URL to force timeout
    let invalid_device = create_test_device("http://192.0.2.1:9999", Some("test_key_1234567890123456".to_string()));
    
    // Use very short timeout
    let result = test_http_connection(&invalid_device, 1).await;
    
    assert!(result.is_err());
    // Could be timeout or connection error
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Timeout(_)) || matches!(err, blink_api::AppError::Http(_)));
}

#[tokio::test]
async fn test_health_check_service_unavailable() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("GET", "/health")
        .with_status(503)
        .with_body("Service unavailable")
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    
    let result = test_http_connection(&device, 10).await;
    
    mock.assert_async().await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Http(_)));
}

#[tokio::test]
async fn test_execute_cursor_agent_success() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("POST", "/execute")
        .match_header("content-type", "application/json")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{
            "success": true,
            "stdout": "Command executed successfully",
            "stderr": "",
            "returncode": 0,
            "execution_time_ms": 1234
        }"#)
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;
    
    mock.assert_async().await;
    assert!(result.is_ok());
    
    let response = result.unwrap();
    assert!(response.success);
    assert_eq!(response.returncode, 0);
    assert_eq!(response.stdout, "Command executed successfully");
    assert_eq!(response.execution_time_ms, 1234);
}

#[tokio::test]
async fn test_execute_cursor_agent_unauthorized() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("POST", "/execute")
        .with_status(401)
        .with_body(r#"{"error": "Invalid API key"}"#)
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("wrong_key_1234567890123456".to_string()));
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;
    
    mock.assert_async().await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Http(_)));
}

#[tokio::test]
async fn test_execute_cursor_agent_missing_api_key() {
    let mut server = Server::new_async().await;
    
    let device = create_test_device(&server.url(), None); // No API key
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;
    
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Validation(_)));
}

#[tokio::test]
async fn test_execute_cursor_agent_command_failure() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("POST", "/execute")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{
            "success": false,
            "stdout": "",
            "stderr": "Command failed: directory not found",
            "returncode": 1,
            "execution_time_ms": 123
        }"#)
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/nonexistent/directory",
        Some("test-model"),
        "json",
    )
    .await;
    
    mock.assert_async().await;
    assert!(result.is_ok()); // HTTP call succeeded even though command failed
    
    let response = result.unwrap();
    assert!(!response.success); // But command failed
    assert_eq!(response.returncode, 1);
    assert!(response.stderr.contains("directory not found"));
}

#[tokio::test]
async fn test_execute_cursor_agent_timeout() {
    let mut server = Server::new_async().await;
    
    // Use an invalid URL to force timeout
    let invalid_device = create_test_device("http://192.0.2.1:9999", Some("test_key_1234567890123456".to_string()));
    let mut settings = create_test_settings();
    settings.remote_agent_timeout = 1; // Very short timeout
    
    let result = execute_remote_cursor_agent(
        &settings,
        &invalid_device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;
    
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Timeout(_)) || matches!(err, blink_api::AppError::Http(_)));
}

#[tokio::test]
async fn test_execute_cursor_agent_malformed_response() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("POST", "/execute")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{"invalid": "response"}"#) // Missing required fields
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;
    
    mock.assert_async().await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(matches!(err, blink_api::AppError::Http(_)));
}

#[tokio::test]
async fn test_execute_cursor_agent_with_default_model() {
    let mut server = Server::new_async().await;
    
    let mock = server
        .mock("POST", "/execute")
        .match_body(mockito::Matcher::Json(
            serde_json::json!({
                "chat_id": "test-chat-123",
                "prompt": "test prompt",
                "working_directory": "/tmp/test",
                "model": "sonnet-4.5-thinking", // Default model
                "output_format": "json",
                "api_key": "test_key_1234567890123456"
            })
        ))
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{
            "success": true,
            "stdout": "ok",
            "stderr": "",
            "returncode": 0,
            "execution_time_ms": 100
        }"#)
        .create_async()
        .await;
    
    let device = create_test_device(&server.url(), Some("test_key_1234567890123456".to_string()));
    let settings = create_test_settings();
    
    let result = execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat-123",
        "test prompt",
        "/tmp/test",
        None, // Use default model
        "json",
    )
    .await;
    
    mock.assert_async().await;
    assert!(result.is_ok());
}

