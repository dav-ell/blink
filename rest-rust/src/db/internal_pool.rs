use sqlx::{sqlite::SqlitePoolOptions, SqlitePool};
use std::path::Path;

/// Create an async SQLite connection pool for internal databases
/// (jobs, devices, etc.)
pub async fn create_internal_pool(database_url: &str) -> Result<SqlitePool, sqlx::Error> {
    // Ensure the parent directory exists
    if let Some(parent) = Path::new(database_url.trim_start_matches("sqlite://")).parent() {
        std::fs::create_dir_all(parent).ok();
    }

    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(database_url)
        .await?;

    Ok(pool)
}

pub type InternalDbPool = SqlitePool;
