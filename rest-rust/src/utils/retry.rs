use crate::error::AppError;
use rand::Rng;
use std::future::Future;
use std::time::Duration;
use tokio::time::sleep;

/// Retry policy configuration
#[derive(Debug, Clone)]
pub struct RetryPolicy {
    /// Maximum number of retry attempts (not including the initial attempt)
    pub max_attempts: u32,
    
    /// Initial delay before the first retry
    pub initial_delay_ms: u64,
    
    /// Maximum delay between retries
    pub max_delay_ms: u64,
    
    /// Multiplier for exponential backoff (default: 2.0)
    pub backoff_multiplier: f64,
    
    /// Jitter percentage (0.0 to 1.0) to add randomness
    pub jitter: f64,
}

impl RetryPolicy {
    /// Create a new retry policy with default values
    pub fn new() -> Self {
        Self {
            max_attempts: 3,
            initial_delay_ms: 500,
            max_delay_ms: 10000,
            backoff_multiplier: 2.0,
            jitter: 0.2,
        }
    }
    
    /// Create a retry policy from settings
    pub fn from_settings(max_attempts: u32, initial_delay_ms: u64, max_delay_ms: u64) -> Self {
        Self {
            max_attempts,
            initial_delay_ms,
            max_delay_ms,
            backoff_multiplier: 2.0,
            jitter: 0.2,
        }
    }
    
    /// Calculate delay for a given attempt number (1-based)
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        if attempt == 0 {
            return Duration::from_millis(0);
        }
        
        // Calculate exponential backoff
        let delay_ms = (self.initial_delay_ms as f64)
            * self.backoff_multiplier.powi((attempt - 1) as i32);
        
        // Cap at max delay
        let delay_ms = delay_ms.min(self.max_delay_ms as f64);
        
        // Add jitter
        let jitter_range = delay_ms * self.jitter;
        let mut rng = rand::thread_rng();
        let jitter = rng.gen_range(-jitter_range..=jitter_range);
        let with_jitter = delay_ms + jitter;
        
        // Ensure we don't exceed max_delay_ms even with jitter, and never go below 0
        let final_delay = with_jitter.max(0.0).min(self.max_delay_ms as f64);
        
        Duration::from_millis(final_delay as u64)
    }
    
    /// Execute a function with retry logic
    pub async fn execute<F, Fut, T>(&self, mut operation: F) -> Result<T, AppError>
    where
        F: FnMut() -> Fut,
        Fut: Future<Output = Result<T, AppError>>,
    {
        let mut last_error = None;
        
        for attempt in 0..=self.max_attempts {
            match operation().await {
                Ok(result) => {
                    if attempt > 0 {
                        tracing::info!(
                            "Operation succeeded after {} retry attempt(s)",
                            attempt
                        );
                    }
                    return Ok(result);
                }
                Err(err) => {
                    // Check if error is retryable
                    if !err.is_retryable() {
                        tracing::warn!(
                            "Non-retryable error encountered: {}",
                            err
                        );
                        return Err(err);
                    }
                    
                    last_error = Some(err);
                    
                    // If we've exhausted retries, return the error
                    if attempt >= self.max_attempts {
                        tracing::error!(
                            "Operation failed after {} attempts",
                            attempt + 1
                        );
                        break;
                    }
                    
                    // Calculate and apply delay
                    let delay = self.delay_for_attempt(attempt + 1);
                    tracing::warn!(
                        "Attempt {} failed, retrying in {:?}",
                        attempt + 1,
                        delay
                    );
                    sleep(delay).await;
                }
            }
        }
        
        Err(last_error.unwrap_or_else(|| {
            AppError::Internal("Retry exhausted with no error captured".to_string())
        }))
    }
    
    /// Execute with retry and return additional metadata
    pub async fn execute_with_metadata<F, Fut, T>(
        &self,
        mut operation: F,
    ) -> RetryResult<T>
    where
        F: FnMut() -> Fut,
        Fut: Future<Output = Result<T, AppError>>,
    {
        let start_time = std::time::Instant::now();
        let mut attempts = 0;
        let mut last_error = None;
        
        for attempt in 0..=self.max_attempts {
            attempts += 1;
            
            match operation().await {
                Ok(result) => {
                    return RetryResult {
                        result: Ok(result),
                        attempts,
                        total_duration: start_time.elapsed(),
                        succeeded: true,
                    };
                }
                Err(err) => {
                    if !err.is_retryable() {
                        return RetryResult {
                            result: Err(err),
                            attempts,
                            total_duration: start_time.elapsed(),
                            succeeded: false,
                        };
                    }
                    
                    last_error = Some(err);
                    
                    if attempt >= self.max_attempts {
                        break;
                    }
                    
                    let delay = self.delay_for_attempt(attempt + 1);
                    sleep(delay).await;
                }
            }
        }
        
        RetryResult {
            result: Err(last_error.unwrap_or_else(|| {
                AppError::Internal("Retry exhausted with no error captured".to_string())
            })),
            attempts,
            total_duration: start_time.elapsed(),
            succeeded: false,
        }
    }
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self::new()
    }
}

/// Result of a retry operation with metadata
#[derive(Debug)]
pub struct RetryResult<T> {
    pub result: Result<T, AppError>,
    pub attempts: u32,
    pub total_duration: Duration,
    pub succeeded: bool,
}

impl<T> RetryResult<T> {
    /// Unwrap the result
    pub fn unwrap(self) -> T {
        self.result.unwrap()
    }
    
    /// Check if operation succeeded
    pub fn is_ok(&self) -> bool {
        self.succeeded
    }
    
    /// Check if operation failed
    pub fn is_err(&self) -> bool {
        !self.succeeded
    }
}

/// Helper function to create a retry policy with quick defaults
pub fn quick_retry() -> RetryPolicy {
    RetryPolicy {
        max_attempts: 2,
        initial_delay_ms: 100,
        max_delay_ms: 1000,
        backoff_multiplier: 2.0,
        jitter: 0.2,
    }
}

/// Helper function to create a retry policy for longer operations
pub fn patient_retry() -> RetryPolicy {
    RetryPolicy {
        max_attempts: 5,
        initial_delay_ms: 1000,
        max_delay_ms: 30000,
        backoff_multiplier: 2.0,
        jitter: 0.2,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};
    use std::sync::Arc;
    
    #[test]
    fn test_delay_calculation() {
        let policy = RetryPolicy::new();
        
        let delay1 = policy.delay_for_attempt(1);
        let delay2 = policy.delay_for_attempt(2);
        let delay3 = policy.delay_for_attempt(3);
        
        // Delays should increase
        assert!(delay1 < delay2);
        assert!(delay2 < delay3);
        
        // Should not exceed max
        let delay_large = policy.delay_for_attempt(100);
        assert!(delay_large.as_millis() <= policy.max_delay_ms as u128);
    }
    
    #[tokio::test]
    async fn test_retry_success_on_first_attempt() {
        let policy = RetryPolicy::new();
        let counter = Arc::new(AtomicU32::new(0));
        
        let result = policy
            .execute(|| {
                let counter = counter.clone();
                async move {
                    counter.fetch_add(1, Ordering::SeqCst);
                    Ok::<_, AppError>(42)
                }
            })
            .await;
        
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 42);
        assert_eq!(counter.load(Ordering::SeqCst), 1);
    }
    
    #[tokio::test]
    async fn test_retry_success_after_failures() {
        let policy = RetryPolicy {
            max_attempts: 3,
            initial_delay_ms: 10,
            max_delay_ms: 100,
            backoff_multiplier: 2.0,
            jitter: 0.0, // No jitter for predictable testing
        };
        
        let counter = Arc::new(AtomicU32::new(0));
        
        let result = policy
            .execute(|| {
                let counter = counter.clone();
                async move {
                    let count = counter.fetch_add(1, Ordering::SeqCst);
                    if count < 2 {
                        Err(AppError::Http("Temporary failure".to_string()))
                    } else {
                        Ok(42)
                    }
                }
            })
            .await;
        
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 42);
        assert_eq!(counter.load(Ordering::SeqCst), 3);
    }
    
    #[tokio::test]
    async fn test_retry_exhausted() {
        let policy = RetryPolicy {
            max_attempts: 2,
            initial_delay_ms: 10,
            max_delay_ms: 100,
            backoff_multiplier: 2.0,
            jitter: 0.0,
        };
        
        let counter = Arc::new(AtomicU32::new(0));
        
        let result = policy
            .execute(|| {
                let counter = counter.clone();
                async move {
                    counter.fetch_add(1, Ordering::SeqCst);
                    Err::<(), _>(AppError::Http("Always fails".to_string()))
                }
            })
            .await;
        
        assert!(result.is_err());
        // Initial attempt + 2 retries = 3 total
        assert_eq!(counter.load(Ordering::SeqCst), 3);
    }
    
    #[tokio::test]
    async fn test_non_retryable_error() {
        let policy = RetryPolicy::new();
        let counter = Arc::new(AtomicU32::new(0));
        
        let result = policy
            .execute(|| {
                let counter = counter.clone();
                async move {
                    counter.fetch_add(1, Ordering::SeqCst);
                    Err::<(), _>(AppError::NotFound("Not found".to_string()))
                }
            })
            .await;
        
        assert!(result.is_err());
        // Should not retry non-retryable errors
        assert_eq!(counter.load(Ordering::SeqCst), 1);
    }
}

