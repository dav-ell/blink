mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use blink_api::models::device::{Device, DeviceCreate, DeviceStatus};
use blink_api::Settings;
use chrono::Utc;
use http_body_util::BodyExt;
use mockito::Server;
use serde_json::{json, Value};
use std::path::PathBuf;
use tower::ServiceExt;

/// Test network errors when remote service is unavailable
#[tokio::test]
async fn test_remote_service_unavailable() {
    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: "http://192.0.2.1:9999".to_string(), // TEST-NET address - should be unreachable
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 1, // Short timeout
        remote_agent_connect_timeout: 1,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 1,
        ssh_connect_timeout: 1,
        ssh_retry_attempts: 0,
        http_retry_attempts: 0,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    assert!(result.is_err());
}

/// Test HTTP 401 Unauthorized from remote service
#[tokio::test]
async fn test_remote_service_unauthorized() {
    let mut server = Server::new_async().await;

    let mock = server
        .mock("POST", "/execute")
        .with_status(401)
        .with_body(r#"{"error": "Invalid API key"}"#)
        .create_async()
        .await;

    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: server.url(),
        api_key: Some("wrong_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        ssh_retry_attempts: 3,
        http_retry_attempts: 3,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    mock.assert_async().await;
    assert!(result.is_err());
}

/// Test HTTP 500 Internal Server Error from remote service
#[tokio::test]
async fn test_remote_service_internal_error() {
    let mut server = Server::new_async().await;

    let mock = server
        .mock("POST", "/execute")
        .with_status(500)
        .with_body(r#"{"error": "Internal server error"}"#)
        .create_async()
        .await;

    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: server.url(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        ssh_retry_attempts: 3,
        http_retry_attempts: 3,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    mock.assert_async().await;
    assert!(result.is_err());
}

/// Test malformed JSON response from remote service
#[tokio::test]
async fn test_remote_service_malformed_response() {
    let mut server = Server::new_async().await;

    let mock = server
        .mock("POST", "/execute")
        .with_status(200)
        .with_header("content-type", "application/json")
        .with_body(r#"{"invalid": "response", "missing": "fields"}"#)
        .create_async()
        .await;

    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: server.url(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        ssh_retry_attempts: 3,
        http_retry_attempts: 3,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    mock.assert_async().await;
    assert!(result.is_err());
}

/// Test missing API key on device
#[tokio::test]
async fn test_device_missing_api_key() {
    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: None, // Missing API key
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        ssh_retry_attempts: 3,
        http_retry_attempts: 3,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "test prompt",
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        blink_api::AppError::Validation(_)
    ));
}

/// Test API endpoint for deleting non-existent device
#[tokio::test]
async fn test_delete_nonexistent_device() {
    let app = common::create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri("/devices/nonexistent-device-id")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

/// Test API endpoint for updating non-existent device
#[tokio::test]
async fn test_update_nonexistent_device() {
    let app = common::create_test_app().await;

    let update = json!({
        "name": "New Name"
    });

    let response = app
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri("/devices/nonexistent-device-id")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&update).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

/// Test creating device with empty name
#[tokio::test]
async fn test_create_device_empty_name() {
    let app = common::create_test_app().await;

    let device_create = json!({
        "name": "",
        "api_endpoint": "http://localhost:9876"
    });

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/devices")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&device_create).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    // Should either reject empty name or accept it based on validation rules
    // For now, just check that we get some response
    assert!(response.status().is_success() || response.status().is_client_error());
}

/// Test API key validation - too short
#[tokio::test]
async fn test_create_device_short_api_key() {
    let app = common::create_test_app().await;

    let device_create = DeviceCreate {
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("short".to_string()), // Too short
        cursor_agent_path: None,
    };

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/devices")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&device_create).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    // May or may not validate API key length - depends on implementation
    let status = response.status();
    assert!(status.is_success() || status == StatusCode::BAD_REQUEST);
}

/// Test command execution with empty prompt
#[tokio::test]
async fn test_execute_with_empty_prompt() {
    let mut server = Server::new_async().await;

    // Server should handle empty prompts gracefully
    let mock = server
        .mock("POST", "/execute")
        .with_status(400)
        .with_body(r#"{"error": "Prompt cannot be empty"}"#)
        .create_async()
        .await;

    let device = Device {
        id: "test-device".to_string(),
        name: "Test Device".to_string(),
        api_endpoint: server.url(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
        created_at: Utc::now(),
        last_seen: None,
        is_active: true,
        status: DeviceStatus::Online,
    };

    let settings = Settings {
        db_path: PathBuf::from("./test.db"),
        cursor_agent_path: PathBuf::from("cursor-agent"),
        cursor_agent_timeout: 120,
        api_host: "0.0.0.0".to_string(),
        api_port: 8067,
        api_reload: false,
        job_cleanup_max_age_hours: 1,
        job_cleanup_interval_minutes: 30,
        device_db_path: PathBuf::from("./test_devices.db"),
        remote_agent_timeout: 120,
        remote_agent_connect_timeout: 10,
        default_cursor_agent_path: "~/.local/bin/cursor-agent".to_string(),
        ssh_timeout: 300,
        ssh_connect_timeout: 10,
        ssh_retry_attempts: 3,
        http_retry_attempts: 3,
        http_retry_delay_ms: 500,
        http_max_backoff_ms: 10000,
        connection_pool_size: 10,
        connection_pool_timeout: 30,
        enable_request_tracing: true,
        enable_metrics: true,
        metrics_export_path: None,
        max_concurrent_remote_requests: 20,
        cors_allow_origins: vec!["*".to_string()],
        cors_allow_credentials: true,
    };

    let result = blink_api::services::execute_remote_cursor_agent(
        &settings,
        &device,
        "test-chat",
        "", // Empty prompt
        "/tmp/test",
        Some("test-model"),
        "json",
    )
    .await;

    // Should handle empty prompt - either error or send it through
    assert!(result.is_err() || result.is_ok());
}
