use axum::{extract::Request, http::HeaderMap, middleware::Next, response::Response};
use std::time::Instant;

use crate::utils::request_context::RequestContext;
use crate::utils::request_context::CURRENT_CONTEXT;

/// Middleware to inject correlation ID and create request context
pub async fn request_tracing_middleware(
    headers: HeaderMap,
    request: Request,
    next: Next,
) -> Response {
    let start = Instant::now();

    // Extract or generate correlation ID
    let correlation_id = headers
        .get("X-Correlation-ID")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    // Extract method and path for logging
    let method = request.method().clone();
    let path = request.uri().path().to_string();

    // Create request context
    let context = RequestContext::with_correlation_id(correlation_id.clone())
        .with_operation(format!("{} {}", method, path));

    // Log request start
    tracing::info!(
        correlation_id = %context.correlation_id,
        method = %method,
        path = %path,
        "Request started"
    );

    // Run the request with context
    let response = CURRENT_CONTEXT
        .scope(std::sync::Arc::new(context.clone()), async move {
            next.run(request).await
        })
        .await;

    // Calculate duration
    let duration = start.elapsed();
    let status = response.status();

    // Log request completion
    if status.is_server_error() || status.is_client_error() {
        tracing::error!(
            correlation_id = %context.correlation_id,
            method = %method,
            path = %path,
            status = %status.as_u16(),
            duration_ms = %duration.as_millis(),
            "Request failed"
        );
    } else {
        tracing::info!(
            correlation_id = %context.correlation_id,
            method = %method,
            path = %path,
            status = %status.as_u16(),
            duration_ms = %duration.as_millis(),
            "Request completed"
        );
    }

    // Add correlation ID to response headers
    let (mut parts, body) = response.into_parts();
    parts
        .headers
        .insert("X-Correlation-ID", context.correlation_id.parse().unwrap());

    Response::from_parts(parts, body)
}

/// Middleware to collect metrics for requests
pub async fn metrics_middleware(request: Request, next: Next) -> Response {
    let start = Instant::now();
    let method = request.method().clone();
    let path = request.uri().path().to_string();

    // Run the request
    let response = next.run(request).await;

    // Record metrics
    let duration = start.elapsed();
    let status = response.status();

    // Get metrics collector from app state if available
    // Note: This would require extracting State from the request
    // For now, we'll log the metrics
    tracing::debug!(
        method = %method,
        path = %path,
        status = %status.as_u16(),
        duration_ms = %duration.as_millis(),
        "Request metrics"
    );

    response
}

#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn test_correlation_id_generation() {
        // This would require a more complex test setup with axum
        // Placeholder for future implementation
    }
}
