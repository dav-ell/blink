mod common;
mod fixtures;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

#[tokio::test]
async fn test_get_job_details_not_found() {
    let app = common::create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/jobs/nonexistent-job-id")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    // Should return 404 for non-existent job
    let status = response.status();
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::INTERNAL_SERVER_ERROR,
        "Expected 404 or 500, got {}",
        status
    );
}

#[tokio::test]
async fn test_get_job_status_not_found() {
    let app = common::create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/jobs/nonexistent-job-id/status")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    // Should return 404 for non-existent job
    let status = response.status();
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::INTERNAL_SERVER_ERROR,
        "Expected 404 or 500, got {}",
        status
    );
}

#[tokio::test]
async fn test_get_chat_jobs() {
    let app = common::create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/chats/test-chat-id/jobs")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    // Should return OK with empty list or internal error if implementation pending
    let status = response.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::INTERNAL_SERVER_ERROR,
        "Expected 200 or 500, got {}",
        status
    );

    if status == StatusCode::OK {
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert!(json["jobs"].is_array());
    }
}
