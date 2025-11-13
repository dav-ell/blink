pub mod api;
pub mod config;
pub mod db;
pub mod models;
pub mod services;
pub mod utils;
pub mod error;

pub use config::Settings;
pub use error::{AppError, Result};

use sqlx::SqlitePool;

/// Application state shared across handlers
pub struct AppState {
    pub settings: Settings,
    pub job_pool: SqlitePool,
}

