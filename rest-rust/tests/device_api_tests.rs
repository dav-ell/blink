mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use blink_api::models::device::{DeviceCreate, DeviceUpdate};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::ServiceExt;

#[tokio::test]
async fn test_create_device_success() {
    let app = common::create_test_app().await;
    
    let device_create = DeviceCreate {
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: Some("/usr/local/bin/cursor-agent".to_string()),
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
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["status"], "success");
    assert!(json["device"]["id"].is_string());
    assert_eq!(json["device"]["name"], "Test Device");
    assert_eq!(json["device"]["api_endpoint"], "http://localhost:9876");
}

#[tokio::test]
async fn test_create_device_validation_failure() {
    let app = common::create_test_app().await;
    
    // Missing required field api_endpoint
    let invalid_device = json!({
        "name": "Test Device"
        // Missing api_endpoint
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/devices")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&invalid_device).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    // Should fail because api_endpoint is required
    assert!(response.status() == StatusCode::BAD_REQUEST || response.status() == StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn test_list_devices() {
    let app = common::create_test_app().await;
    
    // Create a test device first via API
    let device_create = DeviceCreate {
        name: "Test Device 1".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let _ = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/devices")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&device_create).unwrap()))
                .unwrap(),
        )
        .await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/devices")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json["total"].as_u64().unwrap() >= 1);
    assert!(json["devices"].is_array());
}

#[tokio::test]
async fn test_list_devices_include_active_only() {
    let app = common::create_test_app().await;
    
    // Create an active device
    let device_create = DeviceCreate {
        name: "Active Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json["device"]["id"].as_str().unwrap().to_string();
    
    // List without include_inactive (default is active only)
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/devices?include_inactive=false")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    // Should include our active device
    let devices = json["devices"].as_array().unwrap();
    assert!(devices.iter().any(|d| d["id"] == device_id));
}

#[tokio::test]
async fn test_get_device() {
    let app = common::create_test_app().await;
    
    // Create a device
    let device_create = DeviceCreate {
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json_create: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json_create["device"]["id"].as_str().unwrap().to_string();
    
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri(&format!("/devices/{}", device_id))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["id"], device_id);
    assert_eq!(json["name"], "Test Device");
}

#[tokio::test]
async fn test_get_device_not_found() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/devices/nonexistent-id")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_update_device() {
    let app = common::create_test_app().await;
    
    // Create a device
    let device_create = DeviceCreate {
        name: "Original Name".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json_create: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json_create["device"]["id"].as_str().unwrap().to_string();
    
    // Update it
    let device_update = DeviceUpdate {
        name: Some("Updated Name".to_string()),
        api_endpoint: Some("http://localhost:9877".to_string()),
        api_key: Some("new_api_key_123456789012345678901234".to_string()),
        cursor_agent_path: None,
        is_active: None,
    };
    
    let response = app
        .oneshot(
            Request::builder()
                .method("PUT")
                .uri(&format!("/devices/{}", device_id))
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&device_update).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["status"], "success");
    assert_eq!(json["device"]["name"], "Updated Name");
    assert_eq!(json["device"]["api_endpoint"], "http://localhost:9877");
}

#[tokio::test]
async fn test_delete_device() {
    let app = common::create_test_app().await;
    
    // Create a device
    let device_create = DeviceCreate {
        name: "Device To Delete".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json_create: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json_create["device"]["id"].as_str().unwrap().to_string();
    
    // Delete it
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("DELETE")
                .uri(&format!("/devices/{}", device_id))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["status"], "success");
    
    // Verify device is deleted/deactivated
    let get_response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri(&format!("/devices/{}", device_id))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    // Should be not found or marked inactive
    assert!(get_response.status() == StatusCode::NOT_FOUND || {
        let body = get_response.into_body().collect().await.unwrap().to_bytes();
        let json: Value = serde_json::from_slice(&body).unwrap();
        json["is_active"] == false
    });
}

#[tokio::test]
async fn test_create_remote_chat() {
    let app = common::create_test_app().await;
    
    // Create a device first
    let device_create = DeviceCreate {
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json_create: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json_create["device"]["id"].as_str().unwrap().to_string();
    
    // Create a remote chat
    let chat_create = json!({
        "device_id": device_id,
        "name": "Test Chat",
        "working_directory": "/tmp/test"
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(&format!("/devices/{}/create-chat", device_id))
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&chat_create).unwrap()))
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
    
    // Check if response has expected structure - it might be flat or nested
    if json.get("chat").is_some() {
        assert_eq!(json["status"], "success");
        assert!(json["chat"]["id"].is_string());
        assert_eq!(json["chat"]["device_id"], device_id);
    } else {
        // Response might be the chat object directly
        assert!(json["id"].is_string() || json["chat_id"].is_string());
    }
}

#[tokio::test]
async fn test_list_remote_chats() {
    let app = common::create_test_app().await;
    
    // Create a device
    let device_create = DeviceCreate {
        name: "Test Device".to_string(),
        api_endpoint: "http://localhost:9876".to_string(),
        api_key: Some("test_api_key_12345678901234567890".to_string()),
        cursor_agent_path: None,
    };
    
    let create_response = app
        .clone()
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
    
    let body = create_response.into_body().collect().await.unwrap().to_bytes();
    let json_create: Value = serde_json::from_slice(&body).unwrap();
    let device_id = json_create["device"]["id"].as_str().unwrap().to_string();
    
    // Create a chat
    let chat_create = json!({
        "device_id": device_id,
        "name": "Test Chat",
        "working_directory": "/tmp/test"
    });
    
    let _ = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(&format!("/devices/{}/create-chat", device_id))
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&chat_create).unwrap()))
                .unwrap(),
        )
        .await;
    
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri(&format!("/devices/chats/remote?device_id={}", device_id))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json["total"].as_u64().unwrap() >= 1);
    assert!(json["chats"].is_array());
}

