use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Metrics collector for tracking application performance and health
#[derive(Clone)]
pub struct MetricsCollector {
    inner: Arc<RwLock<MetricsInner>>,
}

#[derive(Debug)]
struct MetricsInner {
    counters: HashMap<String, u64>,
    histograms: HashMap<String, Vec<f64>>,
    gauges: HashMap<String, f64>,
    last_reset: SystemTime,
}

impl Default for MetricsInner {
    fn default() -> Self {
        Self {
            counters: HashMap::new(),
            histograms: HashMap::new(),
            gauges: HashMap::new(),
            last_reset: SystemTime::now(),
        }
    }
}

/// Snapshot of current metrics
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MetricsSnapshot {
    pub timestamp: u64,
    pub uptime_seconds: u64,
    pub counters: HashMap<String, u64>,
    pub histograms: HashMap<String, HistogramStats>,
    pub gauges: HashMap<String, f64>,
}

/// Statistical summary of a histogram
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HistogramStats {
    pub count: usize,
    pub sum: f64,
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub p50: f64,
    pub p95: f64,
    pub p99: f64,
}

impl MetricsCollector {
    /// Create a new metrics collector
    pub fn new() -> Self {
        Self {
            inner: Arc::new(RwLock::new(MetricsInner {
                counters: HashMap::new(),
                histograms: HashMap::new(),
                gauges: HashMap::new(),
                last_reset: SystemTime::now(),
            })),
        }
    }

    /// Increment a counter by 1
    pub fn increment_counter(&self, name: &str) {
        self.add_counter(name, 1);
    }

    /// Add to a counter
    pub fn add_counter(&self, name: &str, value: u64) {
        if let Ok(mut inner) = self.inner.write() {
            *inner.counters.entry(name.to_string()).or_insert(0) += value;
        }
    }

    /// Record a value in a histogram
    pub fn record_histogram(&self, name: &str, value: f64) {
        if let Ok(mut inner) = self.inner.write() {
            inner
                .histograms
                .entry(name.to_string())
                .or_insert_with(Vec::new)
                .push(value);
        }
    }

    /// Set a gauge value
    pub fn set_gauge(&self, name: &str, value: f64) {
        if let Ok(mut inner) = self.inner.write() {
            inner.gauges.insert(name.to_string(), value);
        }
    }

    /// Record a duration in milliseconds
    pub fn record_duration(&self, name: &str, duration: Duration) {
        self.record_histogram(name, duration.as_millis() as f64);
    }

    /// Get a snapshot of current metrics
    pub fn snapshot(&self) -> MetricsSnapshot {
        let inner = self.inner.read().unwrap();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let uptime = SystemTime::now()
            .duration_since(inner.last_reset)
            .unwrap()
            .as_secs();

        let histograms = inner
            .histograms
            .iter()
            .map(|(name, values)| (name.clone(), calculate_histogram_stats(values)))
            .collect();

        MetricsSnapshot {
            timestamp: now,
            uptime_seconds: uptime,
            counters: inner.counters.clone(),
            histograms,
            gauges: inner.gauges.clone(),
        }
    }

    /// Reset all metrics
    pub fn reset(&self) {
        if let Ok(mut inner) = self.inner.write() {
            inner.counters.clear();
            inner.histograms.clear();
            inner.gauges.clear();
            inner.last_reset = SystemTime::now();
        }
    }

    /// Export metrics to JSON string
    pub fn export_json(&self) -> Result<String, serde_json::Error> {
        let snapshot = self.snapshot();
        serde_json::to_string_pretty(&snapshot)
    }
}

impl Default for MetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

/// Calculate histogram statistics
fn calculate_histogram_stats(values: &[f64]) -> HistogramStats {
    if values.is_empty() {
        return HistogramStats {
            count: 0,
            sum: 0.0,
            min: 0.0,
            max: 0.0,
            mean: 0.0,
            p50: 0.0,
            p95: 0.0,
            p99: 0.0,
        };
    }

    let mut sorted = values.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let count = sorted.len();
    let sum: f64 = sorted.iter().sum();
    let mean = sum / count as f64;

    HistogramStats {
        count,
        sum,
        min: sorted[0],
        max: sorted[count - 1],
        mean,
        p50: percentile(&sorted, 0.50),
        p95: percentile(&sorted, 0.95),
        p99: percentile(&sorted, 0.99),
    }
}

/// Calculate percentile from sorted values
fn percentile(sorted: &[f64], p: f64) -> f64 {
    let index = (p * (sorted.len() - 1) as f64) as usize;
    sorted[index]
}

/// Metric names constants
pub mod metric_names {
    // Request metrics
    pub const HTTP_REQUESTS_TOTAL: &str = "http_requests_total";
    pub const HTTP_REQUEST_DURATION_MS: &str = "http_request_duration_ms";
    pub const HTTP_REQUESTS_ERROR: &str = "http_requests_error";

    // Agent execution metrics
    pub const AGENT_EXECUTIONS_TOTAL: &str = "agent_executions_total";
    pub const AGENT_EXECUTION_DURATION_MS: &str = "agent_execution_duration_ms";
    pub const AGENT_EXECUTIONS_ERROR: &str = "agent_executions_error";
    pub const AGENT_EXECUTIONS_TIMEOUT: &str = "agent_executions_timeout";

    // SSH metrics
    pub const SSH_CONNECTIONS_TOTAL: &str = "ssh_connections_total";
    pub const SSH_CONNECTION_DURATION_MS: &str = "ssh_connection_duration_ms";
    pub const SSH_CONNECTIONS_ERROR: &str = "ssh_connections_error";

    // HTTP client metrics
    pub const HTTP_CLIENT_REQUESTS_TOTAL: &str = "http_client_requests_total";
    pub const HTTP_CLIENT_REQUEST_DURATION_MS: &str = "http_client_request_duration_ms";
    pub const HTTP_CLIENT_REQUESTS_ERROR: &str = "http_client_requests_error";

    // Retry metrics
    pub const RETRY_ATTEMPTS_TOTAL: &str = "retry_attempts_total";
    pub const RETRY_SUCCESS_TOTAL: &str = "retry_success_total";
    pub const RETRY_EXHAUSTED_TOTAL: &str = "retry_exhausted_total";

    // Job metrics
    pub const JOBS_CREATED_TOTAL: &str = "jobs_created_total";
    pub const JOBS_COMPLETED_TOTAL: &str = "jobs_completed_total";
    pub const JOBS_FAILED_TOTAL: &str = "jobs_failed_total";
    pub const JOBS_CANCELLED_TOTAL: &str = "jobs_cancelled_total";
    pub const JOB_DURATION_MS: &str = "job_duration_ms";

    // Gauges
    pub const ACTIVE_CONNECTIONS: &str = "active_connections";
    pub const ACTIVE_JOBS: &str = "active_jobs";
    pub const QUEUE_SIZE: &str = "queue_size";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_counter() {
        let metrics = MetricsCollector::new();
        metrics.increment_counter("test_counter");
        metrics.increment_counter("test_counter");
        metrics.add_counter("test_counter", 3);

        let snapshot = metrics.snapshot();
        assert_eq!(snapshot.counters.get("test_counter"), Some(&5));
    }

    #[test]
    fn test_histogram() {
        let metrics = MetricsCollector::new();
        metrics.record_histogram("test_histogram", 1.0);
        metrics.record_histogram("test_histogram", 2.0);
        metrics.record_histogram("test_histogram", 3.0);
        metrics.record_histogram("test_histogram", 4.0);
        metrics.record_histogram("test_histogram", 5.0);

        let snapshot = metrics.snapshot();
        let stats = snapshot.histograms.get("test_histogram").unwrap();

        assert_eq!(stats.count, 5);
        assert_eq!(stats.min, 1.0);
        assert_eq!(stats.max, 5.0);
        assert_eq!(stats.mean, 3.0);
    }

    #[test]
    fn test_gauge() {
        let metrics = MetricsCollector::new();
        metrics.set_gauge("test_gauge", 42.5);

        let snapshot = metrics.snapshot();
        assert_eq!(snapshot.gauges.get("test_gauge"), Some(&42.5));
    }

    #[test]
    fn test_reset() {
        let metrics = MetricsCollector::new();
        metrics.increment_counter("test");
        metrics.reset();

        let snapshot = metrics.snapshot();
        assert!(snapshot.counters.is_empty());
    }

    #[test]
    fn test_export_json() {
        let metrics = MetricsCollector::new();
        metrics.increment_counter("test");

        let json = metrics.export_json();
        assert!(json.is_ok());
        assert!(json.unwrap().contains("test"));
    }
}
