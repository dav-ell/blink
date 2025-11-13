pub mod api;
pub mod config;
pub mod db;
pub mod models;
pub mod services;
pub mod utils;
pub mod error;
pub mod middleware;

pub use config::Settings;
pub use error::{AppError, Result};
pub use utils::{MetricsCollector, RequestContext};

use sqlx::SqlitePool;

/// Application state shared across handlers
pub struct AppState {
    pub settings: Settings,
    pub job_pool: SqlitePool,
    pub metrics: MetricsCollector,
    pub circuit_breaker: middleware::DeviceCircuitBreaker,
}

