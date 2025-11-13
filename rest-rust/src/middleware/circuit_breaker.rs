use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

/// Circuit breaker states
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitBreakerState {
    /// Circuit is closed, requests flow normally
    Closed,
    /// Circuit is open, requests are rejected
    Open,
    /// Circuit is half-open, testing if service recovered
    HalfOpen,
}

/// Per-device circuit breaker
#[derive(Debug, Clone)]
pub struct CircuitBreaker {
    state: CircuitBreakerState,
    failure_count: u32,
    success_count: u32,
    last_failure_time: Option<Instant>,
    last_state_change: Instant,
}

impl CircuitBreaker {
    fn new() -> Self {
        Self {
            state: CircuitBreakerState::Closed,
            failure_count: 0,
            success_count: 0,
            last_failure_time: None,
            last_state_change: Instant::now(),
        }
    }
    
    /// Record a successful request
    fn record_success(&mut self, config: &CircuitBreakerConfig) {
        self.success_count += 1;
        
        match self.state {
            CircuitBreakerState::HalfOpen => {
                // If enough successes in half-open state, close the circuit
                if self.success_count >= config.success_threshold {
                    tracing::info!("Circuit breaker closing after successful requests");
                    self.state = CircuitBreakerState::Closed;
                    self.failure_count = 0;
                    self.success_count = 0;
                    self.last_state_change = Instant::now();
                }
            }
            CircuitBreakerState::Closed => {
                // Reset failure count on success
                self.failure_count = 0;
            }
            CircuitBreakerState::Open => {
                // Shouldn't happen, but reset to closed if it does
                self.state = CircuitBreakerState::Closed;
                self.failure_count = 0;
                self.success_count = 0;
                self.last_state_change = Instant::now();
            }
        }
    }
    
    /// Record a failed request
    fn record_failure(&mut self, config: &CircuitBreakerConfig) {
        self.failure_count += 1;
        self.last_failure_time = Some(Instant::now());
        
        match self.state {
            CircuitBreakerState::Closed => {
                // Open circuit if failure threshold exceeded
                if self.failure_count >= config.failure_threshold {
                    tracing::warn!(
                        "Circuit breaker opening after {} failures",
                        self.failure_count
                    );
                    self.state = CircuitBreakerState::Open;
                    self.success_count = 0;
                    self.last_state_change = Instant::now();
                }
            }
            CircuitBreakerState::HalfOpen => {
                // Return to open state on failure
                tracing::warn!("Circuit breaker re-opening after failure in half-open state");
                self.state = CircuitBreakerState::Open;
                self.success_count = 0;
                self.last_state_change = Instant::now();
            }
            CircuitBreakerState::Open => {
                // Already open, just track the failure
            }
        }
    }
    
    /// Check if the circuit breaker should transition to half-open
    fn maybe_transition_to_half_open(&mut self, config: &CircuitBreakerConfig) {
        if self.state == CircuitBreakerState::Open {
            let elapsed = self.last_state_change.elapsed();
            if elapsed >= config.timeout {
                tracing::info!("Circuit breaker transitioning to half-open after {:?}", elapsed);
                self.state = CircuitBreakerState::HalfOpen;
                self.failure_count = 0;
                self.success_count = 0;
                self.last_state_change = Instant::now();
            }
        }
    }
    
    /// Check if a request should be allowed
    fn should_allow_request(&self) -> bool {
        match self.state {
            CircuitBreakerState::Closed => true,
            CircuitBreakerState::HalfOpen => true,
            CircuitBreakerState::Open => false,
        }
    }
}

/// Circuit breaker configuration
#[derive(Debug, Clone)]
pub struct CircuitBreakerConfig {
    /// Number of failures before opening the circuit
    pub failure_threshold: u32,
    
    /// Number of successes required to close the circuit from half-open
    pub success_threshold: u32,
    
    /// Time to wait before transitioning from open to half-open
    pub timeout: Duration,
}

impl Default for CircuitBreakerConfig {
    fn default() -> Self {
        Self {
            failure_threshold: 5,
            success_threshold: 2,
            timeout: Duration::from_secs(60),
        }
    }
}

/// Manages circuit breakers for multiple devices
#[derive(Clone)]
pub struct DeviceCircuitBreaker {
    breakers: Arc<RwLock<HashMap<String, CircuitBreaker>>>,
    config: CircuitBreakerConfig,
}

impl DeviceCircuitBreaker {
    /// Create a new device circuit breaker manager
    pub fn new(config: CircuitBreakerConfig) -> Self {
        Self {
            breakers: Arc::new(RwLock::new(HashMap::new())),
            config,
        }
    }
    
    /// Create with default configuration
    pub fn default() -> Self {
        Self::new(CircuitBreakerConfig::default())
    }
    
    /// Check if a request to a device should be allowed
    pub fn should_allow_request(&self, device_id: &str) -> bool {
        let mut breakers = self.breakers.write().unwrap();
        let breaker = breakers
            .entry(device_id.to_string())
            .or_insert_with(CircuitBreaker::new);
        
        // Check if should transition to half-open
        breaker.maybe_transition_to_half_open(&self.config);
        
        breaker.should_allow_request()
    }
    
    /// Record a successful request to a device
    pub fn record_success(&self, device_id: &str) {
        let mut breakers = self.breakers.write().unwrap();
        let breaker = breakers
            .entry(device_id.to_string())
            .or_insert_with(CircuitBreaker::new);
        
        breaker.record_success(&self.config);
    }
    
    /// Record a failed request to a device
    pub fn record_failure(&self, device_id: &str) {
        let mut breakers = self.breakers.write().unwrap();
        let breaker = breakers
            .entry(device_id.to_string())
            .or_insert_with(CircuitBreaker::new);
        
        breaker.record_failure(&self.config);
    }
    
    /// Get the current state of a device's circuit breaker
    pub fn get_state(&self, device_id: &str) -> CircuitBreakerState {
        let breakers = self.breakers.read().unwrap();
        breakers
            .get(device_id)
            .map(|b| b.state)
            .unwrap_or(CircuitBreakerState::Closed)
    }
    
    /// Reset a device's circuit breaker
    pub fn reset(&self, device_id: &str) {
        let mut breakers = self.breakers.write().unwrap();
        breakers.remove(device_id);
    }
    
    /// Get statistics for all circuit breakers
    pub fn get_statistics(&self) -> HashMap<String, CircuitBreakerStats> {
        let breakers = self.breakers.read().unwrap();
        breakers
            .iter()
            .map(|(device_id, breaker)| {
                (
                    device_id.clone(),
                    CircuitBreakerStats {
                        state: breaker.state,
                        failure_count: breaker.failure_count,
                        success_count: breaker.success_count,
                        last_failure_seconds_ago: breaker
                            .last_failure_time
                            .map(|t| t.elapsed().as_secs()),
                    },
                )
            })
            .collect()
    }
}

/// Statistics for a circuit breaker
#[derive(Debug, Clone, serde::Serialize)]
pub struct CircuitBreakerStats {
    pub state: CircuitBreakerState,
    pub failure_count: u32,
    pub success_count: u32,
    pub last_failure_seconds_ago: Option<u64>,
}

impl serde::Serialize for CircuitBreakerState {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(match self {
            CircuitBreakerState::Closed => "closed",
            CircuitBreakerState::Open => "open",
            CircuitBreakerState::HalfOpen => "half_open",
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_circuit_breaker_transitions() {
        let config = CircuitBreakerConfig {
            failure_threshold: 3,
            success_threshold: 2,
            timeout: Duration::from_millis(100),
        };
        
        let cb = DeviceCircuitBreaker::new(config);
        let device_id = "test-device";
        
        // Initially closed
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::Closed);
        assert!(cb.should_allow_request(device_id));
        
        // Record failures
        cb.record_failure(device_id);
        cb.record_failure(device_id);
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::Closed);
        
        cb.record_failure(device_id);
        // Should open after 3 failures
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::Open);
        assert!(!cb.should_allow_request(device_id));
    }
    
    #[tokio::test]
    async fn test_circuit_breaker_half_open() {
        let config = CircuitBreakerConfig {
            failure_threshold: 2,
            success_threshold: 2,
            timeout: Duration::from_millis(50),
        };
        
        let cb = DeviceCircuitBreaker::new(config);
        let device_id = "test-device";
        
        // Open the circuit
        cb.record_failure(device_id);
        cb.record_failure(device_id);
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::Open);
        
        // Wait for timeout
        tokio::time::sleep(Duration::from_millis(60)).await;
        
        // Should transition to half-open
        assert!(cb.should_allow_request(device_id));
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::HalfOpen);
        
        // Record successes
        cb.record_success(device_id);
        cb.record_success(device_id);
        
        // Should close
        assert_eq!(cb.get_state(device_id), CircuitBreakerState::Closed);
    }
}

