mod common;
mod fixtures;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::ServiceExt;

#[tokio::test]
async fn test_list_devices_empty() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/devices")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["total"], 0);
    assert!(json["devices"].is_array());
}

#[tokio::test]
async fn test_create_device() {
    let app = common::create_test_app().await;
    
    let device_data = json!({
        "name": "Test Device",
        "api_endpoint": "http://localhost:9876",
        "api_key": "test_api_key_12345678901234567890"
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/devices")
                .method("POST")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_string(&device_data).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert_eq!(json["status"], "success");
    assert_eq!(json["device"]["name"], "Test Device");
}

#[tokio::test]
async fn test_get_device_not_found() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/devices/nonexistent-device-id")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_list_remote_chats() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/devices/chats/remote")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json["chats"].is_array());
    assert_eq!(json["total"], 0);
}

