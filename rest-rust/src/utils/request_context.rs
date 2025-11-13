use std::sync::Arc;
use tokio::task_local;
use uuid::Uuid;

/// Request context containing correlation ID and other metadata
#[derive(Debug, Clone)]
pub struct RequestContext {
    /// Correlation ID for tracing requests across services
    pub correlation_id: String,
    
    /// Timestamp when request started (Unix timestamp in milliseconds)
    pub start_time: u128,
    
    /// Optional user/device identifier
    pub user_id: Option<String>,
    
    /// Optional operation name
    pub operation: Option<String>,
}

impl RequestContext {
    /// Create a new request context with generated correlation ID
    pub fn new() -> Self {
        Self {
            correlation_id: Uuid::new_v4().to_string(),
            start_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis(),
            user_id: None,
            operation: None,
        }
    }
    
    /// Create a request context with an existing correlation ID
    pub fn with_correlation_id(correlation_id: String) -> Self {
        Self {
            correlation_id,
            start_time: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis(),
            user_id: None,
            operation: None,
        }
    }
    
    /// Get elapsed time in milliseconds
    pub fn elapsed_ms(&self) -> u128 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis()
            - self.start_time
    }
    
    /// Set operation name
    pub fn with_operation(mut self, operation: String) -> Self {
        self.operation = Some(operation);
        self
    }
    
    /// Set user ID
    pub fn with_user_id(mut self, user_id: String) -> Self {
        self.user_id = Some(user_id);
        self
    }
}

impl Default for RequestContext {
    fn default() -> Self {
        Self::new()
    }
}

task_local! {
    pub static CURRENT_CONTEXT: Arc<RequestContext>;
}

/// Get the current request context if available
pub fn get_current_context() -> Option<Arc<RequestContext>> {
    CURRENT_CONTEXT.try_with(|ctx| ctx.clone()).ok()
}

/// Get the current correlation ID if available
pub fn get_correlation_id() -> Option<String> {
    get_current_context().map(|ctx| ctx.correlation_id.clone())
}

/// Structured logging macros that include correlation ID
#[macro_export]
macro_rules! log_with_context {
    ($level:expr, $($arg:tt)*) => {
        if let Some(ctx) = $crate::utils::request_context::get_current_context() {
            tracing::event!(
                $level,
                correlation_id = %ctx.correlation_id,
                elapsed_ms = %ctx.elapsed_ms(),
                $($arg)*
            );
        } else {
            tracing::event!($level, $($arg)*);
        }
    };
}

#[macro_export]
macro_rules! info_ctx {
    ($($arg:tt)*) => {
        $crate::log_with_context!(tracing::Level::INFO, $($arg)*)
    };
}

#[macro_export]
macro_rules! warn_ctx {
    ($($arg:tt)*) => {
        $crate::log_with_context!(tracing::Level::WARN, $($arg)*)
    };
}

#[macro_export]
macro_rules! error_ctx {
    ($($arg:tt)*) => {
        $crate::log_with_context!(tracing::Level::ERROR, $($arg)*)
    };
}

#[macro_export]
macro_rules! debug_ctx {
    ($($arg:tt)*) => {
        $crate::log_with_context!(tracing::Level::DEBUG, $($arg)*)
    };
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_request_context_creation() {
        let ctx = RequestContext::new();
        assert!(!ctx.correlation_id.is_empty());
        assert!(ctx.start_time > 0);
        assert!(ctx.user_id.is_none());
        assert!(ctx.operation.is_none());
    }
    
    #[test]
    fn test_request_context_with_correlation_id() {
        let test_id = "test-correlation-id".to_string();
        let ctx = RequestContext::with_correlation_id(test_id.clone());
        assert_eq!(ctx.correlation_id, test_id);
    }
    
    #[test]
    fn test_request_context_elapsed_time() {
        let ctx = RequestContext::new();
        std::thread::sleep(std::time::Duration::from_millis(10));
        let elapsed = ctx.elapsed_ms();
        assert!(elapsed >= 10);
    }
    
    #[test]
    fn test_request_context_builder() {
        let ctx = RequestContext::new()
            .with_operation("test_operation".to_string())
            .with_user_id("user123".to_string());
        
        assert_eq!(ctx.operation, Some("test_operation".to_string()));
        assert_eq!(ctx.user_id, Some("user123".to_string()));
    }
}

