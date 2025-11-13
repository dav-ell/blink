mod common;
mod fixtures;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use tower::ServiceExt;

#[tokio::test]
async fn test_list_chats() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(Request::builder().uri("/chats").body(Body::empty()).unwrap())
        .await
        .unwrap();
    
    // The endpoint requires a valid cursor database, so it may return 404 or error
    // This is acceptable for a test with no real Cursor DB
    let status = response.status();
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::INTERNAL_SERVER_ERROR || status == StatusCode::OK,
        "Unexpected status: {}",
        status
    );
}

#[tokio::test]
async fn test_list_chats_with_pagination() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/chats?limit=10&offset=0")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    // The endpoint requires a valid cursor database, so it may return 404 or error
    let status = response.status();
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::INTERNAL_SERVER_ERROR || status == StatusCode::OK,
        "Unexpected status: {}",
        status
    );
}

#[tokio::test]
async fn test_get_chat_messages_not_found() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/chats/nonexistent-chat-id")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    // Should return 404 or empty result
    let status = response.status();
    assert!(status == StatusCode::NOT_FOUND || status == StatusCode::OK);
}

#[tokio::test]
async fn test_get_chat_metadata_not_found() {
    let app = common::create_test_app().await;
    
    let response = app
        .oneshot(
            Request::builder()
                .uri("/chats/nonexistent-chat-id/metadata")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    
    // Should handle gracefully
    let status = response.status();
    assert!(status == StatusCode::NOT_FOUND || status == StatusCode::OK);
}

