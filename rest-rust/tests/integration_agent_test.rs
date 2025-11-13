mod common;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

#[tokio::test]
async fn test_get_models() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/agent/models")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    assert_eq!(response.status(), StatusCode::OK);
    
    let body = response.into_body().collect().await.unwrap().to_bytes();
    let json: Value = serde_json::from_slice(&body).unwrap();
    
    assert!(json["models"].is_array());
    let models = json["models"].as_array().unwrap();
    assert!(!models.is_empty(), "Should have at least one model");
}

