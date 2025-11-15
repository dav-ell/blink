use axum::{extract::State, Json};
use serde_json::{json, Value};
use std::sync::Arc;

use crate::{AppState, Result};

/// Get current metrics snapshot
pub async fn get_metrics(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    let snapshot = state.metrics.snapshot();
    let circuit_breaker_stats = state.circuit_breaker.get_statistics();

    Ok(Json(json!({
        "timestamp": snapshot.timestamp,
        "uptime_seconds": snapshot.uptime_seconds,
        "counters": snapshot.counters,
        "histograms": snapshot.histograms,
        "gauges": snapshot.gauges,
        "circuit_breakers": circuit_breaker_stats,
    })))
}

/// Export metrics in Prometheus format
pub async fn get_metrics_prometheus(State(state): State<Arc<AppState>>) -> Result<String> {
    let snapshot = state.metrics.snapshot();
    let circuit_breaker_stats = state.circuit_breaker.get_statistics();

    let mut output = String::new();

    // Add timestamp as comment
    output.push_str(&format!(
        "# Metrics snapshot at timestamp {}\n",
        snapshot.timestamp
    ));
    output.push_str(&format!(
        "# Uptime: {} seconds\n\n",
        snapshot.uptime_seconds
    ));

    // Export counters
    for (name, value) in &snapshot.counters {
        output.push_str(&format!("# TYPE {} counter\n", name));
        output.push_str(&format!("{} {}\n\n", name, value));
    }

    // Export histograms as summaries
    for (name, stats) in &snapshot.histograms {
        output.push_str(&format!("# TYPE {} summary\n", name));
        output.push_str(&format!("{}_count {}\n", name, stats.count));
        output.push_str(&format!("{}_sum {}\n", name, stats.sum));
        output.push_str(&format!("{}{{quantile=\"0.5\"}} {}\n", name, stats.p50));
        output.push_str(&format!("{}{{quantile=\"0.95\"}} {}\n", name, stats.p95));
        output.push_str(&format!("{}{{quantile=\"0.99\"}} {}\n\n", name, stats.p99));
    }

    // Export gauges
    for (name, value) in &snapshot.gauges {
        output.push_str(&format!("# TYPE {} gauge\n", name));
        output.push_str(&format!("{} {}\n\n", name, value));
    }

    // Export circuit breaker states
    output.push_str("# TYPE circuit_breaker_state gauge\n");
    for (device_id, stats) in &circuit_breaker_stats {
        let state_value = match stats.state {
            crate::middleware::circuit_breaker::CircuitBreakerState::Closed => 0,
            crate::middleware::circuit_breaker::CircuitBreakerState::HalfOpen => 1,
            crate::middleware::circuit_breaker::CircuitBreakerState::Open => 2,
        };
        output.push_str(&format!(
            "circuit_breaker_state{{device_id=\"{}\"}} {}\n",
            device_id, state_value
        ));
    }
    output.push('\n');

    output.push_str("# TYPE circuit_breaker_failures counter\n");
    for (device_id, stats) in &circuit_breaker_stats {
        output.push_str(&format!(
            "circuit_breaker_failures{{device_id=\"{}\"}} {}\n",
            device_id, stats.failure_count
        ));
    }

    Ok(output)
}

/// Reset metrics (useful for testing)
pub async fn reset_metrics(State(state): State<Arc<AppState>>) -> Result<Json<Value>> {
    state.metrics.reset();

    Ok(Json(json!({
        "status": "ok",
        "message": "Metrics reset successfully"
    })))
}
