use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

pub type Result<T> = std::result::Result<T, AppError>;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("SQLx database error: {0}")]
    SqlxDatabase(#[from] sqlx::Error),

    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Internal server error: {0}")]
    Internal(String),

    #[error("Cursor agent error: {0}")]
    CursorAgent(String),

    #[error("SSH error: {0}")]
    Ssh(String),

    #[error("HTTP error: {0}")]
    Http(String),

    #[error("Validation error: {0}")]
    Validation(String),

    #[error("Timeout error: {0}")]
    Timeout(String),
}

impl AppError {
    /// Determine if this error type is retryable
    pub fn is_retryable(&self) -> bool {
        match self {
            // Retryable errors - transient failures
            AppError::Timeout(_) => true,
            AppError::Http(_) => true,
            AppError::Ssh(_) => true,
            AppError::Io(_) => true,
            
            // Non-retryable errors - client errors or permanent failures
            AppError::NotFound(_) => false,
            AppError::BadRequest(_) => false,
            AppError::Validation(_) => false,
            AppError::Json(_) => false,
            
            // Database and internal errors - could be transient
            AppError::Database(_) => true,
            AppError::SqlxDatabase(_) => true,
            AppError::Internal(_) => false, // Generally not retryable
            
            // Cursor agent errors - depends on the error
            AppError::CursorAgent(_) => false, // Default to non-retryable
        }
    }
    
    /// Get the error category for logging and metrics
    pub fn category(&self) -> &'static str {
        match self {
            AppError::Database(_) | AppError::SqlxDatabase(_) => "database",
            AppError::Io(_) => "io",
            AppError::Json(_) => "json",
            AppError::NotFound(_) => "not_found",
            AppError::BadRequest(_) => "bad_request",
            AppError::Internal(_) => "internal",
            AppError::CursorAgent(_) => "cursor_agent",
            AppError::Ssh(_) => "ssh",
            AppError::Http(_) => "http",
            AppError::Validation(_) => "validation",
            AppError::Timeout(_) => "timeout",
        }
    }
    
    /// Add context to an error
    pub fn with_context(self, context: &str) -> Self {
        match self {
            AppError::Database(e) => AppError::Internal(format!("{}: {}", context, e)),
            AppError::SqlxDatabase(e) => AppError::Internal(format!("{}: {}", context, e)),
            AppError::Io(e) => AppError::Internal(format!("{}: {}", context, e)),
            AppError::Json(e) => AppError::Internal(format!("{}: {}", context, e)),
            AppError::NotFound(msg) => AppError::NotFound(format!("{}: {}", context, msg)),
            AppError::BadRequest(msg) => AppError::BadRequest(format!("{}: {}", context, msg)),
            AppError::Internal(msg) => AppError::Internal(format!("{}: {}", context, msg)),
            AppError::CursorAgent(msg) => AppError::CursorAgent(format!("{}: {}", context, msg)),
            AppError::Ssh(msg) => AppError::Ssh(format!("{}: {}", context, msg)),
            AppError::Http(msg) => AppError::Http(format!("{}: {}", context, msg)),
            AppError::Validation(msg) => AppError::Validation(format!("{}: {}", context, msg)),
            AppError::Timeout(msg) => AppError::Timeout(format!("{}: {}", context, msg)),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        // Get metadata before consuming self
        let category = self.category();
        let is_retryable = self.is_retryable();
        let correlation_id = crate::utils::request_context::get_correlation_id();
        
        let (status, error_message) = match self {
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, msg),
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Database(ref e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()),
            AppError::SqlxDatabase(ref e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()),
            AppError::CursorAgent(msg) => (StatusCode::SERVICE_UNAVAILABLE, msg),
            AppError::Ssh(msg) => (StatusCode::SERVICE_UNAVAILABLE, msg),
            AppError::Http(msg) => (StatusCode::BAD_GATEWAY, msg),
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Timeout(msg) => (StatusCode::GATEWAY_TIMEOUT, msg),
            _ => (StatusCode::INTERNAL_SERVER_ERROR, format!("{}", self)),
        };
        
        let mut json_body = json!({
            "error": error_message,
            "status": status.as_u16(),
            "category": category,
            "retryable": is_retryable,
        });
        
        if let Some(corr_id) = correlation_id {
            json_body["correlation_id"] = json!(corr_id);
        }

        let body = Json(json_body);

        (status, body).into_response()
    }
}

